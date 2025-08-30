import Foundation

public func createDrawnPDF(
    filename: String,
    exportDirectory: URL,
    leftTitle: NSAttributedString?,
    centerTitle: NSAttributedString?,
    rightTitle: NSAttributedString?,
    headerMeta: DocumentDrawValues,
    bodyLines: DocumentDrawValues,
    indentKeys: Set<String> = [],
    indentWidth: CGFloat = 20
) throws {
    let pdfURL = exportDirectory.appendingPathComponent("\(filename).pdf")
    let drawer = try DocumentDrawer(documentURL: pdfURL)
    var layout = drawer.beginPage()

    drawer.drawHeader(
        leftTitle: leftTitle,
        centerTitle: centerTitle,
        rightTitle: rightTitle,
        metaRightValues: headerMeta,
        layout: &layout
    )

    let items = { () -> [DocumentDrawValue] in
        let byId = Dictionary(uniqueKeysWithValues: bodyLines.values.map { ($0.identifier, $0) })
        if let o = bodyLines.order, !o.isEmpty {
            var out: [DocumentDrawValue] = o.compactMap { byId[$0] }
            let mentioned = Set(o)
            for v in bodyLines.values where !mentioned.contains(v.identifier) { out.append(v) }
            return out
        } else {
            return bodyLines.values
        }
    }()

    for v in items {
        let attrs = v.appearance.attributes()
        let indent = indentKeys.contains(v.identifier) ? indentWidth : 0
        let y = layout.cursorY
        drawer.drawText(v.title, at: CGPoint(x: layout.contentLeftX + indent, y: y), attributes: attrs)
        drawer.drawText(v.value, at: CGPoint(x: layout.contentRightX, y: y), attributes: attrs, rightAligned: true)
        layout.nextLine()
    }

    drawer.endPage()
    drawer.close()
}
