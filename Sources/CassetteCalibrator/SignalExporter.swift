import Foundation

struct SignalExporter {
    private let sampleRate = 44_100
    private let duration: Double = 8.0
    private let amplitude = 0.25

    func exportAllSignals(to directory: URL) throws {
        try export(signal: .noise, to: directory.appendingPathComponent("calibration_noise.wav"))
        try export(signal: .tone10k, to: directory.appendingPathComponent("calibration_tone_10k.wav"))
        try export(signal: .wowFlutter3k, to: directory.appendingPathComponent("calibration_tone_3k.wav"))
    }

    private func export(signal: GeneratedSignal, to url: URL) throws {
        let frameCount = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: frameCount * 4)

        for frame in 0 ..< frameCount {
            let sampleValue: Double
            switch signal {
            case .noise:
                sampleValue = Double.random(in: -1 ... 1) * amplitude
            case .tone10k:
                sampleValue = sin(2.0 * .pi * 10_000.0 * Double(frame) / Double(sampleRate)) * amplitude
            case .wowFlutter3k:
                sampleValue = sin(2.0 * .pi * 3_000.0 * Double(frame) / Double(sampleRate)) * amplitude
            }

            let intSample = Int16(max(min(sampleValue * Double(Int16.max), Double(Int16.max)), Double(Int16.min)))
            pcm.append(intSample)
            pcm.append(intSample)
        }

        let wavData = makeWAVData(pcmData: pcm, channels: 2, sampleRate: sampleRate, bitsPerSample: 16)
        try wavData.write(to: url, options: .atomic)
    }

    private func makeWAVData(pcmData: Data, channels: Int, sampleRate: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let riffChunkSize = 36 + pcmData.count

        var data = Data()
        data.append("RIFF")
        data.append(UInt32(riffChunkSize))
        data.append("WAVE")
        data.append("fmt ")
        data.append(UInt32(16))
        data.append(UInt16(1))
        data.append(UInt16(channels))
        data.append(UInt32(sampleRate))
        data.append(UInt32(byteRate))
        data.append(UInt16(blockAlign))
        data.append(UInt16(bitsPerSample))
        data.append("data")
        data.append(UInt32(pcmData.count))
        data.append(pcmData)
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(string.data(using: .ascii)!)
    }

    mutating func append(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(_ value: Int16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
