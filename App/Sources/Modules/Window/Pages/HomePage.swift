import AppKit
import SwiftUI

/// The start page a fresh project sees: app icon and name, what this page is, three next steps
/// with the paths to open, and the building blocks drawn with themselves. Registered as
/// `AppPage(id: "home", section: .main, order: 0)`. A project replaces it by registering its own
/// page at `section: .main, order: 0` (or lower); the sidebar then leaves this one out
/// (`MainWindowModel.visible`).
struct HomePage: View {
    static let id = "home"
    static let order = 0

    static var page: AppPage {
        AppPage(id: id, section: .main, order: order, title: { WindowText.homeTitle }, symbol: "house.fill") {
            AnyView(HomePage())
        }
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        PageScaffold(WindowText.homeTitle) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    AppIconImage(size: Metrics.Window.homeIcon)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(AppInfo.displayName).font(TypeScale.title).foregroundStyle(t.fg)
                        Text(CommonText.version(AppInfo.version, build: AppInfo.build))
                            .font(TypeScale.secondary).foregroundStyle(t.fg2)
                    }
                }
                Text(WindowText.homeLede)
                    .font(TypeScale.lede)
                    .foregroundStyle(t.prose)
                    .lineSpacing(TypeScale.proseLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: Metrics.settingsColumn, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                PageSectionTitle(WindowText.nextSteps)
                HStack(alignment: .top, spacing: Space.m) {
                    StepCard(number: 1, title: WindowText.stepPageTitle, text: WindowText.stepPageText, path: WindowCodeNames.featuresPath)
                    StepCard(number: 2, title: WindowText.stepBlocksTitle, text: WindowText.stepBlocksText, path: WindowCodeNames.componentsPath)
                    StepCard(number: 3, title: WindowText.stepAgentTitle, text: WindowText.stepAgentText, path: WindowCodeNames.skillPath)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            Shelf(WindowText.buildingBlocks, items: BuildingBlock.all, tileWidth: Metrics.Window.tile) { block in
                Tile(title: block.name, subtitle: block.detail(), seed: block.name, symbol: block.symbol)
            }

            Text(WindowText.replaceHome)
                .font(TypeScale.secondary)
                .foregroundStyle(t.fg2)
        }
    }
}

/// The app icon from the bundle, or the accent squircle with `app.symbol` before `make icon` ran.
struct AppIconImage: View {
    let size: CGFloat

    var body: some View {
        if let icon = AppInfo.icon() {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            SquircleIcon(symbol: AppConfig.symbol, size: size)
        }
    }
}

/// A numbered next-step card with a sentence and the path to open.
private struct StepCard: View {
    let number: Int
    let title: String
    let text: String
    let path: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(Format.number(number))
                .font(TypeScale.secondarySemibold.monospacedDigit())
                .foregroundStyle(t.accentText)
                .frame(width: Metrics.Window.stepNumber, height: Metrics.Window.stepNumber)
                .background(Circle().fill(t.accentSoft))
                .accessibilityHidden(true)
            Text(title)
                .font(TypeScale.bodySemibold)
                .foregroundStyle(t.fg)
                .padding(.top, Space.xxs)
            Text(text)
                .font(TypeScale.secondary)
                .foregroundStyle(t.prose)
                .lineSpacing(TypeScale.footnoteLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Space.xxs)
            // verbatim: a file path, the same in every language
            Text(verbatim: path)
                .font(TypeScale.caption.monospaced())
                .foregroundStyle(t.fg2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.xs)
                .padding(.vertical, Space.xxs)
                .background(RoundedRectangle(cornerRadius: Radius.keyCap, style: .continuous).fill(t.chip))
                .textSelection(.enabled)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(shape.fill(t.card))
        .overlay(shape.strokeBorder(t.cardStroke, lineWidth: Metrics.hairline))
        .accessibilityElement(children: .combine)
    }
}

/// The window module's building blocks, as shown on the start page and in the gallery.
struct BuildingBlock: Identifiable {
    let name: String
    let symbol: String
    let detail: () -> String
    var id: String { name }

    static var all: [BuildingBlock] {
        [
            BuildingBlock(name: WindowCodeNames.pageScaffold, symbol: "rectangle.topthird.inset.filled") { WindowText.blockPageScaffold },
            BuildingBlock(name: WindowCodeNames.heroHeader, symbol: "photo.fill") { WindowText.blockHero },
            BuildingBlock(name: WindowCodeNames.shelf, symbol: "rectangle.split.3x1.fill") { WindowText.blockShelf },
            BuildingBlock(name: WindowCodeNames.tile, symbol: "square.fill") { WindowText.blockTile },
            BuildingBlock(name: WindowCodeNames.tileGrid, symbol: "square.grid.3x3.fill") { WindowText.blockTileGrid },
            BuildingBlock(name: WindowCodeNames.itemList, symbol: "list.number") { WindowText.blockItemList },
            BuildingBlock(name: WindowCodeNames.detailHeader, symbol: "text.below.photo.fill") { WindowText.blockDetailHeader },
            BuildingBlock(name: WindowCodeNames.artwork, symbol: "paintpalette.fill") { WindowText.blockArtwork },
            BuildingBlock(name: WindowCodeNames.emptyPage, symbol: "tray.fill") { WindowText.blockEmptyPage },
        ]
    }
}
