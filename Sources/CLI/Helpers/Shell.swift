import Foundation

struct ShellError: Error, CustomStringConvertible {
    let command: String
    let status: Int32
    var description: String { "Command failed (exit \(status)): \(command)" }
}

/// Runs `command` in zsh, streaming its output. Throws if it exits non-zero.
func shell(_ command: String) throws {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]

    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw ShellError(command: command, status: process.terminationStatus)
    }
}
