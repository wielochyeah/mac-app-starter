"""Tests for scripts/check_texts.py and the shared matcher in scripts/rules_lib.py."""
import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
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
        self.assertEqual(code, 0, "a fixed finding keeps a strand green locally")
        self.assertIn("Verkleinern", output)
        self.assertEqual(self.main("--ci")[0], 1, "in CI a stale entry fails")
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


class UiPositionTests(unittest.TestCase):
    """UI text in the places the kit contracts and patterns take it."""

    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def literals(self, view):
        self.repo.write(VIEW_FILE, view + "\n")
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        return [(f.line, f.match) for f in findings if f.term_id == "ui-literal"]

    def test_title_closures_of_the_registry(self):
        view = "\n".join([
            'Registry.pages.append(AppPage(id: "home", section: .main, order: 0, title: { "Home" }, symbol: "house", content: { AnyView(EmptyView()) }))',
            'MenuItemContribution(id: "x", order: 1, title: { "Show Window" }, symbol: nil, shortcut: nil, action: {})',
            'SettingsPane(id: "general", group: .settings, order: 0, title: { return "General" }, symbol: "gear", tint: .graphite, content: { AnyView(EmptyView()) })',
            'GalleryEntry(id: "buttons", area: "controls", title: { "Buttons" }, content: { AnyView(EmptyView()) })',
            'WindowHost.show(id: "main", style: .main, title: { "Main Window" }) { AnyView(EmptyView()) }',
            'AppPage(id: "notes", section: .main, order: 1, title: { NotesText.title }, symbol: "note", content: { AnyView(Text(NotesText.title)) })',
        ])
        self.assertEqual(self.literals(view), [(1, "Home"), (2, "Show Window"), (3, "General"), (4, "Buttons"), (5, "Main Window")])

    def test_onboarding_patterns(self):
        view = "\n".join([
            'OnboardingFooter(count: 5, index: 0, advanceTitle: "Start now", back: nil, advance: {})',
            'slot = .granted("Access granted")',
            'slot = .restartNeeded("Restart needed", buttonTitle: "Restart", restart: {})',
            'slot = .waiting(button: .init(title: "Open Settings", action: {}))',
            'slot = .denied(button: .openSettings(open))',
        ])
        self.assertEqual(self.literals(view), [(1, "Start now"), (2, "Access granted"), (3, "Restart needed"), (3, "Restart"),
                                               (4, "Open Settings")])

    def test_formats_assignments_and_appkit(self):
        view = "\n".join([
            'Text(String(format: "%d files", n))',
            'let clock = String(format: "%d:%02d", m, s)',
            'let label = String(format: "%.2f s", t)',
            'content.body = "Your export is ready"',
            'NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)',
            'Text(String(localized: "Welcome"))',
        ])
        self.assertEqual(self.literals(view), [(1, "%d files"), (4, "Your export is ready"), (5, "Launch at login"), (6, "Welcome")])

    def test_tab_value_is_an_id(self):
        self.assertEqual(self.literals('Tab(WindowText.home, systemImage: "house", value: "home")\nTab("Home", systemImage: "house", value: 0)'),
                         [(2, "Home")])


class CommentAndGlyphTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def check(self, files):
        for rel, text in files.items():
            self.repo.write(rel, text)
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        return [(f.path.split("/")[-1], f.term_id, f.line) for f in findings]

    def test_code_and_arithmetic_in_comments_are_not_prose(self):
        source = ("/// Cache layout: `<hub>/models--org--name/snapshots`\n"
                  "// width = 900 - sidebar 224 - panel inset 8\n"
                  "/// ↑ / ↓ move the selection, ↩ opens it, 🌐E shows emoji\n"
                  "// Saved - restart to apply\n"
                  "let a = 1\n")
        self.assertEqual(self.check({VIEW_FILE: source}), [("DemoView.swift", "gedankenstrich", 4)])

    def test_exception_comment_covers_a_comment(self):
        source = ("// text-ausnahme: the cache folder is named like this on disk\n"
                  "/// Cache layout: models--org--name\n"
                  "let a = 1\n")
        self.assertEqual(self.check({VIEW_FILE: source}), [])
        python = "# text-ausnahme: quotes the folder name\n# models--org--name\nx = 1\n# text-ausnahme: unused here\n"
        self.assertEqual(self.check({"scripts/demo.py": python}), [("demo.py", "ausnahme-ungenutzt", 4)])

    def test_unused_verbatim_comment(self):
        source = "// verbatim: token name\nlet a = 1\nText(verbatim: name) // verbatim: digits only\n"
        self.assertEqual(self.check({VIEW_FILE: source}), [("DemoView.swift", "ausnahme-ungenutzt", 1)])

    def test_key_glyphs_in_ui_texts(self):
        body = ('enum DemoText {\n'
                '    static var a: String { tr(en: "Press ↑ or ↓ to move, ↩ to open", de: "Mit ↑ oder ↓ wechseln, mit ↩ öffnen") }\n'
                '    static var b: String { tr(en: "Press 🌐E for emoji, ⇞ and ⇟ to scroll", de: "Mit 🌐E Emoji, mit ⇞ und ⇟ blättern") }\n'
                '    static var c: String { tr(en: "Draft → Review", de: "Entwurf → Prüfung") }\n'
                '    static var d: String { tr(en: "Language 🌐", de: "Sprache 🌐") }\n'
                '}\n')
        self.assertEqual(self.check({TEXT_FILE: body}), [("DemoText.swift", "pfeil", 4), ("DemoText.swift", "pfeil", 4),
                                                         ("DemoText.swift", "emoji", 5), ("DemoText.swift", "emoji", 5)])


class TrPairTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def text_file(self, body):
        self.repo.write(TEXT_FILE, "enum DemoText {\n" + body + "\n}\n")
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        return [(f.term_id, f.line) for f in findings]

    def test_language_members_of_one_insert_match(self):
        self.assertEqual(self.text_file('    static func a(_ p: Phrase) -> String { tr(en: "Say \\(p.en)", de: "Sag \\(p.de)") }'), [])
        self.assertEqual(self.text_file('    static func a(_ p: Phrase) -> String { tr(en: "Say \\(p.en)", de: "Sag \\(q.de)") }'),
                         [("einsetzungen", 2)])

    def test_deliberate_break_needs_its_reason(self):
        body = ('    // umbruch: balanced two-line subtitle under the step title\n'
                '    static var a: String { tr(en: "Allow access to type at your cursor\\nand see which app you write in.", '
                'de: "Erlaube den Zugriff, um am Cursor zu schreiben\\nund zu sehen, in welcher App du schreibst.") }\n'
                '    static var b: String { tr(en: "One line\\nbroken", de: "Ein Satz\\ngebrochen") }\n'
                '    // umbruch: nothing to break here\n'
                '    static var c: String { tr(en: "Done", de: "Fertig") }')
        self.assertEqual(self.text_file(body), [("harter-umbruch", 4), ("harter-umbruch", 4), ("ausnahme-ungenutzt", 5)])


class InputTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()

    def tearDown(self):
        self.repo.close()

    def main(self, *args):
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            code = check_texts.main(list(args) + ["--wurzel", str(self.repo.root)])
        return code, out.getvalue()

    def test_broken_files_are_findings_with_their_name(self):
        self.repo.write("App/Resources/InfoPlist.json", "{\n  \"NSCameraUsageDescription\": \n")
        self.repo.path("App/Sources/Modules/Demo").mkdir(parents=True)
        self.repo.path("App/Sources/Modules/Demo/Latin1.swift").write_bytes("// Grüße\n".encode("latin-1"))
        findings, _ = check_texts.collect(self.repo.root, self.repo.terms())
        self.assertEqual(sorted((f.path, f.term_id) for f in findings),
                         [("App/Resources/InfoPlist.json", "nicht-lesbar"), ("App/Sources/Modules/Demo/Latin1.swift", "nicht-lesbar")])

    def test_broken_baseline_and_missing_paths_fail_without_traceback(self):
        self.repo.write(check_texts.BASELINE, "[")
        code, output = self.main()
        self.assertEqual(code, 1)
        self.assertIn("rules/baseline/texte.json: nicht lesbar", output)
        self.repo.write(check_texts.BASELINE, "{}\n")
        code, output = self.main("App/Sources/Modules/Islan")
        self.assertEqual(code, 1)
        self.assertIn("Pfad fehlt", output)
        self.assertNotIn("Traceback", output)

    def test_every_markdown_file_is_a_doc(self):
        self.repo.write("tools/README.md", "# Werkzeuge\n\n› Icon bauen\n")
        self.repo.write("App/Resources/Notices/en.md", "Permission is hereby granted!\n")
        code, output = self.main()
        self.assertEqual(code, 1)
        self.assertIn("tools/README.md:3:1: Glyphe statt Symbol", output)
        self.assertNotIn("Notices", output)
        self.assertIn("1 Befund in", output)


class RepositoryTests(unittest.TestCase):
    def test_baseline_file_is_valid(self):
        baseline = rules_lib.load_baseline(ROOT / check_texts.BASELINE)
        self.assertIsInstance(baseline, dict)

    def test_other_address_form_only_hits_files_a_project_may_change(self):
        """With the other address form every finding of the anrede pack lies in a *Text.swift file, InfoPlist.json or
        project code (shared or project paths in starter.manifest.json), so a project can switch and fix every place."""
        current = json.loads((ROOT / "starter.json").read_text(encoding="utf-8")).get("texts", {}).get("anrede", "du")
        other = "sie" if current == "du" else "du"
        repo = Repo(texts={"languages": ["en", "de"], "anrede": other})
        try:
            import shutil
            shutil.rmtree(repo.path("App"))
            shutil.copytree(ROOT / "App", repo.path("App"))
            findings, _ = check_texts.collect(repo.root, repo.terms(), ["App"])
            address = [f for f in findings if f.term_id in ("du-form", "sie-form")]
            self.assertTrue(address or current == "sie", "the kit texts use du, so sie must find them")
            for finding in address:
                self.assertTrue(rules_lib.path_matches(finding.path, ["App/Sources/**/*Text.swift", "App/Resources/InfoPlist.json",
                                                                      "App/Sources/Features/**"]), finding.format())
        finally:
            repo.close()


if __name__ == "__main__":
    unittest.main()
