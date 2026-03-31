import SwiftUI

struct WowFlutterView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                wowCard(title: localizer.text(.detectedFrequency), value: String(format: "%.1f Hz", viewModel.wowFlutterResult.frequency))
                wowCard(title: localizer.text(.tabWowFlutter), value: String(format: "%.3f %%", viewModel.wowFlutterResult.wowFlutterPercent))
                wowCard(title: localizer.text(.rating), value: localizer.wowRating(viewModel.wowFlutterResult.rating))
                wowCard(title: localizer.text(.wowProgress), value: "\(viewModel.wowFlutterResult.sampleCount)/\(viewModel.wowFlutterResult.requiredSampleCount)")
                wowCard(title: localizer.text(.wowMode), value: localizer.wowModeLabel(isHolding: viewModel.wowFlutterResult.isHolding))
            }

            GroupBox(localizer.text(.howToUse)) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizer.text(.wowStep1))
                    Text(localizer.text(.wowStep2))
                    Text(localizer.text(.wowStep3))
                    Text(localizer.wowProgressLabel(current: viewModel.wowFlutterResult.sampleCount, required: viewModel.wowFlutterResult.requiredSampleCount))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(viewModel.isSignalPlaying && viewModel.generatedSignal == .wowFlutter3k ? localizer.text(.stop3k) : localizer.text(.play3k)) {
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
