import SwiftUI

enum ModelBrowserViewLayout: String, CaseIterable {
    case cards, table
}

/// The model browser (clide.md §14). Data-driven from `ModelCatalog` — this
/// view knows how to present metadata, never what any particular model is.
struct ModelBrowserView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var layout: ModelBrowserViewLayout = .cards
    @State private var errorMessage: String?
    @Namespace private var layoutSwitch

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case local = "Local"
        case cloud = "Cloud"
        case installed = "Installed"
        case recommended = "Recommended"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Rectangle().fill(ClideTheme.hairline).frame(height: 1)

            if visibleModels.isEmpty {
                ClideEmptyState(
                    symbol: "magnifyingglass",
                    title: "No matching models",
                    message: searchText.isEmpty
                        ? "Nothing fits that filter right now."
                        : "Nothing matches “\(searchText)”. Try a different search or filter.",
                    actionTitle: filter == .all ? nil : "Clear filter",
                    action: filter == .all ? nil : { filter = .all }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if layout == .cards {
                cardList
            } else {
                ModelComparisonTable(models: visibleModels, modelManager: modelManager)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .clideCanvas()
        .alert("Couldn't prepare that model", isPresented: errorBinding) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("Search models", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous)
                        .fill(ClideTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous)
                                .strokeBorder(ClideTheme.hairline, lineWidth: 1)
                        )
                )

                LayoutSwitch(layout: $layout, namespace: layoutSwitch)
            }

            FilterBar(filter: $filter)
        }
        .padding(12)
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filter == .all, searchText.isEmpty {
                    RecommendedStrip(models: modelManager.catalog, modelManager: modelManager)
                }

                ForEach(visibleModels) { model in
                    ModelCard(
                        model: model,
                        isActive: model.id == modelManager.activeModelID,
                        isInstalled: modelManager.isInstalled(model),
                        isPreparing: modelManager.preparingModelIDs.contains(model.id),
                        isReady: modelManager.isReadyToUse(model),
                        onUse: { modelManager.setActiveModel(model.id) },
                        onDownload: { download(model) },
                        onDelete: { modelManager.deleteDownload(for: model) }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .clideAnimation(ClideTheme.Motion.gentle, value: visibleModels.map(\.id))
            .padding(12)
        }
    }

    // MARK: - Data

    private var visibleModels: [TranscriptionModelInfo] {
        modelManager.catalog
            .filter { matchesFilter($0) }
            .filter { matchesSearch($0) }
            .sorted { lhs, rhs in
                // Best fit for this Mac first, so the useful choice is at the top.
                let lhsFit = HardwareFit.evaluate(model: lhs).stars
                let rhsFit = HardwareFit.evaluate(model: rhs).stars
                if lhsFit != rhsFit { return lhsFit > rhsFit }
                return lhs.accuracyScore > rhs.accuracyScore
            }
    }

    private func matchesFilter(_ model: TranscriptionModelInfo) -> Bool {
        switch filter {
        case .all: return true
        case .local: return model.isLocal
        case .cloud: return !model.isLocal
        case .installed: return modelManager.isInstalled(model) && model.isLocal
        case .recommended: return HardwareFit.evaluate(model: model).stars >= 4
        }
    }

    private func matchesSearch(_ model: TranscriptionModelInfo) -> Bool {
        guard !searchText.isEmpty else { return true }
        let haystack = [model.displayName, model.runtime.displayName, model.languageSummary, model.summary]
        return haystack.contains { $0.localizedStandardContains(searchText) }
    }

    private func download(_ model: TranscriptionModelInfo) {
        Task {
            do {
                try await modelManager.prepare(model)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Controls

/// Two-way toggle between the card gallery and the comparison table. The
/// selection indicator slides between icons via `matchedGeometryEffect`
/// rather than the layout jumping straight to the new state.
private struct LayoutSwitch: View {
    @Binding var layout: ModelBrowserViewLayout
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 2) {
            option(.cards, symbol: "square.grid.2x2")
            option(.table, symbol: "tablecells")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous)
                .fill(ClideTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous)
                        .strokeBorder(ClideTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func option(_ value: ModelBrowserViewLayout, symbol: String) -> some View {
        let isSelected = layout == value
        return Button { layout = value } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 26, height: 22)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: ClideTheme.Radius.inner - 2, style: .continuous)
                            .fill(ClideTheme.accent)
                            .matchedGeometryEffect(id: "layoutSelection", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .clideAnimation(ClideTheme.Motion.snap, value: isSelected)
    }
}

private struct FilterBar: View {
    @Binding var filter: ModelBrowserView.Filter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ModelBrowserView.Filter.allCases) { option in
                FilterPill(title: option.rawValue, isSelected: filter == option) {
                    filter = option
                }
            }
        }
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        isSelected ? ClideTheme.accent : (isHovering ? ClideTheme.surfaceHover : .clear)
                    )
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? .clear : ClideTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .clideAnimation(ClideTheme.Motion.snap, value: isSelected)
        .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
    }
}

/// The Mac's best-fitting models, surfaced above the full list rather than
/// buried in it (clide.md's "Recommended for this Mac" call-out).
private struct RecommendedStrip: View {
    let models: [TranscriptionModelInfo]
    @ObservedObject var modelManager: ModelManager

    private var recommended: [TranscriptionModelInfo] {
        models
            .filter { $0.isLocal && HardwareFit.evaluate(model: $0).stars >= 4 }
            .sorted { HardwareFit.evaluate(model: $0).stars > HardwareFit.evaluate(model: $1).stars }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        if !recommended.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ClideSectionHeader("Recommended for this Mac")

                HStack(spacing: 8) {
                    ForEach(recommended) { model in
                        RecommendedCard(
                            model: model,
                            isActive: model.id == modelManager.activeModelID,
                            activate: { modelManager.setActiveModel(model.id) }
                        )
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }
}

private struct RecommendedCard: View {
    let model: TranscriptionModelInfo
    let isActive: Bool
    let activate: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: activate) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    StarRow(filled: HardwareFit.evaluate(model: model).stars, size: 8, isAnimating: isHovering)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ClideTheme.accent)
                    }
                }
                Text(model.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(model.formattedDownloadSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .clideCard(padding: 0, radius: ClideTheme.Radius.inner, isHighlighted: isActive, isHovering: isHovering)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    ModelBrowserView()
}
