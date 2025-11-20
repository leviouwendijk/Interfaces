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
        public var shellOptions: [String]

        public init(
            target: Target,
            line: String,
            requiresSudo: Bool = false,
            shell: String = "sh",
            shellOptions: [String] = ["-lc"]
        ) {
            self.target = target
            self.line = line
            self.requiresSudo = requiresSudo
            self.shell = shell
            self.shellOptions = shellOptions
        }

        public static func local(
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false,
            shell: String = "sh",
            shellOptions: [String] = ["-lc"]
        ) -> Hook {
            .init(
                target: .local(cwd: cwd),
                line: line,
                requiresSudo: requiresSudo,
                shell: shell,
                shellOptions: shellOptions
            )
        }

        public static func remote(
            _ host: String,
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false,
            shell: String = "sh",
            shellOptions: [String] = ["-lc"]
        ) -> Hook {
            .init(
                target: .remote(host: host, cwd: cwd),
                line: line,
                requiresSudo: requiresSudo,
                shell: shell,
                shellOptions: shellOptions
            )
        }
    }
}

extension RSynchronizer {
    public static func hookCommand(_ hook: Hook) -> Command {
        func makeShellCommand(shell: String, options: [String], line: String) -> [String] {
            var args: [String] = ["/usr/bin/env", shell]
            args.append(contentsOf: options)
            args.append(line)
            return args
        }

        switch hook.target {
        case let .local(cwd):
            var localLine = hook.requiresSudo ? "sudo \(hook.line)" : hook.line

            if let cwd, !cwd.isEmpty {
                localLine = "cd \(cwd) && \(localLine)"
            }

            return Command(arguments: makeShellCommand(
                shell: hook.shell,
                options: hook.shellOptions,
                line: localLine
            ))

        case let .remote(host, cwd):
            var remoteLine = hook.requiresSudo ? "sudo \(hook.line)" : hook.line

            if let cwd, !cwd.isEmpty {
                remoteLine = "cd \(cwd) && \(remoteLine)"
            }

            var args: [String] = ["ssh", host]
            args.append(contentsOf: makeShellCommand(
                shell: hook.shell,
                options: hook.shellOptions,
                line: remoteLine
            ))

            return Command(arguments: args)
        }
    }
}
