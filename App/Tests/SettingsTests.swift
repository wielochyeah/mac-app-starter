#if TESTING
import Foundation

nonisolated private struct WindowFrame: Codable, Sendable, Equatable {
    var width: Int
    var height: Int
}

private extension SettingKey {
    static var testCount: SettingKey<Int> { .init("test.count", default: 3) }
    static var testName: SettingKey<String> { .init("test.name", default: "none") }
    static var testFlag: SettingKey<Bool> { .init("test.flag", default: false) }
    static var testWindow: SettingKey<WindowFrame> { .init("test.window", default: WindowFrame(width: 900, height: 620)) }
}

final class SettingsTests: TestSuite {
    static func json(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    override class func register() {
        test("defaults when the file is missing") {
            let s = Settings(fileURL: tempDir().appendingPathComponent("settings.json"))
            expectEqual(s[.testCount], 3)
            expectEqual(s[.testWindow], WindowFrame(width: 900, height: 620))
            expect(!FileManager.default.fileExists(atPath: s.fileURL.path), "reading must not create the file")
        }

        test("values round-trip through the file") {
            let url = tempDir().appendingPathComponent("settings.json")
            let s = Settings(fileURL: url)
            s[.testCount] = 7
            s[.testName] = "Ada"
            s[.testWindow] = WindowFrame(width: 1000, height: 700)
            let again = Settings(fileURL: url)
            expectEqual(again[.testCount], 7)
            expectEqual(again[.testName], "Ada")
            expectEqual(again[.testWindow], WindowFrame(width: 1000, height: 700))
        }

        test("unknown keys are kept") {
            let url = tempDir().appendingPathComponent("settings.json")
            try #"{"future.key": {"nested": [1, 2, "x"]}, "other": 1.5}"#.write(to: url, atomically: true, encoding: .utf8)
            let s = Settings(fileURL: url)
            s[.testFlag] = true
            let object = json(url)
            expect(object["future.key"] != nil, "future.key dropped")
            expectEqual(object["other"] as? Double, 1.5)
            expectEqual(object["test.flag"] as? Bool, true)
        }

        test("keys written by someone else survive a save") {
            let url = tempDir().appendingPathComponent("settings.json")
            let s = Settings(fileURL: url)
            s[.testCount] = 1
            try #"{"test.count": 1, "written.elsewhere": "yes"}"#.write(to: url, atomically: true, encoding: .utf8)
            s[.testName] = "after"
            expectEqual(json(url)["written.elsewhere"] as? String, "yes")
        }

        test("broken values fall back to the default") {
            let url = tempDir().appendingPathComponent("settings.json")
            try #"{"test.count": "seven", "test.flag": 1, "test.window": {"width": "wide"}, "test.name": "ok"}"#
                .write(to: url, atomically: true, encoding: .utf8)
            let s = Settings(fileURL: url)
            expectEqual(s[.testCount], 3)
            expectEqual(s[.testFlag], false)
            expectEqual(s[.testWindow], WindowFrame(width: 900, height: 620))
            expectEqual(s[.testName], "ok")
        }

        test("a broken file is moved aside on the next save") {
            let url = tempDir().appendingPathComponent("settings.json")
            try "{ not json".write(to: url, atomically: true, encoding: .utf8)
            let s = Settings(fileURL: url)
            expectEqual(s[.testCount], 3)
            s[.testCount] = 4
            expectEqual(json(url)["test.count"] as? Int, 4)
            let aside = url.appendingPathExtension("broken")
            expectEqual(try String(contentsOf: aside, encoding: .utf8), "{ not json")
        }

        test("writes are atomic (new file, no temp files left)") {
            let dir = tempDir()
            let url = dir.appendingPathComponent("settings.json")
            let s = Settings(fileURL: url)
            s[.testCount] = 1
            let inode1 = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int
            s[.testCount] = 2
            let inode2 = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int
            expect(inode1 != nil && inode1 != inode2, "file was rewritten in place")
            expectEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["settings.json"])
            expect(s.lastError == nil)
        }

        test("reset removes the key") {
            let url = tempDir().appendingPathComponent("settings.json")
            let s = Settings(fileURL: url)
            s[.testCount] = 9
            expect(s.hasValue(.testCount))
            s.reset(.testCount)
            expectEqual(s[.testCount], 3)
            expect(json(url)["test.count"] == nil)
        }

        test("JSONValue keeps integers and nesting") {
            let v = try JSONValue(encoding: ["a": [1, 2], "b": [3]])
            expectEqual(v, .object(["a": .array([.int(1), .int(2)]), "b": .array([.int(3)])]))
            expectEqual(JSONValue.int(5).decode(Double.self), 5.0)
            expectEqual(JSONValue.string("x").decode(Int.self), nil)
        }
    }
}
#endif
