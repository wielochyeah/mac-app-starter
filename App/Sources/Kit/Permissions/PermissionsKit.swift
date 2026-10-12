import AppKit

/// Kit/Permissions: which permissions this app uses (`starter.json` "permissions"), project
/// texts for them, and the self-tests. The onboarding shows one step per configured kind.
enum PermissionsKit {
    /// Project copy for "why the app asks", per kind (replaces `PermissionText.why`). Set it in
    /// your feature's registration, e.g.
    ///     PermissionsKit.reasons[.microphone] = { tr(en: "…", de: "…") }
    static var reasons: [PermissionKind: () -> String] = [:]

    static func register() {
        let kinds = configured
        Registry.launchHooks.append {
            PermissionMonitor.shared.sampleLaunchStatus(kinds)
        }
        Registry.selfTests += [
            SelfTestCheck(id: "permissions.config") {
                let bad = invalidConfigEntries(AppConfig.permissions)
                return bad.isEmpty ? nil
                    : "starter.json permissions not understood: \(bad.joined(separator: ", ")) (automation needs a target: \"automation:com.apple.mail\")"
            },
            SelfTestCheck(id: "permissions.symbols") {
                let all = PermissionKind.simple + [.automation(bundleId: "com.apple.mail")]
                let missing = all.filter { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) == nil }
                return missing.isEmpty ? nil : "no SF Symbol for \(missing.map(\.id).joined(separator: ", "))"
            },
            SelfTestCheck(id: "permissions.links") {
                let broken = (PermissionKind.simple + [.automation(bundleId: "com.apple.mail")]).filter { $0.settingsURL() == nil }
                return broken.isEmpty ? nil : "no System Settings link for \(broken.map(\.id).joined(separator: ", "))"
            },
            SelfTestCheck(id: "permissions.texts") {
                // every kind has words in both languages for every state
                let saved = Localizer.shared.forced
                defer { Localizer.shared.forced = saved }
                for lang in Lang.allCases {
                    Localizer.shared.forced = lang
                    for kind in PermissionKind.simple + [.automation(bundleId: "com.apple.mail")] {
                        if PermissionText.title(kind).isEmpty || why(kind).isEmpty { return "\(kind.id): empty text (\(lang))" }
                        for status in PermissionStatus.allCases where PermissionText.hint(kind, status).contains(where: \.isEmpty) {
                            return "\(kind.id) \(status): empty hint (\(lang))"
                        }
                    }
                }
                return nil
            },
        ]
    }

    /// The permissions listed in starter.json, in order, that the app can understand.
    static var configured: [PermissionKind] { AppConfig.permissions.compactMap(PermissionKind.init(id:)) }

    /// Config entries that are not a known permission (pure; tests).
    nonisolated static func invalidConfigEntries(_ entries: [String]) -> [String] {
        entries.filter { PermissionKind(id: $0) == nil }
    }

    /// The step subtitle: the project's reason when set, else the kit's.
    static func why(_ kind: PermissionKind) -> String {
        reasons[kind]?() ?? PermissionText.why(kind)
    }

    /// The name of the app with this bundle id ("Mail"), or the id when it is not installed.
    static func appName(_ bundleId: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return bundleId }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
