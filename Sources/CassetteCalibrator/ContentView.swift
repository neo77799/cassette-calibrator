import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        TabView {
            BiasView()
                .tabItem {
                    Label("Bias", systemImage: "dial.medium")
                }

            GuidedView()
                .tabItem {
                    Label("Guided", systemImage: "list.number")
                }

            WowFlutterView()
                .tabItem {
                    Label("Wow & Flutter", systemImage: "waveform.path.ecg")
                }

            SignalExportView()
                .tabItem {
                    Label("Signal Export", systemImage: "square.and.arrow.down")
                }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottomLeading) {
            StatusStrip()
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }
}

private struct StatusStrip: View {
    @EnvironmentObject private var viewModel: CalibrationViewModel

    var body: some View {
        HStack(spacing: 16) {
            Label(viewModel.audioStateText, systemImage: viewModel.audioReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(viewModel.audioReady ? .green : .orange)
            Label(viewModel.inputDeviceSummary, systemImage: "waveform")
            Label("Sample Rate: \(Int(viewModel.sampleRate)) Hz", systemImage: "speedometer")
            if !viewModel.calibrationPerformed {
                Label("Reference not calibrated", systemImage: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}
