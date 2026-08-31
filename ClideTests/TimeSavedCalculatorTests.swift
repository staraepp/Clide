import Testing
@testable import Clide
import Foundation

struct TimeSavedCalculatorTests {
    @Test func countsWordsIgnoringExtraWhitespace() {
        #expect(TimeSavedCalculator.wordCount(of: "  hello   there  world ") == 3)
        #expect(TimeSavedCalculator.wordCount(of: "") == 0)
        #expect(TimeSavedCalculator.wordCount(of: "   ") == 0)
    }

    @Test func typingDurationUsesTheDocumentedBaseline() {
        // 40 words at the 40 WPM baseline should be one minute.
        let duration = TimeSavedCalculator.estimatedTypingDuration(wordCount: 40)
        #expect(abs(duration - 60) < 0.001)
    }

    @Test func typingDurationOfNothingIsZero() {
        #expect(TimeSavedCalculator.estimatedTypingDuration(wordCount: 0) == 0)
    }

    @Test func reportsSavingWhenSpeakingWasFaster() throws {
        // 40 words would take ~60s to type; speaking took 15s.
        let transcript = Array(repeating: "word", count: 40).joined(separator: " ")
        let saved = try #require(
            TimeSavedCalculator.timeSaved(transcript: transcript, speakingDuration: 15)
        )
        #expect(abs(saved - 45) < 0.001)
    }

    @Test func reportsNothingWhenSpeakingWasSlower() {
        // Two words is ~3s of typing; taking 30s to say them saved nothing.
        #expect(TimeSavedCalculator.timeSaved(transcript: "hello there", speakingDuration: 30) == nil)
    }

    @Test func reportsNothingRatherThanZeroWhenExactlyEqual() {
        let typingDuration = TimeSavedCalculator.estimatedTypingDuration(wordCount: 10)
        #expect(TimeSavedCalculator.timeSaved(wordCount: 10, speakingDuration: typingDuration) == nil)
    }

    @Test func emptyTranscriptNeverClaimsASaving() {
        #expect(TimeSavedCalculator.timeSaved(transcript: "", speakingDuration: 5) == nil)
    }

    @Test func descriptionsRoundFriendlyRatherThanPrecisely() {
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 7.438192) == "7 seconds")
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 1) == "1 second")
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 43.2) == "45 seconds")
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 90) == "2 minutes")
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 3600) == "1 hour")
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 5400) == "1.5 hours")
    }

    @Test func subSecondSavingsStillReadAsAtLeastOneSecond() {
        #expect(TimeSavedCalculator.friendlyDescription(ofSaved: 0.4) == "1 second")
    }
}
