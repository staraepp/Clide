import AppKit
import Foundation

/// Drives the onboarding sequence and owns everything the steps need to
/// observe. Permission steps poll rather than asking the user to confirm they
/// did it, per clide.md §6.
@MainActor
final class OnboardingState: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case microphone
        case accessibility
        case model
        case tryIt
        case result
        case preferences
        case done
    }

    private static let completedKey = "Clide.hasCompletedOnboarding"

    static var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    @Published private(set) var step: Step = .welcome
    @Published private(set) var microphoneStatus = PermissionsManager.microphoneStatus()
    @Published private(set) var accessibilityStatus = PermissionsManager.accessibilityStatus()

    @Published private(set) var isPreparingModel = false
    @Published private(set) var modelError: String?
    /// Compatible models already on this Mac, so onboarding can say the
    /// download isn't needed rather than fetching a duplicate.
    @Published private(set) var discoveredModels: [DiscoveredModel] = []

    @Published private(set) var transcript: String?
    @Published private(set) var speakingDuration: TimeInterval = 0

    private let coordinator: DictationCoordinator
    private let modelManager: ModelManager
    private var permissionPollTimer: Timer?

    init(coordinator: DictationCoordinator, modelManager: ModelManager = .shared) {
        self.coordinator = coordinator
        self.modelManager = modelManager
    }

    var activeModel: TranscriptionModelInfo { modelManager.activeModel }

    /// The time saved by the practice dictation, or nil when speaking wasn't
    /// actually faster — onboarding then shows a plain success message instead
    /// of an unearned claim.
    var timeSaved: TimeInterval? {
        guard let transcript else { return nil }
        return TimeSavedCalculator.timeSaved(transcript: transcript, speakingDuration: speakingDuration)
    }

    // MARK: - Navigation

    func advance() {
        let next = min(step.rawValue + 1, Step.done.rawValue)
        goTo(Step(rawValue: next) ?? .done)
    }

    func goTo(_ newStep: Step) {
        step = newStep
        stopPollingPermissions()

        switch newStep {
        case .microphone, .accessibility:
            startPollingPermissions()
        case .model:
            discoveredModels = ExistingModelDiscovery.discover()
            Task { await prepareModel() }
        case .tryIt:
            beginPracticeDictation()
        default:
            break
        }
    }

    func finish() {
        stopPollingPermissions()
        coordinator.transcriptHandler = nil
        Self.hasCompleted = true
    }

    // MARK: - Permissions

    func requestMicrophone() {
        Task {
            _ = await PermissionsManager.requestMicrophoneAccess()
            refreshPermissionStatuses()
        }
    }

    func requestAccessibility() {
        PermissionsManager.promptForAccessibilityAccess()
    }

    func openAccessibilitySettings() {
        PermissionsManager.openAccessibilitySettings()
    }

    private func startPollingPermissions() {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissionStatuses() }
        }
    }

    private func stopPollingPermissions() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func refreshPermissionStatuses() {
        microphoneStatus = PermissionsManager.microphoneStatus()
        accessibilityStatus = PermissionsManager.accessibilityStatus()
    }

    // MARK: - Model

    private func prepareModel() async {
        isPreparingModel = true
        modelError = nil
        defer { isPreparingModel = false }

        do {
            try await modelManager.currentEngine().prepare()
        } catch {
            modelError = error.localizedDescription
        }
    }

    // MARK: - Practice dictation

    private func beginPracticeDictation() {
        coordinator.transcriptHandler = { [weak self] text, duration in
            guard let self else { return }
            self.transcript = text
            self.speakingDuration = duration
            self.goTo(.result)
        }
    }

    func retryDictation() {
        transcript = nil
        speakingDuration = 0
        goTo(.tryIt)
    }
}
