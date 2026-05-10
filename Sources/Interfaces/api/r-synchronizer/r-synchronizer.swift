import Foundation
// import plate
import Indentation

public enum RSynchronizer {
    public struct HostPermission: Sendable, Hashable {
        public var hostnames: Set<String>

        public static let any = Self()

        public init(
            _ hostnames: Set<String> = []
        ) {
            self.hostnames = hostnames
        }

        public func allows(
            _ hostname: String
        ) -> Bool {
            hostnames.isEmpty || hostnames.contains(
                hostname
            )
        }

        public func require(
            _ hostname: String,
            route: String
        ) throws {
            guard allows(hostname) else {
                throw PermissionError.host_not_allowed(
                    hostname: hostname,
                    route: route
                )
            }
        }
    }

    public enum PermissionError: Error, LocalizedError, Sendable {
        case host_not_allowed(
            hostname: String,
            route: String
        )

        public var errorDescription: String? {
            switch self {
            case .host_not_allowed(let hostname, let route):
                return "Host '\(hostname)' is not allowed to run rsync route '\(route)'."
            }
        }
    }

    public struct Route: Sendable {
        public let name: String
        public let aliases: [String]
        public let batches: [Batch]
        public let deletesExtraneous: Bool
        public let hooks: [Hook]
        public let hostPermission: HostPermission

        public init(
            name: String,
            aliases: [String] = [],
            deletesExtraneous: Bool = false,
            batches: [Batch],
            hooks: [Hook] = [],
            hostPermission: HostPermission = .any
        ) {
            self.name = name
            self.aliases = aliases
            self.batches = batches
            self.deletesExtraneous = deletesExtraneous
            self.hooks = hooks
            self.hostPermission = hostPermission
        }

        public func matches(_ candidate: String) -> Bool {
            if candidate == name { return true }
            return aliases.contains(candidate)
        }

        public var allNames: [String] {
            [name] + aliases
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
                    .init([0: .init(skip: true)])
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
        public struct Entry: Sendable {
            public var invocation: Invocation?
            public var command: Command

            public init(
                invocation: Invocation? = nil,
                command: Command
            ) {
                self.invocation = invocation
                self.command = command
            }
        }

        public let route: Route
        public let entries: [Entry]

        public var commands: [Command] {
            entries.map(\.command)
        }

        public init(
            route: Route,
            entries: [Entry]
        ) {
            self.route = route
            self.entries = entries
        }

        public init(
            route: Route,
            commands: [Command]
        ) {
            self.route = route
            self.entries = commands.map {
                Entry(
                    command: $0
                )
            }
        }
    }

    public static func plan(
        _ route: Route,
        options: PlanOptions = .init(),
        includeDeleteOverride: Bool? = nil
    ) -> Plan {
        let includeDelete = includeDeleteOverride ?? route.deletesExtraneous
        var entries: [Plan.Entry] = []

        for batch in route.batches {
            for source in batch.sources {
                for destination in batch.destinations {
                    let target: Endpoint

                    if let host = destination.host,
                       !host.isEmpty {
                        target = .remote(
                            host: host,
                            path: destination.directory
                        )
                    } else {
                        target = .local(
                            destination.directory
                        )
                    }

                    var seenExcludes = Set<String>()

                    let exclude = (
                        batch.excludes.map(Exclude.init)
                        + options.exclude
                    )
                    .filter { item in
                        seenExcludes.insert(
                            item.pattern
                        )
                        .inserted
                    }

                    let invocation = Invocation(
                        source: .local(
                            source
                        ),
                        destination: target,
                        delete: includeDelete ? .extraneous : .keep,
                        owner: batch.chown,
                        exclude: exclude,
                        privilege: batch.requiresSudo ? .sudo : .normal,
                        comparison: options.comparison,
                        metadata: options.metadata,
                        raw: options.raw
                    )

                    entries.append(
                        .init(
                            invocation: invocation,
                            command: invocation.command()
                        )
                    )
                }
            }
        }

        return Plan(
            route: route,
            entries: entries
        )
    }

    // public static func plan(
    //     _ route: Route,
    //     includeDeleteOverride: Bool? = nil
    // ) -> Plan {
    //     let includeDelete = includeDeleteOverride ?? route.deletesExtraneous
    //     var commands: [Command] = []

