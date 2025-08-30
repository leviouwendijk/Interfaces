import Foundation

public struct DocumentDrawValue: Sendable, Codable {
    public let identifier: String
    public let title: String
    public let value: String
    public let appearance: DocumentTextAppearance
    
    public init(
        identifier: String,
        title: String,
        value: String,
        appearance: DocumentTextAppearance
    ) {
        self.identifier = identifier
        self.title = title
        self.value = value
        self.appearance = appearance
    }
}

public struct DocumentDrawValues: Sendable, Codable {
    public let values: [DocumentDrawValue]
    public let order: [String]?
    
    public init(
        values: [DocumentDrawValue],
        order: [String]? = nil
    ) throws {
        self.values = values
        self.order = order
        
        try validateOrder()
    }

    public func validateOrder() throws {
        if let o = order {
            var identifiers: [String] = []
            for v in values {
                identifiers.append(v.identifier)
            }
            
            for i in o {
                guard identifiers.contains(i) else {
                    throw DocumentDrawerError.missingKeyInValuesOrder(key: i)
                }
            }
        }
    }

    public func unpack() -> [DocumentDrawValue] {
        let byId = Dictionary(uniqueKeysWithValues: self.values.map { ($0.identifier, $0) })

        if let o = self.order, !o.isEmpty {
            var out: [DocumentDrawValue] = []
            out.reserveCapacity(self.values.count)

            for id in o { if let v = byId[id] { out.append(v) } }

            let mentioned = Set(o)
            for v in self.values where !mentioned.contains(v.identifier) {
                out.append(v)
            }
            return out
        } else {
            return self.values
        }
    }
}
