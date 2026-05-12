//
//  ToolchainManager.swift
//  swiftjs
//
//  Manages the create-swiftjs-app binary lifecycle.
//  Downloads, updates, and locates the Go binary in ~/.swiftjs/bin/
//

import Foundation

public struct ToolchainManager {
    /// The directory where managed binaries live
    private static let binDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".swiftjs/bin")
    }()

    private static let versionFile: URL = {
        return binDir.appendingPathComponent("version.txt")
    }()

    /// The expected path to the managed binary
    public static func binaryPath() -> String {
        return binDir.appendingPathComponent("create-swiftjs-app").path
    }

    /// Ensure the binary exists in ~/.swiftjs/bin/. Download or update if missing or outdated.
    public static func ensureBinary() throws {
        let fm = FileManager.default
        let path = binaryPath()

        // Create ~/.swiftjs/bin/ if it doesn't exist
        if !fm.fileExists(atPath: binDir.path) {
            try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
        }

        let latestTag = checkForUpdate()
        var needsUpdate = false
        
        if !fm.fileExists(atPath: path) {
            needsUpdate = true
            print("📦 Downloading create-swiftjs-app...")
        } else if let latestTag = latestTag {
            let localVersion = try? String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            if localVersion != latestTag {
                needsUpdate = true
                print("📦 Update available: \(latestTag). Downloading...")
            }
        }

        if needsUpdate {
            try downloadBinary(to: path)
            if let latestTag = latestTag {
                 try latestTag.write(to: versionFile, atomically: true, encoding: .utf8)
            }
            print("✅ create-swiftjs-app installed/updated to ~/.swiftjs/bin/")
        }
    }

    /// Download the latest pre-compiled binary from GitHub Releases
    private static func downloadBinary(to destination: String) throws {
        // Determine architecture
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "amd64"
        #endif

        let downloadURL = URL(
            string:
                "https://github.com/atpugvaraa/create-swiftjs-app/releases/latest/download/create-swiftjs-app-darwin-\(arch)"
        )!

        // Synchronous download using URLSession
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var downloadError: Error?
        nonisolated(unsafe) var downloadedData: Data?

        let task = URLSession.shared.dataTask(with: downloadURL) { data, response, error in
            if let error = error {
                downloadError = error
                semaphore.signal()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                downloadError = ToolchainError.invalidResponse
                semaphore.signal()
                return
            }

            guard httpResponse.statusCode == 200 else {
                downloadError = ToolchainError.downloadFailed(statusCode: httpResponse.statusCode)
                semaphore.signal()
                return
            }

            downloadedData = data
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = downloadError {
            throw error
        }

        guard let data = downloadedData else {
            throw ToolchainError.noData
        }

        // Write binary to disk
        let destURL = URL(fileURLWithPath: destination)
        try data.write(to: destURL)

        // Make it executable (chmod +x)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", destination]
        try process.run()
        process.waitUntilExit()
    }

    /// Check if a newer version of the binary is available
    public static func checkForUpdate() -> String? {
        // Query GitHub API for the latest tag
        let url = URL(
            string: "https://api.github.com/repos/atpugvaraa/create-swiftjs-app/tags")!
        guard let data = try? Data(contentsOf: url),
            let tags = try? JSONDecoder().decode([GitHubTag].self, from: data),
            let latest = tags.first
        else {
            return nil
        }
        return latest.name
    }
}

// MARK: - Supporting Types

enum ToolchainError: LocalizedError {
    case invalidResponse
    case downloadFailed(statusCode: Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .downloadFailed(let code):
            return "Download failed with HTTP \(code). Have you pushed a release to GitHub?"
        case .noData:
            return "No data received from GitHub"
        }
    }
}

struct GitHubTag: Codable {
    let name: String
}
