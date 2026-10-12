"""Tests for scripts/swift_source.py."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rules_testlib  # noqa: E402,F401

import swift_source  # noqa: E402


def parse(text):
    return swift_source.parse("x.swift", text)


class LexerTests(unittest.TestCase):
    def test_plain_literal_with_escapes(self):
        src = parse('let a = "Say \\"hi\\"\\n\\t\\u{2026}"\n')
        self.assertEqual(src.literals[0].text, 'Say "hi"\n\t' + chr(0x2026))

    def test_interpolation_with_nested_string_and_parens(self):
        src = parse('let a = "Open \\(f("a)b", g(1))) now"\n')
        literal = src.literals[0]
        self.assertEqual(literal.text, "Open X now")
        self.assertEqual(literal.interpolations, ['f("a)b", g(1))'])
        self.assertEqual(len(src.literal_at), 1, "the nested literal is not top-level")

    def test_multiline_literal_strips_indentation(self):
        src = parse('    let a = """\n        first line\n          indented\n        last \\\n        joined\n        """\n')
        self.assertEqual(src.literals[0].text, "first line\n  indented\nlast joined")
        self.assertTrue(src.literals[0].multiline)

    def test_raw_string(self):
        src = parse('let a = #"C:\\path "quoted" \\#(x)"#\n')
        literal = src.literals[0]
        self.assertTrue(literal.raw)
        self.assertEqual(literal.text, 'C:\\path "quoted" X')

    def test_comments_are_found_and_masked(self):
        src = parse('let a = 1 // see "this"\n/* outer /* inner */ still */ let b = 2\n')
        self.assertEqual([c.text for c in src.comments], [' see "this"', " outer /* inner */ still "])
        self.assertNotIn("see", src.masked)
        self.assertIn("let b = 2", src.masked)
        self.assertEqual(len(src.masked), len(src.text))

    def test_comment_markers_inside_strings_are_text(self):
        src = parse('let url = "https://example.com" // real\n')
        self.assertEqual(len(src.comments), 1)
        self.assertEqual(src.literals[0].text, "https://example.com")

    def test_masked_keeps_quotes_and_lines(self):
        text = 'Text("Hallo")\nlet x = """\nA\n"""\n'
        src = parse(text)
        self.assertEqual(src.masked.count("\n"), text.count("\n"))
        self.assertTrue(src.masked.startswith('Text("     ")'))

    def test_line_and_column(self):
        src = parse('a\n  b "x"\n')
        offset = src.text.index('"x"')
        self.assertEqual((src.line_of(offset), src.column_of(offset)), (2, 5))

    def test_unclosed_literal_raises(self):
        with self.assertRaises(swift_source.LexError):
            parse('let a = "open\nlet b = 1\n')

    def test_own_line_comment_flag(self):
        src = parse("// alone\nlet a = 1 // trailing\n")
        self.assertEqual([c.own_line for c in src.comments], [True, False])


class CallTests(unittest.TestCase):
    def test_arguments_with_labels_and_literals(self):
        src = parse('tr(en: "Open \\(name)", de: "\\(name) öffnen")\n')
        (name, at, paren), = list(swift_source.find_calls(src, ["tr"]))
        args, close = swift_source.call_arguments(src, paren)
        self.assertEqual([a.label for a in args], ["en", "de"])
        self.assertEqual(args[1].literal.text, "X öffnen")
        self.assertEqual(src.text[close], ")")

    def test_func_declaration_is_no_call(self):
        src = parse("func tr(en: String, de: String) -> String { en }\n")
        self.assertEqual(list(swift_source.find_calls(src, ["tr"])), [])

    def test_member_calls(self):
        src = parse('view.help("Tip").padding()\nfoo.tr(x)\n')
        self.assertEqual([n for n, _, _ in swift_source.find_calls(src, ["help"], member=True)], ["help"])
        self.assertEqual(list(swift_source.find_calls(src, ["tr"])), [])

    def test_commas_inside_nested_calls_and_closures(self):
        src = parse('Button(f(a, b), action: { g(1, 2) })\n')
        (_, _, paren), = list(swift_source.find_calls(src, ["Button"]))
        args, _ = swift_source.call_arguments(src, paren)
        self.assertEqual([a.label for a in args], [None, "action"])

    def test_expression_with_literal_and_code_is_not_a_single_literal(self):
        src = parse('Text("a" + name)\n')
        (_, _, paren), = list(swift_source.find_calls(src, ["Text"]))
        args, _ = swift_source.call_arguments(src, paren)
        self.assertIsNone(args[0].literal)
        self.assertEqual(len(args[0].literals), 1)

    def test_empty_call(self):
        src = parse("Text()\n")
        (_, _, paren), = list(swift_source.find_calls(src, ["Text"]))
        args, _ = swift_source.call_arguments(src, paren)
        self.assertEqual(args, [])


class RepositoryTests(unittest.TestCase):
    def test_every_swift_file_of_the_app_lexes(self):
        for path in sorted((rules_testlib.ROOT / "App").rglob("*.swift")):
            src = swift_source.parse(str(path), path.read_text(encoding="utf-8"))
            self.assertEqual(len(src.masked), len(src.text), path)


if __name__ == "__main__":
    unittest.main()
