import Arguments
import Foundation
import Interfaces
import Version

enum CommitCommand: RunnableArgumentCommand {
    static let name = "commit"
    static let aliases = [
        "c",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Add, commit, and optionally push."),
            arg(
                "message",
                as: String.self,
                arity: .variadic,
                help: "Commit message."
            ),
            flag(
                "push",
                help: "Push after committing."
            ),
            opt(
                "release",
                as: String.self,
                help: "Tag the new commit as a release (major | minor | patch | x.y.z) and push the branch and the tag together. Implies --push."
            ),
        ] + GitManagerCLI.stagingComponents() + [
            example(
                "gm commit update git manager --push",
                description: "Commit and push."
            ),
            example(
                "gm commit -o Sources/gm -o Package.swift fix staging --push",
                description: "Stage and commit only the given paths."
            ),
            example(
                "gm commit fix renewal --release patch",
                description: "Commit, tag the next patch release, push both atomically."
            ),
            example(
                "gm commit -x compiled.pkl regenerate specs",
                description: "Stage everything except the given path."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let message = try GitManagerCLI.message(
            from: invocation
        )

        let release = try invocation.value(
            "release",
            as: String.self
        )
        .map { text in
            let text = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard let target = ReleaseTarget(text) else {
                throw GitManagerError.invalidRelease(text)
            }
            return target
        }

        let push = try invocation.flag(
            "push"
        ) || release != nil

        let staging = try GitManagerCLI.staging(
            from: invocation
        )

        GitManagerCLI.renderStaging(
            staging
        )

        GitManagerRenderer.command(
            "git commit -m \"\(message)\""
        )

        if release != nil {
            GitManagerRenderer.command(
                "git tag -a <release> && git push --atomic -u <default-remote> <default-branch> <release>"
            )
        } else if push {
            GitManagerRenderer.command(
                "git push -u <default-remote> <default-branch>"
            )
        }

        let outputs = try await GitManagerAction.commit(
            message: message,
            staging: staging,
            push: push,
            release: release,
            at: GitManagerCLI.currentDirectory
        )

        for output in outputs {
            GitManagerRenderer.output(
                output
            )
        }

        if release != nil, let version = try await GitRepo.latestRelease(
            at: GitManagerCLI.currentDirectory
        ) {
            GitManagerRenderer.success(
                "Committed, released \(ReleaseTag.name(for: version)) and pushed both."
            )
        } else {
            GitManagerRenderer.success(
                push ? "Committed and pushed." : "Committed."
            )
        }
    }
}
