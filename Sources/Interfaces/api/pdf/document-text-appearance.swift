import Foundation
import AppKit

public enum DocumentTextAppearance: Sendable, Codable {
    case titleBold
    case titleRegular
    case textRegular
    case textBold
    case textItalic

    public func attributes() -> [NSAttributedString.Key: Any] {
        switch self {
        case .titleBold:
            return [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
        case .titleRegular:
            return [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
        case .textRegular:
            return [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor.black
            ]
        case .textBold:
            return [
                .font: NSFont.boldSystemFont(ofSize: 8),
                .foregroundColor: NSColor.black
            ]
        case .textItalic:
            return [
                .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 8), toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.black
            ]
        }
    }
}
