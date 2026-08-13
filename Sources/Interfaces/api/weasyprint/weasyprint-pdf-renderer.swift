import Foundation
import plate
import Processes

public protocol PDFRenderable:
    Sendable
{
    func pdf(
        html: URL,
        css: URL,
        destination: String
    ) async throws
}

public struct WeasyPrintRenderer:
    PDFRenderable,
    Sendable
{
    private let weasyBinaryPath: String

    public let encoding: String.Encoding

    public init(
        weasyBinaryPath: String = "/opt/homebrew/bin/weasyprint",
        encoding: String.Encoding = .utf8
    ) {
        self.weasyBinaryPath =
            weasyBinaryPath

        self.encoding =
            encoding
    }

    public func pdf(
        html: URL,
        css: URL,
        destination: String
    ) async throws {
        let fileManager =
            FileManager.default

        guard fileManager.fileExists(
            atPath: html.path
        ) else {
            throw PDFGenerationError.htmlFileMissing(
                html
            )
        }

        guard fileManager.fileExists(
            atPath: css.path
        ) else {
            throw PDFGenerationError.cssFileMissing(
                css
            )
        }

        let result: ProcessResult

        do {
            result = try await ProcessRunner().run(
                .init(
                    executable: .path(
                        weasyBinaryPath
                    ),
                    arguments: [
                        html.path,
                        destination,
                        "--stylesheet",
                        css.path,
                    ],
                    outputLimit: .max
                )
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PDFGenerationError.cannotRunProcess(
                underlying: error
            )
        }

        switch result.exit {
        case .exited(0):
            return

        case .exited(
            let code
        ):
            throw PDFGenerationError.processFailed(
                exitCode: code,
                output: processOutput(
                    result
                )
            )

        case .signaled(
            let signal
        ):
            throw PDFGenerationError.processFailed(
                exitCode: signal,
                output: processOutput(
                    result
                )
            )
        }
    }

    private func processOutput(
        _ result: ProcessResult
    ) -> String {
        let data =
            result.stdout
            + result.stderr

        return String(
            data: data,
            encoding: encoding
        ) ?? "<no output>"
    }
}

extension String {
    public func weasyPDF(
        css: CSSPageSetting = CSSPageSetting(),
        destination: String,
        encoding: String.Encoding = .utf8
    ) async throws {
        let htmlTemp = try self.tempFile(
            fileExtension: "html",
            encoding: encoding
        )

        let cssString =
            css.css()

        let cssTemp = try cssString.tempFile(
            fileExtension: "css"
        )

        let renderer = WeasyPrintRenderer(
            encoding: encoding
        )

        try await renderer.pdf(
            html: htmlTemp,
            css: cssTemp,
            destination: destination
        )
    }

    public func weasyPathPDF(
        css: CSSPageSetting = CSSPageSetting(),
        destination: String,
        encoding: String.Encoding = .utf8
    ) async throws {
        let htmlURL = URL(
            filePath: self
        )

        let cssString =
            css.css()

        let cssTemp = try cssString.tempFile(
            fileExtension: "css"
        )

        let renderer = WeasyPrintRenderer(
            encoding: encoding
        )

        try await renderer.pdf(
            html: htmlURL,
            css: cssTemp,
            destination: destination
        )
    }
}
