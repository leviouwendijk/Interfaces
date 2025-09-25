import Foundation

public extension Shell {
    enum ExitStatus: Sendable, Equatable {
        case exited(Int)
        case signaled(Int)
    }
}
