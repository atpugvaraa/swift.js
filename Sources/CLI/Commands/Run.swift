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
        try Template.requireBun()
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)

        // 1. Verify Project
        guard fm.fileExists(atPath: cwd.appendingPathComponent("Package.swift").path) else {
            throw ValidationError("Not a swift.js project: no Package.swift in \(cwd.path)")
        }

        // 2. Apple's compiler decides what is valid SwiftUI; only code it accepts is transpiled.
        print("Type-checking Swift sources...")
        try shell("swift build")

        // 3. Locate Runtime
        // User requested dist/ folder.
        let runtimeDir = cwd.appendingPathComponent("dist")
        let runtimeSrc = runtimeDir.appendingPathComponent("src")

        if !fm.fileExists(atPath: runtimeDir.path) {
            print("Runtime missing. Attempting to repair...")
            try Template.scaffold(into: runtimeDir)
        }

        // 4. Transpile all Swift files of the module together.
        //    A file ending in Page.swift is its folder's route (Swift needs unique file names):
        //    App/Page.swift -> src/app/page.tsx (/), App/about/AboutPage.swift ->
        //    src/app/about/page.tsx (/about). Other files (views, models) ->
        //    src/views/<path>.tsx, imported where used as "@/views/<path>".
        print("Transpiling Sources...")
        let sourcesDir = cwd.appendingPathComponent("Sources")
        var files: [(url: URL, target: String, input: TranspileInput)] = []
        for case let fileURL as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil) ?? .init()
        where fileURL.pathExtension == "swift" {
            let relative = String(fileURL.path.dropFirst(sourcesDir.path.count + 1))  // App/Rows/Row.swift
            let withinApp = relative.hasPrefix("App/") ? String(relative.dropFirst("App/".count)) : relative
            let stem = String(withinApp.dropLast(".swift".count))
            let target: String
            let module: String
            if fileURL.lastPathComponent.hasSuffix("Page.swift") {
                // Lowercase: Next's App Router only treats page.tsx as a route
                let folder = (withinApp as NSString).deletingLastPathComponent
                target = "app/" + (folder.isEmpty ? "" : folder + "/") + "page.tsx"
                module = "@/" + String(target.dropLast(".tsx".count))
            } else {
                target = "views/\(stem).tsx"
                module = "@/views/\(stem)"
            }
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            files.append((fileURL, target, TranspileInput(fileName: fileURL.path, source: source, module: module)))
        }

        var unsupported: [TranspileError] = []
        for (file, result) in zip(files, Transpiler().transpile(project: files.map(\.input))) {
            print("   📄 \(file.url.lastPathComponent) -> src/\(file.target)")
            switch result {
            case .success(let tsx):
                let destURL = runtimeSrc.appendingPathComponent(file.target)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try tsx.write(to: destURL, atomically: true, encoding: .utf8)
            case .failure(let error):
                unsupported.append(error)
            }
        }

        // Valid SwiftUI that swift.js cannot translate yet: report every location, write nothing broken.
        guard unsupported.isEmpty else {
            for error in unsupported {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
            }
            let count = unsupported.reduce(0) { $0 + $1.diagnostics.count }
            throw ValidationError("\(count) SwiftUI construct(s) not yet supported by swift.js")
        }

        // 5. Prettier & ESLint
        print("Formatting code...")
        try shell("cd \(quoted(runtimeDir.path)) && bun x prettier --write src/")

        // `next dev` never type-checks, so check the generated TSX before serving it.
        print("Type-checking generated TSX...")
        try shell("cd \(quoted(runtimeDir.path)) && bun x tsc --noEmit -p .")

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
