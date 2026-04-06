# BusinessMath v2.1.0 Release Notes

**Release Date:** April 6, 2026

BusinessMath 2.1.0 is a **stability and quality release** focused on fixing a CI crash, eliminating all compiler warnings, hardening concurrency safety, and adding Thread Sanitizer to the CI pipeline.

---

## Highlights

| Area | Description |
|------|-------------|
| **CI Crash Fixed** | SIGABRT caused by incorrect vDSP FFT function in AccelerateFFTBackend |
| **Zero Warnings** | All Sendable and generic default-expression warnings eliminated |
| **Thread Safety** | NSLock added to ScenarioConfiguration; `@preconcurrency import Metal` |
| **TSan CI** | Thread Sanitizer job added to scheduled release test workflow |
| **4,708 Tests** | All passing in parallel with clean build |

---

## CI Crash Root Cause

The intermittent SIGABRT in CI was traced through multiple layers:

1. `AccelerateFFTBackend.powerSpectrum()` used `vDSP_fft_zipD` (complex-to-complex FFT) instead of `vDSP_fft_zripD` (real-input FFT)
2. This produced spectra with incorrect sizes, causing the test's `1..<spectrum.count` range to hit a precondition failure when counts diverged
3. The Range precondition triggered `fatalError` (SIGABRT / signal 6), crashing the parallel test runner
4. The crash corrupted in-flight async task state, producing the secondary SEGV in `swift_job_runImpl`

**Fix:** Single character change — `zipD` to `zripD` — plus a defensive guard in the test.

---

## Sendable Conformance Cleanup

### MetalMatrixBackend

Metal framework types (`MTLDevice`, `MTLCommandQueue`, `MTLLibrary`) predate Swift concurrency and don't declare `Sendable`. Rather than marking the struct `@unchecked Sendable`, we use:

```swift
@preconcurrency import Metal
```

This tells the compiler these types were designed before Sendable existed and our usage is thread-safe.

### ScenarioConfiguration

Had `@unchecked Sendable` with **no synchronization** — a ticking time bomb. Added `NSLock` protection on all dictionary reads and writes.

### Test Mocks

Mock provider classes in `SplitProtocolTests` now explicitly declare `@unchecked Sendable` since they have mutable `var callCount` tracking for test assertions.

---

## Generic Default Parameter Warnings

Swift 6.1+ warns when default values on generic `T` parameters participate in type inference when `T` is already inferrable. We refactored to the **constrained extension pattern**:

**Before:**
```swift
public init(alpha: T = 0.2, beta: T = 0.1, ...) { ... }
```

**After:**
```swift
public init(alpha: T, beta: T, ...) { ... }

extension HoltWintersModel where T == Double {
    public init(alpha: Double = 0.2, beta: Double = 0.1, ...) { ... }
}
```

This eliminates the warning while preserving the API for `Double` callers. Generic callers must now specify values explicitly — a more correct API surface.

---

## Thread Sanitizer CI

A new `thread_sanitizer` job in `release-tests.yml` runs on the same schedule as release tests (twice daily). It uses:

```yaml
swift test --sanitize thread --enable-swift-testing --parallel
```

TSan detects data races at runtime by instrumenting every memory access. It runs in Debug mode (TSan is incompatible with Release optimizations) and is macOS-only (Xcode includes TSan out of the box).

---

## Installation

**Swift Package Manager:**
```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath", from: "2.1.0")
]
```

**Migration from v2.0.0:** No changes required — all fixes are backward compatible.

---

## Resources

- [CHANGELOG](CHANGELOG.md) for detailed change list
- [GitHub Repository](https://github.com/jpurnell/BusinessMath)
