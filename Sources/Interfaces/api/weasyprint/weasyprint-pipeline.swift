import Foundation
import plate

public struct WeasyActor {
    public let html: LoadableResource
    public let replacements: [StringTemplateReplacement]
    public let destination: String

    public init(
        html: LoadableResource,
        replacements: [StringTemplateReplacement] = [],
        destination: String
    ) {
        self.html = html
        self.replacements = replacements
        self.destination = destination
    }

    public func pdf() throws {
        let htmlRaw = try html.content()
        let converter = StringTemplateConverter(
            text: htmlRaw,
            replacements: replacements
        )

        let html = converter.replace()
        try html.weasyPDF(destination: destination)
    }
}
