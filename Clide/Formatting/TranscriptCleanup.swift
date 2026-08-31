import Foundation

/// Deterministic, LLM-free transcript tidying (clide.md §21).
///
/// Kept intentionally conservative and predictable: it fixes spacing and
/// obvious punctuation/capitalization artifacts that speech models produce,
/// and does nothing clever. Anything requiring judgement belongs in the
/// optional AI formatting step instead.
enum TranscriptCleanup {
    static func clean(_ transcript: String) -> String {
        var text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        text = collapseWhitespace(in: text)
        text = tightenPunctuationSpacing(in: text)
        text = capitalizeSentences(in: text)
        return text
    }

    /// Runs of whitespace become single spaces; blank-line runs collapse to
    /// one paragraph break.
    private static func collapseWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
    }

    /// Removes the space some models emit before punctuation, and ensures one
    /// space after it.
    private static func tightenPunctuationSpacing(in text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "([,.!?;:])(?=[^\\s\\d])", with: "$1 ", options: .regularExpression)
    }

    /// Capitalizes the first letter of the text and of each sentence following
    /// terminal punctuation.
    private static func capitalizeSentences(in text: String) -> String {
        let characters = Array(text)
        var result = ""
        result.reserveCapacity(characters.count)
        var capitalizeNext = true

        for (index, character) in characters.enumerated() {
            if capitalizeNext, character.isLetter {
                result.append(contentsOf: character.uppercased())
                capitalizeNext = false
            } else {
                result.append(character)
                if character == "\n" {
                    capitalizeNext = true
                } else if character == "." || character == "!" || character == "?" {
                    // Only a sentence end if whitespace (or nothing) follows —
                    // otherwise this is something like the "." in "3.50".
                    let next = characters.indices.contains(index + 1) ? characters[index + 1] : " "
                    capitalizeNext = next.isWhitespace
                }
            }
        }
        return result
    }
}
