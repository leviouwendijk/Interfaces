import Foundation
import PDFKit
import plate

public struct NumbersParser {
    private let exporter: NumbersParserExporter
    private let extractor: NumbersParserExtractor
    private let pdfFilter: NumbersParserInvoicePDF

    /// any `nil` argument will be sourced from environment.
    public init(
        // exporter args
        source: String? = nil,
        destination: String? = nil,
        invoiceRaw: String? = nil,
        sheet: String? = nil,
        table: String? = nil,
        row: String? = nil,
        column: String? = nil,
        value: String? = nil,
        close: Bool = false,
        responder: Bool = false,

        // extractor args
        csvPath: String? = nil,
        rawJsonPath: String? = nil,
        reparsedJsonPath: String? = nil,

        // pdf filter args
        invoiceOut: String? = nil,
        openAfterwards: Bool = false,
        openingMethod: PathOpenerOpeningMethod?,
    ) throws {
        self.exporter = try NumbersParserExporter(
            source: source,
            destination: destination,
            invoicePdf: invoiceRaw,
            sheet: sheet,
            table: table,
            row: row,
            column: column,
            value: value,
            close: close,
            responder: responder
        )

        // note: destination == CSV destination; parsed JSON sits in env.parsed; reparsed in env.reparsed
        self.extractor = try NumbersParserExtractor(
            csvPath: destination,
            rawJsonPath: rawJsonPath,
            reparsedJsonPath: reparsedJsonPath
        )

        self.pdfFilter = try NumbersParserInvoicePDF(
            invoiceRaw: invoiceRaw,
            invoiceOut: invoiceOut,
            openAfterwards: openAfterwards,
            openingMethod: openingMethod,
        )
    }

    public func renderInvoice() throws {
        try exporter.runAppleScriptExport()
        try extractor.extractInvoice()
        try pdfFilter.convertRawNumbersPdfToInvoice()
    }

    public func renderInvoiceData() throws {
        try exporter.runAppleScriptExport()
        try extractor.extractInvoice()
        try pdfFilter.convertRawNumbersPdfToInvoice()
    }
}

// example calls:
// do {
//     // uses env defaults for anything you omit
//     let parser = try NumbersParser(
//         // you can override only what you need:
//         sheet: "2",
//         table: "InvoiceTable",
//         row: "5",
//         column: "3",
//         value: "469",
//     )

//     try parser.renderInvoice()
//     print("Success")
// } catch {
//     print("Render failed:", error)
// }

// specifying openingMethod
// func run() throws {
//     do {
//         let parser = try NumbersParser(
//             value: "469",
//             openAfterwards: true,
//             openingMethod: .direct
//         )

//         try parser.renderInvoice()
//         print("Success")
//     } catch {
//         print("Render failed:", error)
//     }
// }
