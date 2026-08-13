import Foundation
import Processes

public struct Shell: Sendable {
    public let exec: Exec

    public init(
        _ exec: Exec = .zsh
    ) {
        self.exec = exec
    }

    @discardableResult
    public func run(
        _ programOrLauncher: String,
        _ args: [String] = [],
        options: Options = .init()
    ) async throws -> Result {
        let (
            launchPath,
            argv
        ) = loweredInvocation(
            programOrLauncher,
            args,
            options: options
        )

        let environment = resolvedEnvironment(
            options
        )

        let observation =
            ShellProcessObservation()

        let timeout = processTimeout(
            options.timeout
        )

        let startHandler: ProcessStartHandler = {
            processIdentifier in

            await observation.recordStart(
                processIdentifier:
                    processIdentifier
            )
        }

        let stdoutHandler: ProcessOutputHandler = {
            chunk in

            if options.teeToStdout {
                FileHandle.standardOutput.write(
                    chunk
                )
            }

            options.onStdoutChunk?(
                chunk
            )
        }

        let stderrHandler: ProcessOutputHandler = {
            chunk in

            if options.teeToStderr {
                FileHandle.standardError.write(
                    chunk
                )
            }

            options.onStderrChunk?(
                chunk
            )
        }

        let processResult: ProcessResult

        do {
            processResult = try await ProcessRunner().run(
                .init(
                    executable: .path(
                        launchPath
                    ),
                    arguments: argv,
                    workingDirectory:
                        options.cwd,
                    environment: .custom(
                        environment
                    ),
                    input: options.stdin.map {
                        .data(
                            $0
                        )
                    } ?? .none,
                    io: .pipes,
                    outputLimit: .max,
                    timeout: timeout,
                    terminationPolicy: .init(
                        gracefulShutdownTimeout:
                            .seconds(
                                1
                            ),
                        isolateProcessGroup:
                            true
                    )
                ),
                onStart: startHandler,
                onStdout: stdoutHandler,
                onStderr: stderrHandler
            )
        } catch let error as ProcessError {
            switch error {
            case .timedOut:
                let snapshot =
                    await observation.snapshot()

                throw Error.timedOut(
                    after:
                        options.timeout
                        ?? 0,
                    pid:
                        snapshot.pid
                        ?? 0
                )

            default:
                throw error
            }
        }

        let snapshot =
            await observation.snapshot()

        guard
            let pid = snapshot.pid,
            let startedAt =
                snapshot.startedAt
        else {
            throw Error.launchFailure(
                "Process completed without start observation."
            )
        }

        let duration = Date()
            .timeIntervalSince(
                startedAt
            )

        let status = shellExitStatus(
            processResult.exit
        )

        let result = Result(
            status: status,
            pid: pid,
            launchedPath: launchPath,
            argv: argv,
            duration: duration,
            stdout:
                processResult.stdout,
            stderr:
                processResult.stderr
        )

        if case .exited(
            let code
        ) = status,
           !options.expectedExitCodes
            .contains(
                code
            )
        {
            let envShown =
                environment.reduce(
                    into:
                        [String: String]()
                ) {
                    result,
                    entry in

                    result[
                        entry.key
                    ] = "<redacted>"
                }

            let context = RunContext(
                exec: exec,
                launchPath: launchPath,
                argv: argv,
                cwd: options.cwd?.path,
                inheritEnvironment:
                    options
                        .inheritEnvironment,
                env: envShown,
                timeout: options.timeout,
                expectedExitCodes:
                    options
                        .expectedExitCodes,
                teeToStdout:
                    options
                        .teeToStdout,
                teeToStderr:
                    options
                        .teeToStderr,
                redactions:
                    options.redactions,
                duration: duration,
                pid: pid
            )

            let stdoutPreview = String(
                result
                    .stdoutText()
                    .prefix(
                        400
                    )
            )

            let stderrPreview = String(
                result
                    .stderrText()
                    .prefix(
                        400
                    )
            )

            throw Error.nonZeroExit(
                code: code,
                stdoutPreview:
                    stdoutPreview,
                stderrPreview:
                    stderrPreview,
                result: result,
                context: context
            )
        }

        return result
    }
}

private extension Shell {
    func loweredInvocation(
        _ programOrLauncher: String,
        _ args: [String],
        options: Options
    ) -> (
        launchPath: String,
        argv: [String]
    ) {
        let (
            launcher,
            prefix
        ) = exec
            .launchPathAndArgsPrefix

        switch exec {
        case .path:
            return (
                programOrLauncher,
                args
            )

        case .env:
            return (
                launcher,
                [
                    programOrLauncher,
                ] + args
            )

        case .sh,
             .bash,
             .zsh:
            let command =
                quoteForShell(
                    programOrLauncher,
                    redactions:
                        options
                            .redactions
                )
                + " "
                + args.map {
                    quoteForShell(
                        $0,
                        redactions:
                            options
                                .redactions
                    )
                }
                .joined(
                    separator: " "
                )

            return (
                launcher,
                prefix
                    + [
                        command,
                    ]
            )
        }
    }

    func resolvedEnvironment(
        _ options: Options
    ) -> [String: String] {
        var environment =
            options
                .inheritEnvironment
            ? ProcessInfo
                .processInfo
                .environment
            : [:]

        for (
            key,
            value
        ) in options.env {
            environment[
                key
            ] = value
        }

        return environment
    }

    func processTimeout(
        _ timeout: TimeInterval?
    ) -> Duration? {
        guard
            let timeout,
            timeout > 0
        else {
            return nil
        }

        return .nanoseconds(
            Int64(
                timeout
                    * 1_000_000_000
            )
        )
    }

    func shellExitStatus(
        _ exit: ProcessExit
    ) -> ExitStatus {
        switch exit {
        case .exited(
            let code
        ):
            return .exited(
                Int(
                    code
                )
            )

        case .signaled(
            let signal
        ):
            return .signaled(
                Int(
                    signal
                )
            )
        }
    }

    func quoteForShell(
        _ value: String,
        redactions: [String]
    ) -> String {
        let redacted =
            redactions.reduce(
                value
            ) {
                accumulated,
                needle in

                accumulated
                    .replacingOccurrences(
                        of: needle,
                        with:
                            "‹redacted›"
                    )
            }

        if redacted.isEmpty {
            return "''"
        }

        return "'"
            + redacted
                .replacingOccurrences(
                    of: "'",
                    with:
                        "'\"'\"'"
                )
            + "'"
    }
}

private actor ShellProcessObservation {
    private var processIdentifier:
        pid_t?

    private var startedAt:
        Date?

    func recordStart(
        processIdentifier: Int64
    ) {
        self.processIdentifier =
            pid_t(
                processIdentifier
            )

        startedAt = Date()
    }

    func snapshot() -> (
        pid: pid_t?,
        startedAt: Date?
    ) {
        (
            processIdentifier,
            startedAt
        )
    }
}
