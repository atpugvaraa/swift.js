import XCTest

@testable import Core

final class TranspilerIntegrationTests: XCTestCase {
    func testTranspilerRendersBasicSwiftUIView() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("Hello")
                }
            }
            """

        let output = try Transpiler().transpile(source)

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

        XCTAssertThrowsError(try Transpiler().transpile(source, fileName: "Page.swift")) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("Page.swift:5:9: error: not yet supported: view List"), message)
            XCTAssertTrue(message.contains("Page.swift:6:13: error: not yet supported: modifier .shadow"), message)
        }
    }

    func testValidSwiftUIThatCannotBeTranslatedFailsInsteadOfBeingDropped() {
        let source = """
            import SwiftUI

            struct Todo {
                var title: String
            }

            struct Page: View {
                @State private var count = 0

                var doubled: Int { count * 2 }

                var body: some View {
                    VStack {
                        if count > 0 {
                            Text("Positive")
                        }
                        Text("Count").onTapGesture { count += 1 }
                    }
                }

                func reset() { count = 0 }
            }
            """

        XCTAssertThrowsError(try Transpiler().transpile(source, fileName: "Page.swift")) { error in
            let message = "\(error)"
            for expected in [
                "Page.swift:3:1: error: not yet supported: top-level struct Todo",
                "Page.swift:10:5: error: not yet supported: var doubled in View Page",
                "Page.swift:14:13: error: not yet supported: if inside a view or expression",
                "Page.swift:17:40: error: not yet supported: trailing closure on .onTapGesture",
                "Page.swift:21:5: error: not yet supported: func reset in View Page",
            ] {
                XCTAssertTrue(message.contains(expected), "missing \(expected) in:\n\(message)")
            }
        }
    }

    func testFontTextStyleMapsToSwiftUIJSToken() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("Hi").font(.largeTitle)
                }
            }
            """

        let output = try Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"style={{ fontSize: "var(--sw-font-size-large-title)" }}"#), output)
        XCTAssertFalse(output.contains("data-font"), output)
        XCTAssertFalse(output.contains("Unsupported modifier: font"), output)
    }

    func testStacksDefaultToCenterAlignmentLikeSwiftUI() throws {
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

        let output = try Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"<VStack alignment={"center"}>"#), output)
        XCTAssertTrue(output.contains(#"<HStack alignment={"top"}>"#), output)
    }
}
