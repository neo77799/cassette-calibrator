import Foundation
import AVFoundation
import Combine
import CoreAudio

@MainActor
final class CalibrationViewModel: ObservableObject {
    @Published var audioReady = false
    @Published var audioStateText = ""
    @Published var inputDeviceSummary = ""
    @Published var sampleRate: Double = 44_100
    @Published var inputLevelDB: Double = -120
    @Published var signalDetected = false
    @Published var signalStable = false
    @Published var signalQuality: SignalQuality = .poor
    @Published var biasSpreadDB: Double = 0
    @Published var toneSpreadDB: Double = 0
    @Published var calibrationPerformed = false
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputDeviceID: AudioDeviceID = 0
    @Published var biasKnobPosition = 0
    @Published var toneMeasurements: [ToneMeasurement] = []
    @Published var referenceCalibration = ReferenceCalibration.empty

    @Published var noiseResult = NoiseCalibrationResult.empty
    @Published var toneResult = ToneCalibrationResult.empty
    @Published var wowFlutterResult = WowFlutterResult.empty

    @Published var generatedSignal: GeneratedSignal = .noise
    @Published var isSignalPlaying = false
    @Published var exportMessage = ""

    @Published var guidedStep: GuidedStep = .prepare

    private let audioController = AudioController()
    private let exporter = SignalExporter()
    private var cancellables: Set<AnyCancellable> = []
    private weak var localizer: AppLocalizer?

    init() {
        applyLocalizedDefaults()
    }

    func setLocalizer(_ localizer: AppLocalizer) {
        self.localizer = localizer
        applyLocalizedDefaults()
    }

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

    func playSignal(_ signal: GeneratedSignal) {
        generatedSignal = signal
        audioController.playSignal(signal)
    }

    func stopSignalPlayback() {
        audioController.stopSignal()
    }

    func exportSignals() {
        do {
            let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try exporter.exportAllSignals(to: outputDirectory)
            exportMessage = localizer?.exportSuccess(path: outputDirectory.path) ?? outputDirectory.path
        } catch {
            exportMessage = localizer?.exportFailure(error: error.localizedDescription) ?? error.localizedDescription
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

        audioController.$inputLevelDB
            .receive(on: DispatchQueue.main)
            .assign(to: &$inputLevelDB)

        audioController.$signalDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$signalDetected)

        audioController.$signalStable
            .receive(on: DispatchQueue.main)
            .assign(to: &$signalStable)

        audioController.$signalQuality
            .receive(on: DispatchQueue.main)
            .assign(to: &$signalQuality)

        audioController.$biasSpreadDB
            .receive(on: DispatchQueue.main)
            .assign(to: &$biasSpreadDB)

        audioController.$toneSpreadDB
            .receive(on: DispatchQueue.main)
            .assign(to: &$toneSpreadDB)

        audioController.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableInputDevices)

        audioController.$selectedInputDeviceID
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedInputDeviceID)

        audioController.$referenceCalibration
            .receive(on: DispatchQueue.main)
            .assign(to: &$referenceCalibration)

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

    private func applyLocalizedDefaults() {
        audioStateText = localizer?.text(.audioNotStarted) ?? "Audio not started"
        inputDeviceSummary = localizer?.text(.inputUnknown) ?? "Input unknown"
        exportMessage = localizer?.text(.ready) ?? "Ready"
        audioController.setLocalizer(localizer)
    }

    func selectInputDevice(_ deviceID: AudioDeviceID) {
        audioController.selectInputDevice(deviceID)
    }

    func captureToneMeasurement() {
        guard signalDetected else { return }
        let measurement = ToneMeasurement(position: biasKnobPosition, levelDB: toneResult.levelDB, deltaDB: toneResult.deltaDB)
        toneMeasurements.removeAll { $0.position == biasKnobPosition }
        toneMeasurements.append(measurement)
        toneMeasurements.sort { $0.position < $1.position }
    }

    func clearToneMeasurements() {
        toneMeasurements.removeAll()
    }

    var suggestedToneMeasurement: ToneMeasurement? {
        guard let peak = toneMeasurements.max(by: { $0.levelDB < $1.levelDB }) else { return nil }
        let candidates = toneMeasurements
            .filter { (peak.levelDB - 1.5) ... (peak.levelDB - 0.5) ~= $0.levelDB }
            .sorted { abs($0.position - peak.position) < abs($1.position - peak.position) }
        return candidates.first ?? peak
    }

    var peakToneMeasurement: ToneMeasurement? {
        toneMeasurements.max(by: { $0.levelDB < $1.levelDB })
    }

    func captureNoiseReference() {
        audioController.captureReference(.noise)
    }

    func captureToneReference() {
        audioController.captureReference(.tone10k)
    }

    func clearReferenceCalibration() {
        audioController.clearReferenceCalibration()
    }

    var hasNoiseReference: Bool {
        referenceCalibration.noiseBiasReferenceDB != nil
    }

    var hasToneReference: Bool {
        referenceCalibration.toneReferenceLevelDB != nil
    }

    var noiseStatusHint: MeasurementHint {
        if !hasNoiseReference {
            return .referenceMissing
        }
        if !signalDetected {
            return .noSignal
        }
        if signalQuality == .poor {
            return .signalTooUnstable
        }
        return .ready
    }

    var toneStatusHint: MeasurementHint {
        if !hasToneReference {
            return .referenceMissing
        }
        if !signalDetected {
            return .noSignal
        }
        if signalQuality == .poor {
            return .signalTooUnstable
        }
        return .ready
    }
}

enum GeneratedSignal: String, CaseIterable, Identifiable {
    case noise
    case tone10k
    case wowFlutter3k

    var id: String { String(describing: self) }
}

enum GuidedStep: CaseIterable {
    case prepare
    case noise
    case tone
    case complete

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
    let sourceDeltaDB: Double?
    let status: BiasStatus

    static let empty = ToneCalibrationResult(levelDB: -120, peakDB: -120, deltaDB: 0, sourceDeltaDB: nil, status: .unknown)
}

struct WowFlutterResult {
    let frequency: Double
    let wowFlutterPercent: Double
    let rating: WowFlutterRating
    let sampleCount: Int
    let requiredSampleCount: Int
    let isHolding: Bool

    static let empty = WowFlutterResult(frequency: 0, wowFlutterPercent: 0, rating: .unknown, sampleCount: 0, requiredSampleCount: 24, isHolding: false)
}

struct ToneMeasurement: Identifiable, Hashable {
    let position: Int
    let levelDB: Double
    let deltaDB: Double

    var id: Int { position }
}

struct ReferenceCalibration: Equatable {
    let noiseBiasReferenceDB: Double?
    let toneReferenceLevelDB: Double?
    let sourceDescription: String?

    static let empty = ReferenceCalibration(noiseBiasReferenceDB: nil, toneReferenceLevelDB: nil, sourceDescription: nil)

    var hasAnyReference: Bool {
        noiseBiasReferenceDB != nil || toneReferenceLevelDB != nil
    }
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

enum SignalQuality: String {
    case good
    case fair
    case poor
}

enum MeasurementHint {
    case ready
    case referenceMissing
    case noSignal
    case signalTooUnstable
}
