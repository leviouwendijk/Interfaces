import Foundation
import plate

public enum ApplicationEnvironmentLoaderError: Error {
    case fileNotFound(String)
    case invalidConfigLine(String)
    case missingEnv(String)
}

public enum ApplicationEnvironmentActorError: Error {
    case missingEnv(String)
}

public struct ApplicationEnvironmentLoader {
    public static func load(from filePath: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ApplicationEnvironmentLoaderError.fileNotFound(filePath)
        }
        
        let raw = try String(contentsOf: url, encoding: .utf8)
        var result: [String: String] = [:]
        
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed
            .strippingExportPrefix()
            .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard parts.count == 2 else {
                throw ApplicationEnvironmentLoaderError.invalidConfigLine(trimmed)
            }
            
            let key = parts[0]
            .trimmingCharacters(in: .whitespaces)

            let value = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .replacingShellHomeVariable()
            .strippingEnclosingQuotes()

            result[key] = value
        }
        
        return result
    }
    
    public static func set(to loadedDictionary: [String: String]) {
        for (key, value) in loadedDictionary {
            setenv(key, value, 1)
        }
    }
}

public struct ApplicationEnvironmentActor {
    public let environmentFile: String // environment filepath

    public init(
        environmentFile: String
    ) throws {
        self.environmentFile = environmentFile
        let dictionary = try ApplicationEnvironmentLoader.load(from: environmentFile)
        ApplicationEnvironmentLoader.set(to: dictionary)
    }

    public static func get(key: String) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[key],
            !raw.isEmpty
        else {
            throw ApplicationEnvironmentActorError.missingEnv(key)
        }
        return raw
    }
}
