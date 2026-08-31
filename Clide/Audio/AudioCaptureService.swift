import AVFoundation

enum AudioCaptureError: Error, LocalizedError {
    case engineStartFailed(Error)
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let error):
            return "Couldn't start the microphone: \(error.localizedDescription)"
        case .converterUnavailable:
            return "Couldn't prepare audio for transcription."
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
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: AudioCaptureService.whisperSampleRate,
        channels: 1,
        interleaved: false
    )!

    func startRecording() throws {
        lock.lock()
        capturedSamples.removeAll()
        lock.unlock()

        let inputNode = engine.inputNode
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
}
