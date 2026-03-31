import Foundation
import AVFoundation
import AVFAudio
import Combine
import CoreMedia
import CoreAudio

final class AudioController: ObservableObject, @unchecked Sendable {
    @Published var audioReady = false
    @Published var audioStateText = "Audio idle"
    @Published var inputDeviceSummary = "Input unknown"
    @Published var sampleRate: Double = 44_100
    @Published var inputLevelDB: Double = -120
    @Published var signalDetected = false
    @Published var signalStable = false
    @Published var signalQuality: SignalQuality = .poor
    @Published var biasSpreadDB: Double = 0
    @Published var toneSpreadDB: Double = 0
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputDeviceID: AudioDeviceID = 0
    @Published var referenceCalibration = ReferenceCalibration.empty
    @Published var noiseResult = NoiseCalibrationResult.empty
    @Published var toneResult = ToneCalibrationResult.empty
    @Published var wowFlutterResult = WowFlutterResult.empty
    @Published var isSignalPlaying = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let analyzer = SignalAnalyzer()
    private var lastPeakDB = -120.0
    private weak var localizer: AppLocalizer?
    private var smoothing = AnalysisSmoother()
    private var latestSmoothedAnalysis: SmoothedAnalysisFrame?

    func setLocalizer(_ localizer: AppLocalizer?) {
        self.localizer = localizer
        audioStateText = localizer?.text(.audioIdle) ?? "Audio idle"
        if inputDeviceSummary == "Input unknown" || inputDeviceSummary == "No audio device detected" {
            inputDeviceSummary = localizer?.text(.inputUnknown) ?? "Input unknown"
        }
    }

    func start() {
        refreshInputDevices()
        refreshDeviceSummary()
        configureAudioSession()
        installInputTap()
        startEngineIfNeeded()
    }

    func selectInputDevice(_ deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        do {
            try AudioHardwareBridge.setDefaultInputDevice(deviceID)
            selectedInputDeviceID = deviceID
            restartInputMonitoring()
        } catch {
            let prefix = localizer?.text(.deviceSwitchFailed) ?? "Input device switch failed"
            audioStateText = "\(prefix): \(error.localizedDescription)"
        }
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

    func captureReference(_ signal: GeneratedSignal) {
        guard let latestSmoothedAnalysis else { return }
        let sourceDescription = currentReferenceSourceDescription()
        switch signal {
        case .noise:
            referenceCalibration = ReferenceCalibration(
                noiseBiasReferenceDB: latestSmoothedAnalysis.rawBiasErrorDB,
                toneReferenceLevelDB: referenceCalibration.toneReferenceLevelDB,
                sourceDescription: sourceDescription
            )
        case .tone10k:
            referenceCalibration = ReferenceCalibration(
                noiseBiasReferenceDB: referenceCalibration.noiseBiasReferenceDB,
                toneReferenceLevelDB: latestSmoothedAnalysis.toneLevelDB,
                sourceDescription: sourceDescription
            )
        case .wowFlutter3k:
            break
        }
    }

    func clearReferenceCalibration() {
        referenceCalibration = .empty
    }

    private func configureAudioSession() {
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        sampleRate = inputFormat.sampleRate
        audioStateText = inputFormat.channelCount > 0
            ? (localizer?.text(.audioMonitoringActive) ?? "Audio monitoring active")
            : (localizer?.text(.noInputChannels) ?? "No input channels available")
        audioReady = inputFormat.channelCount > 0
    }

    private func installInputTap() {
        engine.inputNode.removeTap(onBus: 0)
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { return }
        let analyzer = self.analyzer

        engine.inputNode.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            let analysis = analyzer.analyze(buffer: buffer)
            DispatchQueue.main.async { [weak self] in
                self?.apply(analysis)
            }
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            audioReady = true
            audioStateText = localizer?.text(.audioEngineRunning) ?? "Audio engine running"
        } catch {
            audioReady = false
            let prefix = localizer?.text(.audioStartFailed) ?? "Audio start failed"
            audioStateText = "\(prefix): \(error.localizedDescription)"
        }
    }

