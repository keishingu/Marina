import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: MarinaSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                if let error = settings.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Picker("Refresh Interval", selection: $settings.refreshInterval) {
                    ForEach(MarinaSettings.RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
            }

            Section("Visible Services") {
                Toggle("Show System Services", isOn: $settings.showSystemServices)
                Toggle("Show Loopback Only", isOn: $settings.showLoopbackOnly)
                Toggle("Group Duplicate Listeners", isOn: $settings.groupDuplicateListeners)
                    .disabled(true)
                Text("IPv4 and IPv6 sockets for the same process and port are always normalized for accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show PID", isOn: $settings.showPID)
                Toggle("Show Bind Address", isOn: $settings.showBindAddress)
            }

            Section("Docker") {
                Toggle("Show Docker Details", isOn: $settings.showDockerDetails)
                Toggle("Group Docker Ports by Container", isOn: $settings.groupDockerPorts)
                    .disabled(true)
                Text("Container grouping is reserved for the next display mode; the MVP uses one row per host port.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Confirmations") {
                Toggle("Confirm Before Terminating Process", isOn: $settings.confirmBeforeTerminating)
                Toggle("Confirm Before Stopping or Restarting Container", isOn: $settings.confirmBeforeStopping)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 520, height: 560)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.isLaunchAtLoginEnabled },
            set: settings.setLaunchAtLogin
        )
    }
}
