import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ja

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: "EN"
        case .ja: "JP"
        }
    }
}

final class AppLocalizer: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "app.language"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: rawValue) {
            self.language = language
        } else {
            self.language = Locale.preferredLanguages.first?.hasPrefix("ja") == true ? .ja : .en
        }
    }

    func text(_ key: LocalizedKey) -> String {
        switch language {
        case .en: key.en
        case .ja: key.ja
        }
    }

    func generatedSignalName(_ signal: GeneratedSignal) -> String {
        switch signal {
        case .noise:
            text(.whiteNoise)
        case .tone10k:
            text(.tone10k)
        case .wowFlutter3k:
            text(.tone3k)
        }
    }

    func guidedStepTitle(_ step: GuidedStep) -> String {
        switch step {
        case .prepare:
            text(.guidedPrepare)
        case .noise:
            text(.guidedNoise)
        case .tone:
            text(.guidedTone)
        case .complete:
            text(.guidedComplete)
        }
    }

    func guidedStepInstructions(_ step: GuidedStep) -> String {
        switch step {
        case .prepare:
            text(.guidedPrepareInstructions)
        case .noise:
            text(.guidedNoiseInstructions)
        case .tone:
            text(.guidedToneInstructions)
        case .complete:
            text(.guidedCompleteInstructions)
        }
    }

    func biasStatus(_ status: BiasStatus) -> String {
        switch status {
        case .under:
            text(.statusUnder)
        case .ok:
            text(.statusOK)
        case .over:
            text(.statusOver)
        case .max:
            text(.statusMax)
        case .recommended:
            text(.statusRecommended)
        case .unknown:
            text(.statusUnknown)
        }
    }

    func wowRating(_ rating: WowFlutterRating) -> String {
        switch rating {
        case .excellent:
            text(.ratingExcellent)
        case .good:
            text(.ratingGood)
        case .ok:
            text(.ratingOK)
        case .bad:
            text(.ratingBad)
        case .unknown:
            text(.statusUnknown)
        }
    }

    func biasNoiseSubtitle(high: Double, mid: Double) -> String {
        switch language {
        case .en:
            return "High \(String(format: "%.1f", high)) dB / Mid \(String(format: "%.1f", mid)) dB"
        case .ja:
            return "高域 \(String(format: "%.1f", high)) dB / 中域 \(String(format: "%.1f", mid)) dB"
        }
    }

    func biasToneSubtitle(peak: Double, delta: Double) -> String {
        switch language {
        case .en:
            return "Peak \(String(format: "%.1f", peak)) dB / Delta \(String(format: "%.1f", delta)) dB"
        case .ja:
            return "ピーク \(String(format: "%.1f", peak)) dB / 差分 \(String(format: "%.1f", delta)) dB"
        }
    }

    func sampleRateLabel(_ sampleRate: Double) -> String {
        switch language {
        case .en:
            return "Sample Rate: \(Int(sampleRate)) Hz"
        case .ja:
            return "サンプルレート: \(Int(sampleRate)) Hz"
        }
    }

    func exportSuccess(path: String) -> String {
        switch language {
        case .en:
            return "Exported WAV files to \(path)"
        case .ja:
            return "WAV を \(path) に書き出しました"
        }
    }

    func exportFailure(error: String) -> String {
        switch language {
        case .en:
            return "Export failed: \(error)"
        case .ja:
            return "書き出しに失敗しました: \(error)"
        }
    }

    func inputLevelLabel(_ level: Double) -> String {
        switch language {
        case .en:
            return String(format: "Input Level: %.1f dBFS", level)
        case .ja:
            return String(format: "入力レベル: %.1f dBFS", level)
        }
    }

    func signalQuality(_ quality: SignalQuality) -> String {
        switch quality {
        case .good:
            return text(.signalGood)
        case .fair:
            return text(.signalFair)
        case .poor:
            return text(.signalPoor)
        }
    }

    func spreadLabel(title: String, value: Double) -> String {
        switch language {
        case .en:
            return String(format: "%@: ±%.2f dB", title, value)
        case .ja:
            return String(format: "%@: ±%.2f dB", title, value)
        }
    }

    func sourceDeltaLabel(_ value: Double?) -> String {
        guard let value else {
            return text(.sourceDeltaUnavailable)
        }
        switch language {
        case .en:
            return String(format: "Source delta: %+.2f dB", value)
        case .ja:
            return String(format: "SOURCE 差分: %+.2f dB", value)
        }
    }

    func wowProgressLabel(current: Int, required: Int) -> String {
        switch language {
        case .en:
            return "Samples: \(current)/\(required)"
        case .ja:
            return "サンプル数: \(current)/\(required)"
        }
    }

    func wowModeLabel(isHolding: Bool) -> String {
        isHolding ? text(.wowHolding) : text(.wowLive)
    }

    func guidedSignalLabel(_ signal: GeneratedSignal?) -> String {
        guard let signal else {
            return text(.guidedNoSignalRequired)
        }
        switch language {
        case .en:
            return "Use signal: \(generatedSignalName(signal))"
        case .ja:
            return "使用信号: \(generatedSignalName(signal))"
        }
    }

    func guidedChecklist(for step: GuidedStep) -> [String] {
        switch step {
        case .prepare:
            return [
                text(.guidedPrepareCheck1),
                text(.guidedPrepareCheck2),
                text(.guidedPrepareCheck3),
                text(.guidedPrepareCheck4)
            ]
        case .noise:
            return [
                text(.guidedNoiseCheck1),
                text(.guidedNoiseCheck2),
                text(.guidedNoiseCheck3),
                text(.guidedNoiseCheck4)
            ]
        case .tone:
            return [
                text(.guidedToneCheck1),
                text(.guidedToneCheck2),
                text(.guidedToneCheck3),
                text(.guidedToneCheck4)
            ]
        case .complete:
            return [
                text(.guidedCompleteCheck1),
                text(.guidedCompleteCheck2),
                text(.guidedCompleteCheck3)
            ]
        }
    }

    func guidedObservedText(for step: GuidedStep) -> String {
        switch step {
        case .prepare:
            return text(.guidedPrepareWatch)
        case .noise:
            return text(.guidedNoiseWatch)
        case .tone:
            return text(.guidedToneWatch)
        case .complete:
            return text(.guidedCompleteWatch)
        }
    }

    func measurementHint(_ hint: MeasurementHint) -> String {
        switch hint {
        case .ready:
            return text(.hintReady)
        case .referenceMissing:
            return text(.hintReferenceMissing)
        case .noSignal:
            return text(.hintNoSignal)
        case .signalTooUnstable:
            return text(.hintSignalTooUnstable)
        }
    }
}

