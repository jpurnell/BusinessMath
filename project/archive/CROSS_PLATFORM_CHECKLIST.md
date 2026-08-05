# Cross-Platform Development Checklist

**Purpose:** Ensure new features maintain Linux compatibility in BusinessMath

---

## 📋 Before Writing New Code

### 1. Platform Availability Check
- [ ] Will this feature use Apple-only frameworks?
  - Metal, MetalKit, MetalPerformanceShaders
  - os.Logger, os.signpost, OSLog
  - CoreFoundation (CF* functions)
  - Accelerate framework (vDSP, BLAS)
  - CryptoKit (use swift-crypto on Linux)

### 2. API Selection
- [ ] Choose cross-platform alternatives when available:
  - ✅ `Date().timeIntervalSinceReferenceDate` instead of `CFAbsoluteTimeGetCurrent()`
  - ✅ Swift standard library instead of Foundation extensions
  - ✅ `import Numerics` for portable math
  - ✅ Swift Crypto instead of CryptoKit directly

---

## 💾 While Writing Code

### Math Functions
- [ ] If using math functions (pow, sqrt, exp, log, sin, cos, tan, erfc):
  - Add `import TestSupport` in test files
  - Or add conditional imports in source files:
    ```swift
    #if canImport(Darwin)
    import Darwin
    #else
    import Glibc
    #endif
    ```

### Networking Code
- [ ] If using URLSession, URLRequest, URLResponse:
  - Add to test files:
    ```swift
    import TestSupport  // Provides FoundationNetworking on Linux
    ```
  - Or add to source files:
    ```swift
    import Foundation
    #if canImport(FoundationNetworking)
    import FoundationNetworking
    #endif
    ```

### Memory Management
- [ ] If using `autoreleasepool`:
  ```swift
  #if canImport(Darwin)
  autoreleasepool {
      // Your code
  }
  #else
  do {
      // Your code
  }
  #endif
  ```

### GPU/Metal Features
- [ ] Wrap all Metal code with guards:
  ```swift
  #if canImport(Metal)
  import Metal

  // Metal code here
  #endif
  ```

### Logging
- [ ] Use BusinessMath's Logger (has Linux fallback):
  ```swift
  import BusinessMath

  let logger = Logger.shared
  logger.info("Message")
  ```
- [ ] Don't import OSLog directly in shared code

### Date/Time Handling
- [ ] Be aware of timezone differences
- [ ] Test date parsing with ISO8601DateFormatter
- [ ] Avoid locale-specific formatting in tests

---

## ✅ After Writing Code

### Build Verification
- [ ] Build succeeds on macOS:
  ```bash
  swift build
  ```
- [ ] Tests build successfully:
  ```bash
  swift build --build-tests
  ```
- [ ] Run static analysis:
  ```bash
  /tmp/check_linux_compatibility.sh
  ```

### Test Verification
- [ ] Tests pass on macOS:
  ```bash
  swift test
  ```
- [ ] Check for platform-specific test failures
- [ ] Review any test skips to ensure they're intentional

### Documentation
- [ ] Document any platform-specific behavior in code comments
- [ ] Update README if feature has platform requirements
- [ ] Note any known Linux limitations

---

## 🐳 Before Committing

### Final Checks
- [ ] Run comprehensive compatibility check:
  ```bash
  /tmp/comprehensive_linux_check.sh
  ```
- [ ] Review changes for unintentional platform dependencies
- [ ] Ensure all new test files import TestSupport if needed

### Optional: Docker Testing
- [ ] Test on actual Linux (if Docker available):
  ```bash
  /tmp/test_linux_docker.sh
  ```

---

## 🚫 Common Pitfalls to Avoid

### ❌ Don't Do This
```swift
// Unguarded Darwin import
import Darwin

// Unguarded Metal import
import Metal

// Direct OSLog usage without fallback
import OSLog
let logger = Logger(subsystem: "...", category: "...")

// CoreFoundation functions
let time = CFAbsoluteTimeGetCurrent()

// Unguarded autoreleasepool
autoreleasepool { }
```

### ✅ Do This Instead
```swift
// Guarded imports
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// Guarded Metal
#if canImport(Metal)
import Metal
// Metal code here
#endif

// Use BusinessMath Logger
import BusinessMath
let logger = Logger.shared

// Cross-platform time
let time = Date().timeIntervalSinceReferenceDate

// Guarded autoreleasepool
#if canImport(Darwin)
autoreleasepool { }
#else
do { }
#endif
```

---

## 📚 Quick Reference

### TestSupport Module
```swift
import TestSupport  // Provides:
// - Darwin/Glibc math functions
// - FoundationNetworking on Linux
```

### Conditional Compilation
```swift
#if canImport(Metal)
    // Metal-specific code
#endif

#if canImport(Darwin)
    // Apple platform code
#else
    // Linux alternative
#endif

#if os(Linux)
    // Linux-only code
#endif
```

### Platform Detection at Runtime
```swift
#if canImport(Darwin)
let isApplePlatform = true
#else
let isApplePlatform = false
#endif
```

---

## 🔍 Testing Matrix

### Minimum Test Coverage
| Platform | Build | Test | Notes |
|----------|-------|------|-------|
| macOS | ✅ Required | ✅ Required | Primary development platform |
| Linux | ✅ Required | ✅ Required | Use Docker or CI |
| iOS Simulator | ⚠️ Optional | ⚠️ Optional | If mobile features added |

### CI/CD Recommendations
- Run macOS tests on every commit
- Run Linux tests on every PR
- Consider weekly full Linux test suite

---

## 📖 Resources

### Documentation
- [Swift on Linux Guide](https://swift.org/download/#linux)
- [Foundation on Linux](https://github.com/apple/swift-corelibs-foundation)
- [Swift Crypto](https://github.com/apple/swift-crypto)
- [Swift Numerics](https://github.com/apple/swift-numerics)

### Tools
- Docker for local Linux testing
- GitHub Actions for automated CI
- SwiftLint for code consistency

### Internal Documentation
- `LINUX_TEST_PARITY_PLAN.md` - Original migration plan
- `LINUX-BUILD-FIXES.md` - Build fixes applied
- `MIGRATION_GUIDE.md` - Complete change documentation
- `/tmp/linux_readiness_report.md` - Verification results

---

## 🎯 Success Criteria

Before marking a feature as "cross-platform ready":

- ✅ Builds on both macOS and Linux
- ✅ Tests pass on both platforms (or intentionally skip)
- ✅ No unguarded platform-specific APIs
- ✅ Documentation notes any platform differences
- ✅ CI validates Linux compatibility

---

**Last Updated:** 2025-02-24
**Maintained By:** Development Team
**Questions?** Check `MIGRATION_GUIDE.md` or ask the team
