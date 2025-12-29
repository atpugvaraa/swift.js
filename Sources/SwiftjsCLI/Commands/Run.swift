//
//  Run.swift
//  swift.js
//
//  Created by Aarav Gupta on 17/12/25.
//

// Sources/SwiftJSCLI/Commands/Run.swift
import ArgumentParser
import Foundation
import SwiftjsCore

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run the project")

    func run() throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        
        // 1. Verify Project
        guard fm.fileExists(atPath: cwd.appendingPathComponent("Package.swift").path) else {
            print("❌ Not a SwiftJS project (missing Package.swift)")
            return
        }
        
        // 2. Locate Runtime
        // User requested .build/ folder. We use .build/web to be safe.
        let runtimeDir = cwd.appendingPathComponent(".build/web")
        let runtimeSrc = runtimeDir.appendingPathComponent("src")
        
        if !fm.fileExists(atPath: runtimeDir.path) {
            print("⚠️ Runtime missing. Attempting to repair...")
            // Call create-swiftjs-app if needed
        }
        
        // 3. Traverse & Transpile (1:1 Mapping)
        print("⚡️ Transpiling Sources...")
        let sourcesDir = cwd.appendingPathComponent("Sources")
        
        if let enumerator = fm.enumerator(at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    // Calculate relative path
                    // Sources/App/page.swift -> App/page.swift
                    let relativePath = fileURL.path.replacingOccurrences(of: sourcesDir.path + "/", with: "")
                    
                    // Map to Target
                    // .build/web/src/ + App/page.tsx
                    let targetPath = relativePath.replacingOccurrences(of: ".swift", with: ".tsx")
                    let destURL = runtimeSrc.appendingPathComponent(targetPath)
                    
                    // Ensure directory exists
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    
                    // Transpile
                    print("   📄 \(relativePath) -> \(targetPath)")
                    let swiftCode = try String(contentsOf: fileURL, encoding: .utf8)
                    let transpiler = Transpiler()
                    let tsxCode = transpiler.transpile(swiftCode)
                    
                    try tsxCode.write(to: destURL, atomically: true, encoding: .utf8)
                }
            }
        }
        
        // 4. Prettier & ESLint
        print("🎨 Formatting code...")
        try shell("cd \(runtimeDir.path) && bun x prettier --write src/")
        // try shell("cd \(runtimeDir.path) && bun x eslint src/") // Optional: Fail on errors?
        
        // 5. Run Bun
        print("🌍 Starting Server...")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bun", "dev"]
        task.currentDirectoryURL = runtimeDir
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError
        
        try task.run()
        task.waitUntilExit()
    }
    
    private func shell(_ command: String) throws {
        let task = Process()
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        try task.run()
        task.waitUntilExit()
    }
}
