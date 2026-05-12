import XCTest

@testable import Core

final class CapabilityRegistryTests: XCTestCase {
    func testCapabilityRegistryTracksComponentsAndModifiers() {
        let registry = CapabilityRegistry()
        registry.registerComponent("Text")
        registry.registerModifier("padding")

        XCTAssertTrue(registry.supportsComponent("Text"))
        XCTAssertTrue(registry.supportsModifier("padding"))
        XCTAssertEqual(registry.missingComponents(from: ["Text", "Button"]), ["Button"])
        XCTAssertEqual(registry.missingModifiers(from: ["padding", "frame"]), ["frame"])
    }
}
