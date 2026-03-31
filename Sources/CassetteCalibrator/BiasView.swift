import SwiftUI

struct BiasView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                metricCard(
                    title: "Noise Calibration",
                    value: String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB),
                    subtitle: "High \(String(format: "%.1f", viewModel.noiseResult.highBandDB)) dB / Mid \(String(format: "%.1f", viewModel.noiseResult.midBandDB)) dB",
                    status: viewModel.noiseResult.status.rawValue
                )

                metricCard(
                    title: "Tone Calibration",
                    value: String(format: "%.2f dB", viewModel.toneResult.levelDB),
                    subtitle: "Peak \(String(format: "%.1f", viewModel.toneResult.peakDB)) dB / Delta \(String(format: "%.1f", viewModel.toneResult.deltaDB)) dB",
                    status: viewModel.toneResult.status.rawValue
                )
            }

            controlPanel

            VStack(alignment: .leading, spacing: 10) {
                Text("Bias Meter")
                    .font(.headline)
                Gauge(value: min(max(viewModel.noiseResult.biasErrorDB, -3), 3), in: -3 ... 3) {
                    EmptyView()
                } currentValueLabel: {
                    Text(String(format: "%.2f dB", viewModel.noiseResult.biasErrorDB))
                } minimumValueLabel: {
                    Text("OVER")
                } maximumValueLabel: {
                    Text("UNDER")
                }
                .gaugeStyle(.accessoryLinearCapacity)

                Text("Use white noise for direction finding, then switch to 10 kHz tone for final positioning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var controlPanel: some View {
        GroupBox("Generator") {
            HStack {
                Picker("Signal", selection: $viewModel.generatedSignal) {
                    ForEach(GeneratedSignal.allCases) { signal in
                        Text(signal.rawValue).tag(signal)
                    }
                }
                .pickerStyle(.segmented)

                Button(viewModel.isSignalPlaying ? "Stop" : "Play") {
                    viewModel.toggleSignalPlayback()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Mark Reference Calibrated") {
                    viewModel.markCalibrationPerformed()
                }
            }
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
}
