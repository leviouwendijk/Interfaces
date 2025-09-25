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
        while let nl = buffer.firstIndex(of: 0x0A) { 
            let line = buffer[..<nl] 
            let next = buffer.index(after: nl)
            buffer.removeSubrange(..<next)
            if colorize, let s = String(data: line, encoding: .utf8) {
                let painted = paint?(s) ?? s
                handle.write(Data((painted + "\n").utf8))
            } else {
                handle.write(line)
                handle.write(Data([0x0A]))
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
