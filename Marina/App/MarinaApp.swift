import SwiftUI

@main
struct MarinaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PortListView(
                viewModel: appState.portListViewModel,
                settings: appState.settings
            )
        } label: {
            Label {
                Text(String(appState.portListViewModel.filteredPorts().count))
            } icon: {
                Image(systemName: "sailboat.fill")
            }
            .accessibilityLabel("Marina, \(appState.portListViewModel.filteredPorts().count) listening ports")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: appState.settings)
        }
    }
}
