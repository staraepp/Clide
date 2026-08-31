import Foundation

/// Turns a raw transcript into the text that actually gets inserted
/// (clide.md §20): deterministic cleanup always runs, then the optional
/// transformations are applied according to the user's preferences.
///
/// Every optional step is best-effort by design — if one can't run, the
/// pipeline returns the text it has rather than failing the dictation.
struct TranscriptPipeline {
    let fillerRemovalMode: FormattingMode
    let aiFormattingMode: FormattingMode

    /// Optional steps the user still needs to decide on, for the pill's
    /// ask-each-time actions. The returned `text` is always safe to insert
    /// as-is if the user dismisses the prompt.
    struct Output {
        let text: String
        let pendingChoices: Set<OptionalStep>
    }

    enum OptionalStep: Hashable {
        case removeFillers
        case aiFormat
    }

    func process(_ rawTranscript: String) -> Output {
        var text = TranscriptCleanup.clean(rawTranscript)
        var pending: Set<OptionalStep> = []

        switch fillerRemovalMode {
        case .alwaysOn:
            text = FillerWordRemover.removeFillers(from: text)
        case .askEachTime:
            // Only worth asking if there's actually something to remove.
            if FillerWordRemover.removeFillers(from: text) != text {
                pending.insert(.removeFillers)
            }
        case .alwaysOff:
            break
        }

        // AI formatting has no engine yet (Apple's on-device model and the
        // Clide Mini local formatter are both still to come), so there is
        // nothing to apply or to ask about. The preference is honoured the
        // moment an engine exists; until then dictation proceeds unformatted
        // rather than blocking on a step Clide can't perform.

        return Output(text: text, pendingChoices: pending)
    }
}
