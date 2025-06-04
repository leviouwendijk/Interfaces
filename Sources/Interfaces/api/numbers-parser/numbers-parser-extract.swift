import Foundation

public struct NumbersParserExtractor {
    public let csvPath: String
    public let rawJsonPath: String
    public let reparsedJsonPath: String

    public init(
        csvPath: String? = nil,
        rawJsonPath: String? = nil,
        reparsedJsonPath: String? = nil
    ) throws {
        self.csvPath          = try csvPath          ?? NumbersParserEnvironment.require(.target)
        self.rawJsonPath      = try rawJsonPath      ?? NumbersParserEnvironment.require(.parsed)
        self.reparsedJsonPath = try reparsedJsonPath ?? NumbersParserEnvironment.require(.reparsed)
    }

    public func getCurrentRender() throws -> [String: [String: String]] {
        let data = try Data(contentsOf: URL(fileURLWithPath: reparsedJsonPath))
        let decoder = JSONDecoder()
        let parsedData = try decoder.decode([String: [String: String]].self, from: data)
        return parsedData
    }

    public func extractInvoiceData() throws -> [String: [String: String]] {
        print("Extracting data from CSV file: \(csvPath)")

        let rows = try parseRawCSV(filePath: csvPath)
        guard !rows.isEmpty else {
            throw NumbersParserError.noRows(file: csvPath)
        }

        try saveJSON(data: rows, to: rawJsonPath)
        print("Parsed data saved to \(rawJsonPath)")

        let restructured = try reparseJSON(filePath: rawJsonPath)

        try saveReparsedJSON(data: restructured, to: reparsedJsonPath)
        print("Reparsed data saved to \(reparsedJsonPath)")

        return restructured
    }

    public func extractInvoice() throws {
        print("Extracting data from CSV file: \(csvPath)")

        let rows = try parseRawCSV(filePath: csvPath)
        guard !rows.isEmpty else {
            throw NumbersParserError.noRows(file: csvPath)
        }

        try saveJSON(data: rows, to: rawJsonPath)
        print("Parsed data saved to \(rawJsonPath)")

        let restructured = try reparseJSON(filePath: rawJsonPath)

        try saveReparsedJSON(data: restructured, to: reparsedJsonPath)
        print("Reparsed data saved to \(reparsedJsonPath)")
    }

    private func parseRawCSV(filePath: String) throws -> [[String: String]] {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        guard let headerLine = lines.first else {
            throw NumbersParserError.missingHeaders(file: filePath)
        }
        let headers = headerLine.components(separatedBy: ";")

        var result: [[String: String]] = []
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ";")
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    row[header] = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            result.append(row)
        }
        return result
    }

    private func reparseJSON(filePath: String) throws -> [String: [String: String]] {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        guard let rawArray = any as? [[String: String]] else {
            throw NumbersParserError.invalidJSON(file: filePath)
        }

        var invoiceData: [String: String] = [:]
        for entry in rawArray {
            guard let key = entry["Invoice ID"],
                  let value = entry.first(where: { $0.key.hasPrefix("RN") })?.value
            else { continue }
            invoiceData[key] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ["Invoices": invoiceData]
    }

    private func saveJSON(data: [[String: String]], to filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        do {
            let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try json.write(to: url)
        } catch {
            throw NumbersParserError.writeFailed(file: filePath, underlying: error)
        }
    }

    private func saveReparsedJSON(data: [String: [String: String]], to filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        do {
            let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try json.write(to: url)
        } catch {
            throw NumbersParserError.writeFailed(file: filePath, underlying: error)
        }
    }
}
