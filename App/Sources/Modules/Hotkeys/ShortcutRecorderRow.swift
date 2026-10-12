import SwiftUI

/// One hotkey in a settings card (VoiceBud HubShortcutsGroup row): title, what it does (or why the
/// last try was refused, in red, or the note of the new one), and on the right its key caps with
/// "Undo", "Default" and "Change"; while recording the held keys, a free variant and "Cancel".
/// Works in the settings pane and on the onboarding step (the subtitle tone comes from the
/// enclosing `SettingsSection`).
struct ShortcutRecorderRow: View {
    let id: String
    let center: HotkeyCenter
    let recorder: ShortcutRecorder
    @Environment(\.colorScheme) private var scheme
    @Environment(\.textTone) private var tone

    init(_ id: String, center: HotkeyCenter, recorder: ShortcutRecorder) {
        self.id = id
        self.center = center
        self.recorder = recorder
    }

    var body: some View {
        let t = Theme(scheme)
        if let definition = center.definition(id) {
            let (text, color) = subtitle(definition, t)
            Row(definition.title(), subtitle: text, subtitleColor: color, tone: tone) {
                trailing(t)
            }
        }
    }

    /// What the row says while it records, why the last try was refused, the note of the new
    /// shortcut, a registration problem, or what the hotkey does.
    private func subtitle(_ definition: HotkeyDefinition, _ t: Theme) -> (String?, Color?) {
        let problem = recorder.problem?.target == id ? recorder.problem : nil
        if recorder.target == id {
            if let problem { return (problem.text + "\n" + HotkeysText.tryAnother, t.strike) }
            if !recorder.live.isEmpty { return (HotkeysText.recordHolding, nil) }
            return (HotkeysText.recordPrompt, nil)
        }
        if let problem { return (problem.text, t.strike) }
        if let note = recorder.note, note.target == id { return (note.text, nil) }
        if let keys = center.display(id) {
            switch center.status[id] {
            case .heldElsewhere?: return (HotkeysText.heldElsewhereStatus(keys), t.strike)
            case .failed(let code)?: return (HotkeysText.failedStatus(keys, Int(code)), t.strike)
            default: break
            }
        }
        return (definition.subtitle?(), nil)
    }

    @ViewBuilder private func trailing(_ t: Theme) -> some View {
        let recording = recorder.target == id
        HStack(spacing: Space.shortcutRowGap) {
            if recording {
                if !recorder.live.isEmpty {
                    ringed(KeyCaps(recorder.live), t.accent)
                } else if let problem = recorder.problem, problem.target == id, !problem.keys.isEmpty {
                    ringed(KeyCaps(problem.keys), t.strike)            // what was pressed, refused
                } else {
                    Text(HotkeysText.pressKeys)
                        .font(TypeScale.secondaryMedium)
                        .foregroundStyle(t.accentText)
                        .padding(.horizontal, Space.recordingPlaceholderX)
                        .frame(height: Metrics.Hotkeys.recordingPlaceholderHeight)
                        .background(RoundedRectangle(cornerRadius: Radius.keyCap, style: .continuous)
                            .strokeBorder(t.accent, lineWidth: Metrics.Hotkeys.recordingRingLine))
                }
                if let problem = recorder.problem, problem.target == id, let free = problem.suggestion {
                    Chip(HotkeysText.use(center.layout.label(free))) { recorder.use(free) }
                }
                Chip(HotkeysText.cancel) { recorder.cancel() }
            } else {
                caps(t)
                if recorder.target == nil {
                    if recorder.canUndo(id) {
                        Chip(HotkeysText.undo) { recorder.undoLast() }
                    }
                    if center.choice(id) != .standard {
                        Chip(HotkeysText.standard) { recorder.restore(id, to: .standard) }
                            .help(HotkeysText.standardHelp)
                    }
                }
                Chip(HotkeysText.change) { recorder.start(id) }
            }
        }
        .fixedSize()                                         // the reason beside it wraps instead
    }

    @ViewBuilder private func caps(_ t: Theme) -> some View {
        let _ = center.layoutRevision                        // redraw when the keyboard layout changes
        if let combo = center.combo(id) {
            let caps = center.layout.caps(combo)
            KeyCaps(caps).accessibilityLabel(HotkeysText.accessibilityKeys(caps.joined()))
        } else {
            Text(HotkeysText.none)
                .font(TypeScale.secondaryMedium)
                .foregroundStyle(t.fg3)
                .frame(minHeight: Metrics.keyCap)
        }
    }

    private func ringed(_ caps: KeyCaps, _ color: Color) -> some View {
        caps
            .padding(Metrics.Hotkeys.recordingRingInset)
            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(color, lineWidth: Metrics.Hotkeys.recordingRingLine))
    }
}

/// Large key caps with the words printed on Mac keys (VoiceBud OnboardingBigKeys): the onboarding
/// step shows the primary shortcut this way, lit in the accent while it is held.
struct BigKeyCaps: View {
    let keys: [String]
    var pressed = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: Space.s) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                VStack(spacing: Metrics.Hotkeys.bigKeyWordGap) {
                    glyph(key).frame(height: Metrics.Hotkeys.bigKeyGlyphLine)
                    if let word = HotkeysText.capWord(key) {
                        Text(word)
                            .font(TypeScale.keyWord)
                            .foregroundStyle(pressed ? t.onAccent : t.prose)
                    }
                }
                .foregroundStyle(pressed ? t.onAccent : t.fg)
                .frame(width: Metrics.Hotkeys.bigKey.width, height: Metrics.Hotkeys.bigKey.height)
                .background(shape.fill(pressed ? t.accent : t.buttonSecondary))
                .overlay(shape.strokeBorder(t.buttonSecondaryEdge, lineWidth: Metrics.hairline))
                .background(shape.fill(t.tileEdge)
                    .offset(y: pressed ? Metrics.Hotkeys.bigKeyDepthPressed : Metrics.Hotkeys.bigKeyDepth))
                .offset(y: pressed ? Metrics.Hotkeys.bigKeyPress : 0)
            }
        }
        .animation(Motion.adaptive(Motion.press, reduce: reduceMotion), value: pressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HotkeysText.accessibilityKeys(keys.joined()))
    }

    @ViewBuilder private func glyph(_ key: String) -> some View {
        if let symbol = KeyCaps.symbolFor[key] {
            Image(systemName: symbol).symbolFont(Metrics.Hotkeys.bigKeyGlyph, weight: .regular)
        } else {
            Text(key).font(TypeScale.keyLetter)
        }
    }
}
