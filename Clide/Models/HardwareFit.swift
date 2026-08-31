import Foundation

/// How well a model suits this particular Mac, with the reasoning kept
/// alongside the score so the UI can explain the rating rather than just
/// showing decorative stars (clide.md §13).
struct HardwareFit: Sendable {
    /// 1–5.
    let stars: Int
    let summary: String
    let positives: [String]
    let cautions: [String]

    static func evaluate(model: TranscriptionModelInfo, on hardware: HardwareProfile = .current) -> HardwareFit {
        guard model.isLocal else { return cloudFit(for: model) }

        var positives: [String] = []
        var cautions: [String] = []
        var score = 3

        if model.usesNeuralEngine, hardware.hasNeuralEngine {
            positives.append("Runs on the Apple Neural Engine")
            score += 1
        } else if model.usesNeuralEngine {
            cautions.append("This Mac has no Neural Engine, so the model runs on the CPU")
            score -= 1
        }

        if hardware.isAppleSilicon {
            positives.append("Native Apple Silicon runtime")
        }

        let memoryHeadroom = hardware.memoryGigabytes - model.recommendedMemoryGB
        if memoryHeadroom >= 4 {
            positives.append("Comfortable memory headroom (\(model.formattedMemoryRequirement) recommended)")
            score += 1
        } else if memoryHeadroom >= 0 {
            positives.append("Meets the \(model.formattedMemoryRequirement) memory recommendation")
        } else {
            cautions.append("Wants \(model.formattedMemoryRequirement); this Mac has \(hardware.formattedMemory)")
            score -= 2
        }

        if model.speedScore >= 4, hardware.isAppleSilicon {
            positives.append("Expected to transcribe faster than real time")
        } else if model.speedScore <= 2 {
            cautions.append("Slower than the other local options")
        }

        let stars = min(max(score, 1), 5)
        return HardwareFit(
            stars: stars,
            summary: summaryText(for: stars),
            positives: positives,
            cautions: cautions
        )
    }

    private static func cloudFit(for model: TranscriptionModelInfo) -> HardwareFit {
        HardwareFit(
            stars: 3,
            summary: "Doesn't depend on this Mac",
            positives: [
                "Runs on \(model.runtime.displayName)'s hardware, not yours",
                "No model download and no local memory used",
            ],
            cautions: [
                "Your audio is sent to \(model.runtime.displayName)",
                "Needs an internet connection and your own API key",
            ]
        )
    }

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
        downloadSizeMB >= 1000
            ? String(format: "%.1f GB", Double(downloadSizeMB) / 1000)
            : "\(downloadSizeMB) MB"
    }
}

extension HardwareProfile {
    var formattedMemory: String {
        "\(Int(memoryGigabytes.rounded())) GB"
    }
}
