import SwiftUI

/// One model in the browser's card view.
struct ModelCard: View {
    let model: TranscriptionModelInfo
    let isActive: Bool
    let isInstalled: Bool
    let isPreparing: Bool
    let isReady: Bool
    let onUse: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var justFinishedInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            Text(model.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.capabilityTags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(model.capabilityTags, id: \.self) { ClideChip(text: $0) }
                }
            }

            ratings

            Rectangle().fill(ClideTheme.hairline).frame(height: 1)

            footer
        }
        .clideCard(isHighlighted: isActive, isHovering: isHovering)
        .onHover { isHovering = $0 }
        .onChange(of: isInstalled) { _, installed in
            guard installed else { return }
            justFinishedInstalling = true
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                justFinishedInstalling = false
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(model.displayName)
                .font(.clideDisplay(14.5))

            ClideChip(text: model.runtime.displayName)

            if isActive {
                ClideBadge(text: "Active", symbol: "checkmark", tone: .accent)
            }

            Spacer(minLength: 0)

            ClideBadge(
                text: model.isLocal ? "On this Mac" : "Cloud",
                symbol: model.isLocal ? "lock.fill" : "cloud",
                tone: model.isLocal ? .positive : .neutral
            )
        }
    }

    private var ratings: some View {
        VStack(alignment: .leading, spacing: 4) {
            RatingRow(label: "Accuracy", stars: model.accuracyScore, isAnimating: isHovering)
            RatingRow(label: "Speed", stars: model.speedScore, isAnimating: isHovering)
            HStack(spacing: 8) {
                Text("Hardware Fit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .leading)
                HardwareFitBadge(model: model)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(model.languageSummary)
            Text("·").foregroundStyle(.tertiary)
            Text(model.formattedDownloadSize)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .overlay(alignment: .trailing) { actions }
    }

    @ViewBuilder
    private var actions: some View {
        Group {
            if isPreparing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Downloading…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if justFinishedInstalling {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ClideTheme.positive)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else if isActive {
                Label("In use", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ClideTheme.accent)
            } else {
                HStack(spacing: 6) {
                    if model.isLocal, !isInstalled {
                        Button("Download", action: onDownload)
                            .buttonStyle(.clideSecondary)
                    } else if model.isLocal, isInstalled {
                        Button("Delete", action: onDelete)
                            .buttonStyle(.clideQuiet)
                    }

                    Button("Use", action: onUse)
                        .buttonStyle(.clidePrimary)
                        .disabled(!isReady && !model.isLocal)
                }
            }
        }
        .clideAnimation(ClideTheme.Motion.pop, value: isPreparing)
        .clideAnimation(ClideTheme.Motion.pop, value: justFinishedInstalling)
    }
}

#Preview {
    VStack(spacing: 10) {
        ForEach(ModelCatalog.all.prefix(3)) { model in
            ModelCard(
                model: model,
                isActive: model.id == ModelCatalog.defaultModelID,
                isInstalled: true,
                isPreparing: false,
                isReady: true,
                onUse: {},
                onDownload: {},
                onDelete: {}
            )
        }
    }
    .padding(20)
    .frame(width: 520)
    .clideCanvas()
}
