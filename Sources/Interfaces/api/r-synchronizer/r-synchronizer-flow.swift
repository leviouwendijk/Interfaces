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
                    "--out-format=%i\t%l\t%n%L",
                    "--stats",
                ],
                output: OutputPolicy = .quiet
            ) {
                self.flags = flags
                self.output = output
            }
        }

        public enum Kind: String, Sendable, Hashable {
            case created
            case transfer
            case metadata
            case deleted
            case other
        }

        public enum FileKind: String, Sendable, Hashable {
            case file
            case dir
            case symlink
            case device
            case special
            case unknown
        }

        public enum Reason: String, Sendable, Hashable {
            case transfer
            case checksum
            case size
            case timestamp
            case permissions
            case owner
            case group
            case uid
            case acl
            case xattr
            case created
            case deleted
        }

        public struct Item: Sendable, Hashable {
            public var raw: String
            public var code: String
            public var path: String
            public var size: Int?
            public var kind: Kind
            public var fileKind: FileKind
            public var reasons: [Reason]

            public init?(
                _ line: String
            ) {
                let trimmed = line.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !trimmed.isEmpty else {
                    return nil
                }

                if trimmed.hasPrefix("*deleting ") {
                    self.raw = trimmed
                    self.code = "*deleting"
                    self.path = String(
                        trimmed.dropFirst("*deleting ".count)
                    )
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                    self.size = nil
                    self.kind = .deleted
                    self.fileKind = .unknown
                    self.reasons = [
                        .deleted
                    ]
                    return
                }

                let parsed = Self.parts(
                    trimmed
                )

                guard let parsed,
                    Self.is_itemized(parsed.code)
                else {
                    return nil
                }

                self.raw = trimmed
                self.code = parsed.code
                self.path = parsed.path
                self.size = parsed.size
                self.fileKind = Self.file_kind(
                    parsed.code
                )
                self.reasons = Self.reasons(
                    parsed.code
                )
                self.kind = Self.kind(
                    code: parsed.code,
                    reasons: self.reasons
                )
            }

            private static func parts(
                _ line: String
            ) -> (
                code: String,
                size: Int?,
                path: String
            )? {
                let tabbed = line.split(
                    separator: "\t",
                    maxSplits: 2,
                    omittingEmptySubsequences: false
                )

                if tabbed.count == 3 {
                    return (
                        code: String(tabbed[0]),
                        size: Int(tabbed[1]),
                        path: String(tabbed[2])
                    )
                }

                guard
                    let space = line.firstIndex(
                        of: " "
                    )
                else {
                    return nil
                }

                let code = String(
                    line[..<space]
                )

                let path = String(
                    line[line.index(after: space)...]
                )
                .trimmingCharacters(
                    in: .whitespaces
                )

                return (
                    code: code,
                    size: nil,
                    path: path
                )
            }

            private static func kind(
                code: String,
                reasons: [Reason]
            ) -> Kind {
                if code.contains("+++++++++") {
                    return .created
                }

                guard let first = code.first else {
                    return .other
                }

                if first == ">" || first == "<" {
                    return .transfer
                }

                if !reasons.isEmpty {
                    return .metadata
                }

                return .other
            }

            private static func file_kind(
                _ code: String
            ) -> FileKind {
                guard code.count > 1 else {
                    return .unknown
                }

                let index = code.index(
                    after: code.startIndex
                )

                switch code[index] {
                case "f":
                    return .file

                case "d":
                    return .dir

                case "L":
                    return .symlink

                case "D":
                    return .device

                case "S":
                    return .special

                default:
                    return .unknown
                }
            }

            private static func reasons(
                _ code: String
            ) -> [Reason] {
                if code.contains("+++++++++") {
                    return [
                        .created
                    ]
                }

                var out: [Reason] = []

                if let first = code.first,
                    first == ">" || first == "<"
                {
                    out.append(
                        .transfer
                    )
                }

                let chars = Array(
                    code
                )

                func has(
                    _ offset: Int,
                    _ character: Character
                ) -> Bool {
                    chars.indices.contains(offset)
                        && chars[offset] == character
                }

                if has(2, "c") {
                    out.append(
                        .checksum
                    )
                }

                if has(3, "s") {
                    out.append(
                        .size
                    )
                }

                if has(4, "t") || has(4, "T") {
                    out.append(
                        .timestamp
                    )
                }

                if has(5, "p") {
                    out.append(
                        .permissions
                    )
                }

                if has(6, "o") {
                    out.append(
                        .owner
                    )
                }

                if has(7, "g") {
                    out.append(
                        .group
                    )
                }

                if has(8, "u") {
                    out.append(
                        .uid
                    )
                }

                if has(9, "a") {
                    out.append(
                        .acl
                    )
                }

                if has(10, "x") {
                    out.append(
                        .xattr
                    )
                }

                return out
            }

            private static func is_itemized(
                _ code: String
            ) -> Bool {
                guard code.count >= 11,
                    let first = code.first
                else {
                    return false
                }

                switch first {
                case ">", "<", "c", "h", ".", "*":
                    return true

                default:
                    return false
                }
            }
        }

        public struct Summary: Sendable, Hashable {
            public var items: [Item]

            public var created: Int {
                createdItems.count
            }

            public var updated: Int {
                transferItems.count
                    + metadataItems.count
                    + otherItems.count
            }

            public var deleted: Int {
                deletedItems.count
            }

            public var changed: Int {
                items.count
            }

            public var lines: [String] {
                items.map(\.raw)
            }

            public var createdItems: [Item] {
                items.filter {
                    $0.kind == .created
                }
            }

            public var transferItems: [Item] {
                items.filter {
                    $0.kind == .transfer
                }
            }

            public var metadataItems: [Item] {
                items.filter {
                    $0.kind == .metadata
                }
            }

            public var deletedItems: [Item] {
                items.filter {
                    $0.kind == .deleted
                }
            }

            public var otherItems: [Item] {
                items.filter {
                    $0.kind == .other
                }
            }

            public var plannedBytes: Int {
                items.reduce(into: 0) { total, item in
                    guard item.kind == .created || item.kind == .transfer else {
                        return
                    }

                    total += item.size ?? 0
                }
            }

            public init(
                items: [Item] = []
            ) {
                self.items = items
            }
        }

        public struct CommandReport: Sendable {
            public var index: Int
            public var entry: Plan.Entry
            public var result: Shell.Result
            public var summary: Summary

            public var command: Command {
                entry.command
            }

            public var items: [Item] {
                summary.items
            }

            public init(
                index: Int,
                entry: Plan.Entry,
                result: Shell.Result,
                summary: Summary
            ) {
                self.index = index
                self.entry = entry
                self.result = result
                self.summary = summary
            }
        }

        public struct Report: Sendable {
            public var results: [Shell.Result]
            public var summary: Summary
            public var commands: [CommandReport]

            public init(
                results: [Shell.Result],
                summary: Summary,
                commands: [CommandReport] = []
            ) {
                self.results = results
                self.summary = summary
                self.commands = commands
            }

            public init(
                commands: [CommandReport]
            ) {
                self.commands = commands
                self.results = commands.map(\.result)

                self.summary = Summary(
                    items: commands.flatMap {
                        $0.summary.items
                    }
                )
            }
        }

        public enum Parser {
            public static func summary(
                from output: String
            ) -> Summary {
                let items =
                    output
                    .split(
                        separator: "\n",
                        omittingEmptySubsequences: false
                    )
                    .map(String.init)
                    .compactMap(Item.init)

                return Summary(
                    items: items
                )
            }

            public static func summary(
                from result: Shell.Result
            ) -> Summary {
                summary(
                    from: [
                        result.stdoutText(),
                        result.stderrText(),
                    ]
                    .filter {
                        !$0.isEmpty
                    }
                    .joined(
                        separator: "\n"
                    )
                )
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

        let inspectedRoute = route.hookless()

        let syncPlan = RSynchronizer.plan(
            inspectedRoute,
            options: execution.plan,
            includeDeleteOverride: options.includeDeleteOverride
        )

        let results = try await execute(
            inspectedRoute,
            options: execution,
            includeDeleteOverride: options.includeDeleteOverride
        )

        let commandReports = Array(
            zip(
                syncPlan.entries,
                results
            )
        )
        .enumerated()
        .map { index, pair in
            let entry = pair.0
            let result = pair.1

            return Preflight.CommandReport(
                index: index,
                entry: entry,
                result: result,
                summary: Preflight.Parser.summary(
                    from: result
                )
            )
        }

        return .init(
            commands: commandReports
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
