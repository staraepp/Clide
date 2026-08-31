import Foundation

/// Estimates how much time dictating saved compared with typing the same text.
///
/// Used by onboarding after the first dictation, and reusable for the
/// today/this-week/lifetime totals on the dashboard.
///
/// The methodology is deliberately simple so it stays explainable to users:
/// take the transcript's word count, divide by an average typing speed to get
/// an estimated typing duration, and subtract how long the user actually spoke.
enum TimeSavedCalculator {
    /// Average sustained typing speed for an adult on a full keyboard, in words
    /// per minute. 40 WPM is the widely cited average for general prose typing;
    /// it's an estimate, and the UI must say so wherever a saving is shown.
    ///
    /// Exposed as a named constant (rather than inlined at a call site) because
    /// it's a documented product assumption that may later become configurable.
    static let averageTypingWordsPerMinute: Double = 40

    /// Words in a transcript, counted the way a person would count them.
    static func wordCount(of transcript: String) -> Int {
        transcript.split(whereSeparator: \.isWhitespace).count
    }

    /// How long the given transcript would take to type, in seconds.
    static func estimatedTypingDuration(
        wordCount: Int,
        wordsPerMinute: Double = averageTypingWordsPerMinute
    ) -> TimeInterval {
        guard wordCount > 0, wordsPerMinute > 0 else { return 0 }
        return Double(wordCount) / wordsPerMinute * 60
    }

    /// Time saved by speaking instead of typing, in seconds.
    ///
    /// Returns `nil` when speaking wasn't actually faster — callers should then
    /// show a plain success message rather than an unearned or negative claim.
    static func timeSaved(
        transcript: String,
        speakingDuration: TimeInterval,
        wordsPerMinute: Double = averageTypingWordsPerMinute
    ) -> TimeInterval? {
        timeSaved(
            wordCount: wordCount(of: transcript),
            speakingDuration: speakingDuration,
            wordsPerMinute: wordsPerMinute
        )
    }

    static func timeSaved(
        wordCount: Int,
        speakingDuration: TimeInterval,
        wordsPerMinute: Double = averageTypingWordsPerMinute
    ) -> TimeInterval? {
        let typingDuration = estimatedTypingDuration(wordCount: wordCount, wordsPerMinute: wordsPerMinute)
        let saved = typingDuration - speakingDuration
        return saved > 0 ? saved : nil
    }

    /// Friendly, deliberately imprecise phrasing for a saved duration —
    /// "about 8 seconds", never "7.438192 seconds".
    static func friendlyDescription(ofSaved seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())

        if totalSeconds < 60 {
            let rounded = totalSeconds < 10 ? totalSeconds : Int((Double(totalSeconds) / 5).rounded() * 5)
            let value = max(rounded, 1)
            return "\(value) second\(value == 1 ? "" : "s")"
        }

        let minutes = Int((Double(totalSeconds) / 60).rounded())
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }

        let hours = Double(minutes) / 60
        let formatted = hours.rounded() == hours
            ? String(Int(hours))
            : String(format: "%.1f", hours)
        return "\(formatted) hour\(hours == 1 ? "" : "s")"
    }

    /// The disclaimer that must accompany any time-saved figure shown to users.
    static let methodologyDisclaimer = "Estimated using an average typing speed. Actual typing speed varies."
}
