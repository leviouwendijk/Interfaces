import Foundation
import plate
import Structures

public enum LogLevel: Int, Comparable {
    case info, warn, error, critical, debug

    public var label: String {
        switch self {
        case .info:  return "INFO"
        case .warn:  return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        case .debug: return "DEBUG"
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public actor StandardLogger {
    public var minimumLevel: LogLevel = .info
    public var onError: ((Error) -> Void)?
    
    public init(logFileURL: URL? = nil) throws {
        self.fileHandle = try Self.makeFileHandle(for: logFileURL)
    }
    
    public init(for applicationName: String) throws {
        let home     = Home.string()

        let url      = URL(filePath: home)
        .appendingPathComponent("api-logs")
        .appendingPathComponent("\(applicationName).log")

        self.fileHandle = try Self.makeFileHandle(for: url)
    }

    deinit {
        try? fileHandle?.close()
    }
    
    public func configure(logFileURL: URL?) async throws {
        try fileHandle?.close()
        fileHandle = try Self.makeFileHandle(for: logFileURL)
    }
    
    public func log(_ message: String, level: LogLevel = .info) async {
        guard level >= minimumLevel else { return }

        let ts   = Self.sharedFormatter.value.string(from: Date())
        let line = "[\(ts)] [\(level.label)] \(message)\n"
        guard let data = line.data(using: String.Encoding.utf8) else {
            assertionFailure("Logger: UTF-8 encoding failed")
            return
        }

        do {
            if let fh = fileHandle {
                try fh.write(contentsOf: data)
            } else {
                FileHandle.standardOutput.write(data)
            }
        } catch {
            onError?(error)
        }
    }
    
    public nonisolated func info(_  message: String) { Task { await log(message, level: .info)  } }
    public nonisolated func warn(_  message: String) { Task { await log(message, level: .warn)  } }
    public nonisolated func error(_ message: String) { Task { await log(message, level: .error) } }
    public nonisolated func critical(_ message: String) { Task { await log(message, level: .critical) } }
    public nonisolated func debug(_ message: String) { Task { await log(message, level: .critical) } }

    // private static let sharedFormatter: ISO8601DateFormatter = {
    //     let f = ISO8601DateFormatter()
    //     f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    //     return f
    // }()

    private static let sharedFormatter = FormatterBox {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private struct FormatterBox<T>: @unchecked Sendable {
        let value: T
        init(_ make: () -> T) { self.value = make() }
    }

    private var fileHandle: FileHandle?

    private static func makeFileHandle(for url: URL?) throws -> FileHandle? {
        guard let url = url else { return nil }
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )

        let created = FileManager.default.createFile(atPath: url.path, contents: nil)
        guard created || FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(
                .fileWriteUnknown,
                userInfo: [NSFilePathErrorKey: url.path]
            )
        }

        let fh = try FileHandle(forWritingTo: url)
        fh.seekToEndOfFile()
        return fh
    }
}
