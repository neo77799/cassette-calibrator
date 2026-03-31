import Foundation
import AVFoundation
import Combine

@MainActor
final class CalibrationViewModel: ObservableObject {
    @Published var audioReady = false
    @Published var audioStateText = "Audio not started"
    @Published var inputDeviceSummary = "Input unknown"
    @Published var sampleRate: Double = 44_100
    @Published var calibrationPerformed = false

    @Published var noiseResult = NoiseCalibrationResult.empty
    @Published var toneResult = ToneCalibrationResult.empty
    @Published var wowFlutterResult = WowFlutterResult.empty

    @Published var generatedSignal: GeneratedSignal = .noise
    @Published var isSignalPlaying = false
    @Published var exportMessage = "Ready"

    @Published var guidedStep: GuidedStep = .prepare

    private let audioController = AudioController()
    private let exporter = SignalExporter()
    private var cancellables: Set<AnyCancellable> = []

    func start() {
        bind()
        audioController.start()
    }

    func toggleSignalPlayback() {
        if isSignalPlaying {
            audioController.stopSignal()
        } else {
            audioController.playSignal(generatedSignal)
        }
    }

    func exportSignals() {
        do {
            let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try exporter.exportAllSignals(to: outputDirectory)
            exportMessage = "Exported WAV files to \(outputDirectory.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func markCalibrationPerformed() {
        calibrationPerformed = true
    }

    func advanceGuidedStep() {
        guidedStep = guidedStep.next
    }

    func resetGuidedStep() {
        guidedStep = .prepare
    }

    private func bind() {
        audioController.$audioReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioReady)

        audioController.$audioStateText
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioStateText)

        audioController.$inputDeviceSummary
            .receive(on: DispatchQueue.main)
            .assign(to: &$inputDeviceSummary)

        audioController.$sampleRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$sampleRate)

        audioController.$noiseResult
            .receive(on: DispatchQueue.main)
            .assign(to: &$noiseResult)

        audioController.$toneResult
            .receive(on: DispatchQueue.main)
            .assign(to: &$toneResult)

        audioController.$wowFlutterResult
            .receive(on: DispatchQueue.main)
            .assign(to: &$wowFlutterResult)

        audioController.$isSignalPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSignalPlaying)
    }
}

enum GeneratedSignal: String, CaseIterable, Identifiable {
    case noise = "White Noise"
    case tone10k = "10 kHz Tone"
    case wowFlutter3k = "3 kHz Tone"

    var id: String { rawValue }
}

enum GuidedStep: String, CaseIterable {
    case prepare = "Prepare"
    case noise = "Noise Calibration"
    case tone = "Tone Calibration"
    case complete = "Complete"

    var instructions: String {
        switch self {
        case .prepare:
            "Connect the cassette deck to the audio interface line input, disable Dolby/AGC, and confirm sample rate alignment."
        case .noise:
            "Play or record white noise, then aim to bring the bias meter toward the center by watching the band-difference result."
        case .tone:
            "Switch to 10 kHz tone and look for the level peak. The recommended point is slightly below the peak."
        case .complete:
            "Store the chosen deck/tape preset and keep the interface gain unchanged for repeatable measurements."
        }
    }

    var next: GuidedStep {
        switch self {
        case .prepare: .noise
        case .noise: .tone
        case .tone: .complete
        case .complete: .complete
        }
    }
}

struct NoiseCalibrationResult {
    let highBandDB: Double
    let midBandDB: Double
    let biasErrorDB: Double
    let status: BiasStatus

    static let empty = NoiseCalibrationResult(highBandDB: 0, midBandDB: 0, biasErrorDB: 0, status: .unknown)
}

struct ToneCalibrationResult {
    let levelDB: Double
    let peakDB: Double
    let deltaDB: Double
    let status: BiasStatus

    static let empty = ToneCalibrationResult(levelDB: -120, peakDB: -120, deltaDB: 0, status: .unknown)
}

struct WowFlutterResult {
    let frequency: Double
    let wowFlutterPercent: Double
    let rating: WowFlutterRating

    static let empty = WowFlutterResult(frequency: 0, wowFlutterPercent: 0, rating: .unknown)
}

enum BiasStatus: String {
    case under = "UNDER"
    case ok = "OK"
    case over = "OVER"
    case max = "MAX"
    case recommended = "RECOMMENDED"
    case unknown = "UNKNOWN"
}

enum WowFlutterRating: String {
    case excellent = "EXCELLENT"
    case good = "GOOD"
    case ok = "OK"
    case bad = "BAD"
    case unknown = "UNKNOWN"
}
