// STUB (S0): strand D replaces this folder (status, request, deep links, polling).
// The kinds match the permission names in starter.json / scripts/gen_config.py.

enum PermissionKind: String, CaseIterable {
    case notifications, accessibility, inputMonitoring, screenRecording, microphone, camera, automation,
         speechRecognition, contacts, calendars, reminders, photos, location, bluetooth, localNetwork
}

enum PermissionsKit {
    static func register() {}
}
