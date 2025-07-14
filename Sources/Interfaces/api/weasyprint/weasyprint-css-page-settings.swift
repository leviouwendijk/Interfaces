import Foundation
import plate

public struct CSSMargins {
    public let top: Int
    public let right: Int
    public let bottom: Int
    public let left: Int

    public init(
        top: Int = 20,
        right: Int = 20,
        bottom: Int = 20,
        left: Int = 20
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

public struct CSSPageSetting {
    public let orientation: PageOrientation
    public let margins: CSSMargins

    public init(
        orientation: PageOrientation = .portrait,
        margins: CSSMargins = CSSMargins()
    ) {
        self.orientation = orientation
        self.margins = margins
    }

    public func css() -> String {
        return orientation.css(margins: margins)
    }
}

public enum PageOrientation: String, RawRepresentable {
    case portrait
    case landscape

    public func css(margins: CSSMargins) -> String {
        let orientation = self.rawValue

        return """
        @page {
            size: A4 \(orientation);
            margin: \(margins.cssValue);
        }
        """
    }
    
    // public func css(margin: Int = 20) -> String {
    //     switch self {
    //     case .portrait:
    //         return """
    //         @page {
    //             size: A4 portrait;
    //             margin: \(margin)mm;
    //         }
    //         """
    //     case .landscape:
    //         return """
    //         @page {
    //             size: A4 landscape;
    //             margin: \(margin)mm;
    //         }
    //         """
    //     }
    // }
}
