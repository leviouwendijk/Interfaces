import ANSI
import Foundation
import Interfaces

actor GitManagerFetchProgressRenderer {
    private let enabled: Bool
    private var started = false
    private var fetched = 0
    private var skipped = 0

    init(
        enabled: Bool
    ) {
        self.enabled = enabled
    }

    func begin(
        count: Int
    ) {
        guard enabled else {
            return
        }

        started = true

        write(
            ""
        )

        write(
            "fetch".ansi(
                .bold,
                .brightWhite
            )
        )

        write(
            "  repositories \(count)".ansi(.brightBlack)
        )
    }

    func fetching(
        _ target: GitManagerRepositoryInspectionTarget
    ) {
        guard enabled else {
            return
        }

        ensureStarted()

        write(
            "  fetching \(target.displayName)".ansi(.brightBlack)
        )
    }

    func fetched(
        _ target: GitManagerRepositoryInspectionTarget
    ) {
        guard enabled else {
            return
        }

        fetched += 1

        write(
            "  fetched  \(target.displayName)".ansi(.brightBlack)
        )
    }

    func skipped(
        _ target: GitManagerRepositoryInspectionTarget,
        reason: String
    ) {
        guard enabled else {
            return
        }

        skipped += 1

        write(
            "  skipped  \(target.displayName) \(reason)".ansi(.brightBlack)
        )
    }

    func end() {
        guard enabled else {
            return
        }

        write(
            "  done     fetched \(fetched), skipped \(skipped)".ansi(.brightBlack)
        )
    }

    private func ensureStarted() {
        guard !started else {
            return
        }

        started = true

        write(
            ""
        )

        write(
            "fetch".ansi(
                .bold,
                .brightWhite
            )
        )
    }

    private func write(
        _ line: String
    ) {
        FileHandle.standardError.write(
            Data(
                (line + "\n").utf8
            )
        )
    }
}
