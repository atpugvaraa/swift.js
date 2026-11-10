# swift.js
the declarative js ui framework* your girl dreams about.

I'd like to call it SwiftUI for the web <3

to install:
```sh
brew tap atpugvaraa/atpugvaraa
brew install swiftjs
```

to use:
```sh
swiftjs new ProjectName # creates swiftjs application
```

to run app:
```sh
cd ProjectName && swiftjs run # runs application
```


> [!NOTE]
> *it is not really a framework but a **transpiler** from swift to react allowing to create dynamic websites using SwiftUI's syntax but for the web

## How it works

You write ordinary SwiftUI. `swiftjs run`:

1. builds your package with `swift build`, so only Swift that Apple's compiler accepts is transpiled;
2. transpiles every file in `Sources/` to TSX in `dist/src/`;
3. type-checks the generated TSX with `tsc`;
4. starts the Next.js dev server.

Valid SwiftUI that swift.js can't translate yet stops the run with `file:line:column: error: not yet supported: …` instead of producing broken output.

Project layout: a file ending in `Page.swift` is its folder's route (`Sources/App/Page.swift` → `/`, `Sources/App/about/AboutPage.swift` → `/about`). Other files (views, models) are shared and imported where used.

## Supported SwiftUI (so far)

- **Views:** `Text`, `Button` (title + action, or `action:` + label), `VStack`/`HStack`/`ZStack`, `Spacer`, `ScrollView`, `List`, `ForEach` (Identifiable, `id: \.self`/`\.property`, `0..<n`), `NavigationStack` + `.navigationTitle`, `TextField`/`SecureField`/`Toggle` with `$state` bindings, `Image(systemName:)` (as [Lucide](https://lucide.dev) icons), `if`/`else`.
- **Modifiers:** `.padding`, `.font` (text styles), `.bold`, `.fontWeight`, `.italic`, `.underline`, `.strikethrough`, `.foregroundStyle`/`.foregroundColor`, `.background`, `.opacity`, `.cornerRadius`, `.frame`, `.disabled`, `.onTapGesture`.
- **Swift:** `@State` (including arrays and nested updates like `todos[i].done.toggle()`), computed properties, methods, View parameters and `let` constants, model structs with memberwise initializers, closures, `if let`/`guard let`, operators with Swift precedence, `Int` division, and common `Array`/`String` members (`count`, `isEmpty`, `filter`, `map`, `contains`, `first(where:)`, `firstIndex(where:)` in `if let`, `append`, `remove(at:)`, `removeAll(where:)` …).

Anything else is reported with its location, never silently dropped.

## Acknowledgements

Generated pages render with [SwiftUI.js](https://github.com/swiftuijs/ui) (`@swiftuijs/ui`), a SwiftUI-inspired React component library by the swiftuijs team, used under the MIT License (Copyright (c) 2022 swiftuijs). See its [documentation](https://swiftuijs.evecalm.com/docs/) for the components and props that swift.js output targets.
