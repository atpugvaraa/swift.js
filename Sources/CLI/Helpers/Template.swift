import Foundation

/// The Next.js starter that hosts generated TSX, fetched from a pinned tag of swiftjs-templates.
enum Template {
    static let repository = "https://github.com/atpugvaraa/swiftjs-templates"
    static let tag = "v0.2.1"

    /// Fails with an actionable message when Bun is missing.
    static func requireBun() throws {
        do {
            try shell("command -v bun >/dev/null")
        } catch {
            throw ShellError(
                command: "bun not found. Install it from https://bun.sh, then re-run.",
                status: 127)
        }
    }

    /// Copies `starter/` from the pinned template tag into `runtimeDir` and installs its dependencies.
    static func scaffold(into runtimeDir: URL) throws {
        try requireBun()
        let checkout = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftjs-template-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: checkout) }

        print("Fetching template \(tag)...")
        try shell(
            "git -c advice.detachedHead=false clone --quiet --depth 1 --branch \(tag) \(repository) \(quoted(checkout.path))"
        )
        try FileManager.default.copyItem(
            at: checkout.appendingPathComponent("starter"), to: runtimeDir)

        print("Installing runtime dependencies...")
        try shell("cd \(quoted(runtimeDir.path)) && bun install")
    }
}

/// Single-quotes `path` for zsh.
func quoted(_ path: String) -> String {
    "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
