"""Tests for scripts/rules_sync.py (run: python3 -m unittest discover -s scripts/tests -t .)."""
import io
import json
import re
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rules_testlib import ROOT, Repo  # noqa: E402

import rules_lib  # noqa: E402
import rules_sync  # noqa: E402


def run_main(args):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = rules_sync.main(args)
    return code, out.getvalue() + err.getvalue()


class RepositoryRulesTests(unittest.TestCase):
    def test_rules_of_this_repository_are_valid_and_in_sync(self):
        errors, outputs, summary = rules_sync.sync(ROOT)
        self.assertEqual(errors, [])
        stale = [file for file, expected, current in outputs if expected != current]
        self.assertEqual(stale, [], "make rules ausführen")
        self.assertIn("Anrede du", summary)

    def test_generated_terms_compile_with_python_re(self):
        for term in rules_lib.load_terms(ROOT):
            if term.quelle is not None:
                self.assertIsNotNone(term.regex, term.id)

    def test_ai_writing_rules_hold_exactly_the_rules_marked_ki(self):
        data = json.loads((ROOT / rules_sync.GENERATED_AI).read_text(encoding="utf-8"))
        ids = [r["id"] for r in data["regeln"]]
        self.assertIn("S-01", ids)
        self.assertNotIn("S-12", ids)
        self.assertNotIn("A-01", ids)


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def sync_errors(self):
        errors, _, _ = rules_sync.sync(self.repo.root)
        return errors

    def edit_pack(self, name, change):
        self.repo.edit_json(f"rules/pakete/{name}.json", change)

    def test_copy_is_valid(self):
        self.assertEqual(self.sync_errors(), [])

    def test_example_that_does_not_hit_fails(self):
        self.edit_pack("zeichen", lambda p: p["begriffe"][0]["beispiele"]["treffer"].append("ganz normaler Text"))
        self.assertTrue(any("Beispiel wird nicht erkannt" in e and "ganz normaler Text" in e for e in self.sync_errors()))

    def test_allowed_example_that_hits_fails(self):
        self.edit_pack("floskeln-en", lambda p: p["begriffe"][0]["beispiele"]["erlaubt"].append("Seamless"))
        self.assertTrue(any("erlaubtes Beispiel wird gemeldet" in e for e in self.sync_errors()))

    def test_pattern_that_does_not_compile_fails(self):
        self.edit_pack("platzhalter", lambda p: p["begriffe"][0]["muster"].append("(unclosed"))
        self.assertTrue(any("kompiliert nicht" in e for e in self.sync_errors()))

    def test_ascii_apostrophe_without_typographic_one_fails(self):
        def change(p):
            p["begriffe"][0]["muster"].append(r"geht's")
            p["begriffe"][0]["beispiele"]["treffer"].append("geht's")
        self.edit_pack("floskeln", change)
        self.assertTrue(any("Apostroph" in e for e in self.sync_errors()))

    def test_apostrophe_check(self):
        ok = rules_sync._apostrophe_ok
        self.assertTrue(ok(r"los\s+geht['’]s"))
        self.assertTrue(ok(r"[)\]“”\"'’.]"))
        self.assertFalse(ok(r"let's"))
        self.assertFalse(ok(r"[a']"))
        self.assertTrue(ok(r"\'"))

    def test_schema_reports_unknown_and_missing_fields(self):
        def change(p):
            p["begriffe"][0]["farbe"] = "rot"
            del p["begriffe"][0]["hinweis"]
        self.edit_pack("platzhalter", change)
        errors = self.sync_errors()
        self.assertTrue(any("unbekanntes Feld farbe" in e for e in errors))
        self.assertTrue(any("Feld hinweis fehlt" in e for e in errors))

    def test_schema_reports_wrong_enum(self):
        self.edit_pack("platzhalter", lambda p: p["begriffe"][0].update(bereiche=["ueberall"]))
        self.assertTrue(any("nicht erlaubt" in e for e in self.sync_errors()))

    def test_duplicate_term_id_fails(self):
        self.edit_pack("platzhalter", lambda p: p["begriffe"][0].update(id="mittelpunkt"))
        self.assertTrue(any("id doppelt" in e for e in self.sync_errors()))

    def test_rule_naming_unknown_pack_fails(self):
        self.repo.edit_json("rules/gruppen/schreiben.json", lambda g: g["regeln"][0]["pakete"].append("gibt-es-nicht"))
        self.assertTrue(any("unbekanntes Paket" in e for e in self.sync_errors()))

    def test_term_naming_unknown_rule_fails(self):
        self.edit_pack("platzhalter", lambda p: p["begriffe"][0].update(regeln=["S-99"]))
        self.assertTrue(any("unbekannte Regel" in e for e in self.sync_errors()))

    def test_pack_without_rule_fails(self):
        self.repo.edit_json("rules/gruppen/schreiben.json",
                            lambda g: [r.update(pakete=[p for p in r["pakete"] if p != "platzhalter"]) for r in g["regeln"]])
        self.assertTrue(any("platzhalter" in e and "keiner Regel" in e for e in self.sync_errors()))

    def test_rule_id_must_match_prefix(self):
        self.repo.edit_json("rules/gruppen/design.json", lambda g: g["regeln"][0].update(id="S-77"))
        self.assertTrue(any("id muss D-NN lauten" in e for e in self.sync_errors()))

    def test_missing_tool_path_fails(self):
        self.repo.edit_json("rules/index.json", lambda i: i["werkzeuge"].append({"name": "x", "regeln": ["A-01"], "pfad": "fehlt/hier"}))
        self.assertTrue(any("fehlt/hier fehlt" in e for e in self.sync_errors()))

    def test_design_pack_needs_exception_comment(self):
        self.edit_pack("gestaltung", lambda p: p.pop("ausnahmeKommentar"))
        self.assertTrue(any("ausnahmeKommentar fehlt" in e for e in self.sync_errors()))

    def test_text_pack_needs_languages(self):
        self.edit_pack("platzhalter", lambda p: p.pop("sprachen"))
        self.assertTrue(any("sprachen fehlt" in e for e in self.sync_errors()))

    def test_missing_markers_fail(self):
        self.repo.write("CLAUDE.md", "# CLAUDE.md\n")
        self.assertTrue(any("Markierungen" in e for e in self.sync_errors()))

    def test_writes_part_a_and_keeps_part_b(self):
        claude = self.repo.path("CLAUDE.md").read_text(encoding="utf-8")
        start, end = claude.index(rules_sync.START_MARKER), claude.index(rules_sync.END_MARKER)
        stale = claude[:start] + rules_sync.START_MARKER + "\nveraltet\n" + claude[end:]
        stale = stale.replace("## Teil B: Projekt", "## Teil B: Projekt\n\nEigener Satz des Projekts.")
        self.repo.write("CLAUDE.md", stale)
        code, output = run_main(["--pruefen", "--wurzel", str(self.repo.root)])
        self.assertEqual(code, 1)
        self.assertIn("weicht von rules/ ab: CLAUDE.md", output)
        code, _ = run_main(["--wurzel", str(self.repo.root)])
        self.assertEqual(code, 0)
        written = self.repo.path("CLAUDE.md").read_text(encoding="utf-8")
        self.assertNotIn("veraltet", written)
        self.assertIn("Eigener Satz des Projekts.", written)
        self.assertIn("- **S-01**", written)
        code, output = run_main(["--check", "--wurzel", str(self.repo.root)])
        self.assertEqual(code, 0, output)

    def test_anrede_sie_swaps_the_address_term(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(anrede="sie"))
        run_main(["--wurzel", str(self.repo.root)])
        ids = {t.id for t in self.repo.terms()}
        self.assertIn("du-form", ids)
        self.assertNotIn("sie-form", ids)
        self.assertIn("Anrede laut `starter.json`: `sie`", self.repo.path("CLAUDE.md").read_text(encoding="utf-8"))

    def test_invalid_anrede_fails(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(anrede="ihr"))
        self.assertTrue(any("texts.anrede" in e for e in self.sync_errors()))

    def test_extra_pack_is_switched_on(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(zusatzpakete=["zeitwoerter"]))
        run_main(["--wurzel", str(self.repo.root)])
        self.assertIn("zeitwort", {t.id for t in self.repo.terms()})

    def test_unknown_or_active_extra_pack_fails(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(zusatzpakete=["gibt-es-nicht", "zeichen"]))
        errors = self.sync_errors()
        self.assertTrue(any("unbekanntes Paket" in e for e in errors))
        self.assertTrue(any("ohnehin aktiv" in e for e in errors))

    def test_people_become_words_of_the_comment_pack(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(personen=["Anna", "Müller"]))
        run_main(["--wurzel", str(self.repo.root)])
        term = next(t for t in self.repo.terms() if t.id == "kommentar-verweis")
        self.assertTrue(rules_lib.matches(term, "// Anna fixed this"))
        self.assertTrue(rules_lib.matches(term, "// as Müller said"))
        self.assertFalse(rules_lib.matches(term, "// Annabelle"))

    def test_person_must_be_one_word(self):
        self.repo.edit_json("starter.json", lambda c: c["texts"].update(personen=["Anna Müller"]))
        self.assertTrue(any("kein einzelnes Wort" in e for e in self.sync_errors()))

    def test_project_rules_and_packs_are_rendered_and_active(self):
        self.repo.edit_json("rules/projekt/projekt.json", lambda g: g["regeln"].append({
            "id": "P-01", "schluessel": "fachwort", "text": "Kunden heißen im UI Mitglieder.", "pakete": ["projekt-woerter"],
            "durchsetzung": ["make check-texts"], "ki": True}))
        self.repo.write_json("rules/projekt/pakete/projekt-woerter.json", {
            "id": "projekt-woerter", "titel": "Fachwörter", "gruppe": "projekt", "standardAktiv": True, "abschaltbar": False,
            "sprachen": ["de"], "beschreibung": "Fachwörter des Projekts.",
            "begriffe": [{"id": "kunde", "label": "Kunde", "hinweis": "Mitglied", "art": "woerter", "muster": ["Kunden?"],
                          "flags": "", "bereiche": ["ui"], "beispiele": {"treffer": ["Neuer Kunde"], "erlaubt": ["Kundin"]}}]})
        code, output = run_main(["--wurzel", str(self.repo.root)])
        self.assertEqual(code, 0, output)
        claude = self.repo.path("CLAUDE.md").read_text(encoding="utf-8")
        block = claude[claude.index(rules_sync.PROJECT_START_MARKER):]
        self.assertIn("- **P-01** Kunden heißen im UI Mitglieder.", block)
        self.assertIn("`projekt-woerter`", block)
        self.assertIn("kunde", {t.id for t in self.repo.terms()})
        ai = self.repo.read_json(rules_sync.GENERATED_AI)
        self.assertIn("P-01", [r["id"] for r in ai["regeln"]])


