import Darwin
import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var ptyFlow: TestFlow {
        TestFlow(
            "pty",
            tags: [
                "process",
                "pty",
                "regression",
            ]
        ) {
            Step("child standard streams are attached to a terminal") {
                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "test -t 0 && test -t 1 && test -t 2",
                    ]
                )

                try Expect.equal(
                    result.exitCode,
                    Int32(0),
                    "stdin stdout and stderr are TTY-backed"
                )
            }

            Step("merge stdout and stderr into terminal transcript") {
                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "printf 'stdout-data'; printf 'stderr-data' >&2",
                    ]
                )

                let transcript = String(
                    decoding: result.stdout,
                    as: UTF8.self
                )

                try Expect.true(
                    transcript.contains(
                        "stdout-data"
                    ),
                    "PTY transcript contains stdout"
                )

                try Expect.true(
                    transcript.contains(
                        "stderr-data"
                    ),
                    "PTY transcript contains stderr"
                )

                try Expect.equal(
                    result.stderr,
                    Data(),
                    "PTY compatibility result keeps stderr empty"
                )
            }

            Step("deliver merged chunks while preserving transcript") {
                let recorder = LockedDataRecorder()

                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "printf 'first'; printf 'second' >&2",
                    ],
                    onChunk: { data in
                        recorder.append(
                            data
                        )
                    }
                )

                try Expect.equal(
                    recorder.snapshot(),
                    result.stdout,
                    "chunk callback observes the complete merged transcript"
                )
            }

            Step("apply working directory") {
                let directory = FileManager
                    .default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "interfaces-pty-\(UUID().uuidString)",
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

                let result = try runPTY(
                    "/bin/pwd",
                    [],
                    cwd: directory
                )

                let reportedDirectory = URL(
                    fileURLWithPath: String(
                        decoding: result.stdout,
                        as: UTF8.self
                    )
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
                    "PTY working directory is applied"
                )
            }

            Step("apply supplied environment") {
                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "printf '%s' \"$INTERFACES_PTY_VALUE\"",
                    ],
                    env: [
                        "INTERFACES_PTY_VALUE": "isolated",
                    ]
                )

                try Expect.equal(
                    String(
                        decoding: result.stdout,
                        as: UTF8.self
                    ),
                    "isolated",
                    "PTY supplied environment reaches child"
                )
            }

            Step("preserve ordinary exit code") {
                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "exit 7",
                    ]
                )

                try Expect.equal(
                    result.exitCode,
                    Int32(7),
                    "PTY ordinary exit code is preserved"
                )
            }

            Step("preserve legacy signal exit encoding") {
                let result = try runPTY(
                    "/bin/sh",
                    [
                        "-c",
                        "kill -KILL $$",
                    ]
                )

                try Expect.equal(
                    result.exitCode,
                    Int32(
                        128 + SIGKILL
                    ),
                    "PTY signal death remains encoded as 128 plus signal"
                )
            }
        }
    }
}
