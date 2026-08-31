import Testing
@testable import Clide

struct TranscriptCleanupTests {
    @Test func collapsesRepeatedSpaces() {
        #expect(TranscriptCleanup.clean("hello    there") == "Hello there")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(TranscriptCleanup.clean("  hello  ") == "Hello")
    }

    @Test func removesSpaceBeforePunctuation() {
        #expect(TranscriptCleanup.clean("hello , there !") == "Hello, there!")
    }

    @Test func addsMissingSpaceAfterPunctuation() {
        #expect(TranscriptCleanup.clean("hello.there") == "Hello. There")
    }

    @Test func leavesDecimalNumbersAlone() {
        #expect(TranscriptCleanup.clean("it costs 3.50 today") == "It costs 3.50 today")
    }

    @Test func capitalizesEachSentence() {
        #expect(TranscriptCleanup.clean("hello there. how are you?") == "Hello there. How are you?")
    }

    @Test func capitalizesAfterExclamationAndQuestion() {
        #expect(TranscriptCleanup.clean("wow! nice. really? yes") == "Wow! Nice. Really? Yes")
    }

    @Test func collapsesBlankLineRuns() {
        #expect(TranscriptCleanup.clean("first\n\n\n\nsecond") == "First\n\nSecond")
    }

    @Test func emptyInputStaysEmpty() {
        #expect(TranscriptCleanup.clean("") == "")
        #expect(TranscriptCleanup.clean("   ") == "")
    }

    @Test func alreadyCleanTextIsUnchanged() {
        let text = "This is already clean. It should not change."
        #expect(TranscriptCleanup.clean(text) == text)
    }
}
