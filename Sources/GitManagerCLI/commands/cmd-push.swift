import Arguments
import Foundation
import Interfaces

enum PushCommand: RunnableArgumentCommand {
    static let name = "push"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Push to the default upstream, or to an explicit remote and branch."),
            arg(
                "remote",
                as: String.self,
                arity: .optional,
                help: "Remote to push to, for example origin."
            ),
            arg(
                "branch",
                as: String.self,
                arity: .optional,
                help: "Branch or ref to push, for example master, main, or HEAD."
            ),
            flag(
                "set-upstream",
                short: "u",
                help: "Set upstream while pushing. Explicit remote/branch pushes default to true."
            ),
            example(
                "gm push",
                description: "Push the current branch to its configured upstream."
            ),
            example(
                "gm push origin master",
                description: "Push master to origin and set upstream."
            ),
            example(
                "gm push origin HEAD",
                description: "Push the current HEAD to origin and set upstream."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let remote = try invocation.value(
            "remote",
            as: String.self
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let branch = try invocation.value(
            "branch",
            as: String.self
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let setUpstream = try invocation.flag(
            "set-upstream"
        )

        switch (
            remote?.isEmpty == false ? remote : nil,
            branch?.isEmpty == false ? branch : nil
        ) {
        case (.none, .none):
            GitManagerRenderer.command(
                "git push -u <default-remote> <default-branch>"
            )

            let output = try await GitManagerAction.push(
                at: GitManagerCLI.currentDirectory
            )

            GitManagerRenderer.output(
                output
            )

        case (.some, .none):
            throw GitManagerError.unsafeSync(
                "Push requires both remote and branch. Use `gm push origin HEAD` or `gm push origin master`."
            )

        case (.none, .some):
            throw GitManagerError.unsafeSync(
                "Push requires both remote and branch. Use `gm push origin HEAD` or `gm push origin master`."
            )

        case let (.some(remote), .some(branch)):
            let arguments = pushArguments(
                remote: remote,
                branch: branch,
                setUpstream: true || setUpstream
            )

            GitManagerRenderer.command(
                "git \(arguments.joined(separator: " "))"
            )

            let output = try await GitManagerAction.raw(
                arguments,
                at: GitManagerCLI.currentDirectory
            )

            GitManagerRenderer.output(
                output
            )
        }
    }
}

private extension PushCommand {
    static func pushArguments(
        remote: String,
        branch: String,
        setUpstream: Bool
    ) -> [String] {
        var arguments = [
            "push",
        ]

        if setUpstream {
            arguments.append(
                "-u"
            )
        }

        arguments.append(
            remote
        )

        arguments.append(
            branch
        )

        return arguments
    }
}
