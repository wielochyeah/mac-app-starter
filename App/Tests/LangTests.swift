#if TESTING
import Foundation

final class LangTests: TestSuite {
    override class func register() {
        test("tr follows the forced language") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .de
            expectEqual(tr(en: "Continue", de: "Weiter"), "Weiter")
            expectEqual(CommonText.back, "Zurück")
            Localizer.shared.forced = .en
            expectEqual(tr(en: "Continue", de: "Weiter"), "Continue")
        }

        test("preferred language from the Mac") {
            expectEqual(Lang.preferred(["de-DE", "en-US"]), .de)
            expectEqual(Lang.preferred(["de-AT"]), .de)
            expectEqual(Lang.preferred(["en-GB", "de-DE"]), .en)
            expectEqual(Lang.preferred(["fr-FR", "de-CH"]), .de)
            expectEqual(Lang.preferred(["fr-FR"]), .en)
            expectEqual(Lang.preferred([]), .en)
        }

        test("precedence forced > choice > system") {
            let l = Localizer(environment: [:], systemLanguages: ["de-DE"], stored: "system", persists: false)
            expectEqual(l.lang, .de)
            l.choice = .en
            expectEqual(l.lang, .en)
            l.forced = .de
            expectEqual(l.lang, .de)
            l.forced = nil
            l.choice = nil
            expectEqual(l.lang, .de)
        }

        test("STARTER_LANG forces the language") {
            let l = Localizer(environment: ["STARTER_LANG": "EN"], systemLanguages: ["de-DE"], stored: "de", persists: false)
            expectEqual(l.lang, .en)
            expectEqual(l.choice, .de)
        }

        test("stored choice is read back") {
            expectEqual(Localizer(environment: [:], systemLanguages: ["en"], stored: "de", persists: false).lang, .de)
            expectEqual(Localizer(environment: [:], systemLanguages: ["en"], stored: "nonsense", persists: false).choice, nil)
        }

        test("numbers follow the UI language") {
            let saved = Localizer.shared.forced
            defer { Localizer.shared.forced = saved }
            Localizer.shared.forced = .de
            expectEqual(Format.number(1284), "1.284")
            expectEqual(Format.decimal(0.75, digits: 1), "0,8")
            Localizer.shared.forced = .en
            expectEqual(Format.number(1284), "1,284")
            expectEqual(Format.decimal(0.7), "0.7")
        }

        test("every language has a native name") {
            for lang in Lang.allCases { expect(!lang.nativeName.isEmpty) }
        }
    }
}

final class VersionTests: TestSuite {
    override class func register() {
        test("parse and compare") {
            expectEqual(Version("1.2.3"), Version(1, 2, 3))
            expectEqual(Version("2"), Version(2, 0, 0))
            expect(Version("1.10.0")! > Version("1.9.9")!)
            expectEqual(Version("1.x"), nil)
            expectEqual(Version(""), nil)
            expectEqual(Version.app.description, AppConfig.version)
        }
    }
}
#endif
