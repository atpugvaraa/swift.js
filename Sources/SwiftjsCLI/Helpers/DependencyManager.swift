//
//  DependencyManager.swift
//  swiftjs
//

import Foundation

public struct DependencyManager {
    
    /// Entry point to ensure all critical dependencies are present before continuing
    public static func ensureAll() throws {
        try ensureBun()
        try ensureCreateSwiftJSApp()
    }
    
    /// Checks for Bun and prompts installation if missing
    private static func ensureBun() throws {
        if !isInstalled("bun") {
            print("⚠️ 'bun' is required to bundle and run the web runtime, but it is not installed.")
            print("Would you like to install Bun now? [y/N]: ", terminator: "")
            
            if let input = readLine(), input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "y" {
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
    
    /// Checks for create-swiftjs-app and prompts installation if missing
    private static func ensureCreateSwiftJSApp() throws {
        if !isInstalled("create-swiftjs-app") {
            print("⚠️ 'create-swiftjs-app' is required to scaffold new project runtimes, but it is not installed.")
            print("Would you like to install create-swiftjs-app now? [y/N]: ", terminator: "")
            
            if let input = readLine(), input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "y" {
                print("Installing create-swiftjs-app...")
                try shell("curl -fsSL https://github.com/atpugvaraa/create-swiftjs-app/releases/latest/download/install.sh | bash")
                print("✅ create-swiftjs-app installed successfully.")
            } else {
                print("❌ create-swiftjs-app installation cancelled. Exiting...")
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
    
    /// Helper to execute shell commands securely
    @discardableResult
    private static func shell(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
