import Foundation
import plate

public enum HTMLDocumentError: Error {
    case missingEnv(String)
    case invalidURL(String)
    case invalidFormat(original: String)
}

public enum HTMLDocumentEnvironmentKey: String {
    case h_logo = "HONDENMEESTERS_H_LOGO"
}

public struct HTMLDocumentEnvironment {
    public static func require(_ key: HTMLDocumentEnvironmentKey) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key.rawValue],
            !raw.isEmpty
        else {
            throw HTMLDocumentError.missingEnv(key.rawValue)
        }
        return raw
    }

    public static func optional(_ key: HTMLDocumentEnvironmentKey) -> String? {
        ProcessInfo.processInfo.environment[key.rawValue]
    }
}

// setup for converting NSAttributedString -> Template content, etc
// make generic string -> HTML
public struct HTMLDocument {
    public let content: String
    public let placeInBody: Bool

    public init(
        content: String,
        placeInBody: Bool = false
    ) {
        self.content = content
        self.placeInBody = placeInBody
    }

    public static func insertedBody(placing body: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
            <head>
                <meta charset="UTF-8">
            </head>
            <body>

            \(body)

            </body>
        </html>
        """
    }
}
