import SwiftParser
import SwiftSyntax
import XCTest

@testable import Core

final class LoweringTests: XCTestCase {
    func testFileLowererFindsStructComponent() {
        let source = """
            import SwiftUI

            struct Counter: View {
                var body: some View {
                    Text("Hello")
                }
            }
            """
        let syntax = Parser.parse(source: source)
        let lowerer = FileLowerer()
        let irFile = lowerer.lower(syntax)

        XCTAssertEqual(irFile.components.count, 1)
        XCTAssertEqual(irFile.components.first?.name, "Counter")
    }

    func testExpressionLowererLowersStringLiteral() {
        let source = "let value = \"Hello\""
        let syntax = Parser.parse(source: source)
        let context = LoweringContext()
        let lowerer = ExpressionLowerer(context: context)

        guard
            let binding = syntax.statements.first?.item.as(VariableDeclSyntax.self)?.bindings.first,
            let expr = binding.initializer?.value
        else {
            return XCTFail("Expected variable initializer expression")
        }

        let lowered = lowerer.lower(expr)
        if case .stringLiteral(let value) = lowered {
            XCTAssertEqual(value, "Hello")
        } else {
            XCTFail("Expected string literal expression")
        }
    }
}
