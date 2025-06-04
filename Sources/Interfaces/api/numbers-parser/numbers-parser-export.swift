import Foundation

public struct NumbersParserExporter {
    public let source: String
    public let destination: String
    public let invoicePdf: String

    public let sheet: String
    public let table: String
    public let row: String
    public let column: String

    public let close: Bool
    public let responder: Bool

    public let data: NumbersParserNumbersData

    private var adjustBeforeExporting: Bool {
        return !(data.value.isEmpty)
    }

    public init(
        source: String? = nil,
        destination: String? = nil,
        invoicePdf: String? = nil,
        sheet: String? = nil,
        table: String? = nil,
        row: String? = nil,
        column: String? = nil,
        value: String? = nil,
        close: Bool = false,
        responder: Bool = false
    ) throws {
        self.source      = try source      ?? NumbersParserEnvironment.require(.source)
        self.destination = try destination ?? NumbersParserEnvironment.require(.destination)
        self.invoicePdf  = try invoicePdf  ?? NumbersParserEnvironment.require(.invoiceRaw)
        self.sheet       = try sheet       ?? NumbersParserEnvironment.require(.sheet)
        self.table       = try table       ?? NumbersParserEnvironment.require(.table)
        self.row         = try row         ?? NumbersParserEnvironment.require(.row)
        self.column      = try column      ?? NumbersParserEnvironment.require(.column)

        self.close                   = close
        self.responder               = responder

        let unwrappedValue = value ?? ""
        self.data = NumbersParserNumbersData(
            sheet:  self.sheet,
            table:  self.table,
            row:    self.row,
            column: self.column,
            value:  unwrappedValue
        )
    }

    public func runAppleScriptExport() throws {
        let src = numbersParserSanitize(source)
        let dst = numbersParserSanitize(destination)
        let inv = numbersParserSanitize(invoicePdf)

        let args = NumbersParserArguments(src: src, dst: dst, inv: inv, data: data)
        
        let open = numbersParserOsaScript(.open, args)
        let setInvoice = numbersParserOsaScript(.setInvoice, args)
        // let debug = numbersParserOsaScript(.debug, args)
        // let debugCells = numbersParserOsaScript(.debugCells, args)
        let csv = numbersParserOsaScript(.exportCSV, args)
        let pdf = numbersParserOsaScript(.exportPDF, args)
        let closeOp = numbersParserOsaScript(.close, args)
        let ghostty = numbersParserOsaScript(.ghostty, args)
        let responder = numbersParserOsaScript(.responder, args)

        try runOsascriptProcess(open)
        if adjustBeforeExporting {
            print("adjust target hit...")

            // print()
            // print("running debug...")
            // runOsascriptProcess(debug)
            // runOsascriptProcess(debugCells)

            print("trying to set: ")
            print("    sheet: \(args.data.sheet)")
            print("    table: \(args.data.table)")
            print("    row: \(args.data.row)")
            print("    column: \(args.data.column)")
            print("    value: \(args.data.value)")
            print("script")
            print(setInvoice)

            try runOsascriptProcess(setInvoice)
        }
        try removeExistingCSV()
        try runOsascriptProcess(csv)
        try runOsascriptProcess(pdf)
        if self.responder {
            try runOsascriptProcess(responder)
        } else {
            try runOsascriptProcess(ghostty)
        }
        if close {
            try runOsascriptProcess(closeOp)
        }
    }

    public func removeExistingCSV(_ path: String? = nil) throws {
        let finalPath = try path ?? NumbersParserEnvironment.require(.destination)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: finalPath) {
            do {
                try fileManager.removeItem(atPath: finalPath)
                print("Deleted existing directory: \(finalPath)")
            } catch {
                print("Failed to delete existing directory: \(error)")
            }
        }
    }
}
