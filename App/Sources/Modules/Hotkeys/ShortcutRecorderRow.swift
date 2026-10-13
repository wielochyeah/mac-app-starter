import SwiftUI

/// One hotkey in a settings card (VoiceBud HubShortcutsGroup row): title, what it does (or why the
/// last try was refused, in red, or the note of the new one), and on the right its key caps with
/// "Undo", "Default" and "Change"; while recording the held keys, a free variant and "Cancel".
/// Works in the settings pane and on the onboarding step (the subtitle tone comes from the
/// enclosing `SettingsSection`). On the step (onboarding tone) the large key caps above already
/// show the keys, so the row leaves them out, and while recording the instructions and reasons
/// run under the title at the full width of the card, the free variant below them.
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

    private var onStep: Bool { tone == .onboarding }
    private var recording: Bool { recorder.target == id }
    private var problem: ShortcutRecorder.Problem? { recorder.problem?.target == id ? recorder.problem : nil }

    var body: some View {
        let t = Theme(scheme)
        if let definition = center.definition(id) {
            let (text, color) = subtitle(definition, t)
            if onStep && recording {
                stacked(definition, text: text, color: color, t)
            } else {
                Row(definition.title(), subtitle: text, subtitleColor: color, tone: tone) {
                    trailing(t)
                }
            }
        }
    }

    /// Title and controls on one line, the text and the free variant below at full width.
    private func stacked(_ definition: HotkeyDefinition, text: String?, color: Color?, _ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.s) {
                Text(definition.title()).font(TypeScale.body).foregroundStyle(t.fg)
                Spacer(minLength: Space.s)
                trailing(t)
            }
            if let text {
                Text(text)
                    .font(tone.small)
                    .foregroundStyle(color ?? tone.smallColor(t))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let free = problem?.suggestion {
                Chip(HotkeysText.use(center.layout.label(free))) { recorder.use(free) }
            }
        }
        .padding(.horizontal, Space.rowX)
        .padding(.vertical, Space.rowY)
        .frame(minHeight: Metrics.rowMinHeight)
    }

    /// What the row says while it records, why the last try was refused, the note of the new
    /// shortcut, a registration problem, or what the hotkey does.
    private func subtitle(_ definition: HotkeyDefinition, _ t: Theme) -> (String?, Color?) {
        if recording {
            if let problem { return (problem.text + " " + HotkeysText.escToCancel, t.strikeText) }
            if !recorder.live.isEmpty { return (HotkeysText.recordHolding, nil) }
            return (HotkeysText.recordPrompt, nil)
        }
        if let problem { return (problem.text, t.strikeText) }
        if let note = recorder.note, note.target == id { return (note.text, nil) }
        // keys that are set but do not arrive are a warning (orange, like the step's status line);
        // red stays for a combination refused while recording
        if let keys = center.display(id) {
            switch center.status[id] {
            case .heldElsewhere?: return (HotkeysText.heldElsewhereStatus(keys), t.warnText)
            case .failed(let code)?: return (HotkeysText.failedStatus(keys, Int(code)), t.warnText)
            case .duplicate(let other)?:
                let title = center.definition(other)?.title() ?? other
                return (HotkeysText.duplicateStatus(keys, of: title), t.warnText)
            default: break
            }
        }
        return (definition.subtitle?(), nil)
    }

    @ViewBuilder private func trailing(_ t: Theme) -> some View {
        HStack(spacing: Space.shortcutRowGap) {
            if recording {
                if !recorder.live.isEmpty {
                    ringed(KeyCaps(recorder.live), t.accent)
                } else if let problem, !problem.keys.isEmpty {
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
                if !onStep, let free = problem?.suggestion {
                    Chip(HotkeysText.use(center.layout.label(free))) { recorder.use(free) }
                }
                Chip(HotkeysText.cancel) { recorder.cancel() }
            } else {
                if !onStep { caps(t) }
                if recorder.target == nil {
                    if recorder.canUndo(id) {
                        Chip(HotkeysText.undo) { recorder.undoLast() }
                    }
                    if center.choice(id) != .standard, center.combo(id) != center.definition(id)?.standard {
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
                .foregroundStyle(t.fg2)
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
