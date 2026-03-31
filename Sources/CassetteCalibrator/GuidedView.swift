import SwiftUI

struct GuidedView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(viewModel.guidedStep.rawValue)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(viewModel.guidedStep.instructions)
                .font(.title3)
                .foregroundStyle(.secondary)

            GroupBox("Current Readings") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Bias Error", value: String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB))
                    LabeledContent("Noise Status", value: viewModel.noiseResult.status.rawValue)
                    LabeledContent("Tone Delta", value: String(format: "%.2f dB", viewModel.toneResult.deltaDB))
                    LabeledContent("Tone Status", value: viewModel.toneResult.status.rawValue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Reset") {
                    viewModel.resetGuidedStep()
                }

                Button(viewModel.guidedStep == .complete ? "Done" : "Next Step") {
                    viewModel.advanceGuidedStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.guidedStep == .complete)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
