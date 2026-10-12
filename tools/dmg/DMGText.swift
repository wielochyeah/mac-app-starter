// Texts of the DMG window background (tools/dmg/Background.swift). English and German, `du` like
// the app. The DMG is one file for everyone, so `both` (the default when the project has both
// languages) shows the English line first and the German one below it.

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

struct DMGCopy {
    let en: String
    let de: String
    func text(_ lang: String) -> String { lang == "de" ? de : en }
}

enum DMGText {
    static func drag(_ app: String, to folder: String) -> DMGCopy {
        DMGCopy(en: "Drag \(app) to \(folder).", de: "Zieh \(app) auf „\(folder)“.")
    }

    /// The Gatekeeper step for builds that are not notarized. Since macOS 15 a right click > Open
    /// no longer gets past Gatekeeper; the way is System Settings > Privacy & Security.
    static let firstOpen = DMGCopy(en: "First launch: System Settings › Privacy & Security › ",
                                   de: "Beim ersten Start: Systemeinstellungen › Datenschutz & Sicherheit › ")
    /// The button's name in System Settings, shown bold.
    static let openAnyway = DMGCopy(en: "“Open Anyway”", de: "„Trotzdem öffnen“")

    /// "Version 1.2.0 · macOS 26+": the same in both languages.
    static func versionLine(_ version: String, minimumMacOS: String) -> String {
        let macOS = minimumMacOS.hasSuffix(".0") ? String(minimumMacOS.dropLast(2)) : minimumMacOS
        return "Version \(version) · macOS \(macOS)+"
    }
}
