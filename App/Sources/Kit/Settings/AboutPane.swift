import AppKit
import SwiftUI

/// Facts the About pane shows. Built from the app at runtime; renders pass fixed values.
struct AboutInfo {
    struct Link: Identifiable {
        let title: String
        let url: URL
        var id: String { url.absoluteString }

        /// What the row shows under the title: the host, or the address of a mailto link.
        var detail: String {
            if url.scheme == "mailto" { return String(url.absoluteString.dropFirst("mailto:".count)) }
            return url.host() ?? url.absoluteString
        }
    }

    var name = AppInfo.displayName
    var symbol = AppInfo.symbol
    var version = AppInfo.version
    var build = AppInfo.build
    var copyright = AppInfo.copyright
    var links: [Link] = AboutInfo.configuredLinks
    /// The bundled THIRD_PARTY_NOTICES.md, nil when the build did not include it.
    var notices: String? = AboutInfo.bundledNotices
    var dataFolder: URL = AboutInfo.dataFolder
    var icon: NSImage? = AppInfo.icon()

    /// `app.links` from starter.json, in the UI language; entries without a usable URL are skipped.
    static var configuredLinks: [Link] {
        AppConfig.links.compactMap { link in
            guard let url = URL(string: link.url), url.scheme != nil else { return nil }
            return Link(title: tr(en: link.en, de: link.de), url: url)
        }
    }

    /// Renders run with STARTER_DATA_DIR inside build/: they show where a person's data lives.
    static var dataFolder: URL {
        guard RenderMode.isStatic else { return Paths.appSupport }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Application Support/\(AppConfig.bundleId)", isDirectory: true)
    }

    static var bundledNotices: String? {
        guard let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// One line for bug reports: "Starter 1.0.0 (1), macOS 26.0.1, arm64".
    static func versionLine(name: String, version: String, build: Int,
                            os: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
                            arch: String = AboutInfo.architecture) -> String {
        let patch = os.patchVersion > 0 ? ".\(os.patchVersion)" : ""
        return "\(name) \(version) (\(build)), macOS \(os.majorVersion).\(os.minorVersion)\(patch), \(arch)"
    }

    static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    /// "~/Library/Application Support/com.example.starter" (home shortened).
    static func displayPath(_ url: URL, home: String = NSHomeDirectory()) -> String {
        let path = url.standardizedFileURL.path
        guard !home.isEmpty, path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }
}

/// Kit pane "About": icon, name, version (build), copyright; support rows (copy version info, data
/// folder); links from starter.json `app.links`; third-party notices in a sheet when bundled.
struct AboutPane: View {
    var info = AboutInfo()
    /// Renders show the "Copied" state with this.
    var copied = false
    @State private var didCopy = false
    @State private var showsNotices = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        PaneScaffold(title: SettingsText.about, symbol: "info.circle.fill", tint: .accent) {
            VStack(spacing: Space.xs) {
                icon.padding(.bottom, Space.xxs)
                Text(info.name).font(TypeScale.title).foregroundStyle(t.fg)
                Text(CommonText.version(info.version, build: info.build))
                    .font(TypeScale.secondary)
                    .foregroundStyle(t.fg2)
                    .monospacedDigit()
                    .textSelection(.enabled)
                if !info.copyright.isEmpty {
                    Text(info.copyright).font(TypeScale.caption).foregroundStyle(t.fg3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s)
            .accessibilityElement(children: .combine)

            SettingsSection(SettingsText.support) {
                Row(SettingsText.versionInfo, subtitle: SettingsText.versionInfoDetail) {
                    Chip(copied || didCopy ? CommonText.copied : CommonText.copy,
                         symbol: copied || didCopy ? "checkmark" : "doc.on.doc", active: copied || didCopy) { copyVersion() }
                }
                ButtonRow(SettingsText.dataFolder, subtitle: AboutInfo.displayPath(info.dataFolder),
                          button: SettingsText.showInFinder) { revealDataFolder() }
            }
            if !info.links.isEmpty {
                SettingsSection(SettingsText.links) {
                    ForEach(info.links) { link in
                        LinkRow(link.title, subtitle: link.detail, url: link.url)
                    }
                }
            }
            if info.notices != nil {
                SettingsSection(SettingsText.legal) {
                    NavigationRow(SettingsText.notices, subtitle: SettingsText.noticesDetail) { showsNotices = true }
                }
            }
        }
        .sheet(isPresented: $showsNotices) {
            NoticesSheet(text: info.notices ?? "") { showsNotices = false }
        }
    }

    @ViewBuilder private var icon: some View {
        if let image = info.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.aboutIcon, height: Metrics.aboutIcon)
                .accessibilityHidden(true)
        } else {
            SquircleIcon(symbol: info.symbol, size: Metrics.aboutIcon)
        }
    }

    private func copyVersion() {
        let line = AboutInfo.versionLine(name: info.name, version: info.version, build: info.build)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(line, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { didCopy = false }
    }

    private func revealDataFolder() {
        let folder = Paths.ensure(info.dataFolder)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

// MARK: - Third-party notices

/// The notices file in a sheet: a header band with Done, the text below (a small Markdown subset).
struct NoticesSheet: View {
    let text: String
    let done: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            SectionHeader(SettingsText.notices, symbol: "doc.text.fill", tint: .graphite) {
                Button(CommonText.done, action: done)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            PaneScroll {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(Array(NoticesText.body(text).enumerated()), id: \.offset) { _, block in
                        blockView(block, t)
                    }
                }
                .textSelection(.enabled)
                .padding(Space.pane)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: Metrics.noticesSheet.width, height: Metrics.noticesSheet.height)
        .background(t.windowBg)
    }

    @ViewBuilder private func blockView(_ block: NoticesText.Block, _ t: Theme) -> some View {
        switch block {
        case .title(let s):
            Text(s).font(TypeScale.headline).foregroundStyle(t.fg)
        case .heading(let s):
            Text(s).font(TypeScale.bodySemibold).foregroundStyle(t.fg).padding(.top, Space.xs)
        case .paragraph(let s):
            Text(s)
                .font(TypeScale.secondary)
                .foregroundStyle(t.prose)
                .lineSpacing(TypeScale.footnoteLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        case .item(let s):
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Circle().fill(t.fg3).frame(width: Space.xxs, height: Space.xxs)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + Space.bulletLift }
                Text(s).font(TypeScale.secondary).foregroundStyle(t.prose).fixedSize(horizontal: false, vertical: true)
            }
        case .rule:
            Separator().padding(.vertical, Space.xxs)
        }
    }
}

/// Splits a notices file into blocks (pure, tested): `# ` title, `##`+ heading, `- `/`* ` item,
/// `---` rule, other lines joined into paragraphs (a blank line ends one). Inline Markdown stays as
/// text: licence texts must read exactly as written.
enum NoticesText {
    enum Block: Equatable {
        case title(String), heading(String), paragraph(String), item(String), rule
    }

    /// The blocks without a leading title (the sheet's header already names the file).
    static func body(_ text: String) -> [Block] {
        let all = blocks(text)
        if case .title = all.first { return Array(all.dropFirst()) }
        return all
    }

    static func blocks(_ text: String) -> [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("# ") {
                flush(); out.append(.title(String(line.dropFirst(2))))
            } else if line.hasPrefix("#") {
                flush(); out.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush(); out.append(.item(String(line.dropFirst(2))))
            } else if line.allSatisfy({ $0 == "-" }) && line.count >= 3 {
                flush(); out.append(.rule)
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return out
    }
}
