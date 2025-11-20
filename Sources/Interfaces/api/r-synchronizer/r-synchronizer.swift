import Foundation
import plate

public enum RSynchronizer {
    public struct Route: Sendable {
        public let name: String
        public let batches: [Batch]
        public let deletesExtraneous: Bool

        public init(
            name: String,
            deletesExtraneous: Bool = false,
            batches: [Batch]
        ) {
            self.name = name
            self.batches = batches
            self.deletesExtraneous = deletesExtraneous
        }
    }

    public struct Batch: Sendable {
        public let sources: [String]
        public let destinations: [Destination]
        public let requiresSudo: Bool
        public let chown: String?
        public let excludes: [String]

        public init(
            sources: [String],
            destinations: [Destination],
            requiresSudo: Bool = false,
            chown: String? = nil,
            excludes: [String] = []
        ) {
            self.sources = sources
            self.destinations = destinations
            self.requiresSudo = requiresSudo
            self.chown = chown
            self.excludes = excludes
        }
    }

    public struct Destination: Sendable {
        public let host: String?
        public let directory: String

        public init(
            host: String? = nil,
            directory: String
        ) {
            self.host = host
            self.directory = directory
        }
    }

    public struct Command: Sendable {
        public let arguments: [String]

        public init(arguments: [String]) {
            self.arguments = arguments
        }

        public var prettyLine: String {
            arguments.joined(separator: " ")
        }

        public func prettyMultiline(
            indentation: IndentationOptions = .init(
                overrides: [
                    .init([1: .init(skip: true)])
                ]
            ),
        ) -> String {
            let newline_separated = arguments
                // .map { $0.indent() }
                // .joined(separator: " \\\n")
                .map { "\($0) \\" }

            return newline_separated.indent(options: indentation)
        }
    }

    public struct Plan: Sendable {
        public let route: Route
        public let commands: [Command]
    }

    public static func plan(
        _ route: Route,
        includeDeleteOverride: Bool? = nil
    ) -> Plan {
        let includeDelete = includeDeleteOverride ?? route.deletesExtraneous
        var commands: [Command] = []

        for batch in route.batches {
            for source in batch.sources {
                for destination in batch.destinations {
                    var argv: [String] = []
                    argv.append("rsync")
                    argv.append("-avz")
                    argv.append("--progress")

                    if includeDelete {
                        argv.append("--delete")
                    }
                    if let chown = batch.chown, !chown.isEmpty {
                        argv.append("--chown=\(chown)")
                    }
                    if !batch.excludes.isEmpty {
                        for p in batch.excludes {
                            argv.append("--exclude=\(p)")
                        }
                    }
                    if batch.requiresSudo {
                        argv.append("--rsync-path=sudo rsync")
                    }

                    argv.append(expandTilde(source))

                    let dir = destination.directory
                    if let host = destination.host, !host.isEmpty {
                        argv.append("\(host):\(dir)")
                    } else {
                        argv.append(expandTilde(dir))
                    }

                    commands.append(Command(arguments: argv))
                }
            }
        }

        return Plan(route: route, commands: commands)
    }

    public enum OutputPolicy: Sendable {
        case verbose               // tee live
        case quiet                 // never tee, never print
        case quietUntilFailure     // never tee, print only on failure (binary decides)
    }

    public enum Event: Sendable {
        case commandStarted(command: Command, index: Int, total: Int)
        case commandFinished(command: Command, result: Shell.Result)
    }

    public struct ExecutionOptions: Sendable {
        public var dryRun: Bool
        public var additionalRsyncFlags: [String]
        public var shell: Shell
        public var cwd: URL?
        public var output: OutputPolicy
        // public var onEvent: (@Sendable (Event) -> Void)?
        public var onEvent: (@Sendable (Event) async -> Void)?

        public init(
            dryRun: Bool = false,
            additionalRsyncFlags: [String] = [],
            shell: Shell = .init(.path("/usr/bin/env")),
            cwd: URL? = nil,
            output: OutputPolicy = .verbose,
            // onEvent: (@Sendable (Event) -> Void)? = nil
            onEvent: (@Sendable (Event) async -> Void)? = nil
        ) {
            self.dryRun = dryRun
            self.additionalRsyncFlags = additionalRsyncFlags
            self.shell = shell
            self.cwd = cwd
            self.output = output
            self.onEvent = onEvent
        }
    }

    @discardableResult
    public static func execute(
        _ route: Route,
        options: ExecutionOptions = .init(),
        includeDeleteOverride: Bool? = nil
    ) async throws -> [Shell.Result] {

        let plan = plan(route, includeDeleteOverride: includeDeleteOverride)
        var results: [Shell.Result] = []
        let total = plan.commands.count

        for (i, cmd) in plan.commands.enumerated() {
            await options.onEvent?(.commandStarted(command: cmd, index: i, total: total))

            var argv = cmd.arguments
            if options.dryRun {
                argv.insert("--dry-run", at: 1)
            }
            if !options.additionalRsyncFlags.isEmpty {
                argv.insert(contentsOf: options.additionalRsyncFlags, at: 1)
            }

            let tee = (options.output == .verbose)

            var shOpt = Shell.Options()
            shOpt.cwd = options.cwd
            shOpt.teeToStdout = tee
            shOpt.teeToStderr = tee

            let res = try await options.shell.run("/usr/bin/env", argv, options: shOpt)
            results.append(res)

            await options.onEvent?(.commandFinished(command: cmd, result: res))

            if case .exited(let code) = res.status, code != 0 {
                throw RSynchronizerError.commandFailed(
                    commandLine: cmd.prettyLine,
                    exitCode: code
                )
            }
        }

        return results
    }

    private static func expandTilde(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
