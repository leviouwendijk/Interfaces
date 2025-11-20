extension RSynchronizer {
    public struct Hook: Sendable, Hashable {
        public enum Target: Sendable, Hashable {
            case local(cwd: String? = nil)
            case remote(host: String, cwd: String? = nil)
        }

        public var target: Target
        public var line: String
        public var requiresSudo: Bool

        public var shell: String

        public init(
            target: Target,
            line: String,
            requiresSudo: Bool = false,
            shell: String = "sh"
        ) {
            self.target = target
            self.line = line
            self.requiresSudo = requiresSudo
            self.shell = shell
        }

        public static func local(
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false,
            shell: String = "sh"
        ) -> Hook {
            .init(
                target: .local(cwd: cwd),
                line: line,
                requiresSudo: requiresSudo,
                shell: shell
            )
        }

        public static func remote(
            _ host: String,
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false,
            shell: String = "sh"
        ) -> Hook {
            .init(
                target: .remote(host: host, cwd: cwd),
                line: line,
                requiresSudo: requiresSudo,
                shell: shell
            )
        }
    }
}

extension RSynchronizer {
    public static func hookCommand(_ hook: Hook) -> Command {
        func makeShellCommand(shell: String, line: String) -> [String] {
            [
                "/usr/bin/env",
                shell,
                "-lc",
                line
            ]
        }

        switch hook.target {
        case let .local(cwd):
            var localLine = hook.requiresSudo ? "sudo \(hook.line)" : hook.line

            if let cwd, !cwd.isEmpty {
                localLine = "cd \(cwd) && \(localLine)"
            }

            return Command(arguments: makeShellCommand(shell: hook.shell, line: localLine))

        case let .remote(host, cwd):
            var remoteLine = hook.requiresSudo ? "sudo \(hook.line)" : hook.line

            if let cwd, !cwd.isEmpty {
                remoteLine = "cd \(cwd) && \(remoteLine)"
            }

            // ssh host "/usr/bin/env <shell> -lc '<remoteLine>'"
            var args: [String] = [
                "ssh",
                host
            ]
            args.append(contentsOf: [
                "/usr/bin/env",
                hook.shell,
                "-lc",
                remoteLine
            ])

            return Command(arguments: args)
        }
    }
}