struct LocalizedKey {
    let en: String
    let ja: String

    static let tabBias = Self(en: "Bias", ja: "バイアス")
    static let tabGuided = Self(en: "Guided", ja: "ガイド")
    static let tabWowFlutter = Self(en: "Wow & Flutter", ja: "ワウフラ")
    static let tabSignalExport = Self(en: "Signal Export", ja: "信号書き出し")
    static let referenceNotCalibrated = Self(en: "Reference not calibrated", ja: "基準未校正")
    static let language = Self(en: "Language", ja: "言語")
    static let noiseCalibration = Self(en: "Noise Calibration", ja: "Noise 調整")
    static let toneCalibration = Self(en: "Tone Calibration", ja: "Tone 調整")
    static let biasMeter = Self(en: "Bias Meter", ja: "バイアスメーター")
    static let directionHelp = Self(en: "Use white noise for direction finding, then switch to 10 kHz tone for final positioning.", ja: "まずホワイトノイズで方向を確認し、その後 10kHz トーンで最終位置を追い込みます。")
    static let generator = Self(en: "Generator", ja: "信号生成")
    static let signal = Self(en: "Signal", ja: "信号")
    static let play = Self(en: "Play", ja: "再生")
    static let stop = Self(en: "Stop", ja: "停止")
    static let markReferenceCalibrated = Self(en: "Mark Reference Calibrated", ja: "基準校正済みにする")
    static let whiteNoise = Self(en: "White Noise", ja: "ホワイトノイズ")
    static let tone10k = Self(en: "10 kHz Tone", ja: "10 kHz トーン")
    static let tone3k = Self(en: "3 kHz Tone", ja: "3 kHz トーン")
    static let statusUnder = Self(en: "UNDER", ja: "不足")
    static let statusOK = Self(en: "OK", ja: "適正")
    static let statusOver = Self(en: "OVER", ja: "過多")
    static let statusMax = Self(en: "MAX", ja: "最大")
    static let statusRecommended = Self(en: "RECOMMENDED", ja: "推奨")
    static let statusUnknown = Self(en: "UNKNOWN", ja: "不明")
    static let guidedPrepare = Self(en: "Prepare", ja: "準備")
    static let guidedNoise = Self(en: "Noise Calibration", ja: "Noise 調整")
    static let guidedTone = Self(en: "Tone Calibration", ja: "Tone 調整")
    static let guidedComplete = Self(en: "Complete", ja: "完了")
    static let guidedPrepareInstructions = Self(en: "Connect the cassette deck to the audio interface line input, disable Dolby/AGC, and confirm sample rate alignment.", ja: "カセットデッキをオーディオ IF のライン入力へ接続し、Dolby や AGC を無効化して、サンプルレートが一致していることを確認します。")
    static let guidedNoiseInstructions = Self(en: "Play or record white noise, then aim to bring the bias meter toward the center by watching the band-difference result.", ja: "ホワイトノイズを再生または録音し、帯域差分を見ながらバイアスメーターが中央へ近づくように調整します。")
    static let guidedToneInstructions = Self(en: "Switch to 10 kHz tone and look for the level peak. The recommended point is slightly below the peak.", ja: "10 kHz トーンに切り替え、レベルのピーク位置を探します。推奨位置はピークより少し下です。")
    static let guidedCompleteInstructions = Self(en: "Store the chosen deck/tape preset and keep the interface gain unchanged for repeatable measurements.", ja: "選んだデッキとテープの設定を記録し、再現性のために IF のゲインを変更しないようにします。")
    static let currentReadings = Self(en: "Current Readings", ja: "現在の測定値")
    static let biasError = Self(en: "Bias Error", ja: "バイアス誤差")
    static let noiseStatus = Self(en: "Noise Status", ja: "Noise 状態")
    static let toneDelta = Self(en: "Tone Delta", ja: "Tone 差分")
    static let toneStatus = Self(en: "Tone Status", ja: "Tone 状態")
    static let reset = Self(en: "Reset", ja: "リセット")
    static let done = Self(en: "Done", ja: "完了")
    static let nextStep = Self(en: "Next Step", ja: "次へ")
    static let detectedFrequency = Self(en: "Detected Frequency", ja: "検出周波数")
    static let rating = Self(en: "Rating", ja: "評価")
    static let signalQualityTitle = Self(en: "Signal Quality", ja: "信号品質")
    static let wowRatingTitle = Self(en: "Wow Rating", ja: "ワウフラ評価")
    static let wowProgress = Self(en: "Progress", ja: "進捗")
    static let wowMode = Self(en: "Mode", ja: "状態")
    static let wowLive = Self(en: "Live", ja: "更新中")
    static let wowHolding = Self(en: "Hold", ja: "保持中")
    static let howToUse = Self(en: "How To Use", ja: "使い方")
    static let wowStep1 = Self(en: "1. Play a 3 kHz test tone from the deck.", ja: "1. デッキから 3 kHz テストトーンを再生します。")
    static let wowStep2 = Self(en: "2. Keep interface gain fixed.", ja: "2. オーディオ IF のゲインを固定します。")
    static let wowStep3 = Self(en: "3. Treat this value as a comparative indicator unless you add standards-based weighting later.", ja: "3. 規格準拠の重み付けを追加するまでは、比較用の目安として扱います。")
    static let play3k = Self(en: "Play 3 kHz Tone", ja: "3 kHz トーン再生")
    static let stop3k = Self(en: "Stop 3 kHz Tone", ja: "3 kHz トーン停止")
    static let exportSignals = Self(en: "Export Test Signals", ja: "テスト信号書き出し")
    static let exportDescription = Self(en: "Writes 44.1 kHz stereo WAV files into the current project directory.", ja: "44.1 kHz ステレオ WAV を現在のプロジェクトディレクトリへ書き出します。")
    static let exportWavFiles = Self(en: "Export WAV Files", ja: "WAV を書き出す")
    static let includedFiles = Self(en: "Included Files", ja: "出力ファイル")
    static let ratingExcellent = Self(en: "EXCELLENT", ja: "非常に良い")
    static let ratingGood = Self(en: "GOOD", ja: "良い")
    static let ratingOK = Self(en: "OK", ja: "普通")
    static let ratingBad = Self(en: "BAD", ja: "悪い")
    static let audioNotStarted = Self(en: "Audio not started", ja: "オーディオ未開始")
    static let inputUnknown = Self(en: "Input unknown", ja: "入力不明")
    static let ready = Self(en: "Ready", ja: "準備完了")
    static let audioIdle = Self(en: "Audio idle", ja: "オーディオ待機中")
    static let audioMonitoringActive = Self(en: "Audio monitoring active", ja: "入力監視中")
    static let noInputChannels = Self(en: "No input channels available", ja: "入力チャンネルがありません")
    static let audioEngineRunning = Self(en: "Audio engine running", ja: "オーディオエンジン動作中")
    static let audioStartFailed = Self(en: "Audio start failed", ja: "オーディオ起動失敗")
    static let noAudioDevice = Self(en: "No audio device detected", ja: "オーディオデバイスが見つかりません")
    static let noSignal = Self(en: "No signal", ja: "信号なし")
    static let signalDetected = Self(en: "Signal detected", ja: "信号検出")
    static let signalStable = Self(en: "Stable", ja: "安定")
    static let signalUnstable = Self(en: "Unstable", ja: "不安定")
    static let signalGood = Self(en: "Good", ja: "良好")
    static let signalFair = Self(en: "Fair", ja: "普通")
    static let signalPoor = Self(en: "Poor", ja: "要注意")
    static let inputSource = Self(en: "Input Source", ja: "入力ソース")
    static let currentDefaultInput = Self(en: "Current macOS default input", ja: "現在の macOS 既定入力")
    static let silenceNotice = Self(en: "Meters are held when the input level is too low, so room noise is not treated as a valid calibration signal.", ja: "入力レベルが低すぎる場合はメーターを止め、環境ノイズを有効な校正信号として扱わないようにしています。")
    static let deviceSwitchFailed = Self(en: "Input device switch failed", ja: "入力デバイスの切り替えに失敗しました")
    static let biasSpread = Self(en: "Bias spread", ja: "バイアスばらつき")
    static let toneSpread = Self(en: "Tone spread", ja: "Tone ばらつき")
    static let referenceCalibration = Self(en: "Reference Calibration", ja: "基準キャリブレーション")
    static let captureNoiseReference = Self(en: "Capture Noise Source Reference", ja: "Noise の SOURCE 基準を記録")
    static let captureToneReference = Self(en: "Capture 10 kHz Source Reference", ja: "10 kHz の SOURCE 基準を記録")
    static let clearReference = Self(en: "Clear Reference", ja: "基準をクリア")
    static let sourceDeltaUnavailable = Self(en: "Source delta: not captured", ja: "SOURCE 差分: 未取得")
    static let sourceWorkflowTitle = Self(en: "External Player Workflow", ja: "外部プレーヤー運用")
    static let sourceWorkflow1 = Self(en: "1. Play the exported WAV from your external player into the deck input.", ja: "1. 書き出した WAV を外部プレーヤーからデッキ入力へ送ります。")
    static let sourceWorkflow2 = Self(en: "2. If your deck supports SOURCE/TAPE monitoring, switch to SOURCE first and capture the reference.", ja: "2. デッキに SOURCE/TAPE モニターがある場合は、先に SOURCE 側で基準を記録します。")
    static let sourceWorkflow3 = Self(en: "3. Then switch to TAPE and compare against that stored reference while adjusting bias.", ja: "3. その後 TAPE 側へ切り替え、保存した基準との差を見ながらバイアス調整します。")
    static let sourceWorkflow4 = Self(en: "4. If SOURCE monitoring is unavailable, temporarily patch the external player directly to the audio interface input to capture the reference.", ja: "4. SOURCE モニターが使えない場合は、外部プレーヤーを一時的にオーディオ IF 入力へ直結して基準を取ります。")
    static let noiseReferenceStatus = Self(en: "Noise reference", ja: "Noise 基準")
    static let toneReferenceStatus = Self(en: "10 kHz reference", ja: "10 kHz 基準")
    static let captured = Self(en: "Captured", ja: "取得済み")
    static let notCaptured = Self(en: "Not captured", ja: "未取得")
    static let guidedReferenceStep = Self(en: "Reference First", ja: "最初に基準取得")
    static let guidedCaptureReference = Self(en: "Capture Reference Here", ja: "ここで基準を取得")
    static let guidedNoiseReferenceAction = Self(en: "Capture Noise Reference", ja: "Noise 基準を記録")
    static let guidedToneReferenceAction = Self(en: "Capture 10 kHz Reference", ja: "10 kHz 基準を記録")
    static let guidedWhyUnknown = Self(en: "Why it shows UNKNOWN", ja: "不明になる理由")
    static let hintReady = Self(en: "Ready to judge. Now move the meter toward center or capture a tone point.", ja: "判定可能です。メーターを中央へ寄せるか、Tone 測定点を記録してください。")
    static let hintReferenceMissing = Self(en: "Reference not captured yet. Capture the SOURCE baseline first.", ja: "まだ基準がありません。先に SOURCE 基準を記録してください。")
    static let hintNoSignal = Self(en: "No valid input signal is detected. Check playback, cabling, and input selection.", ja: "有効な入力信号がありません。再生、配線、入力選択を確認してください。")
    static let hintSignalTooUnstable = Self(en: "Signal fluctuation is too large right now. Average a few seconds and use the spread values as a guide.", ja: "いまは揺れが大きすぎます。数秒平均して、ばらつき値を目安にしてください。")
    static let biasKnobPosition = Self(en: "Bias Knob Position", ja: "バイアスつまみ位置")
    static let toneCapture = Self(en: "Capture 10 kHz Point", ja: "10 kHz 測定点を記録")
    static let clearMeasurements = Self(en: "Clear Points", ja: "測定点をクリア")
    static let toneMeasurementTable = Self(en: "10 kHz Measurement Table", ja: "10 kHz 測定テーブル")
    static let suggestedPosition = Self(en: "Suggested Position", ja: "推奨位置")
    static let peakPosition = Self(en: "Peak Position", ja: "ピーク位置")
    static let noMeasurementsYet = Self(en: "No measurement points captured yet.", ja: "まだ測定点が記録されていません。")
    static let position = Self(en: "Position", ja: "位置")
    static let level = Self(en: "Level", ja: "レベル")
    static let delta = Self(en: "Delta", ja: "差分")
    static let stabilityNotice = Self(en: "On tape decks, slight fluctuation is normal. Prefer capturing after a few seconds of averaging, and use the spread values as a confidence guide.", ja: "テープデッキでは多少の揺れは正常です。数秒平均したあとで記録し、ばらつき値を信頼度の目安にしてください。")
    static let guidedAction = Self(en: "What To Do Now", ja: "このステップでやること")
    static let guidedChecklist = Self(en: "Checklist", ja: "チェックリスト")
    static let guidedTargetSignal = Self(en: "Target Signal", ja: "使う信号")
    static let guidedObservedValues = Self(en: "What To Watch", ja: "見るポイント")
    static let guidedNoSignalRequired = Self(en: "No generator required", ja: "内蔵信号は不要")
    static let guidedPlayStepSignal = Self(en: "Play This Signal", ja: "この信号を再生")
    static let guidedStopSignal = Self(en: "Stop Signal", ja: "信号を停止")
    static let guidedStepReady = Self(en: "When ready, continue to the next step.", ja: "準備ができたら次のステップへ進みます。")
    static let guidedPrepareCheck1 = Self(en: "Connect the deck output to the audio interface line input.", ja: "デッキの出力をオーディオ IF のライン入力へ接続します。")
    static let guidedPrepareCheck2 = Self(en: "Disable Dolby, AGC, limiter, and any voice-processing features.", ja: "Dolby、AGC、リミッター、音声処理を無効にします。")
    static let guidedPrepareCheck3 = Self(en: "Confirm the interface sample rate matches the app setting.", ja: "オーディオ IF のサンプルレートがアプリと一致していることを確認します。")
    static let guidedPrepareCheck4 = Self(en: "Keep interface gain fixed throughout the measurement.", ja: "測定中はオーディオ IF のゲインを固定します。")
    static let guidedNoiseCheck1 = Self(en: "Play or record white noise on the cassette deck.", ja: "カセットデッキでホワイトノイズを再生または録音します。")
    static let guidedNoiseCheck2 = Self(en: "Watch Bias Error and move the deck bias toward the center.", ja: "バイアス誤差を見ながら、メーターが中央へ寄るようにデッキのバイアスを調整します。")
    static let guidedNoiseCheck3 = Self(en: "Use the status as direction only: UNDER means more bias is needed, OVER means less.", ja: "状態表示は方向確認に使います。UNDER はバイアス不足、OVER はバイアス過多の目安です。")
    static let guidedNoiseCheck4 = Self(en: "Aim to bring the bias error close to 0 dB before moving on.", ja: "次へ進む前に、バイアス誤差が 0 dB 付近へ近づくようにします。")
    static let guidedToneCheck1 = Self(en: "Switch the deck or external source to a 10 kHz test tone.", ja: "デッキまたは外部音源を 10 kHz テストトーンへ切り替えます。")
    static let guidedToneCheck2 = Self(en: "Slowly adjust deck bias while watching the level peak.", ja: "レベルのピークを見ながら、デッキのバイアスをゆっくり調整します。")
    static let guidedToneCheck3 = Self(en: "The recommended point is slightly below the absolute peak.", ja: "推奨位置は絶対ピークより少し下です。")
    static let guidedToneCheck4 = Self(en: "If Tone Status shows RECOMMENDED, you are near the target.", ja: "Tone 状態が推奨になれば、狙い位置に近づいています。")
    static let guidedCompleteCheck1 = Self(en: "Stop the test signal and keep note of the deck and tape type used.", ja: "テスト信号を止め、使用したデッキとテープ種別を記録します。")
    static let guidedCompleteCheck2 = Self(en: "If this setup is your reference, mark it as calibrated.", ja: "この環境を基準にするなら、校正済みとして記録します。")
    static let guidedCompleteCheck3 = Self(en: "Do not change interface gain if you want repeatable results later.", ja: "後で再現性を保ちたい場合は、オーディオ IF のゲインを変更しないでください。")
    static let guidedPrepareWatch = Self(en: "Check audio device name, sample rate, and whether input monitoring is active.", ja: "オーディオデバイス名、サンプルレート、入力監視状態を確認します。")
    static let guidedNoiseWatch = Self(en: "Watch Bias Error, Noise Status, and the bias meter moving toward center.", ja: "バイアス誤差、Noise 状態、メーターが中央へ近づく様子を確認します。")
    static let guidedToneWatch = Self(en: "Watch current level, peak hold, and Tone Status while trimming bias.", ja: "現在レベル、ピーク保持、Tone 状態を見ながら微調整します。")
    static let guidedCompleteWatch = Self(en: "Confirm the final readings are stable and note the chosen setting.", ja: "最終値が安定していることを確認し、選んだ設定を記録します。")
}
