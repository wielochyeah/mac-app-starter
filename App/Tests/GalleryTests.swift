#if TESTING
import AppKit
import SwiftUI

final class GalleryTests: TestSuite {
    static func entry(_ id: String, _ area: String, _ title: String) -> GalleryEntry {
        GalleryEntry(id: id, area: area, title: { title }) { AnyView(Color.clear.frame(width: 10, height: 10)) }
    }

    static var sample: [GalleryEntry] {
        [entry("zoo.a", "zoo", "Zebra"), entry("island.card", "island", "Done card"), entry("design.row", "design", "Row"),
         entry("patterns.list", "patterns", "List card"), entry("design.chip", "design", "Chip"), entry("apps.x", "apps", "Áppel")]
    }

    override class func register() {
        test("areas: kit first, then modules, then the rest alphabetically") {
            expectEqual(GalleryModel.areas(sample), ["design", "patterns", "island", "apps", "zoo"])
        }

        test("groups filter by area and search text") {
            let all = GalleryModel.groups(sample, area: nil, query: "")
            expectEqual(all.map(\.area), ["design", "patterns", "island", "apps", "zoo"])
            expectEqual(all[0].entries.map(\.id), ["design.row", "design.chip"], "input order is kept inside an area")
            expectEqual(GalleryModel.groups(sample, area: "design", query: "").map(\.area), ["design"])
            expectEqual(GalleryModel.groups(sample, area: nil, query: "card").flatMap { $0.entries.map(\.id) }, ["patterns.list", "island.card"])
            expectEqual(GalleryModel.groups(sample, area: nil, query: "design.chip").flatMap { $0.entries.map(\.id) }, ["design.chip"],
                        "the id is searchable")
            expectEqual(GalleryModel.groups(sample, area: nil, query: "appel").flatMap { $0.entries.map(\.id) }, ["apps.x"],
                        "accents are ignored")
            expectEqual(GalleryModel.groups(sample, area: "island", query: "row").count, 0)
            expectEqual(GalleryModel.groups(sample, area: nil, query: "   ").count, 5)
        }

        test("fit: fixed sizes scale down, never up; odd sizes are flexible") {
            expectEqual(GalleryFit.classify(CGSize(width: 520, height: 300)), .fixed(CGSize(width: 520, height: 300)))
            expectEqual(GalleryFit.classify(CGSize(width: CGFloat.infinity, height: 40)), .flexible)
            expectEqual(GalleryFit.classify(CGSize(width: 5000, height: 40)), .flexible)
            expectEqual(GalleryFit.classify(CGSize(width: 0, height: 40)), .flexible)
            expectEqual(GalleryFit.scale(ideal: CGSize(width: 800, height: 600), available: 400), 0.5)
            expectEqual(GalleryFit.scale(ideal: CGSize(width: 300, height: 100), available: 400), 1)
            expectEqual(GalleryFit.scale(ideal: CGSize(width: 300, height: 100), available: 0), 1)
        }

        test("fit layout keeps the aspect ratio") {
            expectEqual(GalleryFitLayout.fitted(CGSize(width: 800, height: 600), width: 400), CGSize(width: 400, height: 300))
            expectEqual(GalleryFitLayout.fitted(CGSize(width: 200, height: 100), width: 400), CGSize(width: 200, height: 100))
            expectEqual(GalleryFitLayout.fitted(CGSize(width: 200, height: 100), width: nil), CGSize(width: 200, height: 100))
        }

        test("gallery entries are measured with room to spare") {
            guard let accents = Registry.gallery.first(where: { $0.id == "design.accents" }) else { return fail("design.accents missing") }
            guard case .fixed(let size) = GalleryFit.size(of: accents) else { return fail("design.accents should have a fixed size") }
            expect(size.width >= 400 && size.width < Metrics.galleryFlexibleWidth, "width \(size.width)")
        }

        test("visibility, scheme and area titles") {
            expect(GalleryModel.isVisible(debug: true, setting: false))
            expect(GalleryModel.isVisible(debug: false, setting: true))
            expect(!GalleryModel.isVisible(debug: false, setting: false))
            expectEqual(GalleryScheme.window.resolve(.dark), .dark)
            expectEqual(GalleryScheme.light.resolve(.dark), .light)
            expectEqual(GalleryScheme.dark.resolve(.light), .dark)
            expectEqual(GalleryText.area("myFeature"), "MyFeature")
            Localizer.shared.forced = .de
            expectEqual(GalleryText.area("patterns"), "Muster")
            expectEqual(GalleryText.count(1), "1 Baustein")
            expectEqual(GalleryText.count(1284), "1.284 Bausteine")
            Localizer.shared.forced = .en
            expectEqual(GalleryText.count(2), "2 components")
        }
    }
}
#endif
