import SwiftParser
import SwiftSyntax
import XCTest

@testable import Core

final class SnapshotTests: XCTestCase {

    /// To update snapshots, set this to true and run tests
    private let updateSnapshots = ProcessInfo.processInfo.environment["UPDATE_SNAPSHOTS"] == "1"

    private var snapshotsURL: URL {
        // Find the project root by looking for Package.swift
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path)
            {
                return url.appendingPathComponent("Tests/CoreTests/Snapshots")
            }
            url.deleteLastPathComponent()
        }
        fatalError("Could not find project root")
    }

    func testSnapshots() throws {
        let fileManager = FileManager.default
        let swiftDir = snapshotsURL.appendingPathComponent("Swift")

        // Ensure directories exist
        try fileManager.createDirectory(at: swiftDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: snapshotsURL.appendingPathComponent("IR"), withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: snapshotsURL.appendingPathComponent("TSX"), withIntermediateDirectories: true)

        let enumerator = fileManager.enumerator(at: swiftDir, includingPropertiesForKeys: nil)
        var testCount = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "swift" {
                try runSnapshotTest(for: fileURL)
                testCount += 1
            }
        }

        if testCount == 0 {
            print("⚠️ No snapshot tests found in \(swiftDir.path)")
        }
    }

    private func runSnapshotTest(for fileURL: URL) throws {
        let testName = fileURL.deletingPathExtension().lastPathComponent
        let source = try String(contentsOf: fileURL)

        let transpiler = Transpiler()
        // Here we bypass the legacy Visitor if we want to test the NEW IR pipeline specifically,
        // or just use the main transpiler which currently uses the Visitor.
        // For Phase 2, we want to validate the IR pipeline.

        let syntax = Parser.parse(source: source)
        let lowerer = FileLowerer()
        let irFile = lowerer.lower(syntax)

        let emitter = FileEmitter()
        let tsxOutput = emitter.emit(irFile)

        // 1. Validate IR (Snapshot comparison)
        // We'll use a simple description-based dump for IR
        let irDump = irFile.debugDescription
        let irSnapshotURL = snapshotsURL.appendingPathComponent("IR/\(testName).txt")

        if updateSnapshots || !FileManager.default.fileExists(atPath: irSnapshotURL.path) {
            try irDump.write(to: irSnapshotURL, atomically: true, encoding: .utf8)
        } else {
            let existingIR = try String(contentsOf: irSnapshotURL)
            XCTAssertEqual(irDump, existingIR, "IR snapshot mismatch for \(testName)")
        }

        // 2. Validate TSX (Snapshot comparison)
        let tsxSnapshotURL = snapshotsURL.appendingPathComponent("TSX/\(testName).tsx")

        if updateSnapshots || !FileManager.default.fileExists(atPath: tsxSnapshotURL.path) {
            try tsxOutput.write(to: tsxSnapshotURL, atomically: true, encoding: .utf8)
        } else {
            let existingTSX = try String(contentsOf: tsxSnapshotURL)
            XCTAssertEqual(tsxOutput, existingTSX, "TSX snapshot mismatch for \(testName)")
        }
    }
}

// MARK: - Debug Description Helpers

extension IRFile {
    var debugDescription: String {
        var out = "File:\n"
        for component in components {
            out += "  Component: \(component.name)\n"
            for state in component.stateVariables {
                out += "    State: \(state.name) (\(state.inferredType))\n"
            }
            if let body = component.body {
                out += "    Body: \(body.componentName)\n"
            }
        }
        return out
    }
}
