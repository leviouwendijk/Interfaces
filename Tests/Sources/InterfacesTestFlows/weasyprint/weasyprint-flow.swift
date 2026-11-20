import Foundation
import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var weasyPrintFlow: TestFlow {
        TestFlow(
            "weasyprint",
            tags: [
                "pdf",
                "process",
                "regression",
                "weasyprint",
            ]
        ) {
            Step("invoke renderer with expected paths") {
                let fixture = try WeasyPrintFixture(
                    script: """
                    #!/bin/sh
                    printf 'rendered' > "$2"
                    """
                )

                defer {
                    fixture.remove()
                }

                let renderer = WeasyPrintRenderer(
                    weasyBinaryPath:
                        fixture.executable.path
                )

                try await renderer.pdf(
                    html: fixture.html,
                    css: fixture.css,
                    destination:
                        fixture.destination.path
                )

                let rendered = try String(
                    contentsOf:
                        fixture.destination,
                    encoding: .utf8
                )

                try Expect.equal(
                    rendered,
                    "rendered",
                    "renderer passes destination as second argument"
                )
            }

            Step("nonzero renderer exit retains process output") {
                let fixture = try WeasyPrintFixture(
                    script: """
                    #!/bin/sh
                    printf 'fixture stdout'
                    printf 'fixture stderr' >&2
                    exit 7
                    """
                )

                defer {
                    fixture.remove()
                }

                let renderer = WeasyPrintRenderer(
                    weasyBinaryPath:
                        fixture.executable.path
                )

                do {
                    try await renderer.pdf(
                        html: fixture.html,
                        css: fixture.css,
                        destination:
                            fixture.destination.path
                    )

                    throw TestFlowAssertionFailure(
                        label:
                            "weasyprint.nonzero",
                        message:
                            "expected process failure",
                        actual:
                            "success",
                        expected:
                            "PDFGenerationError.processFailed"
                    )
                } catch let error as PDFGenerationError {
                    switch error {
                    case .processFailed(
                        let code,
                        let output
                    ):
                        try Expect.equal(
                            code,
                            7,
                            "renderer preserves exit code"
                        )

                        try Expect.contains(
                            output,
                            "fixture stdout",
                            "renderer preserves stdout"
                        )

                        try Expect.contains(
                            output,
                            "fixture stderr",
                            "renderer preserves stderr"
                        )

                    default:
                        throw error
                    }
                }
            }

            Step("missing executable remains launch failure") {
                let fixture = try WeasyPrintFixture(
                    script: """
                    #!/bin/sh
                    exit 0
                    """
                )

                defer {
                    fixture.remove()
                }

                let renderer = WeasyPrintRenderer(
                    weasyBinaryPath:
                        fixture.root
                        .appendingPathComponent(
                            "definitely-missing"
                        )
                        .path
                )

                do {
                    try await renderer.pdf(
                        html: fixture.html,
                        css: fixture.css,
                        destination:
                            fixture.destination.path
                    )

                    throw TestFlowAssertionFailure(
                        label:
                            "weasyprint.launch",
                        message:
                            "expected launch failure",
                        actual:
                            "success",
                        expected:
                            "PDFGenerationError.cannotRunProcess"
                    )
                } catch let error as PDFGenerationError {
                    switch error {
                    case .cannotRunProcess:
                        break

                    default:
                        throw error
                    }
                }
            }
        }
    }
}

private struct WeasyPrintFixture {
    let root: URL
    let executable: URL
    let html: URL
    let css: URL
    let destination: URL

    init(
        script: String
    ) throws {
        root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "interfaces-weasyprint-\(UUID().uuidString)",
                isDirectory: true
            )

        executable = root
            .appendingPathComponent(
                "fake-weasyprint"
            )

        html = root
            .appendingPathComponent(
                "input.html"
            )

        css = root
            .appendingPathComponent(
                "input.css"
            )

        destination = root
            .appendingPathComponent(
                "output.pdf"
            )

        try FileManager.default
            .createDirectory(
                at: root,
                withIntermediateDirectories: true
            )

        try script.write(
            to: executable,
            atomically: true,
            encoding: .utf8
        )

        try FileManager.default
            .setAttributes(
                [
                    .posixPermissions:
                        0o755,
                ],
                ofItemAtPath:
                    executable.path
            )

        try "<html></html>".write(
            to: html,
            atomically: true,
            encoding: .utf8
        )

        try "body {}".write(
            to: css,
            atomically: true,
            encoding: .utf8
        )
    }

    func remove() {
        try? FileManager.default
            .removeItem(
                at: root
            )
    }
}
