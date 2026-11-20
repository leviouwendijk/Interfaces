import Foundation

final class LockedDataRecorder:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var data = Data()

    func append(
        _ chunk: Data
    ) {
        lock.lock()
        data.append(
            chunk
        )
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        defer {
            lock.unlock()
        }

        return data
    }
}
