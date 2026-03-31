import SwiftUI

struct WowFlutterView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                wowCard(title: "Detected Frequency", value: String(format: "%.1f Hz", viewModel.wowFlutterResult.frequency))
                wowCard(title: "Wow & Flutter", value: String(format: "%.3f %%", viewModel.wowFlutterResult.wowFlutterPercent))
                wowCard(title: "Rating", value: viewModel.wowFlutterResult.rating.rawValue)
            }

            GroupBox("How To Use") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Play a 3 kHz test tone from the deck.")
                    Text("2. Keep interface gain fixed.")
                    Text("3. Treat this value as a comparative indicator unless you add standards-based weighting later.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(viewModel.isSignalPlaying && viewModel.generatedSignal == .wowFlutter3k ? "Stop 3 kHz Tone" : "Play 3 kHz Tone") {
                viewModel.generatedSignal = .wowFlutter3k
                viewModel.toggleSignalPlayback()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func wowCard(title: String, value: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}