    private func refreshDeviceSummary() {
        if let current = availableInputDevices.first(where: { $0.id == selectedInputDeviceID }) {
            inputDeviceSummary = current.name
        } else {
            inputDeviceSummary = localizer?.text(.noAudioDevice) ?? "No audio device detected"
        }
    }

    private func apply(_ analysis: AnalysisFrame) {
        inputLevelDB = analysis.inputLevelDB
        signalDetected = analysis.signalDetected

        guard analysis.signalDetected else {
            smoothing.reset()
            latestSmoothedAnalysis = nil
            signalStable = false
            signalQuality = .poor
            biasSpreadDB = 0
            toneSpreadDB = 0
            noiseResult = .empty
            toneResult = ToneCalibrationResult(
                levelDB: analysis.inputLevelDB,
                peakDB: lastPeakDB,
                deltaDB: analysis.inputLevelDB - lastPeakDB,
                sourceDeltaDB: nil,
                status: .unknown
            )
            wowFlutterResult = WowFlutterResult(
                frequency: analysis.estimatedFrequency,
                wowFlutterPercent: analysis.wowFlutterPercent,
                rating: analysis.wowFlutterRating,
                sampleCount: analysis.wowFlutterSampleCount,
                requiredSampleCount: analysis.wowFlutterRequiredSampleCount,
                isHolding: analysis.wowFlutterHolding
            )
            return
        }

        let smoothed = smoothing.append(analysis)
        latestSmoothedAnalysis = smoothed
        signalStable = smoothed.quality == .good
        signalQuality = smoothed.quality
        biasSpreadDB = smoothed.biasSpreadDB
        toneSpreadDB = smoothed.toneSpreadDB

        let adjustedBiasError = smoothed.biasErrorDB - (referenceCalibration.noiseBiasReferenceDB ?? 0)
        noiseResult = NoiseCalibrationResult(
            highBandDB: smoothed.highBandDB,
            midBandDB: smoothed.midBandDB,
            biasErrorDB: adjustedBiasError,
            status: statusForBiasError(adjustedBiasError, quality: smoothed.quality)
        )

        lastPeakDB = max(lastPeakDB, smoothed.toneLevelDB)
        let toneStatus: BiasStatus
        if smoothed.quality == .poor {
            toneStatus = .unknown
        } else if abs(lastPeakDB - smoothed.toneLevelDB) <= 0.2 {
            toneStatus = .max
        } else if (-1.5 ... -0.5).contains(smoothed.toneLevelDB - lastPeakDB) {
            toneStatus = .recommended
        } else if smoothed.toneLevelDB > lastPeakDB {
            toneStatus = .under
        } else {
            toneStatus = .over
        }

        toneResult = ToneCalibrationResult(
            levelDB: smoothed.toneLevelDB,
            peakDB: lastPeakDB,
            deltaDB: smoothed.toneLevelDB - lastPeakDB,
            sourceDeltaDB: referenceCalibration.toneReferenceLevelDB.map { smoothed.toneLevelDB - $0 },
            status: toneStatus
        )

        wowFlutterResult = WowFlutterResult(
            frequency: smoothed.estimatedFrequency,
            wowFlutterPercent: smoothed.wowFlutterPercent,
            rating: smoothed.wowFlutterRating,
            sampleCount: smoothed.wowFlutterSampleCount,
            requiredSampleCount: smoothed.wowFlutterRequiredSampleCount,
            isHolding: smoothed.wowFlutterHolding
        )
    }

    private func refreshInputDevices() {
        let devices = (try? AudioHardwareBridge.inputDevices()) ?? []
        availableInputDevices = devices
        if let currentDefault = try? AudioHardwareBridge.defaultInputDeviceID() {
            selectedInputDeviceID = currentDefault
        } else {
            selectedInputDeviceID = devices.first?.id ?? 0
        }
    }

