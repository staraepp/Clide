import Foundation

/// Encodes raw samples as 16-bit PCM WAV data — the format cloud STT APIs expect
/// for a file upload. Kept separate from AudioCaptureService since only cloud
/// transcription engines need it; local engines take Float samples directly.
enum WAVEncoder {
    static func encode(samples: [Float], sampleRate: UInt32 = 16_000) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)

        var data = Data(capacity: 44 + Int(dataSize))

        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append(UInt32(36) + dataSize)
        append("WAVE")
        append("fmt ")
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(channels)
        append(sampleRate)
        append(byteRate)
        append(blockAlign)
        append(bitsPerSample)
        append("data")
        append(dataSize)

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(UInt16(bitPattern: Int16(clamped * Float(Int16.max))))
        }

        return data
    }
}
