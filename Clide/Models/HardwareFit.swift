import Foundation

/// How well a model suits this particular Mac, with the reasoning kept
/// alongside the score so the UI can explain the rating rather than just
/// showing decorative stars (clide.md §13).
struct HardwareFit: Sendable, Equatable {
    /// 1–5.
    let stars: Int
    let summary: String
    let positives: [String]
    let cautions: [String]

    static func evaluate(model: TranscriptionModelInfo, on hardware: HardwareProfile = .current) -> HardwareFit {
        switch model.runtime {
        case .cloud(let provider):
            return cloudFit(provider: provider, model: model)
        case .appleSpeech:
            return appleSpeechFit(hardware: hardware)
        case .whisperKit, .fluidAudio:
            return localFit(model: model, hardware: hardware)
        }
    }

    private static func localFit(model: TranscriptionModelInfo, hardware: HardwareProfile) -> HardwareFit {
        var positives: [String] = []
        var cautions: [String] = []
        var score = 3

        if hardware.hasNeuralEngine {
            positives.append("Runs on the Apple Neural Engine")
            score += 1
        } else {
            cautions.append("No Neural Engine on this Mac, so it runs on the CPU")
            score -= 1
        }

        if hardware.isAppleSilicon {
            positives.append("Native Apple Silicon runtime")
        }

        let headroom = hardware.memoryGigabytes - model.recommendedMemoryGB
        if headroom >= 4 {
            positives.append("Comfortable memory requirement (\(model.formattedMemoryRequirement))")
            score += 1
        } else if headroom >= 0 {
            positives.append("Meets the \(model.formattedMemoryRequirement) memory recommendation")
        } else {
            cautions.append("Wants \(model.formattedMemoryRequirement); this Mac has \(hardware.formattedMemory)")
            score -= 2
        }

        if model.speedScore >= 4, hardware.isAppleSilicon {
            positives.append("Expected to transcribe faster than real time")
        } else if model.speedScore <= 2 {
            cautions.append("Slower than the other local options here")
            score -= 1
        }

        if model.downloadSizeMB >= 1000 {
            cautions.append("Large download (\(model.formattedDownloadSize))")
        }

        return HardwareFit(
            stars: clamp(score),
            summary: summaryText(for: clamp(score)),
            positives: positives,
            cautions: cautions
        )
    }

    private static func appleSpeechFit(hardware: HardwareProfile) -> HardwareFit {
        HardwareFit(
            stars: 4,
            summary: "Built into macOS",
            positives: [
                "Nothing to download — macOS manages the model",
                "Uses no additional disk space",
            ],
            cautions: [
                "Offline support depends on the language models your Mac has installed",
                "Accuracy generally trails the dedicated local models",
            ]
        )
    }

    private static func cloudFit(provider: CloudProvider, model: TranscriptionModelInfo) -> HardwareFit {
        var cautions = [
            "Your audio is sent to \(provider.displayName)",
            "Needs an internet connection and your own API key",
        ]
        if model.speedScore <= 2 {
            cautions.append("Uploads and queues each recording, so expect a wait")
        }

        return HardwareFit(
            stars: 3,
            summary: "Doesn't depend on this Mac",
            positives: [
                "Runs on \(provider.displayName)'s hardware, not yours",
                "No download and no local memory used",
            ],
            cautions: cautions
        )
    }

    private static func clamp(_ score: Int) -> Int { min(max(score, 1), 5) }

    private static func summaryText(for stars: Int) -> String {
        switch stars {
        case 5: return "Excellent for this Mac"
        case 4: return "Great for this Mac"
        case 3: return "Works on this Mac"
        case 2: return "Usable, but not ideal here"
        default: return "Not recommended for this Mac"
        }
    }
}

extension TranscriptionModelInfo {
    var formattedMemoryRequirement: String {
        recommendedMemoryGB.rounded() == recommendedMemoryGB
            ? "\(Int(recommendedMemoryGB)) GB"
            : String(format: "%.1f GB", recommendedMemoryGB)
    }

    var formattedDownloadSize: String {
        switch source {
        case .systemManaged: return "Built in"
        case .remote: return "No download"
        case .download:
            return downloadSizeMB >= 1000
                ? String(format: "%.1f GB", Double(downloadSizeMB) / 1000)
                : "\(downloadSizeMB) MB"
        }
    }

    /// Short capability chips for the model browser.
    var capabilityTags: [String] {
        var tags: [String] = []
        if capabilities.streaming { tags.append("Streaming") }
        if capabilities.wordTimestamps { tags.append("Word timings") }
        if capabilities.diarization { tags.append("Speakers") }
        if capabilities.translation { tags.append("Translation") }
        if isMultilingual { tags.append("Multilingual") }
        return tags
    }
}

extension HardwareProfile {
    var formattedMemory: String {
        "\(Int(memoryGigabytes.rounded())) GB"
    }
}
