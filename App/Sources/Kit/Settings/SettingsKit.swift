import SwiftUI

// STUB (S0): a plain settings window listing Registry.settingsPanes, plus General and About.
// Strand E replaces this folder with the real hub (sidebar, pane header, General, About) and
// keeps `SettingsKit.register()`.

enum SettingsKit {
    static func register() {
        AppActions.settingsHandler = { pane in SettingsWindow.show(pane: pane) }
        Registry.settingsPanes += [
            SettingsPane(id: "general", group: .settings, order: 0, title: { SettingsText.general }, symbol: "gearshape.fill",
                         tint: .graphite) { AnyView(GeneralPaneStub()) },
            SettingsPane(id: "about", group: .settings, order: 1000, title: { SettingsText.about }, symbol: "info.circle.fill",
                         tint: .accent) { AnyView(AboutPaneStub()) },
        ]
    }
}

@Observable final class SettingsSelection {
    static let shared = SettingsSelection()
    var pane: String = "general"
}

enum SettingsWindow {
    static func show(pane: String?) {
        if let pane { SettingsSelection.shared.pane = pane }
        WindowHost.show(id: "settings", style: .settings, title: { CommonText.settings }) { AnyView(SettingsRootStub()) }
    }
}

private struct SettingsRootStub: View {
    @Environment(\.colorScheme) private var scheme
    private let selection = SettingsSelection.shared

    var body: some View {
        let t = Theme(scheme)
        let panes = Registry.orderedSettingsPanes
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Space.hair) {
                ForEach(panes) { pane in
                    Button { selection.pane = pane.id } label: {
                        HStack(spacing: Space.iconGap) {
                            SquircleIcon(symbol: pane.symbol, tint: pane.tint)
                            Text(pane.title()).font(TypeScale.body).foregroundStyle(t.fg)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.xs)
                        .frame(height: Metrics.sidebarRow)
                        .background(RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                            .fill(selection.pane == pane.id ? t.sideSel : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainStyle())
                }
                Spacer()
            }
            .padding(.top, Metrics.paneHeader)
            .padding(.horizontal, Space.xs)
            .frame(width: Metrics.sidebarWidth)
            .background(t.sidebarBg)
            Group {
                if let pane = panes.first(where: { $0.id == selection.pane }) ?? panes.first {
                    VStack(spacing: 0) {
                        SectionHeader(pane.title(), symbol: pane.symbol, tint: pane.tint)
                        pane.content()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(t.windowBg)
        .ignoresSafeArea()
    }
}

private struct GeneralPaneStub: View {
    private let localizer = Localizer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(SettingsText.language)
            Card {
                Row(SettingsText.interface) {
                    Segmented([("system", CommonText.systemLanguage), ("de", Lang.de.nativeName), ("en", Lang.en.nativeName)],
                              selection: Binding(get: { localizer.choice?.rawValue ?? "system" },
                                                 set: { localizer.choice = Lang(rawValue: $0) }))
                }
            }
            Spacer()
        }
        .frame(maxWidth: Metrics.settingsColumn, alignment: .leading)
        .padding(.horizontal, Space.pane)
        .padding(.top, Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AboutPaneStub: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: Space.s) {
            SquircleIcon(symbol: AppInfo.symbol, size: Metrics.squircleLarge)
            Text(AppInfo.displayName).font(TypeScale.title).foregroundStyle(t.fg)
            Text(CommonText.version(AppInfo.version, build: AppInfo.build)).font(TypeScale.secondary).foregroundStyle(t.fg2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
