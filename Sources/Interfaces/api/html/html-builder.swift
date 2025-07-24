import Foundation

@resultBuilder
public struct HTMLBuilder {
    public static func buildBlock(_ nodes: HTMLNode...) -> [HTMLNode] {
        nodes
    }

    public static func buildBlock(_ nodes: [HTMLNode]) -> [HTMLNode] {
        nodes
    }

    public static func buildOptional(_ nodes: [HTMLNode]?) -> [HTMLNode] {
        nodes ?? []
    }

    public static func buildEither(first: [HTMLNode]) -> [HTMLNode] {
        first
    }

    public static func buildEither(second: [HTMLNode]) -> [HTMLNode] {
        second
    }

    public static func buildArray(_ components: [[HTMLNode]]) -> [HTMLNode] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ node: HTMLNode) -> [HTMLNode] {
        [node]
    }

    public static func buildExpression(_ text: String) -> [HTMLNode] {
        [HTMLNode(text: text)]
    }
}

public func html(@HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "html", children: content())
}

public func body(@HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "body", children: content())
}

public func div(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "div", attributes: attrs, children: content())
}

public func p(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "p", attributes: attrs, children: content())
}

public func span(_ attrs: [String: String] = [:], _ text: String) -> HTMLNode {
    HTMLNode(tag: "span", text: text, attributes: attrs)
}

public func b(_ text: String) -> HTMLNode {
    HTMLNode(tag: "b", children: [HTMLNode(text: text)])
}

public func i(_ text: String) -> HTMLNode {
    HTMLNode(tag: "i", children: [HTMLNode(text: text)])
}

public func h(_ level: Int = 1, _ text: String) -> HTMLNode {
    let tagName = "h\(min(max(level,1),6))"
    return HTMLNode(tag: tagName, children: [HTMLNode(text: text)])
}

public func ul(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "ul", attributes: attrs, children: content())
}

public func ol(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "ol", attributes: attrs, children: content())
}

public func li(_ text: String) -> HTMLNode {
    HTMLNode(tag: "li", children: [HTMLNode(text: text)])
}

public func tr(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "tr", attributes: attrs, children: content())
}

public func td(_ attrs: [String: String] = [:], @HTMLBuilder _ content: () -> [HTMLNode]) -> HTMLNode {
    HTMLNode(tag: "td", attributes: attrs, children: content())
}

public func table(
  _ attrs: [String:String] = [:],
  @HTMLBuilder _ content: () -> [HTMLNode]
) -> HTMLNode {
  HTMLNode(tag: "table", attributes: attrs, children: content())
}

public func th(_ text: String) -> HTMLNode {
  HTMLNode(tag: "th", children: [HTMLNode(text: text)])
}

public extension Dictionary where Key == String, Value == String {
    static func `class`(_ value: String) -> [String: String] { ["class": value] }
    static func id(_ value: String)    -> [String: String] { ["id": value] }
    static func attr(_ key: String, _ value: String) -> [String: String] { [key: value] }
}
