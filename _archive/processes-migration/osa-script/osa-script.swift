import Foundation
import plate

public func osaScriptApplicationActivate(_ application: String) -> String {
    return """
    tell application "\(application)"
        activate
    end tell
    """
}

public func runOsascriptProcess(_ script: String) throws {
    let process = Process()
    process.launchPath = "/usr/bin/osascript"
    process.arguments = ["-e", script]
    
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Failed to execute AppleScript: \(error)")
        throw error
    }
}
