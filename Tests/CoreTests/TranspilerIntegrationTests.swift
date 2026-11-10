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
                "Page.swift:17:26: error: not yet supported: modifier .onTapGesture",
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

    func testComputedPropertiesBecomeConstsBeforeReturn() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var count = 2
                var doubled: Int { count * 2 }
                var label: String {
                    return "Doubled: \\(doubled)"
                }

                var body: some View {
                    Text(label)
                }
            }
            """

        let output = try Transpiler().transpile(source)

        XCTAssertTrue(output.contains("const doubled = count * 2;"), output)
        XCTAssertTrue(output.contains("const label = `Doubled: ${doubled}`;"), output)
        XCTAssertLessThan(output.range(of: "const label")!.lowerBound, output.range(of: "return (")!.lowerBound)
    }

    func testMethodsBecomeTypedFunctionsWithStateSetters() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var count = 0
                @State private var note = ""

                var body: some View {
                    Button("Add") { add(5, label: "five") }
                }

                func add(_ amount: Int, label: String) {
                    if amount > 0 {
                        count += amount
                    } else {
                        reset()
                    }
                    note = label
                }

                func reset() {
                    count = 0
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "const add = (amount: number, label: string) => {",
            "setCount((count) => count + amount);",
            "reset();",
            "setNote(label);",
            "const reset = () => {",
            "add(5, \"five\");",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testIfLetConditionIsReported() {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var name: String? = nil
                var body: some View {
                    Button("Go") { go() }
                }
                func go() {
                    if let n = name { name = n + "!" }
                }
            }
            """

        XCTAssertThrowsError(try Transpiler().transpile(source, fileName: "Page.swift")) { error in
            XCTAssertTrue("\(error)".contains("Page.swift:9:12: error: not yet supported: condition let n = name"), "\(error)")
        }
    }

    func testViewParametersBecomeTypedPropsWithCallSites() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var taps = 0

                var body: some View {
                    VStack {
                        Row(title: "Taps", count: taps) { taps += 1 }
                        Header()
                    }
                }
            }

            struct Row: View {
                let title: String
                var count: Int
                let onTap: () -> Void

                var body: some View {
                    Button("\\(title): \\(count)") { onTap() }
                }
            }

            struct Header: View {
                var body: some View { Text("Header") }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            #"<Row title={"Taps"} count={taps} onTap={() => setTaps((taps) => taps + 1)} />"#,
            "<Header />",
            "export const Row = ({ title, count, onTap }: { title: string; count: number; onTap: () => void }) => {",
            "onTap();",
            "import { Button, Text, VStack } from '@swiftuijs/ui';",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testOperatorsFoldWithSwiftPrecedence() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var a = 1
                var sum: Int { a + 2 * 3 }
                var grouped: Int { (a + 2) * 3 }
                var label: String { a == 1 ? "one" : "many" }

                var body: some View {
                    Text(a > 0 && a != 2 ? "yes" : "no")
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "const sum = a + 2 * 3;",
            "const grouped = (a + 2) * 3;",
            #"const label = a === 1 ? "one" : "many";"#,
            #"{(a > 0 && a !== 2) ? "yes" : "no"}"#,
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }

        let range = source.replacingOccurrences(of: "var sum: Int { a + 2 * 3 }", with: "var r: ClosedRange<Int> { 0...a }")
        XCTAssertThrowsError(try Transpiler().transpile(range)) { error in
            XCTAssertTrue("\(error)".contains("not yet supported: operator ..."), "\(error)")
        }
    }

    func testIfInViewContentBecomesConditionalJSX() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var count = 0

                var body: some View {
                    VStack {
                        if count > 0 {
                            Text("Positive")
                        }
                        if count == 0 {
                            Text("Zero")
                        } else if count < 3 {
                            Text("Few")
                        } else {
                            Text("Many")
                            Text("Really")
                        }
                    }
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "{count > 0 && <Text>",
            "{count === 0 ? <Text>",
            ": count < 3 ? <Text>",
            ": <>\n<Text>",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testForEachBecomesKeyedMap() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var names: [String] = ["Ada", "Grace"]
                @State private var showAll = true

                var body: some View {
                    VStack {
                        ForEach(names, id: \\.self) { name in
                            Text(name)
                        }
                        ForEach(0..<3) { i in
                            if showAll {
                                Text("Row \\(i)")
                            }
                        }
                    }
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "useState<string[]>([\"Ada\", \"Grace\"])",
            "{names.map((name) => <Text key={name}>",
            "{Array.from({ \"length\": 3 }, (_, i) => i).map((i) => showAll && <Text key={i}>",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
        XCTAssertFalse(output.contains("ForEach"), output)

        let several = source.replacingOccurrences(of: "Text(name)", with: "Text(name)\n Text(name)")
        XCTAssertThrowsError(try Transpiler().transpile(several)) { error in
            XCTAssertTrue("\(error)".contains("not yet supported: ForEach item with several views"), "\(error)")
        }
    }

    func testClosuresEmitAsArrowFunctions() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var count = 0

                var body: some View {
                    VStack {
                        Button(action: {
                            count += 1
                            count *= 2
                        }) {
                            Text("Bump")
                        }
                        Row { count = 0 }
                    }
                }
            }

            struct Row: View {
                let onReset: () -> Void
                var body: some View { Button("Reset") { onReset() } }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "onClick={() => {",
            "setCount((count) => count + 1);",
            "setCount((count) => count * 2);",
            "<Text>\n{\"Bump\"}\n</Text>",
            "onReset={() => setCount(0)}",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testStateMutationsBecomeImmutableUpdates() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var isOn = false
                @State private var names: [String] = []
                @State private var flags: [Bool] = [false, true]
                @State private var count = 0

                var body: some View {
                    VStack {
                        Button("Go") { run() }
                        Button("Clear") { names.removeAll { $0.isEmpty } }
                    }
                }

                func run() {
                    isOn.toggle()
                    names.append("x")
                    names.insert("first", at: 0)
                    names.remove(at: 1)
                    flags[1].toggle()
                    count += 1
                    count += 1
                }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "setIsOn((isOn) => !isOn);",
            #"setNames((names) => names.concat(["x"]));"#,
            #"setNames((names) => names.slice(0, 0).concat(["first"], names.slice(0)));"#,
            "setNames((names) => names.filter((_item, _index) => _index !== 1));",
            "setFlags((flags) => flags.map((_item, _index) => _index === 1 ? !_item : _item));",
            "setCount((count) => count + 1);",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }

        let stale = source.replacingOccurrences(of: "count += 1\n        count += 1", with: "count += 1\n        names.append(\"\\(count)\")")
        XCTAssertThrowsError(try Transpiler().transpile(stale)) { error in
            XCTAssertTrue("\(error)".contains("not yet supported: reading count after changing it in the same action in Page"), "\(error)")
        }
    }

    func testSwiftLibraryMembersMapToJavaScript() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var names: [String] = ["Ada", "Grace"]
                @State private var draft = ""
                @State private var id = UUID().uuidString

                var total: Int { names.count }
                var empty: Bool { names.isEmpty }
                var long: [String] { names.filter { $0.count > 3 } }
                var shout: String { names.map { $0.uppercased() }.joined(separator: ", ") }
                var hasAda: Bool { names.contains("Ada") }
                var hasShort: Bool { names.contains { $0.count < 4 } }
                var firstG: String? { names.first(where: { $0.hasPrefix("G") }) }
                var letters: Int { names.reduce(0) { $0 + $1.count } }
                var canAdd: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }
                var label: String { String(self.total) }

                var body: some View { Text(label) }
            }
            """

        let output = try Transpiler().transpile(source.replacingOccurrences(of: "UUID().uuidString", with: "\"\""))

        for expected in [
            "const total = names.length;",
            "const empty = names.length === 0;",
            "const long = names.filter(($0) => $0.length > 3);",
            #"const shout = names.map(($0) => $0.toUpperCase()).join(", ");"#,
            #"const hasAda = names.includes("Ada");"#,
            "const hasShort = names.some(($0) => $0.length < 4);",
            #"const firstG = names.find(($0) => $0.startsWith("G"));"#,
            "const letters = names.reduce(($0, $1) => $0 + $1.length, 0);",
            "const canAdd = !(draft.trim().length === 0);",
            "const label = String(total);",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }

        let index = source.replacingOccurrences(of: "names.first(where:", with: "names.firstIndex(where:")
        XCTAssertThrowsError(try Transpiler().transpile(index)) { error in
            XCTAssertTrue("\(error)".contains("not yet supported: call to names.firstIndex()"), "\(error)")
        }
    }

    func testModelStructsBecomeTypesWithMemberwiseInitializers() throws {
        let source = """
            import SwiftUI

            struct Todo: Identifiable {
                let id = UUID()
                var title: String
                var done = false
                var note: String?
            }

            struct Page: View {
                @State private var todos: [Todo] = []

                var body: some View {
                    VStack {
                        ForEach(todos) { todo in
                            Row(todo: todo)
                        }
                        Button("Add") { todos.append(Todo(title: "New", note: nil)) }
                    }
                }
            }

            struct Row: View {
                let todo: Todo
                var body: some View { Text(todo.title) }
            }
            """

        let output = try Transpiler().transpile(source)

        for expected in [
            "export type Todo = { id: string; title: string; done: boolean; note: string | null };",
            "export const Todo = (init: { title: string; done?: boolean; note?: string | null }): Todo => ({ id: crypto.randomUUID(), done: false, note: null, ...init });",
            "useState<Todo[]>([])",
            #"setTodos((todos) => todos.concat([Todo({ "title": "New", "note": null })]));"#,
            "{todos.map((todo) => <Row key={todo.id} todo={todo} />)}",
            "({ todo }: { todo: Todo })",
        ] {
            XCTAssertTrue(output.contains(expected), "missing \(expected) in:\n\(output)")
        }
    }

    func testStringLiteralsInsideInterpolationKeepQuotes() throws {
        let source = """
            import SwiftUI

            struct Page: View {
                @State private var done = false
                var body: some View {
                    Text("Status: \\(done ? "read" : "unread")")
                }
            }
            """

        let output = try Transpiler().transpile(source)

        XCTAssertTrue(output.contains(#"{`Status: ${done ? "read" : "unread"}`}"#), output)
    }
}
