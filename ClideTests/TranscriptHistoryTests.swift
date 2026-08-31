import Testing
@testable import Clide
import Foundation

/// `TranscriptHistory` is a singleton backed by UserDefaults, so these tests
/// exercise the entry model and the privacy rules that don't require mutating
/// the shared store.
struct TranscriptHistoryTests {
    private let model = ModelCatalog.all[0]

    @Test func entriesRoundTripThroughCoding() throws {
        let entry = TranscriptEntry(
            text: "hello there",
            modelID: model.id,
            speakingDuration: 3,
            sourceApplication: "TextEdit"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TranscriptEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.text == entry.text)
        #expect(decoded.modelID == entry.modelID)
        #expect(decoded.sourceApplication == "TextEdit")
    }

    @Test func entriesTolerateAnUnknownSourceApplication() throws {
        let entry = TranscriptEntry(
            text: "no app",
            modelID: model.id,
            speakingDuration: 1,
            sourceApplication: nil
        )
        let decoded = try JSONDecoder().decode(
            TranscriptEntry.self,
            from: try JSONEncoder().encode(entry)
        )
        #expect(decoded.sourceApplication == nil)
    }

    /// Statistics must stay useful with history off, so they must never carry
    /// the transcript itself — only counts derived from it.
    @Test func statisticsRecordsHoldNoTranscriptText() throws {
        let record = DictationRecord(
            date: Date(),
            wordCount: 4,
            speakingDuration: 2,
            modelID: model.id,
            wasLocal: true
        )
        let json = try #require(String(data: try JSONEncoder().encode(record), encoding: .utf8))
        #expect(!json.localizedCaseInsensitiveContains("text"))
        #expect(json.contains("wordCount"))
    }
}
