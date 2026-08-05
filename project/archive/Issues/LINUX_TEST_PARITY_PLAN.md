Below is a complete execution plan you can save as:

```
LINUX_TEST_PARITY_PLAN.md
```

---

# Linux Test Suite Parity Plan  
**Project:** BusinessMath  
**Goal:** Achieve reliable Linux test execution parity (excluding intentional Apple‑only features like Metal)

---

# 1. Objective

Bring the test suite to functional parity on Linux so that:

- ✅ The full portable test suite runs on Linux
- ✅ Apple‑only features are conditionally excluded
- ✅ CI runs `swift test` successfully on Ubuntu
- ✅ Server-side Linux runtime behavior is validated
- ✅ No silent Apple-only assumptions remain

Metal and other explicitly Apple-only functionality will remain conditionally disabled.

---

# 2. Guiding Principles

1. The library must compile and execute correctly on Linux.
2. Tests must not rely on implicit Darwin behavior.
3. Apple‑only APIs must be guarded.
4. Shared cross-platform shims should be centralized.
5. Platform differences must be explicit and intentional.
6. CI must enforce Linux execution success.

---

# 3. High-Level Strategy

We will:

1. Introduce a centralized cross-platform test support module.
2. Normalize math imports (Darwin vs Glibc).
3. Normalize networking imports (FoundationNetworking).
4. Guard Apple‑only APIs.
5. Refactor or conditionally disable non-portable tests.
6. Create a clean Linux CI validation stage.
7. Iteratively reduce Linux-specific failures to zero.

---

# 4. Phase 1 — Introduce Cross‑Platform Test Support

## 4.1 Create Shared Test Support File

Create:

```
Tests/TestSupport/PlatformSupport.swift
```

Add:

```swift
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
```

Purpose:
- Restores `pow`, `sqrt`, `erfc`
- Enables URLRequest / URLResponse
- Normalizes math behavior

---

## 4.2 Ensure All Tests See PlatformSupport

Option A (recommended):
- Add a `TestSupport` target in `Package.swift`
- Make test targets depend on it

Option B:
- Ensure the file is compiled within the main test target

---

# 5. Phase 2 — Networking Fixes

## 5.1 Fix MockNetworkSession

Ensure these files include:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
```

Files affected:
- MockNetworkSession.swift
- MarketDataTests.swift
- Any file using:
  - URLRequest
  - URLResponse
  - HTTPURLResponse

---

# 6. Phase 3 — Replace Apple‑Only APIs

## 6.1 autoreleasepool

Replace:

```swift
autoreleasepool {
    ...
}
```

With:

```swift
#if canImport(Darwin)
autoreleasepool {
    ...
}
#else
do {
    ...
}
#endif
```

Or remove entirely if unnecessary.

---

## 6.2 os.Logger / Logger.businessMath

If extension exists only on Apple:

Option A — Guard tests:

```swift
#if canImport(os)
...
#endif
```

Option B — Provide Linux fallback logger:

Create:

```swift
#if !canImport(os)
extension Logger {
    static let businessMath = Logger(label: "BusinessMath")
}
#endif
```

---

## 6.3 TestSkip Usage

Replace:

```swift
throw TestSkip.skip("...")
```

With Swift Testing compatible skip:

```swift
throw Skip("...")
```

Or:

```swift
#if canImport(Metal)
...
#else
throw Skip("Metal not available")
#endif
```

---

# 7. Phase 4 — GPU / Metal Tests

All Metal tests must be wrapped:

```swift
#if canImport(Metal)
...
#endif
```

Or:

```swift
#if canImport(Metal)
@Test(...)
func testGPU() { ... }
#endif
```

Ensure Linux does not compile GPU code paths.

---

# 8. Phase 5 — Logger Compatibility Strategy

If server logging is required on Linux:

Prefer:

```swift
import Logging
```

And use swift-log cross-platform abstraction instead of os.Logger.

Long-term recommendation:
Replace os.Logger usage with swift-log.

---

# 9. Phase 6 — Math Behavior Validation

Since server-side Linux execution is expected:

Add a new test group:

```
Tests/LinuxParityTests/
```

Include tests validating:

- Floating-point tolerances
- Statistical distribution accuracy
- Optimization solver convergence
- Concurrency determinism

Ensure tolerances account for libm differences.

Example:

```swift
#expect(abs(result - expected) < 1e-10)
```

Avoid exact floating-point equality.

---

# 10. Phase 7 — CI Configuration

Linux CI should run:

```yaml
- name: Linux Debug Test
  run: swift test -c debug --parallel -v

- name: Linux Release Test
  run: swift test -c release --parallel -v
```

Metal-only tests will auto-exclude via `#if`.

CI should fail if:
- Any portable test fails
- Any unguarded Apple API leaks

---

# 11. Phase 8 — LLM Execution Plan

When using an LLM to execute this plan, proceed in this order:

---

## Step 1 — Create PlatformSupport.swift

Prompt:
> Create a cross-platform test support file that normalizes Darwin/Glibc and FoundationNetworking imports.

---

## Step 2 — Scan and Patch Imports

Prompt:
> Find all test files using pow, sqrt, erfc, URLRequest, URLResponse, HTTPURLResponse and ensure correct conditional imports.

---

## Step 3 — Replace autoreleasepool

Prompt:
> Replace all autoreleasepool usage with cross-platform safe constructs.

---

## Step 4 — Guard Metal Tests

Prompt:
> Wrap all Metal-dependent tests with #if canImport(Metal).

---

## Step 5 — Fix Logger Tests

Prompt:
> Refactor Logger tests to avoid os.Logger assumptions on Linux.

---

## Step 6 — Replace TestSkip

Prompt:
> Replace TestSkip.skip with Swift Testing compatible Skip usage.

---

## Step 7 — Run Linux Tests

Command:

```bash
swift test -c debug
```

Repeat patch cycle until zero failures.

---

# 12. Definition of Done

✅ `swift test` passes on Ubuntu  
✅ `swift test` passes on macOS  
✅ Metal tests excluded only on Linux  
✅ No Apple-only symbols leak into Linux  
✅ Floating point tests use tolerance  
✅ CI green across matrix  

---

# 13. Long-Term Hardening

Recommended improvements:

- Adopt swift-log abstraction
- Add CI job that forbids accidental Darwin imports in non-guarded files
- Add lint rule for Apple-only APIs
- Consider splitting tests into:
  - PortableTests
  - ApplePlatformTests

---

# 14. Risk Assessment

Risk | Mitigation
------|-----------
libm floating differences | Use tolerance comparisons
Networking API divergence | Use FoundationNetworking
Logger differences | Abstract logging layer
GPU differences | Conditional compilation

---

# 15. Outcome

After executing this plan:

- BusinessMath will be truly server-ready.
- Linux behavior will be validated, not assumed.
- CI will provide real cross-platform guarantees.
- Platform boundaries will be explicit and intentional.

---

End of Plan.
