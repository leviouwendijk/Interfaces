import Foundation
import Processes

public enum OSAScriptError:
    Error,
    LocalizedError,
    Sendable
{
    case exited(
        code: Int32,
        stderr: String
    )

    case signaled(
        signal: Int32,
        stderr: String
    )

    public var errorDescription: String? {
        switch self {
        case .exited(
            let code,
            let stderr
        ):
            return processFailureDescription(
                reason: "exited with status \(code)",
                stderr: stderr
            )

        case .signaled(
            let signal,
            let stderr
        ):
            return processFailureDescription(
                reason: "terminated by signal \(signal)",
                stderr: stderr
            )
        }
    }

    private func processFailureDescription(
        reason: String,
        stderr: String
    ) -> String {
        let detail = stderr
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !detail.isEmpty else {
            return "osascript \(reason)."
        }

        return "osascript \(reason): \(detail)"
    }
}

public func osaScriptApplicationActivate(
    _ application: String
) -> String {
    """
    tell application "\(application)"
        activate
    end tell
    """
}

public func runOsascriptProcess(
    _ script: String
) async throws {
    let result = try await ProcessRunner().run(
        .init(
            executable: .path(
                "/usr/bin/osascript"
            ),
            arguments: [
                "-e",
                script,
            ],
            outputLimit: .max
        )
    )

    switch result.exit {
    case .exited(0):
        return

    case .exited(
        let code
    ):
        throw OSAScriptError.exited(
            code: code,
            stderr: result.stderrText
        )

    case .signaled(
        let signal
    ):
        throw OSAScriptError.signaled(
            signal: signal,
            stderr: result.stderrText
        )
    }
}
