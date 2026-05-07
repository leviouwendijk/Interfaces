import Foundation
import plate

public enum GitRepo {
    @discardableResult
    public static func git(
        _ cwd: URL,
        _ args: [String]
    ) async throws -> (code: Int32, out: String, err: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: "/usr/bin/env"
            )
            process.arguments = [
                "git",
            ] + args
            process.currentDirectoryURL = cwd

            let stdout = Pipe()
            let stderr = Pipe()

            process.standardOutput = stdout
            process.standardError = stderr

            do {
                try process.run()
            } catch {
                continuation.resume(
                    throwing: error
                )

                return
            }

            let group = DispatchGroup()

            final class Box: @unchecked Sendable {
                var stdout = Data()
                var stderr = Data()
            }

            let box = Box()

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                box.stdout = stdout.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                box.stderr = stderr.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {
                process.waitUntilExit()
                group.leave()
            }

            group.notify(
                queue: DispatchQueue.global(
                    qos: .userInitiated
                )
            ) {
                let out = String(
                    data: box.stdout,
                    encoding: .utf8
                ) ?? ""

                let err = String(
                    data: box.stderr,
                    encoding: .utf8
                ) ?? ""

                continuation.resume(
                    returning: (
                        Int32(
                            process.terminationStatus
                        ),
                        out,
                        err
                    )
                )
            }
        }
    }

    public static func gitOut(
        _ cwd: URL,
        _ args: [String]
    ) async throws -> String {
        let (code, out, err) = try await git(
            cwd,
            args
        )

        guard code == 0 else {
            throw RemoteError.processFailed(
                code,
                err
            )
        }

        return out
    }
}

// public enum GitRepo {
//     @discardableResult
//     public static func git(_ cwd: URL, _ args: [String]) async throws -> (code: Int32, out: String, err: String) {
//         let res = try await sh(.zsh, "git", args, cwd: cwd)
//         let out = res.stdoutText()
//         let err = res.stderrText()
//         return (Int32(res.exitCode ?? 0), out, err)
//     }

//     public static func gitOut(_ cwd: URL, _ args: [String]) async throws -> String {
//         let (code, out, err) = try await git(cwd, args)
//         guard code == 0 else { throw RemoteError.processFailed(code, err) }
//         return out
//     }
// }
