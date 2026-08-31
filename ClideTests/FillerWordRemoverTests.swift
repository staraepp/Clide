import Testing
@testable import Clide

struct FillerWordRemoverTests {
    @Test func removesCommonDisfluencies() {
        #expect(FillerWordRemover.removeFillers(from: "um I think so") == "I think so")
        #expect(FillerWordRemover.removeFillers(from: "so uh we should go") == "So we should go")
    }

    @Test func removesTheCommaTrailingAFiller() {
        #expect(FillerWordRemover.removeFillers(from: "Um, so I think") == "So I think")
    }

    @Test func matchesRegardlessOfCase() {
        #expect(FillerWordRemover.removeFillers(from: "UM I think") == "I think")
    }

    /// The spec explicitly warns against stripping these — they're frequently
    /// meaningful, and this deterministic pass can't tell the difference.
    @Test func leavesAmbiguousWordsAlone() {
        #expect(FillerWordRemover.removeFillers(from: "I like it so well") == "I like it so well")
        #expect(FillerWordRemover.removeFillers(from: "you know the answer") == "You know the answer")
    }

    @Test func doesNotStripFillersEmbeddedInRealWords() {
        #expect(FillerWordRemover.removeFillers(from: "the umbrella is huge") == "The umbrella is huge")
        #expect(FillerWordRemover.removeFillers(from: "she said ahead") == "She said ahead")
    }

    @Test func tidiesWhitespaceLeftBehind() {
        #expect(FillerWordRemover.removeFillers(from: "well um okay") == "Well okay")
    }

    @Test func emptyInputStaysEmpty() {
        #expect(FillerWordRemover.removeFillers(from: "") == "")
    }

    @Test func textWithNoFillersIsUnchanged() {
        #expect(FillerWordRemover.removeFillers(from: "A clean sentence.") == "A clean sentence.")
    }
}
