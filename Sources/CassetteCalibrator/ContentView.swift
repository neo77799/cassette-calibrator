import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Picker(localizer.text(.language), selection: $localizer.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            TabView {
                BiasView()
                    .tabItem {
                        Label(localizer.text(.tabBias), systemImage: "dial.medium")
                    }

                GuidedView()
                    .tabItem {
                        Label(localizer.text(.tabGuided), systemImage: "list.number")
                    }

                WowFlutterView()
                    .tabItem {
                        Label(localizer.text(.tabWowFlutter), systemImage: "waveform.path.ecg")
                    }

                SignalExportView()
                    .tabItem {
                        Label(localizer.text(.tabSignalExport), systemImage: "square.and.arrow.down")
                    }
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: localizer.language) { _, _ in
            viewModel.setLocalizer(localizer)
        }
        .overlay(alignment: .bottomLeading) {
            StatusStrip()
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }
}

private struct StatusStrip: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel
    @EnvironmentObject private var localizer: AppLocalizer

    var body: some View {
        HStack(spacing: 16) {
            Label(viewModel.audioStateText, systemImage: viewModel.audioReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(viewModel.audioReady ? .green : .orange)
            Label("\(localizer.text(.currentDefaultInput)): \(viewModel.inputDeviceSummary)", systemImage: "waveform")
            Label(localizer.sampleRateLabel(viewModel.sampleRate), systemImage: "speedometer")
            if !viewModel.calibrationPerformed {
                Label(localizer.text(.referenceNotCalibrated), systemImage: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}
