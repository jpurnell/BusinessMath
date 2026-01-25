# Documentation Examples

This directory contains test files that serve as the **single source of truth** for all code examples in the BusinessMath documentation.

## Purpose

Documentation examples often drift from reality as APIs evolve. This directory solves that problem by ensuring every code example in the documentation:

1. ✅ **Compiles** without errors
2. ✅ **Runs** successfully in tests
3. ✅ **Matches** the actual API signatures
4. ✅ **Demonstrates** real, working patterns

## How It Works

### 1. Write Tests First

All documentation examples start as passing tests:

```swift
@Suite("Error Handling Documentation Examples")
struct ErrorHandlingExamples {

    @Test("E001: Invalid Input - Negative discount rate")
    func invalidInputNegativeRate() throws {
        // Source: ErrorHandlingGuide.md - Invalid Input section
        let cashFlows = [-1000.0, 300.0, 400.0, 500.0]

        #expect(throws: BusinessMathError.self) {
            _ = try npv(discountRate: -0.5, cashFlows: cashFlows)
        }
    }
}
```

### 2. Extract to Documentation

Copy **verbatim** from passing tests into documentation:

```markdown
## Invalid Input (E001)

​```swift
// Source: ErrorHandlingExamples.swift - invalidInputNegativeRate()
let cashFlows = [-1000.0, 300.0, 400.0, 500.0]

#expect(throws: BusinessMathError.self) {
    _ = try npv(discountRate: -0.5, cashFlows: cashFlows)
}
​```
```

### 3. Tag with Source

Every code example **must** include a source comment:

```swift
// Source: ErrorHandlingExamples.swift - invalidInputNegativeRate()
```

This creates a **traceable link** from documentation back to verified tests.

## Files

| File | Documentation Target | Status |
|------|---------------------|--------|
| `ErrorHandlingExamples.swift` | `1.7-ErrorHandlingGuide.md` | ✅ Complete |
| `FluentAPIExamples.swift` | `1.4-FluentAPIGuide.md` | 🔄 Planned |
| `TimeSeriesExamples.swift` | `2.3-TimeSeriesGuide.md` | 🔄 Planned |
| `OptimizationExamples.swift` | `4.1-OptimizationGuide.md` | 🔄 Planned |

## Rules

### MUST Follow

1. **Tests come first** - Write working tests before documentation
2. **Copy verbatim** - Don't modify examples when copying to docs
3. **Tag sources** - Every example must have `// Source: FileName.swift - methodName()`
4. **Use @Test suite** - Organize examples in test suites matching doc structure
5. **Verify compilation** - All tests must pass before updating docs

### MUST NOT Do

1. ❌ Write documentation examples that haven't been tested
2. ❌ Modify examples when copying from tests to docs
3. ❌ Leave examples without source tags
4. ❌ Use placeholder or aspirational APIs that don't exist yet

## Example Structure

```swift
@Suite("Feature Name Documentation Examples")
struct FeatureNameExamples {

    // MARK: - Basic Usage

    @Test("Basic example 1")
    func basicExample1() throws {
        // Source: FeatureGuide.md - Basic Usage section
        let result = Feature.doSomething()
        #expect(result != nil)
    }

    @Test("Basic example 2")
    func basicExample2() throws {
        // Source: FeatureGuide.md - Basic Usage section
        let feature = Feature()
        #expect(feature.isValid)
    }

    // MARK: - Advanced Patterns

    @Test("Advanced pattern - error handling")
    func advancedErrorHandling() throws {
        // Source: FeatureGuide.md - Advanced Patterns section
        do {
            try Feature.riskyOperation()
        } catch {
            #expect(error is FeatureError)
        }
    }

    // MARK: - Working Examples for Documentation

    /// Complete working example for basic usage
    /// Source tag: basicUsageExample
    static func basicUsageExample() {
        // This can be copied directly into documentation
        let feature = Feature()
        feature.configure()
        feature.run()
    }
}
```

## Workflow

### Adding New Documentation

1. **Create test file** in `Tests/BusinessMathTests/DocumentationExamples/`
2. **Write passing tests** for each code example
3. **Run tests**: `swift test --filter ExampleSuiteName`
4. **Extract examples** to documentation with source tags
5. **Verify links** between tests and docs are correct

### Updating Existing Documentation

1. **Update test file first** with new API
2. **Verify tests pass**
3. **Update documentation** with changes from test file
4. **Keep source tags** pointing to correct test methods

### Catching Drift

If documentation seems wrong:

1. Check the test file named in the source tag
2. Verify the test still passes
3. Compare test code to documentation example
4. Update documentation if mismatch found

## Benefits

- 📖 **Accurate** - Examples always match current API
- 🔒 **Trustworthy** - Readers can trust examples compile and run
- 🚀 **Maintainable** - API changes caught by failing tests
- 🔍 **Traceable** - Easy to find test for any doc example
- ⚡ **Fast updates** - Copy-paste from tests to docs

## See Also

- `CONTRIBUTING.md` - Contribution guidelines including documentation policy
- `Tests/BusinessMathTests/DocumentationExamples/ErrorHandlingExamples.swift` - Reference implementation
