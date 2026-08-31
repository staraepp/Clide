import Foundation

/// Turns a raw transcript into the text that actually gets inserted
/// (clide.md §20): deterministic cleanup always runs, then the optional
/// transformations are applied according to the user's preferences.
///
/// Every optional step is best-effort by design — if one fails or isn't
/// available, the pipeline returns the text it has. Dictation must never fail
/// because formatting did.
struct TranscriptPipeline {
    let fillerRemovalMode: FormattingMode
    let aiFormattingMode: FormattingMode
    let formatter: TranscriptFormatter

    init(
        fillerRemovalMode: FormattingMode,
        aiFormattingMode: FormattingMode,
        formatter: TranscriptFormatter = AppleFormatter()
    ) {
        self.fillerRemovalMode = fillerRemovalMode
        self.aiFormattingMode = aiFormattingMode
        self.formatter = formatter
    }

    /// Optional steps the user still needs to decide on, for the pill's
    /// ask-each-time actions. `text` is always safe to insert as-is.
    struct Output {
        let text: String
        let pendingChoices: Set<OptionalStep>
    }

    enum OptionalStep: Hashable {
        case removeFillers
        case aiFormat
    }

    /// Deterministic-only pass. Synchronous, so callers that can't await
    /// (and tests of the deterministic rules) stay simple.
    func processDeterministically(_ rawTranscript: String) -> Output {
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

        if aiFormattingMode == .askEachTime, formatter.isAvailable, !text.isEmpty {
            pending.insert(.aiFormat)
        }

        return Output(text: text, pendingChoices: pending)
    }

    /// Full pass, applying AI formatting when the user has it set to Always On
    /// and a formatter is actually available.
    func process(_ rawTranscript: String) async -> Output {
        let deterministic = processDeterministically(rawTranscript)

        guard aiFormattingMode == .alwaysOn,
              formatter.isAvailable,
              !deterministic.text.isEmpty
        else {
            return deterministic
        }

        do {
            let formatted = try await formatter.format(deterministic.text)
            return Output(text: formatted, pendingChoices: deterministic.pendingChoices)
        } catch {
            // Formatting is a nice-to-have; keep the transcript and move on.
            await MainActor.run {
                clideLog(.warning, "formatting", "Formatter failed, inserting unformatted: \(error.localizedDescription)")
            }
            return deterministic
        }
    }
}
