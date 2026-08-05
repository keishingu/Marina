import Foundation

struct ProcessIdentity: Codable, Hashable, Sendable {
    let pid: Int32
    let name: String
    let user: String?
    let command: String?
    let executablePath: String?
    let parentPID: Int32?
    let workingDirectory: String?
}
