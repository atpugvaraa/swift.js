//
//  SwiftJSConfig.swift
//  swiftjs
//
//  Reads and represents the swiftjs.config.json lockfile.
//  Written by create-swiftjs-app during project scaffolding.
//

import Foundation

public struct SwiftJSConfig: Codable {
    public let name: String
    public let versions: Versions

    public struct Versions: Codable {
        public let template: String
        public let runtime: String
        public let createSwiftjsApp: String

        enum CodingKeys: String, CodingKey {
            case template
            case runtime
            case createSwiftjsApp = "create_swiftjs_app"
        }
    }

    /// Attempt to load config from a project directory.
    /// Returns nil if the file doesn't exist or can't be parsed (legacy project).
    public static func load(from projectDir: URL) -> SwiftJSConfig? {
        let configPath = projectDir.appendingPathComponent("swiftjs.config.json")
        guard let data = try? Data(contentsOf: configPath) else { return nil }
        return try? JSONDecoder().decode(SwiftJSConfig.self, from: data)
    }
}
