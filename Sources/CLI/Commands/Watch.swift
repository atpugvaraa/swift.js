import ArgumentParser
import Core
import Foundation

struct Watch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Watch a directory for changes and re-transpile"
    )

    @Option(name: .shortAndLong, help: "Input directory containing Swift files")
    var input: String = "."

    @Option(name: .shortAndLong, help: "Output directory for generated TSX files")
    var output: String = "./src/generated"

    func run() throws {
        let watcher = FileWatcher()
        let transpiler = Transpiler()

        print("👀 Watching \(input) for changes...")
        print("🚀 Outputting to \(output)")

        watcher.onChange = { path in
            print("📝 File changed: \(path)")
            // Perform transpile
            // For simplicity in this CLI, we re-run the logic from Run command
            // or a dedicated transpile function
            self.transpileAll(in: input, to: output, using: transpiler)
        }

        try watcher.watch(directory: input)

        // Initial run
        self.transpileAll(in: input, to: output, using: transpiler)

        // Keep the process alive
        RunLoop.main.run()
    }

    private func transpileAll(
        in inputDir: String, to outputDir: String, using transpiler: Transpiler
    ) {
        let fileManager = FileManager.default
        let inputURL = URL(fileURLWithPath: inputDir)
        let outputURL = URL(fileURLWithPath: outputDir)

        // Ensure output directory exists
        try? fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let enumerator = fileManager.enumerator(at: inputURL, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "swift" {
                do {
                    let source = try String(contentsOf: fileURL)
                    let result = transpiler.transpile(source)

                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    let targetURL = outputURL.appendingPathComponent("\(fileName).tsx")

                    try result.write(to: targetURL, atomically: true, encoding: .utf8)
                    print("✅ Transpiled \(fileURL.lastPathComponent) -> \(fileName).tsx")
                } catch {
                    print("❌ Error transpiling \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
    }
}
