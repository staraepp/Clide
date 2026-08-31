import Testing
@testable import Clide

struct TranscriptPipelineTests {
    private func pipeline(filler: FormattingMode) -> TranscriptPipeline {
        TranscriptPipeline(fillerRemovalMode: filler, aiFormattingMode: .alwaysOff)
    }

    @Test func deterministicCleanupAlwaysRuns() {
        let output = pipeline(filler: .alwaysOff).process("hello   there .  how are you")
        #expect(output.text == "Hello there. How are you")
    }

    @Test func removesFillersWhenAlwaysOn() {
        let output = pipeline(filler: .alwaysOn).process("um I think so")
        #expect(output.text == "I think so")
        #expect(output.pendingChoices.isEmpty)
    }

    @Test func keepsFillersWhenAlwaysOff() {
        let output = pipeline(filler: .alwaysOff).process("um I think so")
        #expect(output.text == "Um I think so")
        #expect(output.pendingChoices.isEmpty)
    }

    /// Ask-each-time must never silently alter the text — it only flags that
    /// there's a decision worth surfacing.
    @Test func askEachTimeLeavesTextUntouchedButFlagsTheChoice() {
        let output = pipeline(filler: .askEachTime).process("um I think so")
        #expect(output.text == "Um I think so")
        #expect(output.pendingChoices.contains(.removeFillers))
    }

    @Test func askEachTimeDoesNotAskWhenThereIsNothingToRemove() {
        let output = pipeline(filler: .askEachTime).process("I think so")
        #expect(output.pendingChoices.isEmpty)
    }

    /// AI formatting has no engine yet, so it must never block or prompt.
    @Test func aiFormattingNeverBlocksDictationWhileUnavailable() {
        let pipeline = TranscriptPipeline(fillerRemovalMode: .alwaysOff, aiFormattingMode: .alwaysOn)
        let output = pipeline.process("hello there")
        #expect(output.text == "Hello there")
        #expect(!output.pendingChoices.contains(.aiFormat))
    }

    @Test func emptyTranscriptSurvivesThePipeline() {
        #expect(pipeline(filler: .alwaysOn).process("").text == "")
    }
}
