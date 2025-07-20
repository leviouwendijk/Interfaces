import Foundation

public final class HTMLNode {
    public let tag: String?
    public let text: String?
    public let attributes: [String: String]
    public let children: [HTMLNode]

    public init(
        tag: String? = nil,
        text: String? = nil,
        attributes: [String: String] = [:],
        children: [HTMLNode] = []
    ) {
        self.tag = tag
        self.text = text
        self.attributes = attributes
        self.children = children
    }

    public func render() -> String {
        if let text = text {
            return text
        }

        let attrs = attributes.map { "\($0.key)=\"\($0.value)\"" }
        .joined(separator: " ")

        let open = tag.map { attrs.isEmpty ? "<\($0)>" : "<\($0) \(attrs)>" } ?? ""

        let close = tag.map { "</\($0)>" } ?? ""

        let inner = children.map { $0.render() }.joined()

        return "\(open)\(inner)\(close)"
    }
}
