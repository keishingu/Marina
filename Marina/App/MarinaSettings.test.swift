import Foundation
import XCTest
@testable import Marina

@MainActor
final class MarinaSettingsTests: XCTestCase {
    func test_WorkingDirectory表示設定を永続化する() throws {
        let suiteName = "MarinaSettingsWorkingDirectoryTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialSettings = MarinaSettings(defaults: defaults)
        XCTAssertFalse(initialSettings.showWorkingDirectory)

        initialSettings.showWorkingDirectory = true

        let restoredSettings = MarinaSettings(defaults: defaults)
        XCTAssertTrue(restoredSettings.showWorkingDirectory)
    }
}
