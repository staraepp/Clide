import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The global dictation toggle. Defaults to ⌥+. per the product spec.
    @MainActor static let toggleDictation = Self("toggleDictation", default: .init(.period, modifiers: [.option]))
}
