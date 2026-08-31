import Testing
@testable import Clide
import Foundation

struct WAVEncoderTests {
    @Test func writesAWellFormedRIFFHeader() {
        let data = WAVEncoder.encode(samples: [0, 0.5, -0.5])
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data.subdata(in: 8..<12) == Data("WAVE".utf8))
        #expect(data.subdata(in: 12..<16) == Data("fmt ".utf8))
    }

    @Test func sizeIsHeaderPlusTwoBytesPerSample() {
        let data = WAVEncoder.encode(samples: Array(repeating: 0, count: 100))
        #expect(data.count == 44 + 200)
    }

    @Test func clampsSamplesOutsideTheValidRange() {
        // Values beyond ±1 must not wrap around into loud noise.
        let data = WAVEncoder.encode(samples: [5.0, -5.0])
        let first = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self).littleEndian }
        let second = data.subdata(in: 46..<48).withUnsafeBytes { $0.load(as: Int16.self).littleEndian }
        #expect(first == Int16.max)
        #expect(second == -Int16.max)
    }

    @Test func encodesSilenceForNoSamples() {
        #expect(WAVEncoder.encode(samples: []).count == 44)
    }
}
