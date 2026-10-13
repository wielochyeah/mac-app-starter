import SwiftUI

/// Settings pane "Island & Capsule" (VoiceBud HubIslandPane): the live stage, the shape tiles,
/// confirmation time, hover, feedback and a preview on the real island.
struct IslandPane: View {
    static let symbol = "rectangle.topthird.inset.filled"

    private let settings = Settings.shared

    private let demo = IslandDemo.state

    var body: some View {
        let dodges = Island.shared.notchBusy != nil
        let style = (IslandStyle(rawValue: settings[.islandStyle]) ?? .auto).shown(dodges: dodges)
        let offered = IslandStyle.offered(dodges: dodges)
        PaneScaffold(title: IslandText.pane, symbol: Self.symbol, tint: .black, subtitle: IslandText.paneIntro) {
            IslandStyleStage(style: style)
            // the note explains the chosen shape, so it sits right under the tiles
            SettingsSection(footnote: IslandText.styleNote(style, dodges: dodges),
                            footnoteReserve: offered.map { IslandText.styleNote($0, dodges: dodges) }) {
                TilePicker(offered.map { TileOption($0, title: IslandText.style($0)) },
                           selection: binding(.islandStyle, map: { (IslandStyle(rawValue: $0) ?? .auto).shown(dodges: dodges) },
                                              back: \.rawValue),
                           tone: .settings) { IslandStyleTile(style: $0) }
            }
            SettingsSection {
                PickerRow(IslandText.confirmation, subtitle: IslandText.confirmationDetail,
                          options: IslandPrefs.confirmChoices.map { ($0, IslandText.confirmChoice($0)) },
                          selection: binding(.islandConfirmSeconds, map: Self.nearestChoice, back: { $0 }))
                ToggleRow(IslandText.hoverExpand, subtitle: IslandText.hoverExpandDetail, isOn: binding(.islandHoverExpand))
            }
            SettingsSection(IslandText.feedback) {
                ToggleRow(IslandText.sounds, subtitle: IslandText.soundsDetail, isOn: binding(.islandSounds))
                ToggleRow(IslandText.haptics, subtitle: IslandText.hapticsDetail, isOn: binding(.islandHaptics))
                ToggleRow(IslandText.hideInFullscreen, subtitle: IslandText.hideInFullscreenDetail, isOn: binding(.islandHideInFullscreen))
            }
            SettingsSection {
                ButtonRow(IslandText.preview, subtitle: IslandText.previewDetail, symbol: "play.fill", tint: .black,
                          button: demo.previewing ? IslandText.stopPreview : IslandText.showPreview) {
                    demo.previewing ? IslandDemo.stop() : IslandDemo.preview()
                }
                // the app's own content is up: the preview would replace it
                .disabled(!demo.previewing && Island.shared.model.content != nil)
            }
        }
    }

    /// A stored value that is not one of the choices shows as the nearest one.
    static func nearestChoice(_ seconds: Double) -> Double {
        IslandPrefs.confirmChoices.min { abs($0 - seconds) < abs($1 - seconds) } ?? seconds
    }

    private func binding<V>(_ key: SettingKey<V>) -> Binding<V> {
        binding(key, map: { $0 }, back: { $0 })
    }

    private func binding<V, T>(_ key: SettingKey<V>, map: @escaping (V) -> T, back: @escaping (T) -> V) -> Binding<T> {
        Binding(get: { map(settings[key]) }, set: {
            settings[key] = back($0)
            Island.shared.settingsDidChange()
        })
    }
}
