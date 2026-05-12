//
//  New.swift
//  swift.js
//
//  Created by Aarav Gupta on 17/12/25.
//

import ArgumentParser
import Foundation

struct New: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a new swift.js project")

    @Argument(help: "The name of the project")
    var name: String

    func run() throws {
        try DependencyManager.ensureAll()

        let fileManager = FileManager.default
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let projectDir = cwd.appendingPathComponent(name)

        // 1. Create Project Folder
        print("Creating project \(name)...")
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // 2. Generate Swift Source Structure
        // We need a 'Sources/App' folder to match Next.js 'src/app'
        let sourcesDir = projectDir.appendingPathComponent("Sources/App")
        try fileManager.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // 3. Write Boilerplate Swift Files
        try writeTemplateFiles(to: projectDir)

        // 4. Scaffold Runtime (.build folder)
        // Note: We use dist to avoid conflict with SPM's internal .build
        let runtimeDir = projectDir.appendingPathComponent("dist")
        print("Scaffolding Web Runtime...")

        // Run create-swiftjs-app using the managed binary
        let binary = ToolchainManager.binaryPath()
        try shell("\(binary) new \(runtimeDir.path) --template starter")

        print("\n Project \(name) ready!")
        print("cd \(name) && swiftjs run")
    }

    private func writeTemplateFiles(to dir: URL) throws {
        // A. Package.swift
        let packageSwift = """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "\(name)",
                platforms: [.macOS(.v13)],
                dependencies: [],
                targets: [.executableTarget(name: "App", path: "Sources")]
            )
            """
        try packageSwift.write(
            to: dir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        // B. Sources/App/Page.swift
        let pageSwift = """
            import SwiftUI

            struct Page: View {
                @State var count = 0
                
                var body: some View {
                    VStack(spacing: 20) {
                        Text("Welcome to SwiftJS")
                            .font(.largeTitle)
                        
                        Text("Count: \\(count)")
                        
                        Button("Increment") {
                           count += 1
                        }
                    }
                }
            }
            """
        try pageSwift.write(
            to: dir.appendingPathComponent("Sources/App/Page.swift"), atomically: true,
            encoding: .utf8)

        // C. .gitignore
        let gitignore = """
            .build
            .swiftpm
            dist
            """
        try gitignore.write(
            to: dir.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    }
}
