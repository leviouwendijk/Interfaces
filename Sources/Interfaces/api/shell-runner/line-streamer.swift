import Foundation

public actor LineStreamer {
    private var buffer = Data()
    private let handle: FileHandle
    private let colorize: Bool
    private let paint: (@Sendable (String) -> String)?

    public init(handle: FileHandle, colorize: Bool, paint: (@Sendable (String) -> String)? = nil) {
        self.handle = handle
        self.colorize = colorize
        self.paint = paint
    }

    public func ingest(_ chunk: Data) {
        buffer.append(chunk)
        // Emit on either \n or \r
        while let idx = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) { // 0x0A=\n, 0x0D=\r
            let sep = buffer[idx]
            let slice = buffer[..<idx]
            let next = buffer.index(after: idx)
            buffer.removeSubrange(..<next)

            if let s = String(data: slice, encoding: .utf8) {
                let out = colorize ? (paint?(s) ?? s) : s
                if sep == 0x0A {
                    handle.write(Data((out + "\n").utf8))
                } else {
                    handle.write(Data((out + "\r").utf8))
                }
            } else {
                // binary-ish chunk: just write raw + the separator
                handle.write(slice)
                handle.write(Data([sep]))
            }
        }
    }

    public func flush() {
        guard !buffer.isEmpty else { return }
        if colorize, let s = String(data: buffer, encoding: .utf8) {
            let painted = paint?(s) ?? s
            handle.write(Data(painted.utf8))
        } else {
            handle.write(buffer)
        }
        buffer.removeAll(keepingCapacity: false)
    }
}
