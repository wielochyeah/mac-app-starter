"""Tests for scripts/check_texts.py and the shared matcher in scripts/rules_lib.py."""
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rules_testlib import ROOT, Repo, pack_files, repo_terms  # noqa: E402

import check_texts  # noqa: E402
import rules_lib  # noqa: E402

TEXT_FILE = "App/Sources/Modules/Demo/DemoText.swift"
VIEW_FILE = "App/Sources/Modules/Demo/DemoView.swift"


def ids(findings):
    return [f.term_id for f in findings]


class PackParityTests(unittest.TestCase):
    """Every example of every active text term is found by the checks exactly as rules_sync tests it."""

    def test_examples_hit_through_find_findings(self):
        terms = {t.id: t for t in repo_terms()}
        checked = 0
        for pack in pack_files():
            if pack.get("pruefer", "check_texts") != "check_texts":
                continue
            for raw in pack["begriffe"]:
                term = terms.get(raw["id"])
                if term is None:
                    continue
                area, lang = raw["bereiche"][0], pack["sprachen"][0]
                text = lambda s: rules_lib.blank_markdown(s) if area == "doku" and term.verfahren is None else s  # noqa: E731
                for example in raw["beispiele"]["treffer"]:
                    found = rules_lib.find_findings(text(example), [term], area, lang)
                    self.assertTrue(found, f"{term.id}: {example!r}")
                    checked += 1
                for example in raw["beispiele"]["erlaubt"]:
                    self.assertEqual(rules_lib.find_findings(example, [term], area, lang), [], f"{term.id}: {example!r}")
        self.assertGreater(checked, 150)

    def test_language_filter(self):
        terms = repo_terms()
        self.assertTrue(rules_lib.find_findings("Seamless sync", terms, "ui", "en"))
        self.assertEqual(rules_lib.find_findings("Seamless sync", [t for t in terms if t.paket == "floskeln-en"], "ui", "de"), [])
        self.assertTrue(rules_lib.find_findings("Einstellungen", terms, "ui", "en"))
        self.assertEqual(rules_lib.find_findings("Einstellungen", terms, "ui", "de"), [])

    def test_a_character_hit_by_two_terms_is_reported_once(self):
        found = rules_lib.find_findings("Los geht’s", repo_terms(), "ui", "de")
        self.assertEqual(len(found), 1)

    def test_shortcut_glyphs_pass(self):
        for text in ("Drücke ⇧⌘K", "⌃⌥← springt", "⌘, öffnet die Einstellungen", "Mit ↑/↓ wählen", "⇪ ist an", "⌥⏎ fügt ein"):
            self.assertEqual(rules_lib.find_findings(text, repo_terms(), "ui", "de"), [], text)


class MarkdownTests(unittest.TestCase):
    def test_code_and_comments_are_blanked_with_offsets_kept(self):
        text = "Satz mit `Gespeichert!` und\n```\nGespeichert!\n```\n<!-- Gespeichert! -->\n[Link](https://a.b/x!)\n"
        blanked = rules_lib.blank_markdown(text)
        self.assertEqual(len(blanked), len(text))
        self.assertEqual(blanked.count("\n"), text.count("\n"))
        self.assertNotIn("!", blanked)
        self.assertIn("[Link]", blanked)

    def test_hard_wrapped_paragraph(self):
        breaks = rules_lib.markdown_paragraph_breaks
        self.assertTrue(breaks("Ein Absatz, der\nweiterläuft."))
        self.assertTrue(breaks("- Punkt, der\n  weiterläuft."))
        self.assertTrue(breaks("> Zitat\n> weiter"))
        self.assertEqual(breaks("- eins\n- zwei\n\nText\n\n| a | b |\n|---|---|"), [])
        self.assertEqual(breaks("# Titel\nText"), [])
        self.assertEqual(breaks("Zeile  \nweiter"), [])
        self.assertEqual(breaks("Text\n1. Schritt"), [])


class CheckTextsTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def run_checks(self, files=None):
        for rel, text in (files or {}).items():
            self.repo.write(rel, text)
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        return findings

    def text_file(self, body):
        return self.run_checks({TEXT_FILE: "enum DemoText {\n" + body + "\n}\n"})

    def test_clean_text_file_passes(self):
        findings = self.text_file('    static var a: String { tr(en: "Open \\(name)", de: "\\(name) öffnen") }\n'
                                  '    static var b: String { tr(en: "Settings…", de: "Einstellungen …") }\n'
                                  '    static var c: String {\n        tr(en: "Two lines.\\nSecond line.",\n           de: "Zwei Zeilen.\\nZweite Zeile.")\n    }')
        self.assertEqual(findings, [])

    def test_both_languages_are_checked_with_their_packs(self):
        findings = self.text_file('    static var a: String { tr(en: "Seamless sync!", de: "Nahtlos — schnell") }')
        self.assertEqual(sorted(ids(findings)), sorted(["floskel-en", "ausrufezeichen", "floskel", "gedankenstrich"]))
        lines = {f.line for f in findings}
        self.assertEqual(lines, {2})

    def test_swapped_languages_are_found(self):
        findings = self.text_file('    static var a: String { tr(en: "Einstellungen öffnen", de: "Open Settings") }')
        self.assertIn("deutsch-zeichen", ids(findings))
        self.assertIn("englisch-wort", ids(findings))

    def test_sie_form_is_wrong_with_du(self):
        findings = self.text_file('    static var a: String { tr(en: "Pick an item", de: "Wählen Sie einen Eintrag") }')
        self.assertEqual(ids(findings), ["sie-form"])

    def test_empty_language(self):
        findings = self.text_file('    static var a: String { tr(en: "Done", de: "") }')
        self.assertEqual(ids(findings), ["leerer-text"])

    def test_interpolations_must_match(self):
        findings = self.text_file('    static func a(_ n: Int) -> String { tr(en: "\\(n) files", de: "Dateien") }')
        self.assertEqual(ids(findings), ["einsetzungen"])

    def test_ellipsis_rules(self):
        findings = self.text_file('    static var a: String { tr(en: "Open…", de: "Öffnen") }\n'
                                  '    static var b: String { tr(en: "Open…", de: "Öffnen…") }\n'
                                  '    static var c: String { tr(en: "Open …", de: "Öffnen …") }\n'
                                  '    static var d: String { tr(en: "Loading...", de: "Lädt …") }')
        self.assertEqual(sorted(ids(findings)), sorted(["auslassung-paar", "auslassung-de", "auslassung-en", "auslassung", "auslassung-paar"]))

    def test_hard_break_inside_a_sentence(self):
        findings = self.text_file('    static var a: String { tr(en: "One line\\nbroken", de: "Ein Satz\\ngebrochen") }')
        self.assertEqual(ids(findings), ["harter-umbruch", "harter-umbruch"])

    def test_multiline_literal_lines_are_reported_where_they_are(self):
        source = ('    static var a: String {\n        tr(en: """\n            First.\n            Seamless.\n            """,\n'
                  '           de: """\n            Erst.\n            Dann.\n            """)\n    }')
        findings = self.text_file(source)
        self.assertEqual([(f.term_id, f.line) for f in findings], [("floskel-en", 5)])

    def test_tr_literal_outside_text_file(self):
        findings = self.run_checks({VIEW_FILE: 'let a = tr(en: "Hi", de: "Hallo")\nlet b = tr(en: config.en, de: config.de)\n'})
        self.assertEqual(ids(findings), ["tr-ausserhalb"])

    def test_one_literal_and_concatenation(self):
        findings = self.text_file('    static var a: String { tr(en: "Hi", de: greeting) }\n'
                                  '    static var b: String { tr(en: "Hi " + name, de: "Hallo " + name) }')
        self.assertEqual(ids(findings), ["tr-ohne-literal", "tr-zusammengesetzt"])

    def test_ui_literals_in_views(self):
        view = "\n".join([
            'Text("Hello")',
            'Text(DemoText.a)',
            'Text("\\(count)")',
            'Text("")',
            'Image(systemName: "gear")',
            'Label("Title", systemImage: "star")',
            'Text(flag ? "On" : "Off")',
            'Text(Image(systemName: "star"))',
            'view.help("Tip")',
            'NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")',
            'item.toolTip = "Hint"',
            'StatusMark(.ok, "Fertig")',
            'TileOption("auto", title: "Auto", detail: DemoText.a)',
            'OnboardingHint(["Eins", "Zwei"])',
            'Button { run() } label: { Image(systemName: "play") }',
            'ToggleRow(DemoText.a, isOn: $on)',
            'Log.info("plain log line")',
        ])
        findings = self.run_checks({VIEW_FILE: view + "\n"})
        literals = [(f.line, f.match) for f in findings if f.term_id == "ui-literal"]
        self.assertEqual(literals, [(1, "Hello"), (6, "Title"), (7, "On"), (7, "Off"), (9, "Tip"), (10, "Quit"), (11, "Hint"),
                                    (12, "Fertig"), (13, "Auto"), (14, "Eins"), (14, "Zwei")])

    def test_verbatim_needs_a_reason(self):
        findings = self.run_checks({VIEW_FILE: 'Text(verbatim: "fg2")\n// verbatim: token name, not copy\nText(verbatim: "fg3")\nText(verbatim: name)\n'})
        self.assertEqual([(f.term_id, f.line) for f in findings], [("verbatim-ohne-grund", 1)])

    def test_exception_comment(self):
        source = ('enum DemoText {\n'
                  '    // text-ausnahme: shown in the other language on purpose\n'
                  '    static var a: String {\n'
                  '        tr(en: "Lieber auf Deutsch?", de: "Prefer English?")\n'
                  '    }\n'
                  '    // text-ausnahme: nothing below needs it\n'
                  '    static var b: String { tr(en: "Done", de: "Fertig") }\n'
                  '    // text-ausnahme:\n'
                  '}\n')
        findings = self.run_checks({TEXT_FILE: source})
        self.assertEqual([(f.term_id, f.line) for f in findings], [("ausnahme-ungenutzt", 6), ("ausnahme-ohne-grund", 8)])

    def test_comments_in_swift_and_python(self):
        findings = self.run_checks({
            VIEW_FILE: '// Strang D builds this.\nlet a = "Strang D" // fine: the reason is given here\n/* seamless */\n',
            "scripts/demo.py": '#!/usr/bin/env python3\n# see BAUPLAN for details\nx = "Strang"  # ok\n',
        })
        self.assertEqual([(f.path, f.term_id, f.line) for f in findings],
                         [("App/Sources/Modules/Demo/DemoView.swift", "kommentar-verweis", 1),
                          ("App/Sources/Modules/Demo/DemoView.swift", "floskel-en", 3),
                          ("scripts/demo.py", "kommentar-verweis", 2)])

    def test_scope_exception_limits_areas(self):
        findings = self.run_checks({"scripts/tests/test_demo.py": "# Strang D\n"})
        self.assertEqual(findings, [])

    def test_markdown_docs(self):
        findings = self.run_checks({"docs/DEMO.md": "# Titel\n\nGespeichert! Und `Gespeichert!` im Code.\n\nEin Absatz, der\nweiterläuft.\n",
                                    "docs/bau/status/X.md": "Gespeichert!\n"})
        self.assertEqual([(f.term_id, f.line) for f in findings], [("ausrufezeichen", 3), ("absatz-umbruch", 5)])

    def test_infoplist_values(self):
        self.repo.write_json("App/Resources/InfoPlist.json", {
            "_comment": "Nicht geprüft!",
            "NSMicrophoneUsageDescription": {"en": "Für Diktate.", "de": "Für Diktate."},
            "NSCameraUsageDescription": {"en": "Photos", "de": ""},
        })
        findings = self.run_checks()
        self.assertEqual(sorted(ids(findings)), ["deutsch-zeichen", "leerer-text"])


class BaselineTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.repo.write(VIEW_FILE, 'Text("Hello")\n')

    def tearDown(self):
        self.repo.close()

    def main(self, *args):
        out = io.StringIO()
        with redirect_stdout(out):
            code = check_texts.main(list(args) + ["--wurzel", str(self.repo.root)])
        return code, out.getvalue()

    def test_known_findings_pass_and_the_baseline_only_shrinks(self):
        self.assertEqual(self.main()[0], 1)
        code, output = self.main("--baseline-aktualisieren")
        self.assertEqual(code, 1, "the baseline may not grow")
        self.assertIn("nur schrumpfen", output)
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        self.repo.write_json(check_texts.BASELINE, rules_lib.to_baseline(findings))
        self.assertEqual(self.main()[0], 0)
        self.assertEqual(self.main("--streng")[0], 1)
        self.repo.write(VIEW_FILE, 'Text(DemoText.hello)\n')
        code, output = self.main()
        self.assertEqual(code, 1, "a stale entry fails")
        self.assertIn("Verkleinern", output)
        self.assertEqual(self.main("--baseline-aktualisieren")[0], 0)
        self.assertEqual(self.repo.read_json(check_texts.BASELINE), {})
        self.assertEqual(self.main()[0], 0)

    def test_new_finding_of_the_same_term_in_the_same_file_fails(self):
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        self.repo.write_json(check_texts.BASELINE, rules_lib.to_baseline(findings))
        self.repo.write(VIEW_FILE, 'Text("Hello")\nText("World")\n')
        self.assertEqual(self.main()[0], 1)

    def test_json_report(self):
        report = self.repo.path("report.json")
        self.main("--json", str(report))
        data = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(data["neu"][0]["term_id"], "ui-literal")


class RepositoryTests(unittest.TestCase):
    def test_baseline_file_is_valid(self):
        baseline = rules_lib.load_baseline(ROOT / check_texts.BASELINE)
        self.assertIsInstance(baseline, dict)


if __name__ == "__main__":
    unittest.main()
