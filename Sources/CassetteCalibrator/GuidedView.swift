import SwiftUI

struct GuidedView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(localizer.guidedStepTitle(viewModel.guidedStep))
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(localizer.guidedStepInstructions(viewModel.guidedStep))
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 20) {
                actionPanel
                readingsPanel
            }

            HStack {
                Button(localizer.text(.reset)) {
                    viewModel.resetGuidedStep()
                }

                Spacer()

                if let signal = stepSignal {
                    Button(viewModel.isSignalPlaying && viewModel.generatedSignal == signal ? localizer.text(.guidedStopSignal) : localizer.text(.guidedPlayStepSignal)) {
                        if viewModel.isSignalPlaying && viewModel.generatedSignal == signal {
                            viewModel.stopSignalPlayback()
                        } else {
                            viewModel.playSignal(signal)
                        }
                    }
                }

                Button(viewModel.guidedStep == .complete ? localizer.text(.done) : localizer.text(.nextStep)) {
                    viewModel.advanceGuidedStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.guidedStep == .complete)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var actionPanel: some View {
        GroupBox(localizer.text(.guidedAction)) {
            VStack(alignment: .leading, spacing: 16) {
                labeledSection(title: localizer.text(.guidedTargetSignal)) {
                    Text(localizer.guidedSignalLabel(stepSignal))
                }

                if viewModel.guidedStep == .noise || viewModel.guidedStep == .tone {
                    labeledSection(title: localizer.text(.guidedReferenceStep)) {
                        Text(localizer.text(.guidedCaptureReference))
                            .foregroundStyle(.secondary)

                        HStack {
                            if viewModel.guidedStep == .noise {
                                Button(localizer.text(.guidedNoiseReferenceAction)) {
                                    viewModel.captureNoiseReference()
                                }
                                .disabled(!viewModel.signalDetected)
                            } else {
                                Button(localizer.text(.guidedToneReferenceAction)) {
                                    viewModel.captureToneReference()
                                }
                                .disabled(!viewModel.signalDetected)
                            }

                            Label(viewModel.guidedStep == .noise
                                  ? (viewModel.hasNoiseReference ? localizer.text(.captured) : localizer.text(.notCaptured))
                                  : (viewModel.hasToneReference ? localizer.text(.captured) : localizer.text(.notCaptured)),
                                  systemImage: (viewModel.guidedStep == .noise ? viewModel.hasNoiseReference : viewModel.hasToneReference) ? "checkmark.seal.fill" : "circle.dashed")
                        }
                    }
                }

                labeledSection(title: localizer.text(.guidedChecklist)) {
                    ForEach(Array(localizer.guidedChecklist(for: viewModel.guidedStep).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.tint)
                            Text(item)
                        }
                    }
                }

                labeledSection(title: localizer.text(.guidedObservedValues)) {
                    Text(localizer.guidedObservedText(for: viewModel.guidedStep))
                    Text(localizer.text(.guidedStepReady))
                        .foregroundStyle(.secondary)
                }

                if viewModel.guidedStep == .noise || viewModel.guidedStep == .tone {
                    labeledSection(title: localizer.text(.guidedWhyUnknown)) {
                        Text(localizer.measurementHint(viewModel.guidedStep == .noise ? viewModel.noiseStatusHint : viewModel.toneStatusHint))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var readingsPanel: some View {
        GroupBox(localizer.text(.currentReadings)) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent(localizer.text(.biasError), value: String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB))
                LabeledContent(localizer.text(.noiseStatus), value: localizer.biasStatus(viewModel.noiseResult.status))
                LabeledContent(localizer.text(.toneDelta), value: String(format: "%.2f dB", viewModel.toneResult.deltaDB))
                LabeledContent(localizer.text(.toneStatus), value: localizer.biasStatus(viewModel.toneResult.status))
                LabeledContent(localizer.text(.noiseReferenceStatus), value: viewModel.hasNoiseReference ? localizer.text(.captured) : localizer.text(.notCaptured))
                LabeledContent(localizer.text(.toneReferenceStatus), value: viewModel.hasToneReference ? localizer.text(.captured) : localizer.text(.notCaptured))
                Divider()
                LabeledContent(localizer.text(.signal), value: stepSignal.map(localizer.generatedSignalName) ?? localizer.text(.guidedNoSignalRequired))
                LabeledContent(localizer.text(.inputSource), value: viewModel.inputDeviceSummary)
                LabeledContent(localizer.text(.signalQualityTitle), value: localizer.signalQuality(viewModel.signalQuality))
                LabeledContent(localizer.text(.wowRatingTitle), value: localizer.wowRating(viewModel.wowFlutterResult.rating))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 320)
    }

    private func labeledSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .foregroundStyle(.primary)
        }
    }

    private var stepSignal: GeneratedSignal? {
        switch viewModel.guidedStep {
        case .prepare:
            return nil
        case .noise:
            return .noise
        case .tone:
            return .tone10k
        case .complete:
            return nil
        }
    }
}
