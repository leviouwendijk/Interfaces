import Foundation
import Difference

extension RSynchronizer {
    public enum Diff {
        public struct Options: Sendable {
            public var kinds: Set<Preflight.Kind>
            public var paths: Set<String>
            public var limit: Int?
            public var maximumBytes: Int
            public var allowRemote: Bool
            public var shell: Shell
            public var timeout: TimeInterval?

            public init(
                kinds: Set<Preflight.Kind> = [
                    .created,
                    .transfer,
                    .deleted,
                ],
                paths: Set<String> = [],
                limit: Int? = 10,
                maximumBytes: Int = 512_000,
                allowRemote: Bool = true,
                shell: Shell = .init(.path("/usr/bin/env")),
                timeout: TimeInterval? = 30
            ) {
                self.kinds = kinds
                self.paths = paths
                self.limit = limit
                self.maximumBytes = maximumBytes
                self.allowRemote = allowRemote
                self.shell = shell
                self.timeout = timeout
            }
        }

        public struct Snapshot: Sendable, Hashable {
            public var endpoint: Endpoint
            public var data: Data
            public var text: String
            public var name: String

            public init(
                endpoint: Endpoint,
                data: Data,
                text: String,
                name: String
            ) {
                self.endpoint = endpoint
                self.data = data
                self.text = text
                self.name = name
            }

            public static func empty(
                endpoint: Endpoint,
                name: String
            ) -> Self {
                .init(
                    endpoint: endpoint,
                    data: Data(),
                    text: "",
                    name: name
                )
            }
        }

        public struct Change: Sendable {
            public var commandIndex: Int
            public var entry: Plan.Entry
            public var item: Preflight.Item
            public var old: Snapshot
            public var new: Snapshot
            public var difference: TextDifference

            public init(
                commandIndex: Int,
                entry: Plan.Entry,
                item: Preflight.Item,
                old: Snapshot,
                new: Snapshot,
                difference: TextDifference
            ) {
                self.commandIndex = commandIndex
                self.entry = entry
                self.item = item
                self.old = old
                self.new = new
                self.difference = difference
            }
        }

        public enum Error: Swift.Error, LocalizedError, Sendable {
            case missingInvocation(command: Command)
            case unsupportedItem(Preflight.Item)
            case remoteDisabled(Endpoint)
            case nonText(Endpoint)
            case tooLarge(endpoint: Endpoint, bytes: Int, maximumBytes: Int)
            case commandFailed(endpoint: Endpoint, exitCode: Int, stderr: String)

            public var errorDescription: String? {
                switch self {
                case .missingInvocation:
                    return "Cannot diff preflight item because its typed rsync invocation is missing."

                case .unsupportedItem(let item):
                    return "Cannot diff preflight item '\(item.path)'."

                case .remoteDisabled(let endpoint):
                    return "Remote snapshot reading is disabled for '\(endpoint.argument)'."

                case .nonText(let endpoint):
                    return "Snapshot '\(endpoint.argument)' is not valid UTF-8 text."

                case .tooLarge(let endpoint, let bytes, let maximumBytes):
                    return "Snapshot '\(endpoint.argument)' is too large to diff: \(bytes) bytes exceeds \(maximumBytes) bytes."

                case .commandFailed(let endpoint, let exitCode, let stderr):
                    return "Could not read snapshot '\(endpoint.argument)' over SSH. Exit \(exitCode). \(stderr)"
                }
            }
        }

        public static func changes(
            from report: Preflight.Report,
            options: Options = .init()
        ) async throws -> [Change] {
            var changes: [Change] = []

            for command in report.commands {
                for item in command.items {
                    guard
                        includes(
                            item,
                            options: options
                        )
                    else {
                        continue
                    }

                    do {
                        let change = try await change(
                            command: command,
                            item: item,
                            options: options
                        )

                        guard change.difference.hasChanges else {
                            continue
                        }

                        changes.append(
                            change
                        )

                        if let limit = options.limit,
                            changes.count >= limit
                        {
                            return changes
                        }
                    } catch let error as RSynchronizer.Diff.Error {
                        switch error {
                        case .missingInvocation:
                            throw error

                        case .unsupportedItem,
                            .remoteDisabled,
                            .nonText,
                            .tooLarge,
                            .commandFailed:
                            continue
                        }
                    }
                }
            }

            return changes
        }
    }
}

