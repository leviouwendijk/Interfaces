import Foundation
import Darwin

public struct PTYResult: Sendable {
    public let exitCode: Int32
    public let stdout: Data   // merged stdout+stderr
    public let stderr: Data   // empty (kept for symmetry)
}

public enum PTYError: Error {
    case openPTYFailed(errno: Int32)
    case spawnFailed(errno: Int32)
}

@discardableResult
public func runPTY(
    _ launchPath: String,
    _ args: [String],
    env: [String:String]? = nil,
    cwd: URL? = nil,
    onChunk: (@Sendable (Data) -> Void)? = nil
) throws -> PTYResult {
    var master: Int32 = -1
    var slave:  Int32 = -1
    guard openpty(&master, &slave, nil, nil, nil) == 0 else {
        throw PTYError.openPTYFailed(errno: errno)
    }

    // argv (stable C strings)
    var cargv: [UnsafeMutablePointer<CChar>?] = ([launchPath] + args).map { strdup($0) }
    cargv.append(nil)
    defer { cargv.forEach { if let p = $0 { free(p) } } }

    // envp (inherit if nil)
    var cenv: [UnsafeMutablePointer<CChar>?] = []
    if let env {
        for (k, v) in env { cenv.append(strdup("\(k)=\(v)")) }
        cenv.append(nil)
    } else {
        cenv = [nil]
    }
    defer { cenv.forEach { if let p = $0 { free(p) } } }

    // file actions
    var fa: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&fa)
    defer { posix_spawn_file_actions_destroy(&fa) }

    posix_spawn_file_actions_adddup2(&fa, slave, STDIN_FILENO)
    posix_spawn_file_actions_adddup2(&fa, slave, STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fa, slave, STDERR_FILENO)
    posix_spawn_file_actions_addclose(&fa, slave)

    if let dir = cwd?.path {
        _ = dir.withCString { cstr in
            posix_spawn_file_actions_addchdir_np(&fa, cstr)
        }
    }

    // attrs
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }

    // spawn
    var pid: pid_t = 0
    let spawnErr = cargv.withUnsafeMutableBufferPointer { argvPtr in
        cenv.withUnsafeMutableBufferPointer { envPtr in
            posix_spawn(
                &pid,
                launchPath,
                &fa,
                &attr,
                argvPtr.baseAddress,
                envPtr.baseAddress
            )
        }
    }

    // parent: no need for slave fd
    close(slave)

    guard spawnErr == 0 else {
        close(master)
        throw PTYError.spawnFailed(errno: spawnErr)
    }

    // stream from PTY master
    let fh = FileHandle(fileDescriptor: master, closeOnDealloc: true)
    var buffer = Data()
    while true {
        let chunk = try fh.read(upToCount: 64 * 1024) ?? Data()
        if chunk.isEmpty { break }
        buffer.append(chunk)
        onChunk?(chunk)
        _ = Task { await Task.yield() }            // nudge scheduler
    }

    // wait + exit code
    var status: Int32 = 0
    _ = waitpid(pid, &status, 0)
    let exit: Int32 = (status & 0x7F) == 0 ? ((status >> 8) & 0xFF) : (128 + (status & 0x7F))

    return PTYResult(exitCode: exit, stdout: buffer, stderr: Data())
}
