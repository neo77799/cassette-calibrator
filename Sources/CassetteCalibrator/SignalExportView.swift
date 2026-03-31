import SwiftUI

struct SignalExportView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupBox("Export Test Signals") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Writes 44.1 kHz stereo WAV files into the current project directory.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Export WAV Files") {
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

            GroupBox("Included Files") {
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
