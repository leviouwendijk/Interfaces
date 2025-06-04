import Foundation

public struct NumbersParserArguments {
    public let src: String
    public let dst: String
    public let inv: String
    public let data: NumbersParserNumbersData
    
    public init(
        src: String,
        dst: String,
        inv: String,
        data: NumbersParserNumbersData
    ) {
        self.src = src
        self.dst = dst
        self.inv = inv
        self.data = data
    }
}

public struct NumbersParserNumbersData {
    public let sheet: String
    public let table: String
    public let row: String
    public let column: String
    public let value: String

    public init(
        sheet: String,
        table: String,
        row: String,
        column: String,
        value: String
    ) {
        self.sheet = sheet
        self.table = table
        self.row = row
        self.column = column
        self.value = value
    }
}

public func numbersParserSanitize(_ path: String) -> String {
    var sanitizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if sanitizedPath.hasSuffix(":") {
        sanitizedPath.removeLast()
    }
    
    return sanitizedPath
}

