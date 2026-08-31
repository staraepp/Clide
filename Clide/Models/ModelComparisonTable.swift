import SwiftUI

/// Compact comparison view for scanning many models at once (clide.md §14).
struct ModelComparisonTable: View {
    let models: [TranscriptionModelInfo]
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        Table(models) {
            TableColumn("Model") { model in
                HStack(spacing: 6) {
                    if model.id == modelManager.activeModelID {
                        Circle().fill(ClideTheme.accent).frame(width: 6, height: 6)
                    }
                    Text(model.displayName)
                }
            }

            TableColumn("Runtime") { model in
                Text(model.runtime.displayName).foregroundStyle(.secondary)
            }

            TableColumn("Where") { model in
                ClideBadge(
                    text: model.isLocal ? "On this Mac" : "Cloud",
                    tone: model.isLocal ? .positive : .neutral
                )
            }

            TableColumn("Size") { model in
                Text(model.formattedDownloadSize).foregroundStyle(.secondary)
            }

            TableColumn("Accuracy") { model in
                StarRow(filled: model.accuracyScore)
            }

            TableColumn("Speed") { model in
                StarRow(filled: model.speedScore)
            }

            TableColumn("Fit") { model in
                HardwareFitBadge(model: model, showsSummary: false)
            }

            TableColumn("") { model in
                if model.id == modelManager.activeModelID {
                    Text("Active").font(.caption).foregroundStyle(ClideTheme.accent)
                } else {
                    Button("Use") { modelManager.setActiveModel(model.id) }
                        .buttonStyle(.clideQuiet)
                        .font(.caption)
                }
            }
        }
        .clideCanvas()
    }
}
