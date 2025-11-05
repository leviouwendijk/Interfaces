import Foundation
import PDFKit
import plate

public struct NumbersParserInvoicePDF {
    public let invoiceRaw: String
    public let invoiceOut: String
    public let openAfterwards: Bool
    public let pathOpener: PathOpener?
    public let openingMethod: PathOpenerOpeningMethod?

    public init(
        invoiceRaw: String? = nil,
        invoiceOut: String? = nil,
        openAfterwards: Bool = false,
        pathOpener: PathOpener? = nil,
        openingMethod: PathOpenerOpeningMethod? = nil
    ) throws {
        self.invoiceRaw      = try invoiceRaw ?? NumbersParserEnvironment.require(.invoiceRaw)
        self.invoiceOut      = try invoiceOut ?? NumbersParserEnvironment.require(.invoice)
        self.openAfterwards  = openAfterwards

        let method           = openingMethod ?? PathOpenerOpeningMethod.inParentDirectory
        self.openingMethod   = method
        self.pathOpener      = try pathOpener ?? PathOpener(path: self.invoiceOut, method: method)
    }

    public func convertRawNumbersPdfToInvoice(selectedPages: [Int] = [12, 13]) throws {
        guard FileManager.default.fileExists(atPath: invoiceRaw) else {
            throw NumbersParserError.fileNotFound("Raw invoice PDF not found at \(invoiceRaw)")
        }

        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: invoiceRaw)) else {
            throw NumbersParserError.pdfDocumentCreationFailed("Cannot open PDF at \(invoiceRaw)")
        }

        let newPDF = PDFDocument()
        for (insertIndex, pageIndex) in selectedPages.enumerated() {
            guard let page = pdfDocument.page(at: pageIndex) else {
                throw NumbersParserError.pageNotFound(pageIndex)
            }
            newPDF.insert(page, at: insertIndex)
        }

        guard let outputData = newPDF.dataRepresentation() else {
            throw NumbersParserError.cannotGenerateOutput("Failed to create PDF data for \(invoiceOut)")
        }

        do {
            try outputData.write(to: URL(fileURLWithPath: invoiceOut))

            if openAfterwards {
                try pathOpener?.open()
            }
        } catch {
            throw NumbersParserError.writeFailed(file: invoiceOut, underlying: error)
        }
    }
}
