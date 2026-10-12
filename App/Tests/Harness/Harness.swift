#if TESTING
import AppKit
import ObjectiveC

// A tiny test runner for CLT-only builds (no XCTest, no Swift Testing).
//
// A test file declares a suite; every subclass of TestSuite is found at runtime:
//
//     final class LangTests: TestSuite {
//         override class func register() {
//             test("tr picks German") {
//                 Localizer.shared.forced = .de
//                 expectEqual(tr(en: "Hi", de: "Hallo"), "Hallo")
//             }
//         }
//     }
//
// scripts/test.sh compiles all app sources + App/Tests with -D TESTING into build/tests/run-tests.
// `run-tests --only Lang` runs suites/tests whose "Suite/test" name starts with the prefix.

class TestSuite: NSObject {
    /// Override and call `test(...)` for each test.
    class func register() {}
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

enum TestRun {
    struct Case {
        let name: String
        let body: () throws -> Void
    }

    static var cases: [Case] = []
    static var failures: [String] = []
    static var current = ""
    static var currentSuite = ""
    static var tempDirs: [URL] = []
}

/// Registers a test in the current suite.
func test(_ name: String, _ body: @escaping () throws -> Void) {
    TestRun.cases.append(TestRun.Case(name: "\(TestRun.currentSuite)/\(name)", body: body))
}

func expect(_ condition: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
            file: StaticString = #fileID, line: UInt = #line) {
    do {
        if try !condition() { fail("expectation failed \(message())", file: file, line: line) }
    } catch {
        fail("threw \(error) \(message())", file: file, line: line)
    }
}

func expectEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: String = "",
                               file: StaticString = #fileID, line: UInt = #line) {
    do {
        let (x, y) = (try a(), try b())
        if x != y { fail("\(x) != \(y) \(message)", file: file, line: line) }
    } catch {
        fail("threw \(error) \(message)", file: file, line: line)
    }
}

func expectThrows(_ body: () throws -> Void, _ message: String = "", file: StaticString = #fileID, line: UInt = #line) {
    do {
        try body()
        fail("expected an error \(message)", file: file, line: line)
    } catch {}
}

func fail(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
    TestRun.failures.append("\(TestRun.current) \(file):\(line) \(message)")
}

/// A fresh empty directory, removed after the run.
func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("starter-tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    TestRun.tempDirs.append(url)
    return url
}

/// The repository root (scripts/test.sh exports STARTER_ROOT).
var repoRoot: URL {
    URL(fileURLWithPath: ProcessInfo.processInfo.environment["STARTER_ROOT"] ?? FileManager.default.currentDirectoryPath)
}

@main enum TestMain {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        HeadlessWindows.install()
        Modules.registerAll()

        var only: String?
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--only"), i + 1 < args.count { only = args[i + 1] }

        for suite in suites() {
            TestRun.currentSuite = NSStringFromClass(suite).components(separatedBy: ".").last ?? "\(suite)"
            suite.register()
        }
        let selected = TestRun.cases.filter { only == nil || $0.name.hasPrefix(only!) }
        for c in selected {
            TestRun.current = c.name
            let before = TestRun.failures.count
            do { try c.body() } catch { TestRun.failures.append("\(c.name): threw \(error)") }
            print("\(TestRun.failures.count == before ? "ok  " : "FAIL") \(c.name)")
        }
        for dir in TestRun.tempDirs { try? FileManager.default.removeItem(at: dir) }
        for f in TestRun.failures { FileHandle.standardError.write(Data("FAIL \(f)\n".utf8)) }
        print("\(selected.count) tests, \(TestRun.failures.count) failures")
        exit(TestRun.failures.isEmpty && !selected.isEmpty ? 0 : 1)
    }

    /// Every subclass of TestSuite, sorted by name.
    private static func suites() -> [TestSuite.Type] {
        // A plain buffer, not objc_copyClassList's autoreleasing pointer: reading from that one
        // retains each class, and some runtime classes abort on any message.
        let total = Int(objc_getClassList(nil, 0))
        guard total > 0 else { return [] }
        let buffer = UnsafeMutablePointer<AnyClass>.allocate(capacity: total)
        defer { buffer.deallocate() }
        let count = Int(objc_getClassList(AutoreleasingUnsafeMutablePointer(buffer), Int32(total)))
        var out: [TestSuite.Type] = []
        let base = ObjectIdentifier(TestSuite.self)
        for i in 0..<min(count, total) {
            let cls: AnyClass = buffer[i]
            guard let superclass = class_getSuperclass(cls), ObjectIdentifier(superclass) == base else { continue }
            if let suite = cls as? TestSuite.Type { out.append(suite) }
        }
        return out.sorted { NSStringFromClass($0) < NSStringFromClass($1) }
    }
}
#endif
