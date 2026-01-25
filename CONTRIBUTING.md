# Contributing to BusinessMath

Thank you for your interest in contributing to BusinessMath! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, professional, and constructive in all interactions. We're building a welcoming community for financial modeling and Swift development.

## How to Contribute

### Reporting Bugs

**Before submitting a bug report:**
- Check existing [Issues](https://github.com/jpurnell/BusinessMath/issues) to avoid duplicates
- Verify the bug exists in the latest version
- Test with a minimal code example

**When reporting bugs, include:**
- BusinessMath version (e.g., 2.0.0)
- Swift version and platform (iOS 16, macOS 13, etc.)
- Minimal code to reproduce the issue
- Expected vs actual behavior
- Full error messages or unexpected results

Example:
```
**BusinessMath Version:** 2.0.0
**Platform:** iOS 16.0, Xcode 15.2
**Issue:** NPV calculation returns incorrect result for negative cash flows

**Code to reproduce:**
```swift
let cashFlows = [-100.0, 50.0, -30.0, 80.0]
let result = npv(discountRate: 0.10, cashFlows: cashFlows)
// Expected: X, Got: Y
```

### Suggesting Features

We welcome feature suggestions! Please:
- Check [Discussions](https://github.com/jpurnell/BusinessMath/discussions) for similar requests
- Explain the **use case** (not just the feature)
- Provide example code showing how you'd like to use it
- Describe how it fits with existing APIs

Example:
```
**Feature:** Add support for continuous compounding in bond pricing

**Use Case:** Many zero-coupon bonds use continuous compounding, but current API only supports periodic compounding.

**Proposed API:**
```swift
let bondPrice = bondPresentValue(
  faceValue: 1000,
  rate: 0.05,
  years: 10,
  compounding: .continuous  // New parameter
)
```

### Contributing Code

#### Getting Started

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR_USERNAME/BusinessMath.git`
3. **Create a branch**: `git checkout -b feature/your-feature-name`
4. **Make your changes** (see guidelines below)
5. **Run tests**: `swift test`
6. **Commit**: `git commit -m "Add feature: your feature description"`
7. **Push**: `git push origin feature/your-feature-name`
8. **Open a Pull Request** on GitHub

#### Code Guidelines

**Swift Style:**
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use clear, descriptive names (prefer `discountRate` over `r` or `rate`)
- Use Swift 6 concurrency features where appropriate
- Prefer generics for reusable code (`TimeSeries<T: Real>`)

**Financial Accuracy:**
- Use **industry-standard formulas** (cite sources in comments)
- Handle **calendar realities** (365.25 days/year for annualization)
- Validate edge cases (negative rates, zero cash flows, etc.)
- Include references for complex models (e.g., "ISDA Standard CDS Pricing Model, 2009")

**Testing:**
- **Every new function requires tests**
- Test edge cases: zero, negative, infinity, empty arrays
- Test known values (e.g., "NPV for these cash flows at 10% should be $X")
- Test error cases (invalid inputs should throw appropriate errors)
- Aim for >95% code coverage on new code

**Documentation:**
- Add DocC comments to all public APIs
- Include parameter descriptions
- Provide usage examples in comments
- Add entries to relevant guides in `BusinessMath.docc/`

Example:
```swift
/// Calculates the net present value (NPV) of a series of cash flows.
///
/// NPV discounts future cash flows to their present value using a constant discount rate.
/// The first cash flow is assumed to occur at time t=0 (typically a negative initial investment).
///
/// - Parameters:
///   - discountRate: The discount rate per period (e.g., 0.10 for 10%)
///   - cashFlows: Array of cash flows, starting at t=0
/// - Returns: The net present value
///
/// **Formula:**
/// ```
/// NPV = CF₀ + CF₁/(1+r) + CF₂/(1+r)² + ... + CFₙ/(1+r)ⁿ
/// ```
///
/// **Example:**
/// ```swift
/// let npvValue = npv(discountRate: 0.10, cashFlows: [-100, 30, 40, 50])
/// // Returns: 3.42
/// ```
///
/// - Note: For irregular time periods, use `xnpv(rate:dates:cashFlows:)`
public func npv<T: Real>(discountRate: T, cashFlows: [T]) -> T {
    // Implementation...
}
```

#### What to Contribute

**High Priority:**
- Bug fixes (especially with test cases)
- Performance improvements (with benchmarks)
- Documentation improvements (examples, guides, typos)
- Platform support (Linux, Windows via Swift 6)
- Test coverage increases

**Medium Priority:**
- New financial functions (ensure they're widely used)
- API ergonomics improvements
- Error handling enhancements
- New examples in `Examples/` folder

**Please Discuss First:**
- Major API changes (open an issue or discussion)
- New dependencies (BusinessMath minimizes dependencies)
- Architecture changes
- Breaking changes (we follow semantic versioning strictly)

### Pull Request Process

1. **Ensure all tests pass**: `swift test`
2. **Update documentation** if you changed public APIs
3. **Add tests** for new functionality
4. **Update CHANGELOG.md** (add your change under "Unreleased")
5. **Keep PRs focused**: One feature/fix per PR
6. **Write clear commit messages**: "Add X", "Fix Y", "Update Z"

**PR Description Template:**
```markdown
## Summary
Brief description of what this PR does

## Motivation
Why is this change needed? What problem does it solve?

## Changes
- Bullet list of specific changes
- Include any breaking changes

## Testing
How was this tested? Include test cases added.

## Checklist
- [ ] Tests pass (`swift test`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No breaking changes (or marked as such)
```

### Review Process

- Maintainers will review PRs within 1 week
- We may request changes or ask questions
- Once approved, a maintainer will merge your PR
- Your contribution will be included in the next release!

## Financial Domain Expertise

**Don't have a finance background?** No problem! We'll help with:
- Formula correctness
- Industry terminology
- Real-world use cases

**Have finance expertise?** We especially need help with:
- Domain-specific validations
- Industry-standard implementations
- Real-world examples and case studies

## Development Setup

### Requirements
- Swift 6.0 or later
- Xcode 15+ (for macOS/iOS development)
- Swift Package Manager (included with Swift)

### Building
```bash
swift build
```

### Running Tests
```bash
# Run all tests
swift test

# Run specific test
swift test --filter BusinessMathTests.TimeValueOfMoneyTests

# Run with parallel execution
swift test --parallel
```

### Generating Documentation
```bash
# Preview documentation locally
swift package --disable-sandbox preview-documentation --target BusinessMath
```

### Performance Profiling
```bash
# Run performance benchmarks
swift run performance-profiling
```

## Questions?

- **Bugs/Features**: [GitHub Issues](https://github.com/jpurnell/BusinessMath/issues)
- **General Discussion**: [GitHub Discussions](https://github.com/jpurnell/BusinessMath/discussions)
- **Documentation**: [BusinessMath.docc](Sources/BusinessMath/BusinessMath.docc/)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to BusinessMath!** Every contribution, no matter how small, helps make financial modeling more accessible and accurate.
