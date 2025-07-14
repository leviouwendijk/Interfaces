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
