import Testing
@testable import Clide

/// Stands in for a formatter so pipeline behaviour can be tested without
/// depending on whether this particular Mac has Apple Intelligence.
private struct StubFormatter: TranscriptFormatter {
    var isAvailable: Bool = true
    var unavailableReason: String? = nil
    var displayName = "Stub"
    var result: Result<String, FormattingError> = .success("FORMATTED")

    func format(_ transcript: String) async throws -> String {
        try result.get()
    }
}

struct TranscriptPipelineTests {
    private func pipeline(
        filler: FormattingMode = .alwaysOff,
        ai: FormattingMode = .alwaysOff,
        formatter: StubFormatter = StubFormatter()
    ) -> TranscriptPipeline {
        TranscriptPipeline(fillerRemovalMode: filler, aiFormattingMode: ai, formatter: formatter)
    }

    // MARK: - Deterministic cleanup

    @Test func deterministicCleanupAlwaysRuns() async {
        let output = await pipeline().process("hello   there .  how are you")
        #expect(output.text == "Hello there. How are you")
    }

    @Test func removesFillersWhenAlwaysOn() async {
        let output = await pipeline(filler: .alwaysOn).process("um I think so")
        #expect(output.text == "I think so")
        #expect(output.pendingChoices.isEmpty)
    }

    @Test func keepsFillersWhenAlwaysOff() async {
        let output = await pipeline(filler: .alwaysOff).process("um I think so")
        #expect(output.text == "Um I think so")
    }

    /// Ask-each-time must never silently alter the text — it only flags that
    /// there's a decision worth surfacing.
    @Test func askEachTimeLeavesTextUntouchedButFlagsTheChoice() async {
        let output = await pipeline(filler: .askEachTime).process("um I think so")
        #expect(output.text == "Um I think so")
        #expect(output.pendingChoices.contains(.removeFillers))
    }

    @Test func askEachTimeDoesNotAskWhenThereIsNothingToRemove() async {
        let output = await pipeline(filler: .askEachTime).process("I think so")
        #expect(!output.pendingChoices.contains(.removeFillers))
    }

    // MARK: - AI formatting

    @Test func appliesFormatterWhenAlwaysOn() async {
        let output = await pipeline(ai: .alwaysOn).process("hello there")
        #expect(output.text == "FORMATTED")
    }

    @Test func offersFormattingAsAChoiceWhenAskEachTime() async {
        let output = await pipeline(ai: .askEachTime).process("hello there")
        #expect(output.pendingChoices.contains(.aiFormat))
        // The choice must not have been applied yet.
        #expect(output.text == "Hello there")
    }

    @Test func neverOffersFormattingWhenTheFormatterIsUnavailable() async {
        let unavailable = StubFormatter(isAvailable: false, unavailableReason: "nope")
        let output = await pipeline(ai: .askEachTime, formatter: unavailable).process("hello there")
        #expect(!output.pendingChoices.contains(.aiFormat))
    }

    @Test func skipsFormattingEntirelyWhenUnavailable() async {
        let unavailable = StubFormatter(isAvailable: false)
        let output = await pipeline(ai: .alwaysOn, formatter: unavailable).process("hello there")
        #expect(output.text == "Hello there")
    }

    /// The whole point of the pipeline's design: dictation survives a broken
    /// formatter, returning the clean transcript rather than failing.
    @Test func aFailingFormatterStillYieldsTheTranscript() async {
        let broken = StubFormatter(result: .failure(.failed("boom")))
        let output = await pipeline(ai: .alwaysOn, formatter: broken).process("hello there")
        #expect(output.text == "Hello there")
    }

    @Test func emptyTranscriptSurvivesThePipeline() async {
        let output = await pipeline(filler: .alwaysOn, ai: .alwaysOn).process("")
        #expect(output.text == "")
    }

    @Test func emptyTranscriptNeverOffersFormatting() async {
        let output = await pipeline(ai: .askEachTime).process("")
        #expect(!output.pendingChoices.contains(.aiFormat))
    }

    @Test func bothChoicesCanBeOfferedTogether() async {
        let output = await pipeline(filler: .askEachTime, ai: .askEachTime).process("um I think so")
        #expect(output.pendingChoices.contains(.removeFillers))
        #expect(output.pendingChoices.contains(.aiFormat))
    }
}