    private func restartInputMonitoring() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        refreshInputDevices()
        refreshDeviceSummary()
        configureAudioSession()
        installInputTap()
        startEngineIfNeeded()
    }

    private func statusForBiasError(_ biasError: Double, quality: SignalQuality) -> BiasStatus {
        if quality == .poor {
            return .unknown
        } else if biasError > 0.5 {
            return .under
        } else if biasError < -0.5 {
            return .over
        } else {
            return .ok
        }
    }

    private func currentReferenceSourceDescription() -> String? {
        availableInputDevices.first(where: { $0.id == selectedInputDeviceID })?.name
    }
}

private struct AnalysisFrame: Sendable {
    let inputLevelDB: Double
    let signalDetected: Bool
    let highBandDB: Double
    let midBandDB: Double
    let biasErrorDB: Double
    let biasStatus: BiasStatus
    let toneLevelDB: Double
    let estimatedFrequency: Double
    let wowFlutterPercent: Double
    let wowFlutterRating: WowFlutterRating
    let wowFlutterSampleCount: Int
    let wowFlutterRequiredSampleCount: Int
    let wowFlutterHolding: Bool
}

private struct SmoothedAnalysisFrame {
    let highBandDB: Double
    let midBandDB: Double
    let biasErrorDB: Double
    let rawBiasErrorDB: Double
    let biasStatus: BiasStatus
    let toneLevelDB: Double
    let estimatedFrequency: Double
    let wowFlutterPercent: Double
    let wowFlutterRating: WowFlutterRating
    let wowFlutterSampleCount: Int
    let wowFlutterRequiredSampleCount: Int
    let wowFlutterHolding: Bool
    let quality: SignalQuality
    let biasSpreadDB: Double
    let toneSpreadDB: Double
}

private struct AnalysisSmoother {
    private var frames: [AnalysisFrame] = []
    private let windowSize = 20

    mutating func append(_ frame: AnalysisFrame) -> SmoothedAnalysisFrame {
        frames.append(frame)
        if frames.count > windowSize {
            frames.removeFirst(frames.count - windowSize)
        }

        let highBand = average(\.highBandDB)
        let midBand = average(\.midBandDB)
        let biasError = average(\.biasErrorDB)
        let toneLevel = average(\.toneLevelDB)
        let frequency = average(\.estimatedFrequency)
        let wowFlutter = average(\.wowFlutterPercent)
        let wowFlutterSampleCount = frames.last?.wowFlutterSampleCount ?? 0
        let wowFlutterRequiredSampleCount = frames.last?.wowFlutterRequiredSampleCount ?? 24
        let wowFlutterHolding = frames.last?.wowFlutterHolding ?? false
        let biasStdDev = stddev(\.biasErrorDB, mean: biasError)
        let toneStdDev = stddev(\.toneLevelDB, mean: toneLevel)
        let quality: SignalQuality
        if frames.count < 6 || biasStdDev >= 0.7 || toneStdDev >= 1.2 {
            quality = .poor
        } else if biasStdDev < 0.35 && toneStdDev < 0.7 {
            quality = .good
        } else {
            quality = .fair
        }

        let biasStatus: BiasStatus
        if quality == .poor {
            biasStatus = .unknown
        } else if biasError > 0.5 {
            biasStatus = .under
        } else if biasError < -0.5 {
            biasStatus = .over
        } else {
            biasStatus = .ok
        }

        let wowRating: WowFlutterRating
        switch wowFlutter {
        case ..<0.05:
            wowRating = .excellent
        case ..<0.1:
            wowRating = .good
        case ..<0.2:
            wowRating = .ok
        default:
            wowRating = .bad
        }

        return SmoothedAnalysisFrame(
            highBandDB: highBand,
            midBandDB: midBand,
            biasErrorDB: biasError,
            rawBiasErrorDB: biasError,
            biasStatus: biasStatus,
            toneLevelDB: toneLevel,
            estimatedFrequency: frequency,
            wowFlutterPercent: wowFlutter,
            wowFlutterRating: wowRating,
            wowFlutterSampleCount: wowFlutterSampleCount,
            wowFlutterRequiredSampleCount: wowFlutterRequiredSampleCount,
            wowFlutterHolding: wowFlutterHolding,
            quality: quality,
            biasSpreadDB: biasStdDev,
            toneSpreadDB: toneStdDev
        )
    }

