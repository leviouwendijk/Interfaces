import Foundation

public extension RSynchronizer {
    enum Mode: Sendable {
        case preflight
        case gated
        case direct
    }

    enum Preflight {
        public struct Options: Sendable {
            public var flags: [String]
            public var output: OutputPolicy

            public init(
                flags: [String] = [
                    "--itemize-changes",
                    "--stats"
                ],
                output: OutputPolicy = .quiet
            ) {
                self.flags = flags
                self.output = output
            }
        }

        public struct Summary: Sendable, Hashable {
            public var created: Int
            public var updated: Int
            public var deleted: Int
            public var lines: [String]

            public var changed: Int {
                created + updated + deleted
            }

            public init(
                created: Int = 0,
                updated: Int = 0,
                deleted: Int = 0,
                lines: [String] = []
            ) {
                self.created = created
                self.updated = updated
                self.deleted = deleted
                self.lines = lines
            }
        }

        public struct Report: Sendable {
            public var results: [Shell.Result]
            public var summary: Summary

            public init(
                results: [Shell.Result],
                summary: Summary
            ) {
                self.results = results
                self.summary = summary
            }
        }

        public enum Parser {
            public static func summary(
                from output: String
            ) -> Summary {
                var summary = Summary()

                for line in output
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map(String.init) {
                    guard !line.isEmpty else {
                        continue
                    }

                    if line.hasPrefix("*deleting ") {
                        summary.deleted += 1
                        summary.lines.append(line)
                        continue
                    }

                    guard is_itemized(line) else {
                        continue
                    }

                    summary.lines.append(line)

                    if line.contains("+++++++++") {
                        summary.created += 1
                    } else {
                        summary.updated += 1
                    }
                }

                return summary
            }

            private static func is_itemized(
                _ line: String
            ) -> Bool {
                guard line.count >= 11,
                      let first = line.first
                else {
                    return false
                }

                switch first {
                case ">", "<", "c", "h", ".", "*":
                    return line.contains(" ")

                default:
                    return false
                }
            }
        }
    }

    struct RunOptions: Sendable {
        public var mode: Mode
        public var execution: ExecutionOptions
        public var preflight: Preflight.Options
        public var includeDeleteOverride: Bool?
        public var host: String?

        public init(
            mode: Mode = .gated,
            execution: ExecutionOptions = .init(),
            preflight: Preflight.Options = .init(),
            includeDeleteOverride: Bool? = nil,
            host: String? = nil
        ) {
            self.mode = mode
            self.execution = execution
            self.preflight = preflight
            self.includeDeleteOverride = includeDeleteOverride
            self.host = host
        }
    }

    struct RunResult: Sendable {
        public var preflight: Preflight.Report?
        public var results: [Shell.Result]

        public init(
            preflight: Preflight.Report?,
            results: [Shell.Result]
        ) {
            self.preflight = preflight
            self.results = results
        }
    }

    @discardableResult
    static func run(
        _ route: Route,
        options: RunOptions = .init(),
        shouldRun: @Sendable (Preflight.Report) async throws -> Bool = { _ in true }
    ) async throws -> RunResult {
        if let host = options.host {
            try route.hostPermission.require(
                host,
                route: route.name
            )
        }

        switch options.mode {
        case .preflight:
            let report = try await inspect(
                route,
                options: options
            )

            return .init(
                preflight: report,
                results: []
            )

        case .gated:
            let report = try await inspect(
                route,
                options: options
            )

            guard try await shouldRun(report) else {
                return .init(
                    preflight: report,
                    results: []
                )
            }

            let results = try await execute_live(
                route,
                options: options
            )

            return .init(
                preflight: report,
                results: results
            )

        case .direct:
            let results = try await execute_live(
                route,
                options: options
            )

            return .init(
                preflight: nil,
                results: results
            )
        }
    }

    private static func inspect(
        _ route: Route,
        options: RunOptions
    ) async throws -> Preflight.Report {
        var execution = options.execution
        execution.dryRun = true
        execution.output = options.preflight.output
        execution.onEvent = nil
        execution.additionalRsyncFlags =
            options.execution.additionalRsyncFlags
            + options.preflight.flags

        let results = try await execute(
            route.hookless(),
            options: execution,
            includeDeleteOverride: options.includeDeleteOverride
        )

        let output = results
            .flatMap {
                [
                    $0.stdoutText(),
                    $0.stderrText()
                ]
            }
            .filter {
                !$0.isEmpty
            }
            .joined(separator: "\n")

        return .init(
            results: results,
            summary: Preflight.Parser.summary(
                from: output
            )
        )
    }

    private static func execute_live(
        _ route: Route,
        options: RunOptions
    ) async throws -> [Shell.Result] {
        var execution = options.execution
        execution.dryRun = false

        return try await execute(
            route,
            options: execution,
            includeDeleteOverride: options.includeDeleteOverride
        )
    }
}

public extension RSynchronizer.Route {
    func hookless() -> Self {
        .init(
            name: name,
            aliases: aliases,
            deletesExtraneous: deletesExtraneous,
            batches: batches,
            hooks: [],
            hostPermission: hostPermission
        )
    }
}
