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
        XCTAssertTrue(output.contains("<Text>\n{\"Hello\"}\n</Text>"))
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

        XCTAssertTrue(output.contains("import { Text } from '@swiftuijs/ui';"))
        XCTAssertFalse(output.contains("import { List"))
        XCTAssertTrue(output.contains("// ⚠️ Unsupported runtime component: List"))
        XCTAssertTrue(output.contains("// ⚠️ Unsupported modifier: shadow"))
    }

    func testFontTextStyleMapsToSwiftUIJSToken() {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("Hi").font(.largeTitle)
                }
            }
            """

        let output = Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"style={{ fontSize: "var(--sw-font-size-large-title)" }}"#), output)
        XCTAssertFalse(output.contains("data-font"), output)
        XCTAssertFalse(output.contains("Unsupported modifier: font"), output)
    }

    func testStacksDefaultToCenterAlignmentLikeSwiftUI() {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    VStack {
                        HStack(alignment: .top) {
                            Text("A")
                        }
                    }
                }
            }
            """

        let output = Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"<VStack alignment={"center"}>"#), output)
        XCTAssertTrue(output.contains(#"<HStack alignment={"top"}>"#), output)
    }
}
