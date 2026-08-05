import Foundation
import ServiceManagement

@MainActor
final class MarinaSettings: ObservableObject {
    enum RefreshInterval: Double, CaseIterable, Identifiable {
        case manual = 0
        case oneSecond = 1
        case threeSeconds = 3
        case fiveSeconds = 5
        case tenSeconds = 10

        var id: Double { rawValue }
        var title: String { rawValue == 0 ? "Manual" : "\(Int(rawValue)) seconds" }
        var duration: Duration? { rawValue == 0 ? nil : .seconds(rawValue) }
    }

    private enum Key {
        static let refreshInterval = "refreshInterval"
        static let showSystemServices = "showSystemServices"
        static let showLoopbackOnly = "showLoopbackOnly"
        static let groupDuplicateListeners = "groupDuplicateListeners"
        static let confirmBeforeTerminating = "confirmBeforeTerminating"
        static let confirmBeforeStopping = "confirmBeforeStopping"
        static let showPID = "showPID"
        static let showBindAddress = "showBindAddress"
        static let showDockerDetails = "showDockerDetails"
        static let groupDockerPorts = "groupDockerPorts"
    }

    private let defaults: UserDefaults

    @Published var refreshInterval: RefreshInterval { didSet { defaults.set(refreshInterval.rawValue, forKey: Key.refreshInterval) } }
    @Published var showSystemServices: Bool { didSet { defaults.set(showSystemServices, forKey: Key.showSystemServices) } }
    @Published var showLoopbackOnly: Bool { didSet { defaults.set(showLoopbackOnly, forKey: Key.showLoopbackOnly) } }
    @Published var groupDuplicateListeners: Bool { didSet { defaults.set(groupDuplicateListeners, forKey: Key.groupDuplicateListeners) } }
    @Published var confirmBeforeTerminating: Bool { didSet { defaults.set(confirmBeforeTerminating, forKey: Key.confirmBeforeTerminating) } }
    @Published var confirmBeforeStopping: Bool { didSet { defaults.set(confirmBeforeStopping, forKey: Key.confirmBeforeStopping) } }
    @Published var showPID: Bool { didSet { defaults.set(showPID, forKey: Key.showPID) } }
    @Published var showBindAddress: Bool { didSet { defaults.set(showBindAddress, forKey: Key.showBindAddress) } }
    @Published var showDockerDetails: Bool { didSet { defaults.set(showDockerDetails, forKey: Key.showDockerDetails) } }
    @Published var groupDockerPorts: Bool { didSet { defaults.set(groupDockerPorts, forKey: Key.groupDockerPorts) } }
    @Published private(set) var launchAtLoginError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedInterval = defaults.object(forKey: Key.refreshInterval) as? Double ?? 3
        refreshInterval = RefreshInterval(rawValue: storedInterval) ?? .threeSeconds
        showSystemServices = defaults.object(forKey: Key.showSystemServices) as? Bool ?? false
        showLoopbackOnly = defaults.object(forKey: Key.showLoopbackOnly) as? Bool ?? false
        groupDuplicateListeners = defaults.object(forKey: Key.groupDuplicateListeners) as? Bool ?? true
        confirmBeforeTerminating = defaults.object(forKey: Key.confirmBeforeTerminating) as? Bool ?? true
        confirmBeforeStopping = defaults.object(forKey: Key.confirmBeforeStopping) as? Bool ?? true
        showPID = defaults.object(forKey: Key.showPID) as? Bool ?? true
        showBindAddress = defaults.object(forKey: Key.showBindAddress) as? Bool ?? true
        showDockerDetails = defaults.object(forKey: Key.showDockerDetails) as? Bool ?? true
        groupDockerPorts = defaults.object(forKey: Key.groupDockerPorts) as? Bool ?? false
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
            objectWillChange.send()
        } catch {
            launchAtLoginError = error.localizedDescription
            objectWillChange.send()
        }
    }
}
