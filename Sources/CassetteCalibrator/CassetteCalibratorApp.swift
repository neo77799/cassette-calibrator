import SwiftUI
import AppKit
import Foundation

@main
struct CassetteCalibratorApp: App {
    @StateObject private var viewModel = CalibrationViewModel()
    @StateObject private var localizer = AppLocalizer()

    init() {
        if ProcessInfo.processInfo.arguments.contains("--export-signals") {
            do {
                let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                try SignalExporter().exportAllSignals(to: outputDirectory)
                print("Exported signals to \(outputDirectory.path)")
                exit(0)
            } catch {
                fputs("Export failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(localizer)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    viewModel.setLocalizer(localizer)
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    viewModel.start()
                }
        }
        .windowResizability(.contentSize)
    }
}
