extension RSynchronizer {
    public struct Hook: Sendable, Hashable {
        public enum Target: Sendable, Hashable {
            case local(cwd: String? = nil)
            case remote(host: String, cwd: String? = nil)
        }

        public var target: Target
        public var line: String
        public var requiresSudo: Bool

        public init(
            target: Target,
            line: String,
            requiresSudo: Bool = false
        ) {
            self.target = target
            self.line = line
            self.requiresSudo = requiresSudo
        }

        public static func local(
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false
        ) -> Hook {
            .init(target: .local(cwd: cwd), line: line, requiresSudo: requiresSudo)
        }

        public static func remote(
            _ host: String,
            _ line: String,
            cwd: String? = nil,
            requiresSudo: Bool = false
        ) -> Hook {
            .init(target: .remote(host: host, cwd: cwd), line: line, requiresSudo: requiresSudo)
        }
    }
}

extension RSynchronizer {
    public static func hookCommand(_ hook: Hook) -> Command {
        switch hook.target {
        case let .local(cwd):
            var localLine = hook.requiresSudo ? "sudo \(hook.line)" : hook.line
            if let cwd, !cwd.isEmpty {
                localLine = "cd \(cwd) && \(localLine)"
            }

            return Command(arguments: [
                "sh",
                "-lc",
                localLine
            ])

        case let .remote(host, cwd):
            var remoteLine = hook.line
            if hook.requiresSudo {
                remoteLine = "sudo \(remoteLine)"
            }
            if let cwd, !cwd.isEmpty {
                remoteLine = "cd \(cwd) && \(remoteLine)"
            }

            return Command(arguments: [
                "ssh",
                host,
                "sh",
                "-lc",
                remoteLine
            ])
        }
    }
}
