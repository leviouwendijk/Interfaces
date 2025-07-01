import Foundation
import plate

public protocol PDFRenderable {
    func pdf(html: URL, css: URL, destination: String) throws
}

public struct WeasyPrintRenderer: PDFRenderable {
    private let weasyBinaryPath: String
    public let encoding: String.Encoding
    
    public init(
        weasyBinaryPath: String = "/opt/homebrew/bin/weasyprint",
        encoding: String.Encoding = .utf8
    ) {
        self.weasyBinaryPath = weasyBinaryPath
        self.encoding = encoding
    }
    
    public func pdf(html: URL, css: URL, destination: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: html.path) else {
            throw PDFGenerationError.htmlFileMissing(html)
        }
        guard fm.fileExists(atPath: css.path) else {
            throw PDFGenerationError.cssFileMissing(css)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: weasyBinaryPath)
        process.arguments = [
            html.path,
            destination,
            "--stylesheet", css.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            throw PDFGenerationError.cannotRunProcess(underlying: error)
        }
        
        process.waitUntilExit()
        
        let status = process.terminationStatus
        if status != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: encoding) ?? "<no output>"
            throw PDFGenerationError.processFailed(exitCode: status, output: output)
        }
    }
}

extension String {
    public func weasyPDF(css: CSSPageSetting = CSSPageSetting(), destination: String, encoding: String.Encoding = .utf8) throws {
        let htmlTemp = try self.tempFile(fileExtension: "html", encoding: encoding)

        let cssString = css.css()
        let cssTemp = try cssString.tempFile(fileExtension: "css")

        let renderer = WeasyPrintRenderer(encoding: encoding)
        try renderer.pdf(html: htmlTemp, css: cssTemp, destination: destination)
    }
}
