import SwiftParser
import SwiftSyntax
import XCTest

@testable import Core

final class HandlerMigrationTests: XCTestCase {
    func testTextHandlerRendersThroughIRBridge() {
        let source = Parser.parse(source: "Text(\"Hello\")")
        guard let call = source.statements.first?.item.as(FunctionCallExprSyntax.self) else {
            return XCTFail("Expected function call syntax")
        }

        let handler = TextHandler()
        let result = handler.handle(node: call, props: [], context: Transpiler())

        XCTAssertTrue(result.output.contains("<Text"))
        XCTAssertTrue(result.output.contains("content"))
        XCTAssertFalse(result.traverseChildren)
    }
}
