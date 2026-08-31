import SwiftUI

/// Compact comparison view for scanning many models at once (clide.md §14).
struct ModelComparisonTable: View {
    let models: [TranscriptionModelInfo]
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        Table(models) {
            // Explicit widths throughout — Table's default column sizing
            // truncated model names ("Whisper Large…") and even the "Speed"
            // header itself when left to its own defaults at this sheet width.
            TableColumn("Model") { model in
                HStack(spacing: 6) {
                    if model.id == modelManager.activeModelID {
                        Circle().fill(ClideTheme.accent).frame(width: 6, height: 6)
                    }
                    Text(model.displayName)
                        .lineLimit(1)
                }
            }
            .width(min: 150, ideal: 190)

            TableColumn("Runtime") { model in
                Text(model.runtime.displayName).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 68, ideal: 80, max: 96)

            TableColumn("Where") { model in
                ClideBadge(
                    text: model.isLocal ? "On this Mac" : "Cloud",
                    tone: model.isLocal ? .positive : .neutral
                )
            }
            .width(min: 78, ideal: 90, max: 100)

            TableColumn("Size") { model in
                Text(model.formattedDownloadSize).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 60, ideal: 68, max: 76)

            TableColumn("Accuracy") { model in
                StarRow(filled: model.accuracyScore)
            }
            .width(min: 62, ideal: 68, max: 74)

            TableColumn("Speed") { model in
                StarRow(filled: model.speedScore)
            }
            .width(min: 62, ideal: 68, max: 74)

            TableColumn("Fit") { model in
                HardwareFitBadge(model: model, showsSummary: false)
            }
            .width(min: 74, ideal: 84, max: 96)

            TableColumn("") { model in
                if model.id == modelManager.activeModelID {
                    Text("Active").font(.caption).foregroundStyle(ClideTheme.accent)
                } else {
                    Button("Use") { modelManager.setActiveModel(model.id) }
                        .buttonStyle(.clideQuiet)
                        .font(.caption)
                }
            }
            .width(min: 44, ideal: 56, max: 64)
        }
        .clideCanvas()
    }
}
