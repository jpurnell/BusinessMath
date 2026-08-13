## 1. Linux Foundation / Networking Module Issues

**Root cause:** On Linux, `URLSession`, `URLRequest`, and `URLResponse` live in `FoundationNetworking`, not just `Foundation`.

### Errors

- `cannot find type 'URLRequest' in scope`
- `'URLResponse' is unavailable: This type has moved to the FoundationNetworking module. Import that module to use it.`
- `'URLSession' is unavailable: This type has moved to the FoundationNetworking module. Import that module to use it.`
- `type 'URLSession' (aka 'AnyObject') has no member 'shared'`
- `value of type 'URLSession' (aka 'AnyObject') has no member 'data'`
- `value of type '_' expected to be instance of class or class-constrained type`
- `cannot find 'URLRequest' in scope` (e.g. in `YahooFinanceProvider.swift`)

### Affected Areas

- `Integration/NetworkSession.swift`
- `Integration/YahooFinanceProvider.swift`
- Any other files using:
  - `URLSession`
  - `URLRequest`
  - `URLResponse`

---

## 2. CoreFoundation API Missing on Linux

**Root cause:** `CFAbsoluteTimeGetCurrent` is part of CoreFoundation and may require explicit import on Linux.

### Errors

- `cannot find 'CFAbsoluteTimeGetCurrent' in scope`

### Affected File

- `Optimization/PerformanceBenchmark.swift`
  - At lines computing `startTime` and `endTime`

---

## 3. Swift Type-Checker Performance / Generic Explosion

**Root cause:** Extremely complex generic numeric expressions that overwhelm the Swift type checker.

### Errors

- `the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions`

### Affected File

- `Valuation/Debt/CreditSpreadModel.swift`
  - Expression:
    ```swift
    let secondsPerYear = T(365) * T(24) * T(3600) + T(1)/T(4) * T(24) * T(3600)
    ```

---

## 4. System Library Warning – libxml2 Version Info

**Root cause:** Swift toolchain linked against a versioned `libxml2`, but system library lacks version metadata.

### Warnings (Repeated)

```
/lib/x86_64-linux-gnu/libxml2.so.2: no version information available
(required by .../libFoundationXML.so)
```

### Characteristics

- Repeated multiple times
- Emitted before build steps
- Does not immediately stop compilation
- Environment/toolchain-level issue, not project source issue

---

## 5. Emit-Module Failure (Cascade)

**Root cause:** Upstream compilation errors (primarily FoundationNetworking issues).

### Error

- `error: emit-module command failed with exit code 1`

### Classification

- Secondary failure caused by:
  - Networking module errors
  - Missing CoreFoundation symbols
  - Type-checker failure

---

## Summary by Category

### A. Linux-Specific Foundation Differences
- Missing `FoundationNetworking`
- Unavailable `URLSession`, `URLRequest`, `URLResponse`

### B. CoreFoundation API Usage
- `CFAbsoluteTimeGetCurrent` not found

### C. Compiler Type-Checking Limits
- Large generic arithmetic expression in `CreditSpreadModel.swift`

### D. Toolchain / System Library Warnings
- `libxml2` version information warning

### E. Secondary / Cascading Errors
- `emit-module` failure due to prior errors
