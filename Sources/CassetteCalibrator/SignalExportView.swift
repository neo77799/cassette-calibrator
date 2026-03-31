import SwiftUI

struct SignalExportView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupBox(localizer.text(.exportSignals)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizer.text(.exportDescription))
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(localizer.text(.exportWavFiles)) {
                            viewModel.exportSignals()
                        }
                        .buttonStyle(.borderedProminent)

                        Text(viewModel.exportMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(localizer.text(.includedFiles)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("calibration_noise.wav")
                    Text("calibration_tone_10k.wav")
                    Text("calibration_tone_3k.wav")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
