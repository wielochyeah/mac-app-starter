"""Module markers: Swift #if blocks, comment markers, empty files, dangling references."""
import unittest

from starter.tests.helpers import SCRIPTS  # noqa: F401  (puts scripts/ on sys.path)
from starter.common import StarterError
from starter.markers import (comment_syntax, dangling_references, is_empty_swift, references, strip_comment_markers,
                             strip_swift_flag, swift_flag_problems, top_level_decls, transform)


def lines(*items):
    return "\n".join(items)


class SwiftFlagTests(unittest.TestCase):
    def test_drops_the_block_and_keeps_the_rest(self):
        src = lines("a()", "#if MODUL_ISLAND", "IslandModule.register()", "#endif", "b()")
        self.assertEqual(strip_swift_flag(src, "island"), lines("a()", "b()"))

    def test_keeps_the_else_body(self):
        src = lines("#if MODUL_ISLAND", "useIsland()", "#else", "fallback()", "#endif")
        self.assertEqual(strip_swift_flag(src, "island"), "fallback()")

    def test_a_negated_flag_breaks_the_rule_but_still_resolves(self):
        from starter.markers import swift_flag_problems
        problems = swift_flag_problems(lines("#if !MODUL_ISLAND", "x()", "#endif"), "A.swift", ["island"])
        self.assertEqual(len(problems), 1)
        self.assertIn("ohne !", problems[0])
        self.assertIn("#else-Zweig", problems[0])

    def test_negated_flag_keeps_its_body_and_drops_the_else(self):
        src = lines("#if !MODUL_ISLAND", "noIsland()", "#else", "island()", "#endif", "end()")
        self.assertEqual(strip_swift_flag(src, "island"), lines("noIsland()", "end()"))

    def test_other_conditions_stay_and_are_processed_inside(self):
        src = lines("#if TESTING", "x()", "#if MODUL_AI", "ai()", "#endif", "#else", "y()", "#endif")
        self.assertEqual(strip_swift_flag(src, "ai"), lines("#if TESTING", "x()", "#else", "y()", "#endif"))

    def test_nested_module_blocks(self):
        src = lines("#if MODUL_MLX", "#if MODUL_AI", "both()", "#endif", "mlxOnly()", "#endif")
        self.assertEqual(strip_swift_flag(src, "ai"), lines("#if MODUL_MLX", "mlxOnly()", "#endif"))
        self.assertEqual(strip_swift_flag(src, "mlx"), "")

    def test_other_if_inside_a_removed_block_goes_with_it(self):
        src = lines("#if MODUL_AI", "#if DEBUG", "debugAI()", "#else", "relAI()", "#endif", "#endif", "z()")
        self.assertEqual(strip_swift_flag(src, "ai"), "z()")

    def test_other_modules_and_similar_names_are_untouched(self):
        src = lines("#if MODUL_AIX", "x()", "#endif", "#if MODUL_WINDOW", "w()", "#endif")
        self.assertEqual(strip_swift_flag(src, "ai"), src)

    def test_parentheses_and_trailing_comment(self):
        src = lines("#if (MODUL_AI) // the ai part", "a()", "#endif // MODUL_AI", "b()")
        self.assertEqual(strip_swift_flag(src, "ai"), "b()")

    def test_collapses_the_blank_line_left_at_the_seam(self):
        src = lines("a()", "", "#if MODUL_AI", "ai()", "#endif", "", "b()")
        self.assertEqual(strip_swift_flag(src, "ai"), lines("a()", "", "b()"))

    def test_compound_condition_is_refused(self):
        with self.assertRaises(StarterError) as e:
            strip_swift_flag(lines("#if MODUL_AI && DEBUG", "x()", "#endif"), "ai", "A.swift")
        self.assertIn("A.swift:1", str(e.exception))

    def test_elseif_in_module_block_is_refused(self):
        with self.assertRaises(StarterError):
            strip_swift_flag(lines("#if MODUL_AI", "a()", "#elseif DEBUG", "b()", "#endif"), "ai")

    def test_unbalanced_is_refused(self):
        with self.assertRaises(StarterError):
            strip_swift_flag(lines("#if MODUL_AI", "a()"), "ai")
        with self.assertRaises(StarterError):
            strip_swift_flag(lines("a()", "#endif"), "ai")

    def test_flag_problems(self):
        src = lines("#if MODUL_AI || MODUL_MLX", "#endif", "#if MODUL_NOPE", "#endif",
                    "#if MODUL_AI", "#elseif X", "#endif", "#if TESTING")
        problems = swift_flag_problems(src, "F.swift", ["ai", "mlx"])
        self.assertEqual(len(problems), 4, problems)
        self.assertTrue(any("F.swift:1" in p for p in problems))
        self.assertTrue(any("MODUL_NOPE" in p for p in problems))
        self.assertTrue(any("F.swift:6" in p for p in problems))
        self.assertTrue(any("F.swift:8" in p for p in problems))
        self.assertEqual(swift_flag_problems(lines("#if MODUL_AI", "#else", "#endif"), "F.swift", ["ai"]), [])


