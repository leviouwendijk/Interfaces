import Dispatch
import Foundation
import Processes

public struct PTYResult:
    Sendable
{
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data
}

public enum PTYError:
    Error
{
    case openPTYFailed(
        errno: Int32
    )

    case spawnFailed(
        errno: Int32
    )
}

@discardableResult
public func runPTY(
    _ launchPath: String,
    _ args: [String],
    env: [String: String]? = nil,
    cwd: URL? = nil,
    onChunk: (@Sendable (Data) -> Void)? = nil
) throws -> PTYResult {
    let environment: ProcessEnvironment

    if let env {
        environment = .custom(
            env
        )
    } else {
        environment = .custom(
            [:]
        )
    }

    let specification = ProcessSpecification(
        executable: .path(
            launchPath
        ),
        arguments: args,
        workingDirectory: cwd,
        environment: environment,
        io: .pseudoTerminal,
        outputLimit: .max
    )

    let bridge = PTYCompatibilityBridge()

    Task.detached {
        do {
            let result = try await ProcessRunner().run(
                specification,
                onStdout: { chunk in
                    onChunk?(
                        chunk
                    )
                }
            )

            bridge.complete(
                .success(
                    result
                )
            )
        } catch {
            bridge.complete(
                .failure(
                    error
                )
            )
        }
    }

    let result: ProcessResult

    do {
        result = try bridge.wait()
    } catch ProcessError.pseudoTerminalOpenFailed(
        let error
    ) {
        throw PTYError.openPTYFailed(
            errno: error
        )
    } catch ProcessError.processSpawnFailed(
        let error
    ) {
        throw PTYError.spawnFailed(
            errno: error
        )
    }

    let exitCode: Int32

    switch result.exit {
    case .exited(let code):
        exitCode = code

    case .signaled(let signal):
        exitCode =
            128
            + signal
    }

    return PTYResult(
        exitCode: exitCode,
        stdout: result.stdout,
        stderr: Data()
    )
}

@discardableResult
public func runPTYPassthrough(
    _ launchPath: String,
    _ args: [String],
    env: [String: String]? = nil,
    cwd: URL? = nil
) throws -> PTYResult {
    try runPTY(
        launchPath,
        args,
        env: env,
        cwd: cwd,
        onChunk: { chunk in
            FileHandle.standardOutput.write(
                chunk
            )
        }
    )
}

private final class PTYCompatibilityBridge:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(
        value: 0
    )

    private var result:
        Result<ProcessResult, any Error>?

    func complete(
        _ result: Result<
            ProcessResult,
            any Error
        >
    ) {
        lock.lock()

        self.result = result

        lock.unlock()

        semaphore.signal()
    }

    func wait() throws -> ProcessResult {
        semaphore.wait()

        lock.lock()

        let result = self.result

        lock.unlock()

        guard let result else {
            preconditionFailure(
                "PTY compatibility execution completed without a result."
            )
        }

        return try result.get()
    }
}
