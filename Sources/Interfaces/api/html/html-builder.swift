import Foundation

@resultBuilder
public struct interfaces_HTMLBuilder {
    public static func buildBlock(_ nodes: interfaces_HTMLNode...) -> [interfaces_HTMLNode] {
        nodes
    }

    public static func buildBlock(_ nodes: [interfaces_HTMLNode]) -> [interfaces_HTMLNode] {
        nodes
    }

    public static func buildOptional(_ nodes: [interfaces_HTMLNode]?) -> [interfaces_HTMLNode] {
        nodes ?? []
    }

    public static func buildEither(first: [interfaces_HTMLNode]) -> [interfaces_HTMLNode] {
        first
    }

    public static func buildEither(second: [interfaces_HTMLNode]) -> [interfaces_HTMLNode] {
        second
    }

    public static func buildArray(_ components: [[interfaces_HTMLNode]]) -> [interfaces_HTMLNode] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ node: interfaces_HTMLNode) -> [interfaces_HTMLNode] {
        [node]
    }

    public static func buildExpression(_ text: String) -> [interfaces_HTMLNode] {
        [interfaces_HTMLNode(text: text)]
    }
}

public func html(@interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "html", children: content())
}

public func body(@interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "body", children: content())
}

public func div(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "div", attributes: attrs, children: content())
}

public func p(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "p", attributes: attrs, children: content())
}

public func span(_ attrs: [String: String] = [:], _ text: String) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "span", text: text, attributes: attrs)
}

public func b(_ text: String) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "b", children: [interfaces_HTMLNode(text: text)])
}

public func i(_ text: String) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "i", children: [interfaces_HTMLNode(text: text)])
}

public func h(_ level: Int = 1, _ text: String) -> interfaces_HTMLNode {
    let tagName = "h\(min(max(level,1),6))"
    return interfaces_HTMLNode(tag: tagName, children: [interfaces_HTMLNode(text: text)])
}

public func ul(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "ul", attributes: attrs, children: content())
}

public func ol(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "ol", attributes: attrs, children: content())
}

public func li(_ text: String) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "li", children: [interfaces_HTMLNode(text: text)])
}

public func tr(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "tr", attributes: attrs, children: content())
}

public func td(_ attrs: [String: String] = [:], @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "td", attributes: attrs, children: content())
}

public func table(
    _ attrs: [String:String] = [:],
    @interfaces_HTMLBuilder _ content: () -> [interfaces_HTMLNode]
) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "table", attributes: attrs, children: content())
}

public func th(_ text: String) -> interfaces_HTMLNode {
    interfaces_HTMLNode(tag: "th", children: [interfaces_HTMLNode(text: text)])
}

public extension Dictionary where Key == String, Value == String {
    static func `class`(_ value: String) -> [String: String] { ["class": value] }
    static func id(_ value: String)    -> [String: String] { ["id": value] }
    static func attr(_ key: String, _ value: String) -> [String: String] { [key: value] }
}

