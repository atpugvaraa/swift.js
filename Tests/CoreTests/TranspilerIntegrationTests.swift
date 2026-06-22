import XCTest

@testable import Core

final class TranspilerIntegrationTests: XCTestCase {
    func testTranspilerRendersBasicSwiftUIView() {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("Hello")
                }
            }
            """

        let transpiler = Transpiler()
        let output = transpiler.transpile(source)

        XCTAssertTrue(output.contains("export default function Page()"))
        XCTAssertTrue(output.contains("<Text"))
        XCTAssertTrue(output.contains("content"))
    }

    func testTranspilerReportsUnsupportedCapabilitiesWithoutImportingThem() {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    List {
                        Text("Hello").shadow(radius: 4)
                    }
                }
            }
            """

        let transpiler = Transpiler()
        let output = transpiler.transpile(source)

        XCTAssertTrue(output.contains("import { Text } from '@swiftjs/runtime';"))
        XCTAssertFalse(output.contains("import { List"))
        XCTAssertTrue(output.contains("// ⚠️ Unsupported runtime component: List"))
        XCTAssertTrue(output.contains("// ⚠️ Unsupported modifier: shadow"))
    }
}
