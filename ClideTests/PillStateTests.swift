import Testing
@testable import Clide

struct PillStateTests {
    /// The three clipboard outcomes have different causes and different
    /// advice, so they must never collapse into one message.
    @Test func clipboardStatesExplainTheirDifferentCauses() {
        let states: [PillState] = [
            .copiedAfterInsertionFailed,
            .copiedNeedsAccessibility,
            .copiedUnsupportedField,
        ]
        let messages = states.map(\.message)
        #expect(Set(messages).count == messages.count)
        let allNonEmpty = messages.allSatisfy { !$0.isEmpty }
        #expect(allNonEmpty)
    }

    /// The pill must stay click-through unless it's genuinely offering
    /// something, or it would sit in front of the user's work eating clicks.
    @Test func onlyStatesOfferingSomethingAcceptClicks() {
        let passive: [PillState] = [
            .idle, .listening, .transcribing, .formatting, .inserted,
            .secureFieldBlocked, .copiedAfterInsertionFailed, .error("x"),
        ]
        let noneInteractive = passive.allSatisfy { !$0.isInteractive }
        #expect(noneInteractive)

        #expect(PillState.awaitingChoice.isInteractive)
        #expect(PillState.copiedNeedsAccessibility.isInteractive)
    }

    /// Permission problems must offer the fix, not just describe the problem.
    @Test func permissionProblemsOfferTheirFix() {
        #expect(PillState.copiedNeedsAccessibility.recoveryAction == .openAccessibilitySettings)
        #expect(PillState.microphoneUnavailable("no mic").recoveryAction == .openMicrophoneSettings)
        #expect(PillState.inserted.recoveryAction == nil)
    }

    @Test func idleIsTheOnlyHiddenState() {
        #expect(!PillState.idle.isVisible)
        let visible: [PillState] = [
            .listening, .transcribing, .formatting, .awaitingChoice, .inserted,
            .modelLoading("m"), .secureFieldBlocked, .microphoneUnavailable("x"), .error("x"),
        ]
        let allVisible = visible.allSatisfy(\.isVisible)
        #expect(allVisible)
    }

    @Test func everyVisibleStateSaysSomething() {
        let visible: [PillState] = [
            .listening, .transcribing, .formatting, .awaitingChoice, .inserted,
            .modelLoading("Whisper"), .copiedAfterInsertionFailed, .copiedNeedsAccessibility,
            .copiedUnsupportedField, .secureFieldBlocked, .microphoneUnavailable("no mic"),
            .error("boom"),
        ]
        let allHaveMessages = visible.allSatisfy { !$0.message.isEmpty }
        let allHaveSymbols = visible.allSatisfy { !$0.symbolName.isEmpty }
        #expect(allHaveMessages)
        #expect(allHaveSymbols)
    }

    @Test func onlyWaitingStatesCountAsBusy() {
        #expect(PillState.transcribing.isBusy)
        #expect(PillState.formatting.isBusy)
        #expect(PillState.modelLoading("m").isBusy)
        #expect(!PillState.listening.isBusy)
        #expect(!PillState.inserted.isBusy)
    }

    /// Advisory states get the warning treatment; routine confirmations don't.
    @Test func advisoryStatesAreTheOnesNeedingAttention() {
        #expect(PillState.copiedNeedsAccessibility.isAdvisory)
        #expect(PillState.secureFieldBlocked.isAdvisory)
        #expect(PillState.error("x").isAdvisory)
        #expect(!PillState.inserted.isAdvisory)
        #expect(!PillState.listening.isAdvisory)
    }

    @Test func modelLoadingNamesTheModel() {
        #expect(PillState.modelLoading("Whisper Base").message.contains("Whisper Base"))
    }
}
