import AVFoundation
import CoreAudio

/// An audio input the user can dictate through.
struct AudioInputDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

/// Enumerates microphones and tracks the user's choice (clide.md §8).
///
/// Selection is stored by UID rather than `AudioDeviceID`, because the numeric
/// ID is only stable for the current boot — a remembered ID would silently
/// point at a different device after a restart.
@MainActor
final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    private static let selectedUIDKey = "Clide.selectedInputDeviceUID"

    @Published private(set) var devices: [AudioInputDevice] = []

    /// `nil` means "follow the system default", which is what most people want
    /// and what keeps working when they plug in a headset.
    @Published var selectedDeviceUID: String? {
        didSet {
            UserDefaults.standard.set(selectedDeviceUID, forKey: Self.selectedUIDKey)
            clideLog(.info, "audio", "Input device set to \(selectedDeviceUID ?? "system default")")
        }
    }

    private init() {
        selectedDeviceUID = UserDefaults.standard.string(forKey: Self.selectedUIDKey)
        refreshDevices()
        observeDeviceChanges()
    }

    /// The chosen device, or nil when following the system default or when the
    /// remembered device has been unplugged.
    var selectedDevice: AudioInputDevice? {
        guard let selectedDeviceUID else { return nil }
        return devices.first { $0.uid == selectedDeviceUID }
    }

    /// True when a device was chosen but is no longer connected, so the UI can
    /// say so instead of silently recording from something else.
    var selectedDeviceIsMissing: Bool {
        selectedDeviceUID != nil && selectedDevice == nil
    }

    func refreshDevices() {
        devices = Self.inputDevices()
    }

    // MARK: - Device change handling

    private func observeDeviceChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
                clideLog(.debug, "audio", "Audio devices changed")
            }
        }
    }

    // MARK: - CoreAudio enumeration

    private static func inputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }

        return ids.compactMap { id in
            guard hasInputStreams(id),
                  let name = stringProperty(kAudioObjectPropertyName, of: id),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, of: id)
            else { return nil }
            return AudioInputDevice(id: id, uid: uid, name: name)
        }
    }

    /// Output-only devices also appear in the device list, so filter by whether
    /// the device actually has input streams.
    private static func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr, dataSize > 0
        else { return false }

        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferList.deallocate() }

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferList) == noErr
        else { return false }

        let list = UnsafeMutableAudioBufferListPointer(
            bufferList.assumingMemoryBound(to: AudioBufferList.self)
        )
        return list.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, of id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var value: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &value) == noErr else { return nil }

        let string = value as String
        return string.isEmpty ? nil : string
    }
}
