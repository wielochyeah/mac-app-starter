import AppKit
import ObjectiveC

/// With `STARTER_HEADLESS=1` (and for `--render` / `--selftest`) windows are never put on screen:
/// the NSWindow ordering methods become no-ops, ordering *out* still works. Lets tests drive the
/// real window code with nothing appearing. Ported from VoiceBud (HeadlessWindows).
enum HeadlessWindows {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        let pairs: [(Selector, Selector)] = [
            (#selector(NSWindow.orderFront(_:)), #selector(NSWindow.starterHeadless_orderFront(_:))),
            (#selector(NSWindow.orderBack(_:)), #selector(NSWindow.starterHeadless_orderBack(_:))),
            (#selector(NSWindow.makeKeyAndOrderFront(_:)), #selector(NSWindow.starterHeadless_makeKeyAndOrderFront(_:))),
            (#selector(NSWindow.orderFrontRegardless), #selector(NSWindow.starterHeadless_orderFrontRegardless)),
            (#selector(NSWindow.order(_:relativeTo:)), #selector(NSWindow.starterHeadless_order(_:relativeTo:))),
            (NSSelectorFromString("setIsVisible:"), #selector(NSWindow.starterHeadless_setIsVisible(_:))),
        ]
        for (original, replacement) in pairs {
            guard let a = class_getInstanceMethod(NSWindow.self, original),
                  let b = class_getInstanceMethod(NSWindow.self, replacement) else {
                Log.error("headless: cannot swizzle \(original)", "app")
                continue
            }
            method_exchangeImplementations(a, b)
        }
    }
}

extension NSWindow {
    @objc func starterHeadless_orderFront(_ sender: Any?) {}
    @objc func starterHeadless_orderBack(_ sender: Any?) {}
    @objc func starterHeadless_makeKeyAndOrderFront(_ sender: Any?) {}
    @objc func starterHeadless_orderFrontRegardless() {}
    @objc func starterHeadless_order(_ place: NSWindow.OrderingMode, relativeTo other: Int) {
        // after the exchange this name calls the original implementation
        if place == .out { starterHeadless_order(place, relativeTo: other) }
    }
    @objc func starterHeadless_setIsVisible(_ visible: Bool) {
        if !visible { starterHeadless_setIsVisible(visible) }
    }
}
