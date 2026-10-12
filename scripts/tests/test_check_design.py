"""Tests for scripts/check_design.py."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rules_testlib import pack_files, repo_terms  # noqa: E402

import check_design  # noqa: E402
import rules_lib  # noqa: E402

VIEW = "App/Sources/Modules/Demo/DemoView.swift"
DESIGN = "App/Sources/Kit/Design/Tokens.swift"


def check(text, path=VIEW):
    terms = [t for t in repo_terms() if t.pruefer == "check_design"]
    return check_design.check_file(path, text, terms)


def ids(findings):
    return [f.term_id for f in findings]


class PackParityTests(unittest.TestCase):
    def test_examples_hit_in_a_swift_file(self):
        terms = {t.id: t for t in repo_terms()}
        for pack in pack_files():
            if pack.get("pruefer") != "check_design":
                continue
            for raw in pack["begriffe"]:
                term = terms[raw["id"]]
                for example in raw["beispiele"]["treffer"]:
                    self.assertIn(term.id, ids(check_design.check_file(VIEW, example + "\n", [term])), example)
                for example in raw["beispiele"]["erlaubt"]:
                    self.assertEqual(check_design.check_file(VIEW, example + "\n", [term]), [], example)


class DesignCheckTests(unittest.TestCase):
    def test_tokens_pass(self):
        source = "\n".join([
            "VStack(alignment: .leading, spacing: Space.s) {",
            "    Text(DemoText.title).font(TypeScale.title).foregroundStyle(t.fg)",
            "}",
            ".padding(.horizontal, Space.l)",
            ".background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(t.card))",
            ".animation(Motion.adaptive(Motion.toggle, reduce: reduceMotion), value: on)",
            "HStack(spacing: 0) { }",
        ])
        self.assertEqual(check(source + "\n"), [])

    def test_literals_are_found_with_line_numbers(self):
        source = "\n".join([
            "VStack(spacing: 10) {",
            "    Text(DemoText.title).font(.system(size: 13))",
            "}",
            ".padding(.horizontal,",
            "         12)",
            ".foregroundStyle(.secondary)",
            "RoundedRectangle(cornerRadius: 8)",
            "withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { }",
            ".blur(radius: 20)",
            "Color(red: 1, green: 0, blue: 0)",
        ])
        findings = check(source + "\n")
        self.assertEqual([(f.term_id, f.line) for f in findings],
                         [("abstand", 1), ("schriftgroesse", 2), ("abstand", 4), ("systemfarbe", 6), ("radius", 7),
                          ("bewegung", 8), ("unschaerfe", 9), ("farbe-literal", 10)])

    def test_strings_and_comments_do_not_count(self):
        source = 'let css = ".a { padding: 12px; }"\n// .padding(16) would be wrong\nlet s = "spacing: 10"\n'
        self.assertEqual(check(source), [])

    def test_kit_design_is_excluded_for_gestaltung_only(self):
        self.assertEqual(check("static let body = Font.system(size: 13)\n", DESIGN), [])
        self.assertEqual(ids(check("let x = try! load()\n", DESIGN)), ["erzwungen"])

    def test_exception_comment_with_reason(self):
        source = "// design-ausnahme: artwork needs its own size\nImage(systemName: s).font(.system(size: 40))\n.padding(7) // design-ausnahme: optical centre\n"
        self.assertEqual(check(source), [])

    def test_exception_without_reason_or_finding(self):
        source = "// design-ausnahme:\n.padding(7)\n// design-ausnahme: nothing here\nlet a = 1\n"
        self.assertEqual(sorted(ids(check(source))), ["abstand", "ausnahme-ohne-grund", "ausnahme-ungenutzt"], "an exception without a reason exempts nothing")

    def test_exception_keyword_belongs_to_its_pack(self):
        source = "// design-ausnahme: wrong keyword\nlet x = try! load()\n"
        self.assertEqual(sorted(ids(check(source))), ["ausnahme-ungenutzt", "erzwungen"])
        self.assertEqual(check("// technik-ausnahme: the file is part of the bundle\nlet x = try! load()\n"), [])

    def test_place_bound_terms(self):
        self.assertEqual(ids(check("let s = URLSession.shared\n")), ["netzwerk"])
        self.assertEqual(check("let s = URLSession.shared\n", "App/Sources/Modules/MLX/Download.swift"), [])
        self.assertEqual(ids(check("AVCaptureDevice.requestAccess(for: .audio) { _ in }\n")), ["berechtigung-direkt"])
        self.assertEqual(check("AVCaptureDevice.requestAccess(for: .audio) { _ in }\n", "App/Sources/Kit/Permissions/Permission.swift"), [])
        self.assertEqual(check("try SMAppService.mainApp.register()\n", "App/Sources/Modules/Background/LoginItem.swift"), [])

    def test_module_conditions(self):
        source = "#if MODUL_WINDOW\n#if MODUL_AI\n#endif\n#endif\n#if MODUL_A || MODUL_B\n#endif\n#if !MODUL_A\n#endif\n"
        self.assertEqual([(f.term_id, f.line) for f in check(source)], [("modul-bedingung", 5), ("modul-bedingung", 7)])

    def test_unreadable_file(self):
        self.assertEqual(ids(check('let a = "open\n')), ["nicht-lesbar"])


class RepositoryTests(unittest.TestCase):
    def test_baseline_file_is_valid(self):
        self.assertIsInstance(rules_lib.load_baseline(rules_lib.ROOT / check_design.BASELINE), dict)


if __name__ == "__main__":
    unittest.main()
