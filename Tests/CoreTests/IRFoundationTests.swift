import XCTest

@testable import Core

final class IRFoundationTests: XCTestCase {
    func testIRProgramStoresFiles() {
        let file = IRFile()
        let program = IRProgram(files: [file])
        XCTAssertEqual(program.files.count, 1)
    }

    func testIRModifierStoresEffects() {
        let modifier = IRModifier(name: "padding", arguments: [.numberLiteral(8)])
        modifier.effects = [.styleProperty(key: "padding", value: .numberLiteral(8))]
        XCTAssertEqual(modifier.name, "padding")
        XCTAssertEqual(modifier.effects.count, 1)
    }

    func testIRExpressionConstructorsWork() {
        let expression = IRExpression.functionCall(
            callee: .identifier("Text"),
            arguments: [IRArgument(label: nil, value: .stringLiteral("Hello"))]
        )

        if case .functionCall = expression {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected function call expression")
        }
    }
}
