import Foundation
import plate

public struct CSSPageSetting {
    public let orientation: PageOrientation
    public let margin: Int

    public init(
        orientation: PageOrientation = .portrait,
        margin: Int = 20
    ) {
        self.orientation = orientation
        self.margin = margin
    }

    public func css() -> String {
        return orientation.css(margin: margin)
    }
}

public enum PageOrientation {
    case portrait
    case landscape
    
    public func css(margin: Int = 20) -> String {
        switch self {
        case .portrait:
            return """
            @page {
                size: A4 portrait;
                margin: \(margin)mm;
            }
            """
        case .landscape:
            return """
            @page {
                size: A4 landscape;
                margin: \(margin)mm;
            }
            """
        }
    }
}