private extension RSynchronizer.Diff {
    struct Pair: Sendable, Hashable {
        var old: RSynchronizer.Endpoint
        var new: RSynchronizer.Endpoint
    }

    static func change(
        command: RSynchronizer.Preflight.CommandReport,
        item: RSynchronizer.Preflight.Item,
        options: Options
    ) async throws -> Change {
        let pair = try endpoints(
            for: item,
            entry: command.entry
        )

        let readsDestinationWithSudo = command.entry.invocation?.privilege == .sudo

        let old: Snapshot
        let new: Snapshot

        switch item.kind {
        case .created:
            old = .empty(
                endpoint: pair.old,
                name: pair.old.argument
            )

            new = try await read(
                pair.new,
                options: options,
                sudo: false
            )

        case .transfer:
            old = try await read(
                pair.old,
                options: options,
                sudo: readsDestinationWithSudo
            )

            new = try await read(
                pair.new,
                options: options,
                sudo: false
            )

        case .deleted:
            old = try await read(
                pair.old,
                options: options,
                sudo: readsDestinationWithSudo
            )

            new = .empty(
                endpoint: pair.new,
                name: pair.new.argument
            )

        case .metadata,
             .other:
            throw Error.unsupportedItem(
                item
            )
        }

        let difference = TextDiffer.diff(
            old: old.text,
            new: new.text,
            oldName: old.name,
            newName: new.name
        )

        return Change(
            commandIndex: command.index,
            entry: command.entry,
            item: item,
            old: old,
            new: new,
            difference: difference
        )
    }

    static func includes(
        _ item: RSynchronizer.Preflight.Item,
        options: Options
    ) -> Bool {
        guard
            options.kinds.contains(
                item.kind
            )
        else {
            return false
        }

        guard item.fileKind == .file else {
            return false
        }

        guard !options.paths.isEmpty else {
            return true
        }

        return options.paths.contains(
            item.path
        )
            || options.paths.contains {
                item.path.hasSuffix(
                    $0
                )
            }
    }

    static func endpoints(
        for item: RSynchronizer.Preflight.Item,
        entry: RSynchronizer.Plan.Entry
    ) throws -> Pair {
        guard let invocation = entry.invocation else {
            throw Error.missingInvocation(
                command: entry.command
            )
        }

        return Pair(
            old: destinationEndpoint(
                invocation: invocation,
                item: item
            ),
            new: sourceEndpoint(
                invocation: invocation,
                item: item
            )
        )
    }

    static func sourceEndpoint(
        invocation: RSynchronizer.Invocation,
        item: RSynchronizer.Preflight.Item
    ) -> RSynchronizer.Endpoint {
        let sourcePath = invocation.source.path
        let itemPath = item.path
        let sourceName = lastComponent(
            sourcePath
        )

        if sourcePath.hasSuffix("/") {
            return invocation.source.with(
                path: join(
                    sourcePath,
                    itemPath
                )
            )
        }

        if itemPath == sourceName {
            return invocation.source
        }

        let base = parent(
            sourcePath
        )

        return invocation.source.with(
            path: join(
                base,
                itemPath
            )
        )
    }

    static func destinationEndpoint(
        invocation: RSynchronizer.Invocation,
        item: RSynchronizer.Preflight.Item
    ) -> RSynchronizer.Endpoint {
        let destinationPath = invocation.destination.path
        let sourcePath = invocation.source.path
        let itemPath = item.path
        let sourceName = lastComponent(
            sourcePath
        )

        if !destinationPath.hasSuffix("/"),
           itemPath == sourceName {
            return invocation.destination
        }

        return invocation.destination.with(
            path: join(
                destinationPath,
                itemPath
            )
        )
    }

