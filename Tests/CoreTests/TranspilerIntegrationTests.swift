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
                    TabView {
                        Text("Hello").shadow(radius: 4)
                        Image(systemName: "star")
                    }
                }
            }
            """

        XCTAssertThrowsError(try Transpiler().transpile(source, fileName: "Page.swift")) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("Page.swift:5:9: error: not yet supported: view TabView"), message)
            XCTAssertTrue(message.contains("Page.swift:6:26: error: not yet supported: modifier .shadow"), message)
            XCTAssertTrue(message.contains("Page.swift:7:13: error: not yet supported: view Image"), message)
            XCTAssertFalse(message.contains("argument"), "unsupported views report once:\n\(message)")
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
                "Page.swift:17:26: error: not yet supported: modifier .onTapGesture",
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

    func testAlignmentsMapToSwiftUIJSNames() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    VStack(alignment: .trailing) {
                        ZStack(alignment: .bottom) { Text("A") }
                    }
                }
            }
            """

        let output = try Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"<VStack alignment={"trailing"}>"#), output)
        XCTAssertTrue(output.contains(#"<ZStack alignment={"bottom"}>"#), output)

        let unsupported = source.replacingOccurrences(of: ".bottom", with: ".topLeading")
        XCTAssertThrowsError(try Transpiler().transpile(unsupported, fileName: "Page.swift")) { error in
            XCTAssertTrue("\(error)".contains("Page.swift:6:31: error: not yet supported: alignment .topLeading"), "\(error)")
        }
    }

    func testModifiersMapToCSSAndRejectUnsupportedForms() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("Hi")
                        .bold()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .opacity(0.5)
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "fontWeight: 700", #"color: "var(--sw-color-label-secondary)""#,
            #"background: "var(--sw-color-blue)""#, #"width: "100%""#, "minHeight: 44", #"justifyContent: "center""#,
            "borderRadius: 8", "opacity: 0.5",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }

        let unsupported = """
            import SwiftUI

            struct Page: View {
                let tint = Color.red
                var body: some View {
                    VStack {
                        Text("Hi").padding(.horizontal).foregroundStyle(tint)
                        Text("Order").background(.red).padding()
                    }
                }
            }
            """
        XCTAssertThrowsError(try Transpiler().transpile(unsupported, fileName: "Page.swift")) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("Page.swift:7:23: error: not yet supported: .padding(.horizontal)"), message)
            XCTAssertTrue(message.contains("Page.swift:7:44: error: not yet supported: .foregroundStyle(tint)"), message)
            XCTAssertTrue(message.contains("Page.swift:8:43: error: not yet supported: .padding in this position"), message)
        }
    }

    func testBodyWithSeveralRootViewsIsReported() {
        let twoRootViews = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    Text("One")
                    Text("Two")
                }
            }
            """
        XCTAssertThrowsError(try Transpiler().transpile(twoRootViews)) { error in
            XCTAssertTrue("\(error)".contains("not yet supported: body with 2 statements"), "\(error)")
        }
    }

    func testStateBindingsBecomeValueAndSetter() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var draft = ""
                @State private var password = ""
                @State private var showDone = true

                var body: some View {
                    VStack {
                        TextField("New todo", text: $draft)
                        SecureField("Password", text: $password)
                        Toggle("Show completed", isOn: $showDone)
                    }
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            #"<TextField placeholder={"New todo"} value={draft} onChange={(e) => setDraft(e.target.value)} />"#,
            #"<SecureField placeholder={"Password"} value={password} onChange={(e) => setPassword(e.target.value)} />"#,
            "<Text>\n{\"Show completed\"}\n</Text>",
            #"<Toggle aria-label={"Show completed"} isOn={showDone} onChange={setShowDone} />"#,
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testBindingToNonStateIsReported() {
        let source = """
            import SwiftUI

            struct Page: View {
                var body: some View {
                    TextField("Name", text: .constant("x"))
                }
            }
            """

        XCTAssertThrowsError(try Transpiler().transpile(source, fileName: "Page.swift")) { error in
            XCTAssertTrue("\(error)".contains("Page.swift:5:33: error: not yet supported: binding .constant(\"x\")"), "\(error)")
        }
    }
}
