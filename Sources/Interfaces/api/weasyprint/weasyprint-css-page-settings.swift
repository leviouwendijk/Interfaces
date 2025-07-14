import Foundation
import plate

public struct CSSMargins {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double

    public init(
        top: Double = 20.0,
        right: Double = 20.0,
        bottom: Double = 20.0,
        left: Double = 20.0
    ) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public var cssValue: String {
        return "\(top)mm \(right)mm \(bottom)mm \(left)mm"
    }
}

public enum CSSPageNumberFooterContent: String {
    case x
    case x_of_y
    case x_slash_y
    case skip

    public var value: String {
        switch self {
        case .x:
            return "content: \"counter(page)\";"

        case .x_of_y:
            return "content: \"counter(page) \" of \" counter(pages);"

        case .x_slash_y:
            return "content: \"counter(page) \" / \" counter(pages);"

        case .skip:
            return "content: \"none\";"
        }
    }

    public static func firstPageSkip() -> String {
        return """
        @page:first {
            @bottom-center {
                \(Self.skip.value)
            }
        }
        """
    }
}

public struct CSSPageSetting {
    public let orientation: PageOrientation
    public let margins: CSSMargins
    public let header: String?
    public let footer: String?
    public let skipFirstPageFooter: Bool

    public init(
        orientation: PageOrientation = .portrait,
        margins: CSSMargins = CSSMargins(),
        header: String? = nil,
        footer: String? = CSSPageNumberFooterContent.x.value,
        skipFirstPageFooter: Bool = true
    ) {
        self.orientation = orientation
        self.margins = margins
        self.header = header
        self.footer = footer
        self.skipFirstPageFooter = skipFirstPageFooter
    }

    public func css() -> String {
        let open = "@page {"
        let close = "}"

        var page = open.appendingNewline()
            
        page.append(
            orientation.css(margins: margins)
            .appendingNewline()
        )

        if let hdr = header {
            page += """
            
            @top-center {
                \(hdr)
            }
            """
        }

        if let ftr = footer {
            page += """
            
            @bottom-center {
                \(ftr)
            }
            """
        }

        page.append(close)

        if skipFirstPageFooter {
            page = page
            .appendingNewline()
            .appendingNewline()

            page.append(
                CSSPageNumberFooterContent.firstPageSkip()
            )
        }
        return page
    }
}

public enum PageOrientation: String, RawRepresentable {
    case portrait
    case landscape

    public func css(margins: CSSMargins) -> String {
        let orientation = self.rawValue

        return """
            size: A4 \(orientation);
            margin: \(margins.cssValue);
        """
    }
}
