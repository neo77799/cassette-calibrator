import SwiftUI

struct BiasView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                metricCard(
                    title: localizer.text(.noiseCalibration),
                    value: String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB),
                    subtitle: localizer.biasNoiseSubtitle(high: viewModel.noiseResult.highBandDB, mid: viewModel.noiseResult.midBandDB),
                    status: localizer.biasStatus(viewModel.noiseResult.status)
                )

                metricCard(
                    title: localizer.text(.toneCalibration),
                    value: String(format: "%.2f dB", viewModel.toneResult.levelDB),
                    subtitle: localizer.biasToneSubtitle(peak: viewModel.toneResult.peakDB, delta: viewModel.toneResult.deltaDB),
                    status: localizer.biasStatus(viewModel.toneResult.status)
                )
            }

            controlPanel
            referenceCalibrationPanel
            toneMeasurementPanel

            VStack(alignment: .leading, spacing: 10) {
                Text(localizer.text(.biasMeter))
                    .font(.headline)
                Gauge(value: min(max(viewModel.noiseResult.biasErrorDB, -3), 3), in: -3 ... 3) {
                    EmptyView()
                } currentValueLabel: {
                    Text(String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB))
                } minimumValueLabel: {
                    Text(localizer.biasStatus(.over))
                } maximumValueLabel: {
                    Text(localizer.biasStatus(.under))
                }
                .gaugeStyle(.accessoryLinearCapacity)

                Text(localizer.text(.directionHelp))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(localizer.sourceDeltaLabel(viewModel.toneResult.sourceDeltaDB))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var controlPanel: some View {
        GroupBox(localizer.text(.generator)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Picker(localizer.text(.signal), selection: $viewModel.generatedSignal) {
                        ForEach(GeneratedSignal.allCases) { signal in
                            Text(localizer.generatedSignalName(signal)).tag(signal)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button(viewModel.isSignalPlaying ? localizer.text(.stop) : localizer.text(.play)) {
                        viewModel.toggleSignalPlayback()
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    Button(localizer.text(.markReferenceCalibrated)) {
                        viewModel.markCalibrationPerformed()
                    }
                }

                HStack {
                    Picker(localizer.text(.inputSource), selection: $viewModel.selectedInputDeviceID) {
                        ForEach(viewModel.availableInputDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .frame(maxWidth: 320)
                    .onChange(of: viewModel.selectedInputDeviceID) { _, newValue in
                        viewModel.selectInputDevice(newValue)
                    }

                    Text(localizer.inputLevelLabel(viewModel.inputLevelDB))
                        .font(.footnote.monospacedDigit())

                    Label(viewModel.signalDetected ? localizer.text(.signalDetected) : localizer.text(.noSignal), systemImage: viewModel.signalDetected ? "waveform.circle.fill" : "pause.circle")
                        .foregroundStyle(viewModel.signalDetected ? .green : .secondary)
                        .font(.footnote)

                    Label(localizer.signalQuality(viewModel.signalQuality), systemImage: qualitySymbol)
                        .foregroundStyle(qualityColor)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    Text(localizer.spreadLabel(title: localizer.text(.biasSpread), value: viewModel.biasSpreadDB))
                        .font(.footnote.monospacedDigit())
                    Text(localizer.spreadLabel(title: localizer.text(.toneSpread), value: viewModel.toneSpreadDB))
                        .font(.footnote.monospacedDigit())
                }

                Text(localizer.text(.silenceNotice))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var referenceCalibrationPanel: some View {
        GroupBox(localizer.text(.referenceCalibration)) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizer.text(.sourceWorkflowTitle))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizer.text(.sourceWorkflow1))
                    Text(localizer.text(.sourceWorkflow2))
                    Text(localizer.text(.sourceWorkflow3))
                    Text(localizer.text(.sourceWorkflow4))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button(localizer.text(.captureNoiseReference)) {
                        viewModel.captureNoiseReference()
                    }
                    .disabled(!viewModel.signalDetected)

                    Button(localizer.text(.captureToneReference)) {
                        viewModel.captureToneReference()
                    }
                    .disabled(!viewModel.signalDetected)

                    Button(localizer.text(.clearReference)) {
                        viewModel.clearReferenceCalibration()
                    }
                    .disabled(!viewModel.referenceCalibration.hasAnyReference)
                }

                HStack(spacing: 20) {
                    referenceStatus(localizer.text(.noiseReferenceStatus), captured: viewModel.referenceCalibration.noiseBiasReferenceDB != nil)
                    referenceStatus(localizer.text(.toneReferenceStatus), captured: viewModel.referenceCalibration.toneReferenceLevelDB != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var toneMeasurementPanel: some View {
        GroupBox(localizer.text(.toneMeasurementTable)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Stepper(value: $viewModel.biasKnobPosition, in: -20 ... 20) {
                        Text("\(localizer.text(.biasKnobPosition)): \(viewModel.biasKnobPosition >= 0 ? "+" : "")\(viewModel.biasKnobPosition)")
                    }
                    .frame(maxWidth: 260, alignment: .leading)

                    Button(localizer.text(.toneCapture)) {
                        viewModel.captureToneMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.signalDetected)

                    Button(localizer.text(.clearMeasurements)) {
                        viewModel.clearToneMeasurements()
                    }
                    .disabled(viewModel.toneMeasurements.isEmpty)
                }

                Text(localizer.text(.stabilityNotice))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    if let peak = viewModel.peakToneMeasurement {
                        Text("\(localizer.text(.peakPosition)): \(signedPosition(peak.position))")
                            .font(.subheadline.weight(.semibold))
                    }
                    if let suggested = viewModel.suggestedToneMeasurement {
                        Text("\(localizer.text(.suggestedPosition)): \(signedPosition(suggested.position))")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if viewModel.toneMeasurements.isEmpty {
                    Text(localizer.text(.noMeasurementsYet))
                        .foregroundStyle(.secondary)
                } else {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            Text(localizer.text(.position)).font(.caption.weight(.bold))
                            Text(localizer.text(.level)).font(.caption.weight(.bold))
                            Text(localizer.text(.delta)).font(.caption.weight(.bold))
                        }

                        ForEach(viewModel.toneMeasurements) { measurement in
                            GridRow {
                                Text(signedPosition(measurement.position))
                                    .monospacedDigit()
                                Text(String(format: "%.2f dB", measurement.levelDB))
                                    .monospacedDigit()
                                Text(String(format: "%.2f dB", measurement.deltaDB))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, status: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private func signedPosition(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private func referenceStatus(_ title: String, captured: Bool) -> some View {
        Label("\(title): \(captured ? localizer.text(.captured) : localizer.text(.notCaptured))", systemImage: captured ? "checkmark.seal.fill" : "circle.dashed")
            .foregroundStyle(captured ? .green : .secondary)
            .font(.footnote)
    }

    private var qualityColor: Color {
        switch viewModel.signalQuality {
        case .good:
            return .green
        case .fair:
            return .orange
        case .poor:
            return .secondary
        }
    }

    private var qualitySymbol: String {
        switch viewModel.signalQuality {
        case .good:
            return "checkmark.circle.fill"
        case .fair:
            return "minus.circle.fill"
        case .poor:
            return "exclamationmark.circle"
        }
    }
}
