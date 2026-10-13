import AppKit
import SwiftUI

/// The panel under the status item (macOS 26 Control Center look): header with app icon, name and
/// status line, the contributed sections as rounded tiles, the menu item contributions as
/// actions, and a footer with Settings, Open window (with the window module) and Quit.
struct MenuBarPanelView: View {
    let close: () -> Void
    var sections: [MenuBarSection]
    var actions: [MenuItemContribution]
    var status: MenuBarStatus
    var showsWindowAction: Bool
    var onHeight: ((CGFloat) -> Void)?
    @Environment(\.colorScheme) private var scheme

    init(close: @escaping () -> Void, sections: [MenuBarSection] = MenuBarPanel.orderedSections,
         actions: [MenuItemContribution] = Registry.orderedMenuItems, status: MenuBarStatus = .shared,
         showsWindowAction: Bool = AppInfo.isEnabled("window"), onHeight: ((CGFloat) -> Void)? = nil) {
        self.close = close
        self.sections = sections
        self.actions = actions
        self.status = status
        self.showsWindowAction = showsWindowAction
        self.onHeight = onHeight
    }

    var body: some View {
        let context = MenuBarPanelContext(close: close)
        GlassSurface(cornerRadius: Radius.windowGlass) {
            VStack(alignment: .leading, spacing: Space.xs) {
                MenuBarPanelHeader(status: status)
                ForEach(sections) { section in
                    if section.tiled {
                        MenuBarTile(title: section.title?()) { section.content(context) }
                    } else {
                        section.content(context)
                    }
                }
                if !actions.isEmpty {
                    MenuBarTile(title: MenuBarText.actions) {
                        ForEach(actions) { item in
                            MenuBarActionRow(item.title(), symbol: item.symbol, shortcut: item.shortcut) {
                                close()
                                item.action()
                            }
                        }
                    }
                }
                footer
            }
            .padding(Space.s)
        }
        .frame(width: MenuBarPanelMetrics.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { onHeight?($0) })
    }

    /// Settings, Open window and Quit as named chips without symbols, the same in every language
    /// (German names leave no room for symbols at 340 pt, and one footer must not change its style
    /// with the language).
    private var footer: some View {
        HStack(spacing: Space.xs) {
            Chip(CommonText.settings) {
                close()
                AppActions.openSettings()
            }
            .fixedSize()
            if showsWindowAction {
                Chip(MenuBarText.openWindow) {
                    close()
                    AppActions.openMainWindow()
                }
                .fixedSize()
            }
            Spacer(minLength: Space.xs)
            Chip(MenuBarText.quit) { AppActions.quit() }.fixedSize()
        }
        .padding(.top, Space.xxs)
    }
}

/// App icon, name and the status line.
struct MenuBarPanelHeader: View {
    var status: MenuBarStatus

    private static let icon: NSImage? = AppInfo.icon()

    var body: some View {
        HStack(spacing: Space.s) {
            if let icon = Self.icon {
                Image(nsImage: icon).resizable()
                    .frame(width: MenuBarPanelMetrics.appIcon, height: MenuBarPanelMetrics.appIcon)
            } else {
                SquircleIcon(symbol: AppInfo.symbol, size: MenuBarPanelMetrics.appIcon)
            }
            VStack(alignment: .leading, spacing: Space.hair) {
                MenuBarAppName()
                MenuBarStatusLine(state: status.state, text: status.line)
                    .animation(Motion.fade, value: status.state)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Space.xxs)
        .accessibilityElement(children: .combine)
    }
}

private struct MenuBarAppName: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(AppInfo.displayName).font(TypeScale.bodySemibold).foregroundStyle(Theme(scheme).fg).lineLimit(1)
    }
}

/// The state as a mark and words: grey dot when ready, spinner while working, a red dot like the
/// icon's when the app needs the person. The mark sits at the leading edge of a slot as wide as
/// the spinner, so the dot lines up with the app name above and the words never move sideways.
struct MenuBarStatusLine: View {
    let state: MenuBarState
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.xxs + Space.hair) {
            Group {
                switch state {
                case .idle: Circle().fill(t.idle).frame(width: Metrics.dot, height: Metrics.dot)
                case .busy: Spinner(size: MenuBarPanelMetrics.statusSpinner)
                case .attention: Circle().fill(t.strike).frame(width: Metrics.dot, height: Metrics.dot)
                }
            }
            .frame(width: MenuBarPanelMetrics.statusSpinner, height: MenuBarPanelMetrics.statusSpinner, alignment: .leading)
            Text(text)
                .font(state == .attention ? TypeScale.secondaryMedium : TypeScale.secondary)
                .foregroundStyle(state == .attention ? t.fg : t.prose)
                .lineLimit(1)
        }
    }
}

/// A rounded tile in the panel (one Control Center module), optional title inside at the top.
struct MenuBarTile<Content: View>: View {
    var title: String?
    let content: Content
    @Environment(\.colorScheme) private var scheme

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(TypeScale.secondarySemibold)
                    .foregroundStyle(t.fg2)
                    .padding(.horizontal, Space.xs)
                    .padding(.top, Space.xxs)
                    .padding(.bottom, Space.xxs)
            }
            content
        }
        .padding(Space.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(t.field))
    }
}

/// A menu-like row: symbol, title, shortcut on the right, hover highlight.
struct MenuBarActionRow: View {
    let title: String
    var symbol: String?
    var shortcut: String?
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    init(_ title: String, symbol: String? = nil, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        let t = Theme(scheme)
        HoverButton(action: action) {
            HStack(spacing: Space.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .symbolFont(MenuBarPanelMetrics.rowSymbol, weight: .medium)
                        .foregroundStyle(t.fg2)
                        .frame(width: MenuBarPanelMetrics.rowSymbolColumn)
                }
                Text(title).font(TypeScale.body).foregroundStyle(t.fg).lineLimit(1)
                Spacer(minLength: Space.xs)
                if let shortcut, !shortcut.isEmpty {
                    Text(shortcut).font(TypeScale.secondary).foregroundStyle(t.fg2)
                }
            }
            .padding(.horizontal, Space.xs)
            .frame(height: Metrics.buttonHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

/// A Control Center-style toggle: round symbol button (accent when on), title, state below.
/// Two of them side by side make a quick-settings row (`MenuBarSection(tiled: false)`).
struct MenuBarToggle: View {
    let title: String
    let symbol: String
    var detail: String?
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, symbol: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.symbol = symbol
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        let t = Theme(scheme)
        Button {
            withAnimation(Motion.adaptive(Motion.toggle, reduce: reduceMotion)) { isOn.toggle() }
        } label: {
            HStack(spacing: Space.xs) {
                Circle()
                    .fill(isOn ? t.accent : t.chipActive)
                    .frame(width: MenuBarPanelMetrics.toggleCircle, height: MenuBarPanelMetrics.toggleCircle)
                    .overlay {
                        Image(systemName: symbol)
                            .symbolFont(MenuBarPanelMetrics.rowSymbol, weight: .semibold)
                            .foregroundStyle(isOn ? t.onAccent : t.fg)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(TypeScale.secondarySemibold).foregroundStyle(t.fg).lineLimit(1)
                    Text(detail ?? (isOn ? CommonText.on : CommonText.off))
                        .font(TypeScale.caption).foregroundStyle(t.fg2).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(t.field))
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? CommonText.on : CommonText.off)
    }
}

extension MenuBarPanelMetrics {
    /// Symbols in action rows and toggles.
    static let rowSymbol: CGFloat = 13
    static let rowSymbolColumn: CGFloat = 18
    static let statusSpinner: CGFloat = 12
}
