import Foundation
import AVFoundation
import AVFAudio
import Combine
import CoreMedia

@MainActor
final class AudioController: ObservableObject {
    @Published var audioReady = false
    @Published var audioStateText = "Audio idle"
    @Published var inputDeviceSummary = "Input unknown"
    @Published var sampleRate: Double = 44_100
    @Published var noiseResult = NoiseCalibrationResult.empty
    @Published var toneResult = ToneCalibrationResult.empty
    @Published var wowFlutterResult = WowFlutterResult.empty
    @Published var isSignalPlaying = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let analyzer = SignalAnalyzer()
    private var lastPeakDB = -120.0

    func start() {
        refreshDeviceSummary()
        configureAudioSession()
        installInputTap()
        startEngineIfNeeded()
    }

    func playSignal(_ signal: GeneratedSignal) {
        stopSignal()

        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        var phase = 0.0
        let phaseIncrement = { (frequency: Double) in
            2.0 * Double.pi * frequency / sampleRate
        }

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                let value: Float
                switch signal {
                case .noise:
                    value = Float.random(in: -0.2 ... 0.2)
                case .tone10k:
                    value = Float(sin(phase) * 0.25)
                    phase += phaseIncrement(10_000)
                case .wowFlutter3k:
                    value = Float(sin(phase) * 0.25)
                    phase += phaseIncrement(3_000)
                }

                if phase > 2.0 * Double.pi {
                    phase.formTruncatingRemainder(dividingBy: 2.0 * Double.pi)
                }

                for buffer in abl {
                    let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                    pointer?[frame] = value
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        startEngineIfNeeded()
        isSignalPlaying = true
    }

    func stopSignal() {
        guard let sourceNode else { return }
        engine.disconnectNodeInput(sourceNode)
        engine.disconnectNodeOutput(sourceNode)
        engine.detach(sourceNode)
        self.sourceNode = nil
        isSignalPlaying = false
    }

    private func configureAudioSession() {
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        sampleRate = inputFormat.sampleRate
        audioStateText = inputFormat.channelCount > 0 ? "Audio monitoring active" : "No input channels available"
        audioReady = inputFormat.channelCount > 0
    }

    private func installInputTap() {
        engine.inputNode.removeTap(onBus: 0)
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { return }
        let analyzer = self.analyzer

        engine.inputNode.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            let analysis = analyzer.analyze(buffer: buffer)
            Task { @MainActor [weak self, analysis] in
                self?.apply(analysis)
            }
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            audioReady = true
            audioStateText = "Audio engine running"
        } catch {
            audioReady = false
            audioStateText = "Audio start failed: \(error.localizedDescription)"
        }
    }

    private func refreshDeviceSummary() {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.external, .microphone], mediaType: .audio, position: .unspecified).devices
        if let first = devices.first {
            inputDeviceSummary = first.localizedName
        } else {
            inputDeviceSummary = "No audio device detected"
        }
    }

    private func apply(_ analysis: AnalysisFrame) {
        noiseResult = NoiseCalibrationResult(
            highBandDB: analysis.highBandDB,
            midBandDB: analysis.midBandDB,
            biasErrorDB: analysis.biasErrorDB,
            status: analysis.biasStatus
        )

        lastPeakDB = max(lastPeakDB, analysis.toneLevelDB)
        let toneStatus: BiasStatus
        if abs(lastPeakDB - analysis.toneLevelDB) <= 0.2 {
            toneStatus = .max
        } else if (-1.5 ... -0.5).contains(analysis.toneLevelDB - lastPeakDB) {
            toneStatus = .recommended
        } else if analysis.toneLevelDB > lastPeakDB {
            toneStatus = .under
        } else {
            toneStatus = .over
        }

        toneResult = ToneCalibrationResult(
            levelDB: analysis.toneLevelDB,
            peakDB: lastPeakDB,
            deltaDB: analysis.toneLevelDB - lastPeakDB,
            status: toneStatus
        )

        wowFlutterResult = WowFlutterResult(
            frequency: analysis.estimatedFrequency,
            wowFlutterPercent: analysis.wowFlutterPercent,
            rating: analysis.wowFlutterRating
        )
    }
}

private struct AnalysisFrame: Sendable {
    let highBandDB: Double
    let midBandDB: Double
    let biasErrorDB: Double
    let biasStatus: BiasStatus
    let toneLevelDB: Double
    let estimatedFrequency: Double
    let wowFlutterPercent: Double
    let wowFlutterRating: WowFlutterRating
}

private final class SignalAnalyzer: @unchecked Sendable {
    private var frequencyHistory: [Double] = []

