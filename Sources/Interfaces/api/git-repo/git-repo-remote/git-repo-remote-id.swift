import Foundation

extension GitRepo {
    public struct RemoteID: Sendable {
        public let host: String
        public let owner: String
        public let repo: String
    }
}