class ValidatorTests(unittest.TestCase):
    def check(self, value, schema):
        errors = []
        rules_sync.validate(value, schema, schema, "x", lambda where, message: errors.append(message))
        return errors

    def test_types_patterns_and_lengths(self):
        schema = {"type": "object", "required": ["id"], "additionalProperties": False,
                  "properties": {"id": {"type": "string", "pattern": "^[A-Z]-\\d{2}$"}, "list": {"type": "array", "minItems": 1, "items": {"type": "string", "minLength": 1}}}}
        self.assertEqual(self.check({"id": "S-01", "list": ["a"]}, schema), [])
        self.assertTrue(self.check({"id": "S1"}, schema))
        self.assertTrue(self.check({"id": "S-01", "list": []}, schema))
        self.assertTrue(self.check({"id": "S-01", "list": [""]}, schema))
        self.assertTrue(self.check({"id": 3}, schema))
        self.assertTrue(self.check({}, schema))

    def test_refs_resolve_to_defs(self):
        schema = {"type": "array", "items": {"$ref": "#/$defs/x"}, "$defs": {"x": {"enum": ["a", "b"]}}}
        self.assertEqual(self.check(["a", "b"], schema), [])
        self.assertTrue(self.check(["c"], schema))


class GlobTests(unittest.TestCase):
    def test_globs(self):
        self.assertTrue(rules_lib.path_matches("App/Sources/Kit/Design/Theme.swift", ["App/Sources/Kit/Design/**"]))
        self.assertFalse(rules_lib.path_matches("App/Sources/Kit/DesignX/Theme.swift", ["App/Sources/Kit/Design/**"]))
        self.assertTrue(rules_lib.path_matches("ai-worker/.venv/lib/x.py", ["**/.venv/**"]))
        self.assertTrue(rules_lib.path_matches(".venv/x.py", ["**/.venv/**"]))
        self.assertFalse(rules_lib.path_matches("docs/a/b.md", ["docs/*.md"]))
        self.assertTrue(rules_lib.path_matches("docs/b.md", ["docs/*.md"]))


if __name__ == "__main__":
    unittest.main()
