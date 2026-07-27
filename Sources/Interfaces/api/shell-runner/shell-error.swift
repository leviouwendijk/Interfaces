import Foundation
import plate

public extension Shell {
    enum Error:
        Swift.Error,
        Sendable,
        LocalizedError,
        CustomStringConvertible,
        CustomDebugStringConvertible,
        PrettyError
    {
        case launchFailure(String)

        case timedOut(
            after: TimeInterval,
            pid: pid_t
        )

        case nonZeroExit(
            code: Int,
            stdoutPreview: String,
            stderrPreview: String,
            result: Result,
            context: RunContext
        )

        public var errorDescription: String? {
            switch self {
            case .launchFailure(let message):
                return """
                Shell command could not be launched.
                  reason: \(Self.clean(message))
                """

            case .timedOut(let duration, let pid):
                return """
                Shell command timed out.
                  timeout: \(duration.formattedDuration)
                  process: \(pid)
                """

            case .nonZeroExit(
                let code,
                let stdoutPreview,
                let stderrPreview,
                _,
                let context
            ):
                var lines = [
                    "Shell command failed.",
                    "  exit code: \(code)",
                    "  command:   \(context.commandLine)",
                ]

                if let cwd = context.cwd {
                    lines.append(
                        "  directory: \(cwd)"
                    )
                }

                let output = Self.preferredOutput(
                    stdout: stdoutPreview,
                    stderr: stderrPreview
                )

                if !output.isEmpty {
                    lines.append(
                        "  output:"
                    )

                    lines.append(
                        contentsOf: Self.indentedLines(
                            output,
                            indentation: "    "
                        )
                    )
                }

                return lines.joined(
                    separator: "\n"
                )
            }
        }

        public var description: String {
            errorDescription ?? "Shell command failed."
        }

        public var debugDescription: String {
            description
        }

        public func formatted() -> String {
            switch self {
            case .launchFailure, .timedOut:
                return description

            case .nonZeroExit(
                let code,
                _,
                _,
                let result,
                let context
            ):
                var sections = [
                    "Shell command failed.",
                    "",
                    "Execution",
                    "  exit code: \(code)",
                    "  process:   \(context.pid)",
                    "  duration:  \(result.duration.formattedDuration)",
                    "  command:   \(context.commandLine)",
                ]

                if let cwd = context.cwd {
                    sections.append(
                        "  directory: \(cwd)"
                    )
                }

                Self.appendOutput(
                    title: "Standard error",
                    value: result.stderrText(),
                    to: &sections
                )

                Self.appendOutput(
                    title: "Standard output",
                    value: result.stdoutText(),
                    to: &sections
                )

                return sections.joined(
                    separator: "\n"
                )
            }
        }
    }
}

private extension Shell.Error {
    static func preferredOutput(
        stdout: String,
        stderr: String
    ) -> String {
        let cleanedStderr = clean(
            stderr
        )

        if !cleanedStderr.isEmpty {
            return cleanedStderr
        }

        return clean(
            stdout
        )
    }

    static func appendOutput(
        title: String,
        value: String,
        to sections: inout [String],
        maximumBytes: Int = 4_000
    ) {
        let output = clamp(
            clean(value),
            maximumBytes: maximumBytes
        )

        guard !output.isEmpty else {
            return
        }

        sections.append(
            ""
        )

        sections.append(
            title
        )

        sections.append(
            contentsOf: indentedLines(
                output,
                indentation: "  "
            )
        )
    }

    static func indentedLines(
        _ value: String,
        indentation: String
    ) -> [String] {
        value
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map {
                indentation + String($0)
            }
    }

    static func clean(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    static func clamp(
        _ value: String,
        maximumBytes: Int
    ) -> String {
        guard value.utf8.count > maximumBytes else {
            return value
        }

        var byteCount = 0
        var end = value.startIndex

        while end < value.endIndex {
            let next = value.index(
                after: end
            )

            let bytes = value[end..<next].utf8.count

            guard byteCount + bytes <= maximumBytes else {
                break
            }

            byteCount += bytes
            end = next
        }

        return String(
            value[..<end]
        ) + "\n… output truncated"
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        if self < 1 {
            return "\(Int((self * 1_000).rounded()))ms"
        }

        return String(
            format: "%.2fs",
            self
        )
    }
}

// public extension Shell {
//     enum Error: Swift.Error, Sendable, LocalizedError {
//         case launchFailure(String)
//         case timedOut(after: TimeInterval, pid: pid_t)
//         case nonZeroExit(
//             code: Int,
//             stdoutPreview: String,
//             stderrPreview: String,
//             result: Result,
//             context: RunContext
//         )

//         public var errorDescription: String? {
//             switch self {
//             case .launchFailure(let m):
//                 return "Shell launch failure: \(m)"
//             case .timedOut(let t, let pid):
//                 return "Shell timeout after \(t)s (pid \(pid))."
//             case .nonZeroExit(let c, let outPrev, let errPrev, _, _):
//                 let body = errPrev.isEmpty ? outPrev : errPrev
//                 return "Shell exited with code \(c). Output: \(body)"
//             }
//         }

//         public func pretty(maxPreviewBytes: Int = 4000) -> String {
//             switch self {
//             case .launchFailure, .timedOut:
//                 return self.errorDescription ?? String(describing: self)

//             case .nonZeroExit(let code, _, _, let result, let ctx):
//                 func clamp(_ s: String) -> String {
//                     if s.utf8.count <= maxPreviewBytes { return s }
//                     let end = s.index(s.startIndex, offsetBy: maxPreviewBytes, limitedBy: s.endIndex) ?? s.endIndex
//                     return String(s[..<end]) + "… [truncated]"
//                 }

//                 let kv = { (k: String, v: String) in "    \(k): \(v)\n" }
//                 var out = ""
//                 out += "✗ Exit code: \(code)\n"
//                 out += kv("PID", "\(ctx.pid)")
//                 out += kv("Duration", String(format: "%.3fs", ctx.duration))
//                 out += kv("Exec", "\(ctx.exec)")
//                 out += kv("CWD", ctx.cwd ?? "(nil)")
//                 out += kv("Inherit env", String(ctx.inheritEnvironment))
//                 out += kv("Timeout", ctx.timeout.map { "\($0)s" } ?? "(nil)")
//                 out += kv("Expected exit codes", ctx.expectedExitCodes.sorted().map(String.init).joined(separator: ","))
//                 out += kv("Tee stdout", String(ctx.teeToStdout))
//                 out += kv("Tee stderr", String(ctx.teeToStderr))
//                 out += kv("Redactions", ctx.redactions.isEmpty ? "(none)" : ctx.redactions.joined(separator: ","))
//                 out += "\n— Launcher & Args —\n"
//                 out += "  \(ctx.commandLine)\n"
//                 out += "\n— Environment (redacted values) —\n"
//                 if ctx.env.isEmpty {
//                     out += "  (empty)\n"
//                 } else {
//                     for key in ctx.env.keys.sorted() {
//                         // out += "  \(key)=\(ctx.env[key]!)\n"
//                         out += "  \(key)=<redacted>\n"
//                     }
//                 }
//                 out += "\n— Stdout —\n"
//                 out += clamp(result.stdoutText()) + "\n"
//                 out += "\n— Stderr —\n"
//                 out += clamp(result.stderrText()) + "\n"
//                 return out
//             }
//         }
//     }
// }
