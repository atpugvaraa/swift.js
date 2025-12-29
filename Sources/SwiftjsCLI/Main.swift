// The Swift Programming Language
// https://docs.swift.org/swift-book

/// iOS Plan: Use SwiftParser on device
/// save tsx files on device and push to github repo
/// use github workflows? to run create-swiftjs-app and swiftjs?
/// make it push to github repo remotely
/// use vercel to publish site and setup ci/cd

/// macOS Plan: swift parser -> create-swiftjs-app -> generate tsx files ->  save files -> bun install -> bun dev
/// you should have a working website i guess

/// "bundle" create-swiftjs-app just in case
/// "install bun/prompt to"

import Foundation
import ArgumentParser
import SwiftjsCore

@main
struct swiftjs: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "SwiftUI on Web Toolchain",
        version: "0.1.0",
        subcommands: [New.self, Run.self],
        defaultSubcommand: Run.self
    )
}
