//
//  DependencyManager.swift
//  swiftjs
//

import Foundation

public struct DependencyManager {

    /// Entry point to ensure all critical dependencies are present before continuing
    public static func ensureAll() throws {
        try ensureBun()
        try ToolchainManager.ensureBinary()
    }

    /// Checks for Bun and prompts installation if missing
    private static func ensureBun() throws {
        if !isInstalled("bun") {
            print(
                "⚠️ 'bun' is required to bundle and run the web runtime, but it is not installed.")
            print("Would you like to install Bun now? [y/N]: ", terminator: "")

            if let input = readLine(),
                input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "y"
            {
                print("Installing Bun...")
                try shell("curl -fsSL https://bun.sh/install | bash")
                print("✅ Bun installed successfully.")
                // Note: The user may need to restart their shell for PATH updates, but ~/.bun/bin is usually accessible or the user can proceed.
            } else {
                print("❌ Bun installation cancelled. Exiting...")
                exit(1)
            }
        }
    }

    /// Helper to check if a command exists in the user's PATH
    private static func isInstalled(_ command: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        task.standardOutput = nil
        task.standardError = nil
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
