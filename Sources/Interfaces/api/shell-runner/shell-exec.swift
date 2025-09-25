import Foundation

public extension Shell {
    enum Exec: Sendable {
        case env, sh, bash, zsh
        case path(String)

        var launchPathAndArgsPrefix: (path: String, args: [String]) {
            switch self {
            case .env:   return ("/usr/bin/env", [])
            case .sh:    return ("/bin/sh",   ["-lc"])
            case .bash:  return ("/bin/bash", ["-lc"])
            case .zsh:   return ("/bin/zsh",  ["-lc"])
            case .path(let p): return (p, [])
            }
        }
    }
}
