import SwiftUI

/// The model browser (clide.md §14). Data-driven from `ModelCatalog` — this
/// view knows how to present metadata, never what any particular model is.
struct ModelBrowserView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var layout: Layout = .cards
    @State private var errorMessage: String?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case local = "Local"
        case cloud = "Cloud"
        case installed = "Installed"
        case recommended = "Recommended"

        var id: String { rawValue }
    }

    private enum Layout: String, CaseIterable {
        case cards, table
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()

            if visibleModels.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else if layout == .cards {
                cardList
            } else {
                ModelComparisonTable(models: visibleModels, modelManager: modelManager)
            }
        }
        .frame(minWidth: 620, minHeight: 460)
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
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search models", text: $searchText)
                    .textFieldStyle(.plain)

                Picker("View", selection: $layout) {
                    Image(systemName: "square.grid.2x2").tag(Layout.cards)
                    Image(systemName: "tablecells").tag(Layout.table)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 90)
            }

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(12)
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
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
                }
            }
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

#Preview {
    ModelBrowserView()
}
