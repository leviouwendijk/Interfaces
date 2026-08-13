import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var shellFlow: TestFlow {
        TestFlow(
            "shell",
            tags: [
                "process",
                "shell",
                "regression",
            ]
        ) {
            Step("collect stdout and stderr independently") {
                let result = try await Shell(
                    .path(
                        "/bin/sh"
                    )
                )
                .run(
                    "/bin/sh",
                    [
                        "-c",
                        "printf 'stdout-data'; printf 'stderr-data' >&2",
                    ]
                )

                try Expect.equal(
                    result.stdoutText(),
                    "stdout-data",
                    "stdout is collected independently"
                )

                try Expect.equal(
                    result.stderrText(),
                    "stderr-data",
                    "stderr is collected independently"
                )

                try Expect.equal(
                    result.exitCode ?? -1,
                    0,
                    "successful shell process exits zero"
                )
            }

            Step("send stdin") {
                var options = Shell.Options()
                options.stdin = Data(
                    "stdin-data".utf8
                )

                let result = try await Shell(
                    .path(
                        "/bin/cat"
                    )
                )
                .run(
                    "/bin/cat",
                    options: options
                )

                try Expect.equal(
                    result.stdoutText(),
                    "stdin-data",
                    "stdin reaches the child process"
                )
            }

            Step("apply working directory") {
                let directory = FileManager
                    .default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "interfaces-shell-\(UUID().uuidString)",
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

                var options = Shell.Options()
                options.cwd = directory

                let result = try await Shell(
                    .path(
                        "/bin/pwd"
                    )
                )
                .run(
                    "/bin/pwd",
                    options: options
                )

                let reportedDirectory = URL(
                    fileURLWithPath: result
                        .stdoutText()
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                )
                .resolvingSymlinksInPath()
                .standardizedFileURL

                let expectedDirectory = directory
                    .resolvingSymlinksInPath()
                    .standardizedFileURL

                try Expect.equal(
                    reportedDirectory.path,
                    expectedDirectory.path,
                    "working directory is applied"
                )
            }

            Step("apply isolated environment") {
                var options = Shell.Options()
                options.inheritEnvironment = false
                options.env = [
                    "INTERFACES_SHELL_VALUE": "isolated",
                ]

                let result = try await Shell(
                    .path(
                        "/usr/bin/env"
                    )
                )
                .run(
                    "/usr/bin/env",
                    options: options
                )

                try Expect.true(
                    result.stdoutText().contains(
                        "INTERFACES_SHELL_VALUE=isolated"
                    ),
                    "explicit environment reaches child"
                )

                try Expect.false(
                    result.stdoutText().contains(
                        "PATH="
                    ),
                    "isolated environment does not inherit PATH"
                )
            }

            Step("deliver chunk callbacks without consuming captured output") {
                let stdoutRecorder = LockedDataRecorder()
                let stderrRecorder = LockedDataRecorder()

                var options = Shell.Options()

                options.onStdoutChunk = { data in
                    stdoutRecorder.append(
                        data
                    )
                }

                options.onStderrChunk = { data in
                    stderrRecorder.append(
                        data
                    )
                }

                let result = try await Shell(
                    .path(
                        "/bin/sh"
                    )
                )
                .run(
                    "/bin/sh",
                    [
                        "-c",
                        "printf 'stdout-chunk'; printf 'stderr-chunk' >&2",
                    ],
                    options: options
                )

                try Expect.equal(
                    stdoutRecorder.snapshot(),
                    result.stdout,
                    "stdout callback observes collected stdout"
                )

                try Expect.equal(
                    stderrRecorder.snapshot(),
                    result.stderr,
                    "stderr callback observes collected stderr"
                )
            }

            Step("unexpected nonzero exit throws with retained result") {
                var observedCode: Int?
                var retainedStdout = ""
                var retainedStderr = ""

                do {
                    _ = try await Shell(
                        .path(
                            "/bin/sh"
                        )
                    )
                    .run(
                        "/bin/sh",
                        [
                            "-c",
                            "printf 'before-exit'; printf 'failure-data' >&2; exit 7",
                        ]
                    )
                } catch let error as Shell.Error {
                    switch error {
                    case .nonZeroExit(
                        let code,
                        _,
                        _,
                        let result,
                        _
                    ):
                        observedCode = code
                        retainedStdout = result.stdoutText()
                        retainedStderr = result.stderrText()

                    default:
                        throw error
                    }
                }

                try Expect.equal(
                    observedCode ?? -1,
                    7,
                    "unexpected exit code is retained in Shell.Error"
                )

                try Expect.equal(
                    retainedStdout,
                    "before-exit",
                    "stdout remains available on nonzero exit"
                )

                try Expect.equal(
                    retainedStderr,
                    "failure-data",
                    "stderr remains available on nonzero exit"
                )
            }

            Step("expected nonzero exit returns normally") {
                var options = Shell.Options()
                options.expectedExitCodes = [
                    0,
                    7,
                ]

                let result = try await Shell(
                    .path(
                        "/bin/sh"
                    )
                )
                .run(
                    "/bin/sh",
                    [
                        "-c",
                        "exit 7",
                    ],
                    options: options
                )

                try Expect.equal(
                    result.exitCode ?? -1,
                    7,
                    "configured nonzero exit is returned normally"
                )
            }
        }
    }
}
