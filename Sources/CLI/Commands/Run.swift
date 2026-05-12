//
//  Run.swift
//  swift.js
//
//  Created by Aarav Gupta on 17/12/25.
//

import ArgumentParser
import Core
import Foundation
#if canImport(Darwin)
import Darwin
#endif

nonisolated(unsafe) var activeServerTask: Process?

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run the project")

    func run() throws {
        try DependencyManager.ensureAll()
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)

        // 1. Verify Project
        guard fm.fileExists(atPath: cwd.appendingPathComponent("Package.swift").path) else {
            print("Not a swift.js compatible project (missing Package.swift)")
            return
        }

        // 2. Read Config (if present)
        // The Go CLI places the config inside the scaffolding target (e.g. 'dist/')
        if let config = SwiftJSConfig.load(from: cwd) ?? SwiftJSConfig.load(from: cwd.appendingPathComponent("dist")) {
            print(
                "📦 Project: \(config.name) (template \(config.versions.template), runtime \(config.versions.runtime))"
            )
        } else {
            print(
                "⚠️  No swiftjs.config.json found. Running with defaults (legacy project).")
        }

        // 3. Locate Runtime
        // User requested dist/ folder.
        let runtimeDir = cwd.appendingPathComponent("dist")
        let runtimeSrc = runtimeDir.appendingPathComponent("src")

        if !fm.fileExists(atPath: runtimeDir.path) {
            print("Runtime missing. Attempting to repair...")
            let binary = ToolchainManager.binaryPath()
            try shell("\(binary) new \(runtimeDir.path) --template starter")
            print("Installing runtime dependencies...")
            try shell("cd \(runtimeDir.path) && bun install")
        }

        // 4. Traverse & Transpile (1:1 Mapping)
        print("Transpiling Sources...")
        let sourcesDir = cwd.appendingPathComponent("Sources")

        if let enumerator = fm.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey])
        {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    // Calculate relative path
                    // Sources/App/Page.swift -> App/Page.swift
                    let relativePath = fileURL.path.replacingOccurrences(
                        of: sourcesDir.path + "/", with: "")

                    // Map to Target
                    // dist/src/ + app/Page.tsx
                    var targetPath = relativePath
                        .replacingOccurrences(of: ".swift", with: ".tsx")

                    targetPath = targetPath.replacingOccurrences(
                        of: "App/",
                        with: "app/"
                    )
                    let destURL = runtimeSrc.appendingPathComponent(targetPath)

                    // Ensure directory exists
                    try fm.createDirectory(
                        at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                    // Transpile
                    print("   📄 \(relativePath) -> \(targetPath)")
                    let swiftCode = try String(contentsOf: fileURL, encoding: .utf8)
                    let transpiler = Transpiler()
                    let tsxCode = transpiler.transpile(swiftCode)

                    try tsxCode.write(to: destURL, atomically: true, encoding: .utf8)
                }
            }
        }

        // 5. Prettier & ESLint
        print("Formatting code...")
        try shell("cd \(runtimeDir.path) && bun x prettier --write src/")

        // 6. Run Bun
        print("Starting Server...")
        let task = Process()
        activeServerTask = task

        signal(SIGINT) { _ in
            print("\n🛑 Stopping server...")
            activeServerTask?.terminate()
            #if canImport(Darwin)
            Darwin.exit(0)
            #else
            Foundation.exit(0)
            #endif
        }
        signal(SIGTERM) { _ in
            activeServerTask?.terminate()
            #if canImport(Darwin)
            Darwin.exit(0)
            #else
            Foundation.exit(0)
            #endif
        }
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bun", "dev"]
        task.currentDirectoryURL = runtimeDir
        
        var env = ProcessInfo.processInfo.environment
        env["BROWSERSLIST_IGNORE_OLD_DATA"] = "true"
        task.environment = env
        
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError

        try task.run()
        task.waitUntilExit()
    }
}
