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
    /// Third-party notices in the UI language; nil when the build bundled none. Read when shown,
    /// so a language switch takes effect. Renders and tests can set fixed text.
    var fixedNotices: String?
    var notices: String? { fixedNotices ?? AboutInfo.bundledNotices(Localizer.shared.lang) }
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

    /// `Contents/Resources/Notices/<lang>.md`, copied by build.sh from `App/Resources/Notices/`
    /// (written for the people using the app; THIRD_PARTY_NOTICES.md at the repository root is the
    /// developers' list). Falls back to English.
    static func bundledNotices(_ lang: Lang, bundle: Bundle = .main) -> String? {
        for code in [lang.rawValue, Lang.en.rawValue] {
            if let url = bundle.url(forResource: code, withExtension: "md", subdirectory: "Notices"),
               let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        }
        return nil
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
                    Text(info.copyright).font(TypeScale.caption).foregroundStyle(t.fg2)
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
                          button: SettingsText.showInFinder, buttonSymbol: "folder") { revealDataFolder() }
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
                    NavigationRow(SettingsText.noticesRow, subtitle: SettingsText.noticesDetail) { showsNotices = true }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.copiedHold) { didCopy = false }
    }

    private func revealDataFolder() {
        let folder = Paths.ensure(info.dataFolder)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

// MARK: - Third-party notices

/// The notices file in a sheet: a header band with Done (Return and Esc close it), the text below
/// (a small Markdown subset, see `NoticesText`).
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
            .renderEdgeFade()
        }
        .frame(width: Metrics.noticesSheet.width, height: Metrics.noticesSheet.height)
        .background(t.windowBg)
        .onExitCommand(perform: done)
    }

    @ViewBuilder private func blockView(_ block: NoticesText.Block, _ t: Theme) -> some View {
        switch block {
        case .title(let s):
            Text(NoticesText.styled(s)).font(TypeScale.headline).foregroundStyle(t.fg)
        case .heading(let s):
            Text(NoticesText.styled(s)).font(TypeScale.bodySemibold).foregroundStyle(t.fg).padding(.top, Space.xs)
        case .paragraph(let s):
            Text(NoticesText.styled(s))
                .font(TypeScale.secondary)
                .foregroundStyle(t.prose)
                .lineSpacing(TypeScale.footnoteLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        case .item(let s):
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Circle().fill(t.fg3).frame(width: Space.xxs, height: Space.xxs)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + Space.bulletLift }
                Text(NoticesText.styled(s)).font(TypeScale.secondary).foregroundStyle(t.prose)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .code(let s):
            // verbatim: licence texts are shown exactly as written, line breaks kept
            Text(verbatim: s)
                .font(TypeScale.code)
                .foregroundStyle(t.prose)
                .lineSpacing(TypeScale.footnoteLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(t.chip))
        case .rule:
            Separator().padding(.vertical, Space.xxs)
        }
    }
}

/// Splits a notices file into blocks (pure, tested): `# ` title, `##`+ heading, `- `/`* ` item,
/// `---` rule, fenced code (```) as one verbatim block with its line breaks, `<!-- … -->` comments
/// left out (notes for developers), other lines joined into paragraphs (a blank line ends one).
/// Inline `code` is the only inline Markdown (see `spans`); everything else stays as written.
enum NoticesText {
    enum Block: Equatable {
        case title(String), heading(String), paragraph(String), item(String), code(String), rule
    }

    struct Span: Equatable {
        let text: String
        var code = false
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
        var code: [String]?
        var inComment = false
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if var lines = code {
                if line.hasPrefix("```") {
                    out.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    lines.append(String(raw.reversed().drop { $0 == " " || $0 == "\t" }.reversed()))
                    code = lines
                }
                continue
            }
            if inComment {
                if line.contains("-->") { inComment = false }
                continue
            }
            if line.hasPrefix("<!--") {
                flush()
                inComment = !line.contains("-->")
                continue
            }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("```") {
                flush(); code = []
            } else if line.hasPrefix("# ") {
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
        if let code { out.append(.code(code.joined(separator: "\n"))) }
        return out
    }

    /// Inline code spans: text between a pair of backticks, without the backticks. An unpaired
    /// backtick stays as it is.
    static func spans(_ text: String) -> [Span] {
        var out: [Span] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "`") {
            let after = rest.index(after: open)
            guard let close = rest[after...].firstIndex(of: "`"), close > after else { break }
            if open > rest.startIndex { out.append(Span(text: String(rest[..<open]))) }
            out.append(Span(text: String(rest[after..<close]), code: true))
            rest = rest[rest.index(after: close)...]
        }
        if !rest.isEmpty { out.append(Span(text: String(rest))) }
        return out
    }

    /// `spans` as styled text: code in `TypeScale.codeInline`.
    static func styled(_ text: String) -> AttributedString {
        spans(text).reduce(into: AttributedString()) { result, span in
            var part = AttributedString(span.text)
            if span.code { part.font = TypeScale.codeInline }
            result += part
        }
    }
}