    static func read(
        _ endpoint: RSynchronizer.Endpoint,
        options: Options,
        sudo: Bool
    ) async throws -> Snapshot {
        switch endpoint {
        case .local(let path):
            return try readLocal(
                path: path,
                endpoint: endpoint,
                options: options
            )

        case .remote:
            guard options.allowRemote else {
                throw Error.remoteDisabled(
                    endpoint
                )
            }

            return try await readRemote(
                endpoint,
                options: options,
                sudo: sudo
            )
        }
    }

    static func readLocal(
        path: String,
        endpoint: RSynchronizer.Endpoint,
        options: Options
    ) throws -> Snapshot {
        let expanded = NSString(
            string: path
        )
        .expandingTildeInPath

        let data = try Data(
            contentsOf: URL(
                fileURLWithPath: expanded
            )
        )

        return try snapshot(
            endpoint: endpoint.with(
                path: expanded
            ),
            data: data,
            options: options
        )
    }

    static func readRemote(
        _ endpoint: RSynchronizer.Endpoint,
        options: Options,
        sudo: Bool
    ) async throws -> Snapshot {
        guard case .remote(let host, let path) = endpoint else {
            fatalError(
                "readRemote received a local endpoint."
            )
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "rsynchronizer-diff-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let file = directory.appendingPathComponent(
            "snapshot"
        )

        var arguments = [
            "rsync",
            "-a",
        ]

        if sudo {
            arguments.append(
                "--rsync-path=sudo rsync"
            )
        }

        arguments.append(
            "\(host):\(path)"
        )

        arguments.append(
            file.path
        )

        var shellOptions = Shell.Options()
        shellOptions.timeout = options.timeout

        let result = try await options.shell.run(
            "/usr/bin/env",
            arguments,
            options: shellOptions
        )

        if let code = exitCode(
            from: result
        ),
            code != 0
        {
            throw Error.commandFailed(
                endpoint: endpoint,
                exitCode: code,
                stderr: result.stderrText()
            )
        }

        let data = try Data(
            contentsOf: file
        )

        return try snapshot(
            endpoint: endpoint,
            data: data,
            options: options
        )
    }

    static func snapshot(
        endpoint: RSynchronizer.Endpoint,
        data: Data,
        options: Options
    ) throws -> Snapshot {
        guard data.count <= options.maximumBytes else {
            throw Error.tooLarge(
                endpoint: endpoint,
                bytes: data.count,
                maximumBytes: options.maximumBytes
            )
        }

        guard !data.contains(0) else {
            throw Error.nonText(
                endpoint
            )
        }

        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw Error.nonText(
                endpoint
            )
        }

        return Snapshot(
            endpoint: endpoint,
            data: data,
            text: text,
            name: endpoint.argument
        )
    }

    static func parent(
        _ path: String
    ) -> String {
        let parent = NSString(
            string: path
        )
        .deletingLastPathComponent

        if parent == "." {
            return ""
        }

        return parent
    }

    static func lastComponent(
        _ path: String
    ) -> String {
        NSString(
            string: path
        )
        .lastPathComponent
    }

    static func join(
        _ base: String,
        _ child: String
    ) -> String {
        guard !base.isEmpty else {
            return child
        }

        if base.hasSuffix("/") {
            return base + child
        }

        return base + "/" + child
    }

    static func remoteArgument(
        _ path: String
    ) -> String {
        if path == "~" {
            return "$HOME"
        }

        if path.hasPrefix("~/") {
            return "$HOME/" + singleQuoted(
                String(
                    path.dropFirst(2)
                )
            )
        }

        return singleQuoted(
            path
        )
    }

    static func singleQuoted(
        _ value: String
    ) -> String {
        "'" + value.replacingOccurrences(
            of: "'",
            with: "'\"'\"'"
        ) + "'"
    }

    static func exitCode(
        from result: Shell.Result
    ) -> Int? {
        if case .exited(let code) = result.status {
            return Int(
                code
            )
        }

        return nil
    }
}

private extension RSynchronizer.Endpoint {
    var path: String {
        switch self {
        case .local(let path):
            return path

        case .remote(_, let path):
            return path
        }
    }

    func with(
        path: String
    ) -> Self {
        switch self {
        case .local:
            return .local(
                path
            )

        case .remote(let host, _):
            return .remote(
                host: host,
                path: path
            )
        }
    }
}
