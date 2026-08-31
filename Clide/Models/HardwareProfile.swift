import Foundation

/// What Clide knows about the Mac it's running on, used to give model
/// recommendations that reflect this machine rather than a generic guess
/// (clide.md §13).
struct HardwareProfile: Sendable {
    let modelIdentifier: String
    let physicalMemoryBytes: UInt64
    let coreCount: Int
    let isAppleSilicon: Bool

    var memoryGigabytes: Double {
        Double(physicalMemoryBytes) / 1_073_741_824
    }

    /// Apple Silicon Macs all ship a Neural Engine; Intel Macs never did.
    var hasNeuralEngine: Bool { isAppleSilicon }

    static let current = HardwareProfile(
        modelIdentifier: sysctlString("hw.model") ?? "Unknown",
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        coreCount: ProcessInfo.processInfo.processorCount,
        isAppleSilicon: sysctlInt("hw.optional.arm64") == 1
    )

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}
