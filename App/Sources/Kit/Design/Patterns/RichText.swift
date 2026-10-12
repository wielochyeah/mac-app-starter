import SwiftUI

/// Copy with inline action links (VoiceBud OnboardingRichText): `[Show in Finder](app://reveal)`
/// becomes a link in `accentText` that calls `perform("reveal")` instead of opening anything.
/// Only `app://` links are links; everything else (other brackets, stray Markdown, web URLs) is
/// shown exactly as written. Font, colour and alignment come from the caller's modifiers.
///
///     OnboardingRichText(OnboardingText.revealHint) { action in
///         if action == "reveal" { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
///     }
struct OnboardingRichText: View {
    let text: String
    var perform: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, perform: @escaping (String) -> Void = { _ in }) {
        self.text = text
        self.perform = perform
    }

    var body: some View {
        let t = Theme(scheme)
        let parts = RichTextLinks.parse(text)
        if parts.contains(where: \.isLink) {
            let perform = perform
            Text(RichTextLinks.attributed(parts))
                .tint(t.accentText)
                .environment(\.openURL, OpenURLAction { url in
                    MainActor.assumeIsolated {
                        if let action = RichTextLinks.action(of: url) { perform(action) }
                    }
                    return .handled
                })
        } else {
            Text(verbatim: text)
        }
    }
}

/// Parsing for `OnboardingRichText` (pure, tested in PatternsTests).
enum RichTextLinks {
    /// The link scheme: `app://<action>`.
    static let scheme = "app"

    enum Part: Equatable {
        case text(String)
        case link(title: String, action: String)

        var isLink: Bool { if case .link = self { true } else { false } }
    }

    /// Splits `text` into plain runs and `[title](app://action)` links. A bracket pair that is not
    /// an app link (missing `)`, empty title, other scheme, empty action) stays plain text.
    static func parse(_ text: String) -> [Part] {
        var parts: [Part] = []
        var plain = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "[", let (title, action, end) = link(in: text, at: i) {
                if !plain.isEmpty { parts.append(.text(plain)); plain = "" }
                parts.append(.link(title: title, action: action))
                i = end
            } else {
                plain.append(text[i])
                i = text.index(after: i)
            }
        }
        if !plain.isEmpty { parts.append(.text(plain)) }
        return parts
    }

    /// `[title](app://action)`: the link syntax `parse` reads, for a translated title.
    static func markdown(title: String, action: String) -> String {
        "[\(title)](\(scheme)://\(action))"
    }

    /// The action of an `app://action` URL, nil for anything else.
    static func action(of url: URL) -> String? {
        guard url.scheme == scheme, let host = url.host(), !host.isEmpty else { return nil }
        return host
    }

    static func attributed(_ parts: [Part]) -> AttributedString {
        var out = AttributedString()
        for part in parts {
            switch part {
            case .text(let s):
                out += AttributedString(s)
            case .link(let title, let action):
                var run = AttributedString(title)
                run.link = URL(string: "\(scheme)://\(action)")
                out += run
            }
        }
        return out
    }

    /// `[title](app://action)` starting at `start` (which is "["): title, action, index after ")".
    private static func link(in text: String, at start: String.Index) -> (String, String, String.Index)? {
        let afterOpen = text.index(after: start)
        guard let close = text[afterOpen...].firstIndex(of: "]") else { return nil }
        let title = String(text[afterOpen..<close])
        guard !title.isEmpty, !title.contains("[") else { return nil }
        let prefix = "(\(scheme)://"
        guard text[close...].dropFirst().hasPrefix(prefix) else { return nil }
        let actionStart = text.index(close, offsetBy: 1 + prefix.count)
        guard let paren = text[actionStart...].firstIndex(of: ")") else { return nil }
        let action = String(text[actionStart..<paren])
        // lower-case ASCII, digits and "-": URL hosts are case-insensitive, so nothing else survives
        guard !action.isEmpty, action.unicodeScalars.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" })
        else { return nil }
        return (title, action, text.index(after: paren))
    }
}