    mutating func reset() {
        frames.removeAll(keepingCapacity: true)
    }

    private func average(_ keyPath: KeyPath<AnalysisFrame, Double>) -> Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map(\.self).reduce(0.0) { $0 + $1[keyPath: keyPath] } / Double(frames.count)
    }

    private func stddev(_ keyPath: KeyPath<AnalysisFrame, Double>, mean: Double) -> Double {
        guard frames.count > 1 else { return .infinity }
        let variance = frames.map(\.self).reduce(0.0) {
            let delta = $1[keyPath: keyPath] - mean
            return $0 + (delta * delta)
        } / Double(frames.count)
        return sqrt(variance)
    }
}

private final class SignalAnalyzer: @unchecked Sendable {
    private var frequencyHistory: [Double] = []
    private let requiredWowFlutterSamples = 24
    private var lastValidFrequency: Double = 0

    func analyze(buffer: AVAudioPCMBuffer) -> AnalysisFrame {
        guard let channelData = buffer.floatChannelData?[0] else {
            return .init(
                inputLevelDB: -120,
                signalDetected: false,
                highBandDB: -120,
                midBandDB: -120,
                biasErrorDB: 0,
                biasStatus: .unknown,
                toneLevelDB: -120,
                estimatedFrequency: 0,
                wowFlutterPercent: 0,
                wowFlutterRating: .unknown,
                wowFlutterSampleCount: frequencyHistory.count,
                wowFlutterRequiredSampleCount: requiredWowFlutterSamples,
                wowFlutterHolding: true
            )
        }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        let sampleRate = buffer.format.sampleRate
        let inputLevelDB = rmsLevelDB(samples)
        let signalDetected = inputLevelDB > -60.0

        guard signalDetected else {
            return .init(
                inputLevelDB: inputLevelDB,
                signalDetected: false,
                highBandDB: -120,
                midBandDB: -120,
                biasErrorDB: 0,
                biasStatus: .unknown,
                toneLevelDB: inputLevelDB,
                estimatedFrequency: lastValidFrequency,
                wowFlutterPercent: currentWowFlutterPercent(referenceFrequency: 3_000),
                wowFlutterRating: currentWowFlutterRating(),
                wowFlutterSampleCount: frequencyHistory.count,
                wowFlutterRequiredSampleCount: requiredWowFlutterSamples,
                wowFlutterHolding: true
            )
        }

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
        let rawEstimatedFrequency = estimateFrequency(samples: samples, sampleRate: sampleRate, minimumFrequency: 2_500, maximumFrequency: 3_500)
        let estimatedFrequency: Double
        let holding: Bool
        if rawEstimatedFrequency > 0 {
            estimatedFrequency = rawEstimatedFrequency
            lastValidFrequency = rawEstimatedFrequency
            holding = false
        } else {
            estimatedFrequency = lastValidFrequency
            holding = true
        }

        if rawEstimatedFrequency > 0 {
            frequencyHistory.append(rawEstimatedFrequency)
            if frequencyHistory.count > 32 {
                frequencyHistory.removeFirst(frequencyHistory.count - 32)
            }
        }

        let wowPercent = computeWowFlutterPercent(referenceFrequency: 3_000)
        let wowRating = ratingForWowFlutter(wowPercent)

        return .init(
            inputLevelDB: inputLevelDB,
            signalDetected: true,
            highBandDB: highBand,
            midBandDB: midBand,
            biasErrorDB: biasError,
            biasStatus: biasStatus,
            toneLevelDB: toneLevel,
            estimatedFrequency: estimatedFrequency,
            wowFlutterPercent: wowPercent,
            wowFlutterRating: wowRating,
            wowFlutterSampleCount: frequencyHistory.count,
            wowFlutterRequiredSampleCount: requiredWowFlutterSamples,
            wowFlutterHolding: holding
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

    private func rmsLevelDB(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return -120 }
        let meanSquare = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        } / Double(samples.count)
        return 20.0 * log10(max(sqrt(meanSquare), 1e-6))
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
        guard frequencyHistory.count >= 2 else { return 0 }
        let deviations = frequencyHistory.map { (($0 - referenceFrequency) / referenceFrequency) * 100.0 }
        let meanSquare = deviations.reduce(0.0) { $0 + ($1 * $1) } / Double(deviations.count)
        return sqrt(meanSquare)
    }