class CommentMarkerTests(unittest.TestCase):
    def test_syntax_per_file_type(self):
        self.assertEqual(comment_syntax("docs/A.md"), ("<!--", "-->"))
        self.assertEqual(comment_syntax("scripts/x.sh"), ("#", ""))
        self.assertEqual(comment_syntax("Makefile"), ("#", ""))
        self.assertEqual(comment_syntax("ai-worker/requirements.txt"), ("#", ""))
        self.assertEqual(comment_syntax("App/A.swift"), ("//", ""))
        self.assertIsNone(comment_syntax("starter.json"))
        self.assertIsNone(comment_syntax("scripts/hooks/pre-push"))
        self.assertEqual(comment_syntax("scripts/hooks/pre-push", "#!/bin/zsh\n"), ("#", ""))
        self.assertEqual(comment_syntax("bin/starter", "#!/usr/bin/env python3\n"), ("#", ""))

    def test_markers_in_a_script_without_extension(self):
        src = "#!/bin/zsh\nrun island # modul:island\nmake check\n"
        self.assertEqual(transform("scripts/hooks/pre-push", src, ["island"]), "#!/bin/zsh\nmake check\n")

    def test_markdown_line_and_block(self):
        src = lines("keep", "| Insel | x | <!-- modul:island -->", "<!-- modul:island:anfang -->", "## Insel",
                    "Text", "<!-- modul:island:ende -->", "end")
        self.assertEqual(strip_comment_markers(src, "island", "README.md"), lines("keep", "end"))

    def test_multi_name_line_goes_with_either(self):
        src = lines("a", "both # modul:ai,mlx", "b")
        self.assertEqual(strip_comment_markers(src, "mlx", "x.yml"), lines("a", "b"))
        self.assertEqual(strip_comment_markers(src, "ai", "x.yml"), lines("a", "b"))
        self.assertEqual(strip_comment_markers(src, "window", "x.yml"), src)

    def test_code_marker_inside_markdown_is_an_example(self):
        src = lines("```swift", "let x = 1 // modul:ai", "```")
        self.assertEqual(strip_comment_markers(src, "ai", "docs/A.md"), src)

    def test_unterminated_block(self):
        with self.assertRaises(StarterError):
            strip_comment_markers(lines("# modul:ai:anfang", "x"), "ai", "a.sh")


class TransformTests(unittest.TestCase):
    def test_empty_swift(self):
        self.assertTrue(is_empty_swift(lines("// c", "/* block", "*/", "import Foundation", "#if TESTING", "#endif")))
        self.assertFalse(is_empty_swift(lines("import Foundation", "let x = 1")))

    def test_guarded_test_file_becomes_none(self):
        src = lines("// Island tests", "#if TESTING", "#if MODUL_ISLAND", "final class T {}", "#endif", "#endif")
        self.assertIsNone(transform("App/Tests/IslandTests.swift", src, ["island"]))

    def test_unchanged_comment_only_file_stays(self):
        src = "// only a comment\n"
        self.assertEqual(transform("App/Tests/Notes.swift", src, ["island"]), src)

    def test_several_modules(self):
        src = lines("#if MODUL_AI", "a()", "#endif", "#if MODUL_MLX", "m()", "#endif", "k()")
        self.assertEqual(transform("K.swift", src, ["ai", "mlx"]), "k()")


class ReferenceTests(unittest.TestCase):
    def test_top_level_decls(self):
        src = lines("@MainActor final class IslandController {", "    var inner = 1", "}",
                    "private struct Hidden {}", "enum IslandText {}", "func islandHelper() {}",
                    "extension SettingKey {}", "@Observable final class IslandModel {}")
        self.assertEqual(top_level_decls(src), ["IslandController", "IslandText", "islandHelper", "IslandModel"])

    def test_references_skip_comments_and_strings(self):
        src = lines("// IslandController here", 'let s = "IslandController"', "let c = IslandController()",
                    "/* IslandController", "*/ x()")
        self.assertEqual(references(src, {"IslandController"}), [(3, "IslandController")])

    def test_dangling(self):
        deleted = {"M/Island.swift": "final class IslandController {}\n"}
        remaining = {"K/Use.swift": "let x = IslandController()\n", "K/Other.swift": "let y = 1\n",
                     "README.md": "IslandController\n"}
        self.assertEqual(dangling_references(deleted, remaining), ["K/Use.swift:1 nutzt IslandController (aus M/Island.swift)"])

    def test_fallback_declared_elsewhere_is_not_dangling(self):
        deleted = {"M/Island.swift": "enum IslandBridge {}\n"}
        remaining = {"K/Fallback.swift": "enum IslandBridge {}\nlet b = IslandBridge.self\n"}
        self.assertEqual(dangling_references(deleted, remaining), [])

    def test_nested_types_and_members_of_the_same_name_are_not_uses(self):
        """Kit design tokens `Radius.Island`, `Metrics.Island` next to the module's top-level `class Island`."""
        deleted = {"M/IslandController.swift": "final class Island {\n    static let shared = Island()\n}\n"}
        remaining = {
            "K/Tokens.swift": lines("extension Radius {", "    enum Island {", "        static let card = 12.0",
                                    "    }", "}", "extension Radius {", "    static var x: Double { Island.card }", "}"),
            "K/Catalog.swift": lines("let notch = Metrics.Island.renderNotch",
                                     "let r = Radius", "    .Island.card", "struct Island2 {}"),
            "K/Show.swift": lines("func show() {", "    Island.shared.present()", "}",
                                  "extension Island {}", "let k = \\Metrics.Island.renderNotch"),
        }
        self.assertEqual(dangling_references(deleted, remaining), [
            "K/Show.swift:2 nutzt Island (aus M/IslandController.swift)",
            "K/Show.swift:4 nutzt Island (aus M/IslandController.swift)",
        ])

    def test_references_skip_members_and_declarations(self):
        src = lines("a.Island", "enum Island {}", "struct Island<T> {}", "Island.shared", "x = [Island]()")
        self.assertEqual(references(src, {"Island"}), [(4, "Island"), (5, "Island")])


if __name__ == "__main__":
    unittest.main()
