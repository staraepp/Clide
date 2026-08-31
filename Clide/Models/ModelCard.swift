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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(model.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.capabilityTags.isEmpty {
                TagRow(tags: model.capabilityTags)
            }

            ratings
            Divider()
            footer
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.quaternary.opacity(isHovering ? 0.55 : 0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(model.displayName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(model.runtime.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))

            if isActive {
                Text("Active")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer(minLength: 0)

            Label(
                model.isLocal ? "On this Mac" : "Cloud",
                systemImage: model.isLocal ? "lock.fill" : "cloud"
            )
            .font(.caption)
            .foregroundStyle(model.isLocal ? .green : .secondary)
        }
    }

    private var ratings: some View {
        VStack(alignment: .leading, spacing: 3) {
            RatingRow(label: "Accuracy", stars: model.accuracyScore)
            RatingRow(label: "Speed", stars: model.speedScore)
            HStack(spacing: 8) {
                Text("Hardware Fit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 82, alignment: .leading)
                HardwareFitBadge(model: model)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(model.languageSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·").foregroundStyle(.tertiary)

            Text(model.formattedDownloadSize)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            actions
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isPreparing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Downloading…").font(.caption).foregroundStyle(.secondary)
            }
        } else if isActive {
            Label("In use", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        } else {
            HStack(spacing: 6) {
                if model.isLocal, !isInstalled {
                    Button("Download", action: onDownload)
                } else if model.isLocal, isInstalled {
                    Button("Delete", action: onDelete)
                }

                Button("Use", action: onUse)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!isReady && !model.isLocal)
            }
        }
    }
}

/// A labelled 1–5 star row. These are published-benchmark estimates, not
/// measurements — `ModelCard` shows them beside the computed Hardware Fit.
struct RatingRow: View {
    let label: String
    let stars: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            StarRow(filled: stars)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(stars) out of 5")
    }
}

struct StarRow: View {
    let filled: Int
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= filled ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(index <= filled ? tint : Color.secondary.opacity(0.35))
            }
        }
    }
}

private struct TagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary.opacity(0.6)))
            }
        }
    }
}
