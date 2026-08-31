import AVFoundation
import CoreAudio

enum AudioCaptureError: Error, LocalizedError {
    case engineStartFailed(Error)
    case converterUnavailable
    case deviceUnavailable

    var errorDescription: String? {
        switch self {
        case .engineStartFailed:
            return "Couldn't start the microphone. Check it's connected and not in use."
        case .converterUnavailable:
            return "Couldn't prepare audio for transcription."
        case .deviceUnavailable:
            return "That microphone isn't available. Clide used the default instead."
        }
    }
}

/// Captures microphone audio via AVAudioEngine and exposes it as 16kHz mono
/// Float32 samples, the format WhisperKit expects.
///
/// The tap callback runs on a real-time audio thread, so buffered samples are
/// guarded by a lock rather than an actor — hopping onto an actor from the
/// render thread risks priority inversion and audio glitches.
final class AudioCaptureService: @unchecked Sendable {
    static let whisperSampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var capturedSamples: [Float] = []
    private var converter: AVAudioConverter?
    private var onAmplitude: (@Sendable (Float) -> Void)?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: AudioCaptureService.whisperSampleRate,
        channels: 1,
        interleaved: false
    )!

    /// - Parameter onAmplitude: called from the audio render thread with a
    ///   rough RMS level (roughly 0...0.3 for normal speech) for live waveform UI.
    func startRecording(
        preferredDeviceID: AudioDeviceID? = nil,
        onAmplitude: (@Sendable (Float) -> Void)? = nil
    ) throws {
        lock.lock()
        capturedSamples.removeAll()
        lock.unlock()
        self.onAmplitude = onAmplitude

        let inputNode = engine.inputNode

        // Must happen before the format is read or the engine starts, since
        // changing the device changes the input format.
        if let preferredDeviceID {
            try? Self.setInputDevice(preferredDeviceID, on: inputNode)
        }
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterUnavailable
        }
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer: buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed(error)
        }
    }

    /// Stops capture and returns everything recorded since `startRecording()`.
    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil

        lock.lock()
        defer { lock.unlock() }
        return capturedSamples
    }

    private func consume(buffer: AVAudioPCMBuffer) {
        reportAmplitude(from: buffer)
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard outputCapacity > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity)
        else { return }

        var conversionError: NSError?
        var suppliedInput = false
        converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard conversionError == nil, let channelData = outputBuffer.floatChannelData else { return }
        let frameLength = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        lock.lock()
        capturedSamples.append(contentsOf: samples)
        lock.unlock()
    }

    /// Points the engine's input unit at a specific microphone. Best-effort:
    /// if it fails, capture falls back to the system default rather than
    /// refusing to record.
    private static func setInputDevice(_ deviceID: AudioDeviceID, on inputNode: AVAudioInputNode) throws {
        guard let audioUnit = inputNode.audioUnit else { return }
        var mutableID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioCaptureError.deviceUnavailable
        }
    }

    private func reportAmplitude(from buffer: AVAudioPCMBuffer) {
        guard let onAmplitude, let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for index in 0..<frameLength {
            sumOfSquares += samples[index] * samples[index]
        }
        onAmplitude(sqrt(sumOfSquares / Float(frameLength)))
    }
}