    //     for batch in route.batches {
    //         for source in batch.sources {
    //             for destination in batch.destinations {
    //                 var argv: [String] = []
    //                 argv.append("rsync")
    //                 argv.append("-avz")
    //                 argv.append("--progress")

    //                 if includeDelete {
    //                     argv.append("--delete")
    //                 }
    //                 if let chown = batch.chown, !chown.isEmpty {
    //                     argv.append("--chown=\(chown)")
    //                 }
    //                 if !batch.excludes.isEmpty {
    //                     for p in batch.excludes {
    //                         argv.append("--exclude=\(p)")
    //                     }
    //                 }
    //                 if batch.requiresSudo {
    //                     argv.append("--rsync-path=sudo rsync")
    //                 }

    //                 argv.append(expandTilde(source))

    //                 let dir = destination.directory
    //                 if let host = destination.host, !host.isEmpty {
    //                     argv.append("\(host):\(dir)")
    //                 } else {
    //                     argv.append(expandTilde(dir))
    //                 }

    //                 commands.append(Command(arguments: argv))
    //             }
    //         }
    //     }

    //     return Plan(route: route, commands: commands)
    // }

    public enum OutputPolicy: Sendable {
        case verbose               // tee live
        case quiet                 // never tee, never print
        case quietUntilFailure     // never tee, print only on failure (binary decides)
    }

    public enum Event: Sendable {
        case commandStarted(command: Command, index: Int, total: Int)
        case commandFinished(command: Command, result: Shell.Result)

        case hookStarted(Hook, index: Int, total: Int)
        case hookFinished(Hook, result: Shell.Result)
    }

    public struct ExecutionOptions: Sendable {
        public var plan: PlanOptions
        public var dryRun: Bool
        public var additionalRsyncFlags: [String]
        public var shell: Shell
        public var cwd: URL?
        public var output: OutputPolicy
        public var onEvent: (@Sendable (Event) async -> Void)?

        public init(
            plan: PlanOptions = .init(),
            dryRun: Bool = false,
            additionalRsyncFlags: [String] = [],
            shell: Shell = .init(.path("/usr/bin/env")),
            cwd: URL? = nil,
            output: OutputPolicy = .verbose,
            onEvent: (@Sendable (Event) async -> Void)? = nil
        ) {
            self.plan = plan
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
        let syncPlan = RSynchronizer.plan(
            route,
            options: options.plan,
            includeDeleteOverride: includeDeleteOverride
        )

        var results: [Shell.Result] = []
        let total = syncPlan.commands.count

        for (index, command) in syncPlan.commands.enumerated() {
            await options.onEvent?(
                .commandStarted(
                    command: command,
                    index: index,
                    total: total
                )
            )

            var argv = command.arguments

            if options.dryRun {
                argv.insert(
                    "--dry-run",
                    at: 1
                )
            }

            if !options.additionalRsyncFlags.isEmpty {
                argv.insert(
                    contentsOf: options.additionalRsyncFlags,
                    at: 1
                )
            }

            let tee = options.output == .verbose

            var shellOptions = Shell.Options()
            shellOptions.cwd = options.cwd
            shellOptions.teeToStdout = tee
            shellOptions.teeToStderr = tee

            let result = try await options.shell.run(
                "/usr/bin/env",
                argv,
                options: shellOptions
            )

            results.append(
                result
            )

            await options.onEvent?(
                .commandFinished(
                    command: command,
                    result: result
                )
            )

            if case .exited(let code) = result.status,
               code != 0 {
                throw RSynchronizerError.commandFailed(
                    commandLine: argv.joined(
                        separator: " "
                    ),
                    exitCode: code
                )
            }
        }

        if !route.hooks.isEmpty {
            let totalHooks = route.hooks.count

            for (index, hook) in route.hooks.enumerated() {
                await options.onEvent?(
                    .hookStarted(
                        hook,
                        index: index,
                        total: totalHooks
                    )
                )

                let command = hookCommand(
                    hook
                )

                let tee = options.output == .verbose

                var shellOptions = Shell.Options()
                shellOptions.cwd = options.cwd
                shellOptions.teeToStdout = tee
                shellOptions.teeToStderr = tee

                let result = try await options.shell.run(
                    "/usr/bin/env",
                    command.arguments,
                    options: shellOptions
                )

                results.append(
                    result
                )

                await options.onEvent?(
                    .hookFinished(
                        hook,
                        result: result
                    )
                )

                if case .exited(let code) = result.status,
                   code != 0 {
                    throw RSynchronizerError.hookFailed(
                        hookLine: hook.line,
                        exitCode: code
                    )
                }
            }
        }

        return results
    }