    private func currentWowFlutterPercent(referenceFrequency: Double) -> Double {
        computeWowFlutterPercent(referenceFrequency: referenceFrequency)
    }

    private func currentWowFlutterRating() -> WowFlutterRating {
        ratingForWowFlutter(currentWowFlutterPercent(referenceFrequency: 3_000))
    }

    private func ratingForWowFlutter(_ wowPercent: Double) -> WowFlutterRating {
        switch wowPercent {
        case ..<0.05:
            return .excellent
        case ..<0.1:
            return .good
        case ..<0.2:
            return .ok
        default:
            return .bad
        }
    }
}

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let name: String
}

private enum AudioHardwareBridge {
    static func inputDevices() throws -> [AudioInputDevice] {
        let deviceIDs: [AudioDeviceID] = try readArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            valueType: AudioDeviceID.self
        )

        return try deviceIDs.compactMap { deviceID in
            guard try hasInputStreams(deviceID) else { return nil }
            return AudioInputDevice(id: deviceID, name: try deviceName(deviceID))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func defaultInputDeviceID() throws -> AudioDeviceID {
        try readScalar(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            valueType: AudioDeviceID.self
        )
    }

    static func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        var mutableDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        guard status == noErr else {
            throw AudioHardwareError.osStatus(status)
        }
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) throws -> Bool {
        let streams: [AudioStreamID] = try readArray(
            objectID: deviceID,
            address: AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            ),
            valueType: AudioStreamID.self
        )
        return !streams.isEmpty
    }

    private static func deviceName(_ deviceID: AudioDeviceID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString?
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfName) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0)
        }
        guard status == noErr else {
            throw AudioHardwareError.osStatus(status)
        }
        return (cfName ?? "" as CFString) as String
    }

    private static func readScalar<T>(objectID: AudioObjectID, address: AudioObjectPropertyAddress, valueType: T.Type) throws -> T {
        var mutableAddress = address
        var value: T!
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            $0.withMemoryRebound(to: UInt8.self, capacity: Int(size)) {
                AudioObjectGetPropertyData(objectID, &mutableAddress, 0, nil, &size, $0)
            }
        }
        guard status == noErr else {
            throw AudioHardwareError.osStatus(status)
        }
        return value
    }

    private static func readArray<T>(objectID: AudioObjectID, address: AudioObjectPropertyAddress, valueType: T.Type) throws -> [T] {
        var mutableAddress = address
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &mutableAddress, 0, nil, &size)
        guard status == noErr else {
            throw AudioHardwareError.osStatus(status)
        }

        let count = Int(size) / MemoryLayout<T>.stride
        var values = Array<T>(unsafeUninitializedCapacity: count) { _, initializedCount in
            initializedCount = count
        }
        status = values.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(objectID, &mutableAddress, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else {
            throw AudioHardwareError.osStatus(status)
        }
        return values
    }
}

private enum AudioHardwareError: LocalizedError {
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            return "OSStatus \(status)"
        }
    }
}
