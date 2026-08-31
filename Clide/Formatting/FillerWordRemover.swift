import Foundation

/// Removes disfluencies from a transcript (clide.md §24).
///
/// Deliberately conservative. Only words that are almost never meaningful
/// content are removed — "um", "uh", and friends. Words the spec explicitly
/// warns about ("like", "so", "well", "you know") are left alone, because
/// removing them safely needs to distinguish filler use from ordinary use,
/// which this deterministic pass can't do.
enum FillerWordRemover {
    /// Single-token disfluencies, matched case-insensitively on word boundaries.
    static let fillerWords: Set<String> = [
        "um", "uh", "umm", "uhh", "erm", "hmm", "mmm", "ah", "eh",
    ]

    static func removeFillers(from transcript: String) -> String {
        guard !transcript.isEmpty else { return transcript }

        let alternatives = fillerWords.sorted().joined(separator: "|")
        // Also swallow a directly following comma, since models commonly emit
        // "Um, so I think…" and leaving the comma behind reads worse.
        let pattern = "(?i)\\b(?:\(alternatives))\\b,?"

        let stripped = transcript.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )

        // Removing words leaves double spaces and stranded punctuation behind;
        // reuse the deterministic cleanup rather than duplicating that logic.
        return TranscriptCleanup.clean(stripped)
    }
}