    // public struct ExecutionOptions: Sendable {
    //     public var dryRun: Bool
    //     public var additionalRsyncFlags: [String]
    //     public var shell: Shell
    //     public var cwd: URL?
    //     public var output: OutputPolicy
    //     // public var onEvent: (@Sendable (Event) -> Void)?
    //     public var onEvent: (@Sendable (Event) async -> Void)?

    //     public init(
    //         dryRun: Bool = false,
    //         additionalRsyncFlags: [String] = [],
    //         shell: Shell = .init(.path("/usr/bin/env")),
    //         cwd: URL? = nil,
    //         output: OutputPolicy = .verbose,
    //         // onEvent: (@Sendable (Event) -> Void)? = nil
    //         onEvent: (@Sendable (Event) async -> Void)? = nil
    //     ) {
    //         self.dryRun = dryRun
    //         self.additionalRsyncFlags = additionalRsyncFlags
    //         self.shell = shell
    //         self.cwd = cwd
    //         self.output = output
    //         self.onEvent = onEvent
    //     }
    // }

    // @discardableResult
    // public static func execute(
    //     _ route: Route,
    //     options: ExecutionOptions = .init(),
    //     includeDeleteOverride: Bool? = nil
    // ) async throws -> [Shell.Result] {

    //     let plan = plan(route, includeDeleteOverride: includeDeleteOverride)
    //     var results: [Shell.Result] = []
    //     let total = plan.commands.count

    //     for (i, cmd) in plan.commands.enumerated() {
    //         await options.onEvent?(.commandStarted(command: cmd, index: i, total: total))

    //         var argv = cmd.arguments
    //         if options.dryRun {
    //             argv.insert("--dry-run", at: 1)
    //         }
    //         if !options.additionalRsyncFlags.isEmpty {
    //             argv.insert(contentsOf: options.additionalRsyncFlags, at: 1)
    //         }

    //         let tee = (options.output == .verbose)

    //         var shOpt = Shell.Options()
    //         shOpt.cwd = options.cwd
    //         shOpt.teeToStdout = tee
    //         shOpt.teeToStderr = tee

    //         let res = try await options.shell.run("/usr/bin/env", argv, options: shOpt)
    //         results.append(res)

    //         await options.onEvent?(.commandFinished(command: cmd, result: res))

    //         if case .exited(let code) = res.status, code != 0 {
    //             throw RSynchronizerError.commandFailed(
    //                 commandLine: cmd.prettyLine,
    //                 exitCode: code
    //             )
    //         }
    //     }

    //     // -----------------------------
    //     // Post-sync hooks (post-deploy)
    //     // -----------------------------
    //     if !route.hooks.isEmpty {
    //         let totalHooks = route.hooks.count

    //         for (i, hook) in route.hooks.enumerated() {
    //             await options.onEvent?(.hookStarted(hook, index: i, total: totalHooks))

    //             let cmd = hookCommand(hook)

    //             let tee = (options.output == .verbose)
    //             var shOpt = Shell.Options()
    //             shOpt.cwd = options.cwd
    //             shOpt.teeToStdout = tee
    //             shOpt.teeToStderr = tee

    //             let res = try await options.shell.run("/usr/bin/env", cmd.arguments, options: shOpt)
    //             results.append(res)

    //             await options.onEvent?(.hookFinished(hook, result: res))

    //             if case .exited(let code) = res.status, code != 0 {
    //                 throw RSynchronizerError.hookFailed(
    //                     hookLine: hook.line,
    //                     exitCode: code
    //                 )
    //             }
    //         }
    //     }

    //     return results
    // }

    private static func expandTilde(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
