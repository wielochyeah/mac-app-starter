// Texts of the DMG window background (tools/dmg/Background.swift). English and German; the German
// address form follows texts.anrede in starter.json (du or sie). The DMG is one file for everyone,
// so `both` (the default when the project has both languages) shows the English line first and
// the German one below it.

enum DMGLang: String {
    case en, de, both

    var languages: [String] {
        switch self {
        case .en: ["en"]
        case .de: ["de"]
        case .both: ["en", "de"]
        }
    }
}

/// German address form (texts.anrede).
enum DMGAnrede: String {
    case du, sie
}

struct DMGCopy {
    let en: String
    let de: String
    func text(_ lang: String) -> String { lang == "de" ? de : en }
}

enum DMGText {
    /// `app` is the name Finder shows under the icon (the bundle's file name), `folder` the link's name.
    static func drag(_ app: String, to folder: String, anrede: DMGAnrede) -> DMGCopy {
        let de = switch anrede {
        case .du: "Zieh \(app) auf „\(folder)“."
        case .sie: "Ziehen Sie \(app) auf „\(folder)“."
        }
        return DMGCopy(en: "Drag \(app) to \(folder).", de: de)
    }

    /// The Gatekeeper step for builds that are not notarized. Since macOS 15 a right click > Open
    /// no longer gets past Gatekeeper; the way is System Settings > Privacy & Security, and the
    /// button only shows there after macOS has blocked a launch, hence the question first.
    static let blocked = DMGCopy(en: "Blocked on first launch?", de: "Beim ersten Start blockiert?")
    static let settingsPath = DMGCopy(en: "System Settings › Privacy & Security › ",
                                      de: "Systemeinstellungen › Datenschutz & Sicherheit › ")
    /// The button's name in System Settings (macOS 26: SecurityPrivacyExtension "Open Anyway",
    /// German „Dennoch öffnen“), shown bold.
    static let openAnyway = DMGCopy(en: "“Open Anyway”", de: "„Dennoch öffnen“")

    /// The line with the app version and the minimum macOS: the same in both languages.
    static func versionLine(_ version: String, minimumMacOS: String) -> String {
        let macOS = minimumMacOS.hasSuffix(".0") ? String(minimumMacOS.dropLast(2)) : minimumMacOS
        return "Version \(version) · macOS \(macOS)+"
    }
}
