import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    let settings: MarinaSettings
    let portListViewModel: PortListViewModel
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let settings = MarinaSettings()
        let runner = SystemCommandRunner()
        let processResolver = DefaultProcessResolver(runner: runner)
        let scanner = LsofPortScanner(runner: runner, processResolver: processResolver)
        let dockerURL = DockerResolver.locateDockerExecutable()
        self.settings = settings
        portListViewModel = PortListViewModel(
            settings: settings,
            portScanner: scanner,
            dockerResolver: DockerResolver(runner: runner, dockerExecutableURL: dockerURL),
            actionController: PortActionController(runner: runner, dockerExecutableURL: dockerURL)
        )
        portListViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
