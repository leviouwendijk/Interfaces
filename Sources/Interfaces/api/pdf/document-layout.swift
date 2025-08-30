import Foundation

public struct PageMargins {
    public var left: CGFloat
    public var right: CGFloat
    public var top: CGFloat
    public var bottom: CGFloat

    public init(
        left: CGFloat = 40,
        right: CGFloat = 40,
        top: CGFloat = 40,
        bottom: CGFloat = 40
    ) {
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
    }
}

public struct LayoutState {
    public var cursorY: CGFloat = 0
    public var lineHeight: CGFloat = 18
    public var sectionSpacing: CGFloat = 12
    public var dividerHeight: CGFloat = 1

    public let pageBounds: CGRect
    public let margins: PageMargins

    public var contentLeftX: CGFloat { margins.left }
    public var contentRightX: CGFloat { pageBounds.width - margins.right }
    public var contentWidth: CGFloat { contentRightX - contentLeftX }

    public init(
        pageBounds: CGRect,
        margins: PageMargins,
        lineHeight: CGFloat = 18,
        sectionSpacing: CGFloat = 12,
        dividerHeight: CGFloat = 1
    ) {
        self.pageBounds = pageBounds
        self.margins = margins
        self.lineHeight = lineHeight
        self.sectionSpacing = sectionSpacing
        self.dividerHeight = dividerHeight
        self.cursorY = pageBounds.height - margins.top 
    }

    public mutating func nextLine(_ count: Int = 1) {
        cursorY -= (lineHeight * CGFloat(count))
    }

    public mutating func addSpacing(_ points: CGFloat) {
        cursorY -= points
    }
}