    func analyze(buffer: AVAudioPCMBuffer) -> AnalysisFrame {
        guard let channelData = buffer.floatChannelData?[0] else {
            return .init(
                highBandDB: -120,
                midBandDB: -120,
                biasErrorDB: 0,
                biasStatus: .unknown,
                toneLevelDB: -120,
                estimatedFrequency: 0,
                wowFlutterPercent: 0,
                wowFlutterRating: .unknown
            )
        }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        let sampleRate = buffer.format.sampleRate

        let midBand = bandAverage(samples: samples, sampleRate: sampleRate, frequencies: stride(from: 1_000.0, through: 4_000.0, by: 500.0).map { $0 })
        let highBand = bandAverage(samples: samples, sampleRate: sampleRate, frequencies: stride(from: 8_000.0, through: 12_000.0, by: 500.0).map { $0 })
        let biasError = highBand - midBand

        let biasStatus: BiasStatus
        if biasError > 0.5 {
            biasStatus = .under
        } else if biasError < -0.5 {
            biasStatus = .over
        } else {
            biasStatus = .ok
        }

        let toneLevel = goertzelDB(samples: samples, sampleRate: sampleRate, targetFrequency: 10_000)
        let estimatedFrequency = estimateFrequency(samples: samples, sampleRate: sampleRate, minimumFrequency: 2_500, maximumFrequency: 3_500)

        if estimatedFrequency > 0 {
            frequencyHistory.append(estimatedFrequency)
            if frequencyHistory.count > 32 {
                frequencyHistory.removeFirst(frequencyHistory.count - 32)
            }
        }

        let wowPercent = computeWowFlutterPercent(referenceFrequency: 3_000)
        let wowRating: WowFlutterRating
        switch wowPercent {
        case ..<0.05:
            wowRating = .excellent
        case ..<0.1:
            wowRating = .good
        case ..<0.2:
            wowRating = .ok
        default:
            wowRating = .bad
        }

        return .init(
            highBandDB: highBand,
            midBandDB: midBand,
            biasErrorDB: biasError,
            biasStatus: biasStatus,
            toneLevelDB: toneLevel,
            estimatedFrequency: estimatedFrequency,
            wowFlutterPercent: wowPercent,
            wowFlutterRating: wowRating
        )
    }

    private func bandAverage(samples: [Float], sampleRate: Double, frequencies: [Double]) -> Double {
        let values = frequencies.map { goertzelLinear(samples: samples, sampleRate: sampleRate, targetFrequency: $0) }
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        return linearToDB(mean)
    }

    private func goertzelDB(samples: [Float], sampleRate: Double, targetFrequency: Double) -> Double {
        linearToDB(goertzelLinear(samples: samples, sampleRate: sampleRate, targetFrequency: targetFrequency))
    }

    private func goertzelLinear(samples: [Float], sampleRate: Double, targetFrequency: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let normalizedFrequency = targetFrequency / sampleRate
        let coefficient = 2.0 * cos(2.0 * Double.pi * normalizedFrequency)
        var q0 = 0.0
        var q1 = 0.0
        var q2 = 0.0

        for sample in samples {
            q0 = coefficient * q1 - q2 + Double(sample)
            q2 = q1
            q1 = q0
        }

        let power = q1 * q1 + q2 * q2 - coefficient * q1 * q2
        return max(power / Double(samples.count), 1e-12)
    }

    private func linearToDB(_ linear: Double) -> Double {
        10.0 * log10(max(linear, 1e-12))
    }

    private func estimateFrequency(samples: [Float], sampleRate: Double, minimumFrequency: Double, maximumFrequency: Double) -> Double {
        guard samples.count > 256 else { return 0 }
        let minLag = Int(sampleRate / maximumFrequency)
        let maxLag = Int(sampleRate / minimumFrequency)
        guard minLag < maxLag else { return 0 }

        var bestLag = 0
        var bestCorrelation = -Double.infinity
        for lag in minLag ... maxLag {
            var correlation = 0.0
            for i in 0 ..< (samples.count - lag) {
                correlation += Double(samples[i] * samples[i + lag])
            }
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0 else { return 0 }
        return sampleRate / Double(bestLag)
    }

    private func computeWowFlutterPercent(referenceFrequency: Double) -> Double {
        guard frequencyHistory.count >= 4 else { return 0 }
        let deviations = frequencyHistory.map { (($0 - referenceFrequency) / referenceFrequency) * 100.0 }
        let meanSquare = deviations.reduce(0.0) { $0 + ($1 * $1) } / Double(deviations.count)
        return sqrt(meanSquare)
    }
}
