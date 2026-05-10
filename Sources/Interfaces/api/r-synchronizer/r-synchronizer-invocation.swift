import Foundation

extension RSynchronizer {
    public enum Endpoint: Sendable, Hashable {
        case local(
            String
        )
        case remote(
            host: String,
            path: String
        )

        public var argument: String {
            switch self {
            case .local(let path):
                return Self.expand(
                    path
                )

            case .remote(let host, let path):
                return "\(host):\(path)"
            }
        }

        private static func expand(
            _ path: String
        ) -> String {
            NSString(
                string: path
            )
            .expandingTildeInPath
        }
    }

    public enum Delete: Sendable, Hashable {
        case keep
        case extraneous

        public var arguments: [String] {
            switch self {
            case .keep:
                return []

            case .extraneous:
                return [
                    "--delete",
                ]
            }
        }
    }

    public enum Privilege: Sendable, Hashable {
        case normal
        case sudo

        public var arguments: [String] {
            switch self {
            case .normal:
                return []

            case .sudo:
                return [
                    "--rsync-path=sudo rsync",
                ]
            }
        }
    }

    public struct Exclude: Sendable, Hashable {
        public var pattern: String

        public init(
            _ pattern: String
        ) {
            self.pattern = pattern
        }

        public var argument: String {
            "--exclude=\(pattern)"
        }
    }

    public enum Defaults {
        public static let exclude: [Exclude] = [
            .init(
                "compiled.pkl"
            ),
        ]
    }

    public struct PlanOptions: Sendable, Hashable {
        public var exclude: [Exclude]
        public var raw: [String]

        public init(
            exclude: [Exclude] = Defaults.exclude,
            raw: [String] = []
        ) {
            self.exclude = exclude
            self.raw = raw
        }
    }

    public struct Invocation: Sendable, Hashable {
        public struct Options: Sendable, Hashable {
            public var archive: Bool
            public var verbose: Bool
            public var compress: Bool
            public var progress: Bool

            public init(
                archive: Bool = true,
                verbose: Bool = true,
                compress: Bool = true,
                progress: Bool = true
            ) {
                self.archive = archive
                self.verbose = verbose
                self.compress = compress
                self.progress = progress
            }

            public var arguments: [String] {
                var result: [String] = []
                var short = "-"

                if archive {
                    short += "a"
                }

                if verbose {
                    short += "v"
                }

                if compress {
                    short += "z"
                }

                if short != "-" {
                    result.append(
                        short
                    )
                }

                if progress {
                    result.append(
                        "--progress"
                    )
                }

                return result
            }
        }

        public var source: Endpoint
        public var destination: Endpoint
        public var options: Options
        public var delete: Delete
        public var owner: String?
        public var exclude: [Exclude]
        public var privilege: Privilege
        public var raw: [String]

        public init(
            source: Endpoint,
            destination: Endpoint,
            options: Options = .init(),
            delete: Delete = .keep,
            owner: String? = nil,
            exclude: [Exclude] = [],
            privilege: Privilege = .normal,
            raw: [String] = []
        ) {
            self.source = source
            self.destination = destination
            self.options = options
            self.delete = delete
            self.owner = owner
            self.exclude = exclude
            self.privilege = privilege
            self.raw = raw
        }

        public func arguments(
            executable: String = "rsync"
        ) -> [String] {
            var result = [
                executable,
            ]

            result.append(
                contentsOf: options.arguments
            )

            result.append(
                contentsOf: delete.arguments
            )

            if let owner,
               !owner.isEmpty {
                result.append(
                    "--chown=\(owner)"
                )
            }

            for item in exclude {
                result.append(
                    item.argument
                )
            }

            result.append(
                contentsOf: privilege.arguments
            )

            result.append(
                contentsOf: raw
            )

            result.append(
                source.argument
            )

            result.append(
                destination.argument
            )

            return result
        }

        public func command(
            executable: String = "rsync"
        ) -> Command {
            Command(
                arguments: arguments(
                    executable: executable
                )
            )
        }
    }
}
