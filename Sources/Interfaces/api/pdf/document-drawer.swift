import Foundation
import Quartz

public final class DocumentDrawer {
    public let documentURL: URL
    public let margins: PageMargins
    public var pageBounds: CGRect
    private let context: CGContext

    public init(
        documentURL: URL,
        pageBounds: CGRect = CGRect(x: 0, y: 0, width: 612, height: 792),  // Standard US Letter
        margins: PageMargins = .init()
    ) throws {
        self.documentURL = documentURL
        self.pageBounds = pageBounds
        self.margins = margins

        guard let context = CGContext(
            self.documentURL as CFURL,
            mediaBox: &self.pageBounds, nil
        ) else {
            throw DocumentDrawerError.cannotCreateDocumentCGContext
        }
        self.context = context
    }
    
    public func beginPage() -> LayoutState {
        context.beginPDFPage(nil)
        return LayoutState(pageBounds: pageBounds, margins: margins)
    }

    public func endPage() {
        context.endPDFPage()
    }

    public func close() {
        context.closePDF()
    }

    public func drawAttributedText(
        attributedString: NSAttributedString,
        at point: CGPoint,
        centered: Bool = false,
        rightAligned: Bool = false
    ) {
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let xOffset: CGFloat
        if centered {
            xOffset = -bounds.width / 2.0
        } else if rightAligned {
            xOffset = -bounds.width
        } else {
            xOffset = 0
        }
        context.textPosition = CGPoint(x: point.x + xOffset, y: point.y)
        CTLineDraw(line, context)
    }

    public func drawText(
        _ text: String,
        at point: CGPoint,
        attributes: [NSAttributedString.Key: Any],
        centered: Bool = false,
        rightAligned: Bool = false
    ) {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        drawAttributedText(
            attributedString: attributedString,
            at: point,
            centered: centered,
            rightAligned: rightAligned,
        )
    }

    public func drawDivider(
        at point: CGPoint,
        width: CGFloat,
        color: CGColor,
    ) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.move(to: point)
        context.addLine(to: CGPoint(x: point.x + width, y: point.y))
        context.strokePath()
        context.restoreGState()
    }

    public func drawDivider(at y: CGFloat) {
        let start = CGPoint(x: margins.left, y: y)
        let width = pageBounds.width - margins.left - margins.right
        drawDivider(at: start, width: width, color: CGColor(gray: 0.6, alpha: 1.0))
    }

    private func measure(_ attributed: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var fitRange = CFRange()
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            nil,
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            &fitRange
        )
        return size
    }

    @discardableResult
    public func drawRow(
        left: String,
        right: String?,
        leftAttrs: [NSAttributedString.Key: Any],
        rightAttrs: [NSAttributedString.Key: Any]?,
        layout: inout LayoutState
    ) -> CGFloat {
        let y = layout.cursorY
        drawText(left, at: CGPoint(x: layout.contentLeftX, y: y), attributes: leftAttrs)
        if let r = right, let ra = rightAttrs {
            drawText(r, at: CGPoint(x: layout.contentRightX, y: y), attributes: ra, rightAligned: true)
        }
        layout.nextLine()
        return y
    }

    @discardableResult
    public func drawKeyValuesRight(
        _ values: DocumentDrawValues,
        keyAttrs: [NSAttributedString.Key: Any],
        valueAttrs: [NSAttributedString.Key: Any],
        layout: inout LayoutState,
        keyColumnWidth: CGFloat = 120
    ) -> CGFloat {
        var lastY = layout.cursorY
        let rightColRightX = layout.contentRightX
        let rightColLeftX = max(layout.contentRightX - 200, layout.contentLeftX + layout.contentWidth/2 + 8)

        let items = values.unpack()

        for kv in items {
            let keyPoint = CGPoint(x: rightColLeftX, y: layout.cursorY)
            let valPoint = CGPoint(x: rightColRightX, y: layout.cursorY)
            drawText(kv.title, at: keyPoint, attributes: keyAttrs)
            drawText(kv.value, at: valPoint, attributes: valueAttrs, rightAligned: true)
            lastY = layout.cursorY
            layout.nextLine()
        }
        return lastY
    }

    @discardableResult
    public func drawHeader(
        leftTitle: NSAttributedString?,
        centerTitle: NSAttributedString?,
        rightTitle: NSAttributedString?,
        metaRightValues: DocumentDrawValues,
        titleSpacing: CGFloat = 12,
        bottomDivider: Bool = true,
        layout: inout LayoutState
    ) -> CGFloat {
        let startY = layout.cursorY

        if let left = leftTitle {
            drawAttributedText(attributedString: left, at: CGPoint(x: layout.contentLeftX, y: layout.cursorY))
        }
        if let center = centerTitle {
            let midX = layout.contentLeftX + (layout.contentWidth / 2.0)
            drawAttributedText(attributedString: center, at: CGPoint(x: midX, y: layout.cursorY), centered: true)
        }
        if let right = rightTitle {
            drawAttributedText(attributedString: right, at: CGPoint(x: layout.contentRightX, y: layout.cursorY), rightAligned: true)
        }

        layout.nextLine()
        layout.addSpacing(titleSpacing)

        if !metaRightValues.values.isEmpty {
            _ = drawKeyValuesRight(
                metaRightValues,
                keyAttrs: DocumentTextAppearance.textRegular.attributes(),
                valueAttrs: DocumentTextAppearance.textBold.attributes(),
                layout: &layout
            )
            layout.addSpacing(titleSpacing)
        }

        if bottomDivider {
            drawDivider(at: layout.cursorY)
            layout.addSpacing(layout.dividerHeight + layout.sectionSpacing)
        }

        let usedHeight = startY - layout.cursorY
        return usedHeight
    }
}
