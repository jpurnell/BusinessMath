# Xcode Main Entry Point Guidelines

## The Problem: @main vs Top-Level Code

Swift executable targets face a compatibility challenge between Xcode and Swift Package Manager regarding entry point code.

## Working Solutions

### Solution 1: @main with Nested Types (Universal - RECOMMENDED)

**Works in**: Xcode ✓, swift build ✓

```swift
import Foundation
import BusinessMathMCP
import MCP

// Helper enums MUST be nested inside @main struct
@main
struct BusinessMathMCPServerMain {
    /// Nested types are fine
    enum TransportMode {
        case stdio
        case http(port: Int)

        static func parse() -> TransportMode {
            let args = CommandLine.arguments
            // ...
            return .stdio
        }
    }

    static func main() async {
        do {
            // Server initialization code
            let server = Server(...)
            try await server.start(transport: StdioTransport())
            await server.waitUntilCompleted()
        } catch {
            fputs("Fatal error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

// NO top-level code
// NO extensions with protocol conformances
```

**Key Rules:**
1. **Only imports and the `@main` struct** at top level
2. **All helper types nested inside** the @main struct
3. **No extensions** (especially not `@retroactive` protocol conformances)
4. **Use `fputs()` directly** for stderr, no TextOutputStream extension
5. **No top-level variables** or executable code

### Solution 2: Top-Level Task (Xcode Only)

**Works in**: Xcode ✓, swift build ✗

```swift
import Foundation
import BusinessMathMCP
import MCP

// Helper enums can be top-level
enum TransportMode {
    case stdio
    case http(port: Int)

    static func parse() -> TransportMode {
        // ...
    }
}

struct BusinessMathMCPServerMain {
    static func main() async throws {
        // Server initialization code
        let server = Server(...)
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }
}

// Top-level code to run the async main function
Task {
    do {
        try await BusinessMathMCPServerMain.main()
    } catch {
        fputs("Fatal error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

// Keep the program running
dispatchMain()
```

**Limitations:**
- Does NOT work with `swift build` command line
- Requires building exclusively in Xcode
- The `-parse-as-library` flag does NOT fix this for swift build

## Common Pitfalls

### ❌ Top-Level Extensions
```swift
@main
struct MyServer {
    static func main() async { }
}

// This breaks Xcode!
extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        // ...
    }
}
```

**Why**: Xcode treats `@retroactive` protocol conformances as executable top-level code.

**Fix**: Use `fputs()` directly instead of creating TextOutputStream conformance.

### ❌ Top-Level Helper Types with @main
```swift
// This breaks Xcode!
enum TransportMode {
    case stdio
    case http(port: Int)
}

@main
struct MyServer {
    static func main() async { }
}
```

**Why**: Xcode is stricter than SPM about what can appear alongside `@main`.

**Fix**: Nest the enum inside the `@main` struct.

### ❌ Top-Level Variables
```swift
@main
struct MyServer {
    static func main() async { }
}

// This breaks Xcode!
nonisolated(unsafe) var standardError = FileHandle.standardError
```

**Why**: Variable initialization is executable code.

**Fix**: Use local variables inside `main()`, or use `FileHandle.standardError` directly.

## Recommended Approach

**Use Solution 1 (@main with nested types)** for all projects that need both Xcode and swift build compatibility.

Key advantages:
- Works everywhere (Xcode, swift build, CI/CD)
- Standard Swift pattern
- No special compiler flags needed
- More maintainable

## Testing Compatibility

To verify your entry point works in both environments:

```bash
# Test swift build
swift build -c release

# Test Xcode (command line)
xcodebuild -scheme businessmath-mcp-server -configuration Release

# Test Xcode (GUI)
# Open in Xcode and press Cmd+B
```

## Package.swift Configuration

For universal compatibility, DO NOT use `-parse-as-library`:

```swift
.executableTarget(
    name: "BusinessMathMCPServer",
    dependencies: ["BusinessMathMCP"],
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
        // NO .unsafeFlags(["-parse-as-library"])
    ]
),
```

The `-parse-as-library` flag only works with Xcode, not with swift build, making it pointless for fixing compatibility issues.

## Historical Context

This issue emerged when:
1. Starting with top-level `Task {}` code (works in Xcode only)
2. Trying to make it work with swift build using `-parse-as-library` (fails)
3. Trying `@main` with top-level enums (breaks Xcode)
4. Trying `@main` with top-level extensions (breaks Xcode)
5. **Final solution**: `@main` with ONLY nested types and direct `fputs()` calls

## Summary

| Approach | Xcode | swift build | Notes |
|----------|-------|-------------|-------|
| @main + nested types + no extensions | ✓ | ✓ | **RECOMMENDED** |
| @main + top-level enums | ✗ | ✓ | Xcode rejects |
| @main + top-level extensions | ✗ | ✓ | Xcode rejects |
| Top-level Task + dispatchMain() | ✓ | ✗ | Xcode-only |
| Top-level Task + -parse-as-library | ✓ | ✗ | Flag doesn't help |

## When in Doubt

If Xcode gives: `'main' attribute cannot be used in a module that contains top-level code`

1. Check for top-level enums → Move inside @main struct
2. Check for extensions → Remove and use direct function calls
3. Check for top-level variables → Move to local scope or use directly
4. Verify ONLY imports and @main struct at top level
