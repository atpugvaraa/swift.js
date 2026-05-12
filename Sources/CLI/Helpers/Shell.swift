import Foundation

@discardableResult
func shell(_ command: String) throws -> Int32 {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]

    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    return process.terminationStatus
}