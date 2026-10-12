import AppKit

#if !TESTING
/// Process entry. Flags (`--render`, `--selftest`) run before any window, menu or status item
/// exists and exit; otherwise the AppKit app starts with `AppDelegate`.
@main enum Entry {
    static func main() {
        Launch.run(LaunchFlags.parse(CommandLine.arguments))
    }
}
#endif
