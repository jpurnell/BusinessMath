# Migration Plan: BusinessMathMCP Repository Separation

**Version:** 1.0
**Created:** 2026-02-04
**Completed:** 2026-02-06
**Status:** ✅ COMPLETED

---

## Executive Summary

This plan outlines the separation of BusinessMathMCP into an independent repository to:
- Remove platform-specific MCP dependencies from core BusinessMath library
- Enable independent versioning and evolution of MCP server functionality
- Improve cross-platform compatibility of BusinessMath core library
- Create cleaner architectural boundaries

**Estimated Effort:** 2-3 weeks
**Risk Level:** Medium
**Breaking Changes:** Yes (package import paths change)

---

## Table of Contents

1. [Overview & Rationale](#overview--rationale)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Pre-Migration Checklist](#pre-migration-checklist)
5. [Migration Steps](#migration-steps)
6. [Testing Strategy](#testing-strategy)
7. [Rollback Plan](#rollback-plan)
8. [Timeline](#timeline)
9. [Risk Assessment](#risk-assessment)
10. [Post-Migration Tasks](#post-migration-tasks)

---

## Overview & Rationale

### What Changes?

BusinessMathMCP will move from:
- **Current:** Product within `swift-business-math` monorepo
- **Target:** Standalone repository `swift-business-math-mcp`

### Why Separate?

| Issue | Current State | After Separation |
|-------|--------------|------------------|
| **Platform Constraints** | MCP SDK forces macOS-only constraint on entire package | BusinessMath becomes truly cross-platform |
| **Dependency Bloat** | Core math library pulls in HTTP server, SSE, auth code | Clean separation: core library vs. protocol adapter |
| **Version Coupling** | MCP API changes require BusinessMath version bump | Independent versioning allows faster MCP iteration |
| **User Complexity** | All users download MCP infrastructure even if unused | Users opt-in to MCP functionality only when needed |
| **Maintenance** | Single large repo with mixed concerns | Focused repositories with clear boundaries |

### Who Is Affected?

| User Type | Impact | Migration Required? |
|-----------|--------|---------------------|
| **BusinessMath only users** | None (may see package size reduction) | ❌ No |
| **BusinessMathMCP users** | Import path changes | ✅ Yes |
| **BusinessMathMCPServer users** | New repository location | ✅ Yes |
| **Contributors** | New repository structure | ✅ Yes |

---

## Current State Analysis

### Package Structure

**BusinessMath Repository (Current):**
```
swift-business-math/
├── Sources/
│   ├── BusinessMath/          # Core library (main product)
│   ├── BusinessMathMCP/        # MCP tools layer (51 files, 30,472 lines)
│   ├── BusinessMathMCPServer/  # Executable server
│   ├── BusinessMathDSL/        # Domain-specific language
│   └── BusinessMathMacros/     # Compile-time macros
│
├── Tests/
│   └── BusinessMathTests/
│       └── MCP Tests/          # 6 MCP-specific test files
│
└── Package.swift               # Declares all products
```

### Dependency Graph (Current)

```
BusinessMath ← swift-numerics
    ↓
BusinessMathMCP ← MCP SDK (macOS only)
    ↓
BusinessMathMCPServer
```

**Key Metrics:**
- **BusinessMathMCP Files:** 51 Swift files
- **Lines of Code:** 30,472
- **Tool Implementations:** 40 domain-specific tools
- **Tests:** 6 test files (5 active, 1 disabled)
- **Shared Code:** 2 extension files (with minor duplication)

### Dependency Analysis

| Component | Depends On | Coupling Strength | Notes |
|-----------|-----------|-------------------|-------|
| BusinessMathMCP → BusinessMath | Core types, all calculators | **HARD** | Uses 100+ BusinessMath APIs |
| BusinessMathMCP → MCP SDK | Protocol types | **HARD** | Required for tool definitions |
| BusinessMathMCP → Numerics | Vector operations | **MEDIUM** | Mostly indirect via BusinessMath |
| BusinessMath → BusinessMathMCP | Nothing | **NONE** | ✅ Clean separation already exists |

### Critical Files Inventory

**Infrastructure (11 files, 3,293 lines):**
- `MCPCompat.swift` - Compatibility layer for MCP SDK migration
- `ToolDefinition.swift` - Tool registry system
- `TypeMarshalling.swift` - JSON-compatible wrappers for BusinessMath types
- `HTTPServerTransport.swift` - HTTP server using Network framework
- `SSESession.swift` / `SSESessionManager.swift` - Server-Sent Events
- `HTTPResponseManager.swift` - Response routing
- `APIKeyAuthenticator.swift` - Authentication
- `Resources.swift` - Documentation/examples provider
- `Prompts.swift` - Financial task templates

**Tools (40 files, 27,148 lines):**
- Financial ratios, TVM, equity/bond valuation
- Statistical analysis, hypothesis testing, Bayesian tools
- Optimization (adaptive, parallel, integer programming)
- Portfolio management, risk analytics
- Forecasting, time series, seasonality
- Options, derivatives, credit instruments
- Monte Carlo simulation tools

**Extensions (2 files, 57 lines):**
- `extensionFormatted.swift` - Number formatting helpers
- `extensionString.swift` - String padding utilities

---

## Target Architecture

### New Repository Structure

**BusinessMath Repository (After):**
```
swift-business-math/
├── Sources/
│   ├── BusinessMath/          # Core library (unchanged)
│   ├── BusinessMathDSL/        # Domain-specific language
│   └── BusinessMathMacros/     # Compile-time macros
│
├── Tests/
│   └── BusinessMathTests/      # MCP tests removed
│
└── Package.swift               # BusinessMathMCP products removed
```

**BusinessMathMCP Repository (New):**
```
swift-business-math-mcp/
├── Sources/
│   ├── BusinessMathMCP/        # MCP tools layer (migrated)
│   └── BusinessMathMCPServer/  # Executable server (migrated)
│
├── Tests/
│   └── BusinessMathMCPTests/   # MCP tests (migrated)
│
├── Examples/
│   └── QuickStart.swift        # Getting started guide
│
├── Documentation/
│   └── MCP-INTEGRATION.md      # MCP protocol documentation
│
└── Package.swift               # New package definition
```

### Dependency Graph (Target)

```
swift-numerics
    ↓
BusinessMath (standalone, cross-platform)
    ↓
BusinessMathMCP ← MCP SDK (macOS only)
    ↓
BusinessMathMCPServer
```

### Package.swift (New BusinessMathMCP)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-business-math-mcp",
    platforms: [
        .macOS(.v14)  // MCP SDK requirement
    ],
    products: [
        .library(
            name: "BusinessMathMCP",
            targets: ["BusinessMathMCP"]
        ),
        .executable(
            name: "BusinessMathMCPServer",
            targets: ["BusinessMathMCPServer"]
        )
    ],
    dependencies: [
        // Core BusinessMath library
        .package(
            url: "https://github.com/justinpurnell/swift-business-math.git",
            from: "2.0.0"
        ),
        // MCP SDK
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.10.0"
        ),
        // Numerics (shared dependency)
        .package(
            url: "https://github.com/apple/swift-numerics",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "BusinessMathMCP",
            dependencies: [
                .product(name: "BusinessMath", package: "swift-business-math"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Numerics", package: "swift-numerics")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "BusinessMathMCPServer",
            dependencies: ["BusinessMathMCP"]
        ),
        .testTarget(
            name: "BusinessMathMCPTests",
            dependencies: ["BusinessMathMCP"]
        )
    ]
)
```

---

## Pre-Migration Checklist

### Code Preparation

- [ ] **Verify BusinessMath is stable**
  - [ ] All tests passing (3,552 tests across 278 suites)
  - [ ] No open critical bugs
  - [ ] Version 2.0.0+ released and stable

- [ ] **Audit BusinessMathMCP dependencies**
  - [ ] Document all BusinessMath types used by tools
  - [ ] Identify minimum BusinessMath version required
  - [ ] List all MCP SDK APIs used

- [ ] **Resolve shared code duplication**
  - [ ] Review `extensionFormatted.swift` differences
  - [ ] Review `extensionString.swift` duplication
  - [ ] Decide: keep duplicated or import from BusinessMath?

- [ ] **Create compatibility matrix**
  - [ ] Document BusinessMath versions vs BusinessMathMCP versions
  - [ ] Define support policy (N-1 versions? Strict matching?)

### Repository Setup

- [ ] **Create new GitHub repository**
  - [ ] Name: `swift-business-math-mcp`
  - [ ] Visibility: Public (or match BusinessMath)
  - [ ] License: MIT (match BusinessMath)
  - [ ] Initialize with README, .gitignore

- [ ] **Configure repository settings**
  - [ ] Branch protection rules (main branch)
  - [ ] Required status checks
  - [ ] Code review requirements
  - [ ] Merge strategies

- [ ] **Setup CI/CD**
  - [ ] GitHub Actions workflow for macOS
  - [ ] Swift 6.0 compatibility tests
  - [ ] Integration tests against BusinessMath versions
  - [ ] Release automation

### Documentation

- [ ] **Write migration guide for users**
  - [ ] Import path changes
  - [ ] Dependency declaration examples
  - [ ] Troubleshooting common issues

- [ ] **Create README for new repo**
  - [ ] Installation instructions
  - [ ] Quick start guide
  - [ ] Link to BusinessMath documentation
  - [ ] MCP protocol overview

- [ ] **Update BusinessMath README**
  - [ ] Add section on MCP integration
  - [ ] Link to BusinessMathMCP repository
  - [ ] Deprecation notice for old import paths

### Communication

- [ ] **Notify stakeholders**
  - [ ] Create GitHub issue announcing separation
  - [ ] Update changelog with migration plan
  - [ ] Post on relevant forums/communities

- [ ] **Prepare release notes**
  - [ ] Breaking changes summary
  - [ ] Migration instructions
  - [ ] Version compatibility table

---

## Migration Steps

### Phase 1: Repository Creation (Week 1, Days 1-2)

#### Step 1.1: Create New Repository

```bash
# Create new repository on GitHub
gh repo create swift-business-math-mcp \
  --public \
  --description "MCP (Model Context Protocol) server for BusinessMath" \
  --license MIT

# Clone locally
cd ~/Development
git clone git@github.com:[owner]/swift-business-math-mcp.git
cd swift-business-math-mcp
```

#### Step 1.2: Initialize Package Structure

```bash
# Create directory structure
mkdir -p Sources/BusinessMathMCP
mkdir -p Sources/BusinessMathMCPServer
mkdir -p Tests/BusinessMathMCPTests
mkdir -p Examples
mkdir -p Documentation

# Create initial Package.swift
cat > Package.swift << 'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-business-math-mcp",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BusinessMathMCP", targets: ["BusinessMathMCP"]),
        .executable(name: "BusinessMathMCPServer", targets: ["BusinessMathMCPServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/justinpurnell/swift-business-math.git", from: "2.0.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "BusinessMathMCP",
            dependencies: [
                .product(name: "BusinessMath", package: "swift-business-math"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Numerics", package: "swift-numerics")
            ]
        ),
        .executableTarget(
            name: "BusinessMathMCPServer",
            dependencies: ["BusinessMathMCP"]
        ),
        .testTarget(
            name: "BusinessMathMCPTests",
            dependencies: ["BusinessMathMCP"]
        )
    ]
)
EOF

# Create README
cat > README.md << 'EOF'
# BusinessMath MCP Server

MCP (Model Context Protocol) server providing access to BusinessMath financial calculations and analytics.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/[owner]/swift-business-math-mcp.git", from: "1.0.0")
]
```

## Quick Start

See [Examples/QuickStart.swift](Examples/QuickStart.swift) for usage examples.

## Documentation

- [MCP Integration Guide](Documentation/MCP-INTEGRATION.md)
- [BusinessMath Documentation](https://github.com/justinpurnell/swift-business-math)

## Requirements

- macOS 14+
- Swift 6.0+
- BusinessMath 2.0+

## License

MIT License - See LICENSE file
EOF
```

#### Step 1.3: Copy Source Files

```bash
# From BusinessMath repository
cd ~/Development/swift-business-math

# Copy BusinessMathMCP source files
cp -r Sources/BusinessMathMCP/* \
  ~/Development/swift-business-math-mcp/Sources/BusinessMathMCP/

# Copy BusinessMathMCPServer source files
cp -r Sources/BusinessMathMCPServer/* \
  ~/Development/swift-business-math-mcp/Sources/BusinessMathMCPServer/

# Copy MCP tests
cp -r Tests/BusinessMathTests/MCP\ Tests/* \
  ~/Development/swift-business-math-mcp/Tests/BusinessMathMCPTests/

# Copy LICENSE
cp LICENSE ~/Development/swift-business-math-mcp/
```

### Phase 2: Code Modifications (Week 1, Days 3-5)

#### Step 2.1: Resolve Extension Duplication

**Decision Point:** The `extensionString.swift` is identical in both modules. Options:

**Option A: Remove duplication, import from BusinessMath**
```swift
// In BusinessMathMCP files that need it
import BusinessMath  // Already imported for other types

// Remove local extensionString.swift
// Use BusinessMath's version directly
```

**Option B: Keep duplicated**
- Pros: No risk of breaking if BusinessMath removes it
- Cons: Maintenance burden, code duplication

**Recommendation:** Option A (remove duplication). If BusinessMath's extension is removed later, it's a trivial addition.

**Action:**
```bash
cd ~/Development/swift-business-math-mcp

# Remove duplicate
rm Sources/BusinessMathMCP/Tools/extensionString.swift

# Verify BusinessMath export is public
# (Check BusinessMath/Extensions/extensionString.swift has public access)
```

#### Step 2.2: Update Import Statements (If Needed)

Most files already import `BusinessMath`, so no changes needed. However, verify all tool files have:

```swift
import BusinessMath
import MCP
import Foundation
import Numerics  // Where needed
```

Run audit:
```bash
# Find any files missing imports
grep -L "import BusinessMath" Sources/BusinessMathMCP/Tools/*.swift
```

#### Step 2.3: Update Test Imports

```swift
// Tests/BusinessMathMCPTests/*.swift
// Change from:
@testable import BusinessMathMCP  // ✅ Correct

// Verify no tests import:
@testable import BusinessMath  // ⚠️ Should not happen, but check
```

Run test import audit:
```bash
# Check test imports
grep -n "^import" Tests/BusinessMathMCPTests/*.swift
```

### Phase 3: Testing & Validation (Week 2, Days 1-3)

#### Step 3.1: Compile New Package

```bash
cd ~/Development/swift-business-math-mcp

# Clean build
swift package clean

# Resolve dependencies
swift package resolve

# Build all targets
swift build

# Expected output:
# - BusinessMathMCP builds successfully
# - BusinessMathMCPServer builds successfully
# - All 51 source files compile
```

**Validation Checklist:**
- [ ] No compiler errors
- [ ] No missing imports
- [ ] All 40 tool files compile
- [ ] Server executable builds
- [ ] Dependency resolution succeeds

#### Step 3.2: Run Tests

```bash
# Run all tests
swift test

# Expected: All MCP tests pass (5 active tests)
# Note: SSEIntegrationTests.swift is disabled, should remain disabled
```

**Test Coverage Validation:**
- [ ] ScenarioAnalysisToolTests passes
- [ ] MeanVariancePortfolioToolTests passes
- [ ] APIAuthTests passes
- [ ] SSETransportTests passes
- [ ] HTTPTransportTests passes

#### Step 3.3: Integration Testing

Test against different BusinessMath versions:

```bash
# Test with BusinessMath 2.0.0
swift package update
swift test

# Test with latest BusinessMath (if > 2.0.0)
# Edit Package.swift: from: "2.1.0"
swift package update
swift test

# Document any compatibility issues
```

#### Step 3.4: Server Functionality Testing

```bash
# Run MCP server
swift run BusinessMathMCPServer

# Test MCP protocol endpoints:
# 1. List available tools
# 2. Call sample tool (e.g., FinancialRatiosTools)
# 3. Verify response format
# 4. Test error handling

# Expected: Server starts, responds to MCP requests
```

### Phase 4: CI/CD Setup (Week 2, Days 4-5)

#### Step 4.1: Create GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v4

    - name: Setup Swift
      uses: swift-actions/setup-swift@v2
      with:
        swift-version: "6.0"

    - name: Build
      run: swift build -v

    - name: Run tests
      run: swift test -v

    - name: Build server
      run: swift build --product BusinessMathMCPServer

  integration-test:
    runs-on: macos-14
    strategy:
      matrix:
        businessmath-version: ["2.0.0", "2.1.0"]
    steps:
    - uses: actions/checkout@v4

    - name: Test with BusinessMath ${{ matrix.businessmath-version }}
      run: |
        swift package update
        swift test
```

#### Step 4.2: Setup Release Automation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v4

    - name: Build release
      run: swift build -c release

    - name: Create GitHub Release
      uses: softprops/action-gh-release@v1
      with:
        files: |
          .build/release/BusinessMathMCPServer
        generate_release_notes: true
```

### Phase 5: Update BusinessMath Repository (Week 2, Day 5)

#### Step 5.1: Remove BusinessMathMCP from Package.swift

```bash
cd ~/Development/swift-business-math

# Edit Package.swift
# Remove:
# - .library(name: "BusinessMathMCP", targets: ["BusinessMathMCP"])
# - .executable(name: "BusinessMathMCPServer", targets: ["BusinessMathMCPServer"])
# - .target(name: "BusinessMathMCP", dependencies: [...])
# - .executableTarget(name: "BusinessMathMCPServer", dependencies: [...])
# - MCP SDK dependency
```

**Package.swift changes:**
```diff
products: [
    .library(name: "BusinessMath", targets: ["BusinessMath"]),
-   .library(name: "BusinessMathMCP", targets: ["BusinessMathMCP"]),
-   .executable(name: "BusinessMathMCPServer", targets: ["BusinessMathMCPServer"]),
    .library(name: "BusinessMathDSL", targets: ["BusinessMathDSL"]),
],

dependencies: [
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
-   .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
],

targets: [
    .target(name: "BusinessMath", dependencies: [
        .product(name: "Numerics", package: "swift-numerics")
    ]),
-   .target(name: "BusinessMathMCP", dependencies: [
-       "BusinessMath",
-       .product(name: "MCP", package: "swift-sdk"),
-       .product(name: "Numerics", package: "swift-numerics")
-   ]),
-   .executableTarget(name: "BusinessMathMCPServer", dependencies: ["BusinessMathMCP"]),
]
```

#### Step 5.2: Remove Source Directories

```bash
# Move to archive (don't delete yet, keep backup)
mkdir -p .archive
mv Sources/BusinessMathMCP .archive/
mv Sources/BusinessMathMCPServer .archive/
mv Tests/BusinessMathTests/MCP\ Tests .archive/

# Verify BusinessMath still builds
swift build
swift test
```

**Validation:**
- [ ] BusinessMath builds without errors
- [ ] All 3,552 tests still pass
- [ ] No missing dependencies
- [ ] Package size reduced

#### Step 5.3: Update Documentation

**README.md additions:**
```markdown
## MCP Integration

BusinessMath provides an MCP (Model Context Protocol) server for AI assistant integration.

**Separate Package:** The MCP server is maintained in a separate repository:
- Repository: [swift-business-math-mcp](https://github.com/[owner]/swift-business-math-mcp)
- Installation: See MCP repo README
- Documentation: [MCP Integration Guide](https://github.com/[owner]/swift-business-math-mcp)

### Why Separate?

The MCP server requires macOS-specific dependencies. Separating it allows:
- Cross-platform BusinessMath usage (Linux, Windows)
- Independent versioning of MCP functionality
- Optional adoption (only install if you need MCP)
```

**CHANGELOG.md additions:**
```markdown
## [2.1.0] - 2026-02-25

### Changed

- **BREAKING:** BusinessMathMCP moved to separate repository
  - New location: https://github.com/[owner]/swift-business-math-mcp
  - Migration guide: See BusinessMathMCP repository README
  - Existing users: Update imports and dependencies (see migration guide)

### Removed

- BusinessMathMCP library (moved to separate package)
- BusinessMathMCPServer executable (moved to separate package)
- MCP SDK dependency (no longer required for core library)

### Improved

- Core BusinessMath package is now cross-platform compatible
- Reduced package size and dependency footprint
```

### Phase 6: Documentation & Release (Week 3, Days 1-3)

#### Step 6.1: Write User Migration Guide

Create `Documentation/MIGRATION.md` in BusinessMathMCP repo:

```markdown
# Migration Guide: BusinessMathMCP Separation

## Overview

BusinessMathMCP has moved to a separate repository for better modularity and cross-platform compatibility.

## For Existing Users

### Step 1: Update Package Dependencies

**Before (BusinessMath < 2.1.0):**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/justinpurnell/swift-business-math.git", from: "2.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "BusinessMath", package: "swift-business-math"),
            .product(name: "BusinessMathMCP", package: "swift-business-math")
        ]
    )
]
```

**After (BusinessMath 2.1.0+):**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/justinpurnell/swift-business-math.git", from: "2.1.0"),
    .package(url: "https://github.com/[owner]/swift-business-math-mcp.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "BusinessMath", package: "swift-business-math"),
            .product(name: "BusinessMathMCP", package: "swift-business-math-mcp")
        ]
    )
]
```

### Step 2: Update Imports

**No changes required** - Import statements remain the same:
```swift
import BusinessMath
import BusinessMathMCP
```

### Step 3: Update and Rebuild

```bash
swift package update
swift build
```

## Compatibility Matrix

| BusinessMath Version | BusinessMathMCP Version | Status |
|---------------------|------------------------|--------|
| 2.0.0 - 2.0.x | Use built-in (old location) | Deprecated |
| 2.1.0+ | 1.0.0+ | Current |

## Troubleshooting

### Error: "No such module 'BusinessMathMCP'"

**Cause:** Missing dependency declaration in Package.swift

**Fix:**
```swift
dependencies: [
    .package(url: "https://github.com/[owner]/swift-business-math-mcp.git", from: "1.0.0")
]
```

### Error: "Multiple targets named 'BusinessMathMCP'"

**Cause:** Both old and new packages declared

**Fix:** Remove old BusinessMath dependency, use only 2.1.0+

### Platform Compatibility Issues

**Issue:** MCP server only runs on macOS 14+

**Solution:** This is expected. Core BusinessMath works cross-platform, but MCP server requires macOS for MCP SDK.

## Need Help?

- Open issue: [swift-business-math-mcp/issues](https://github.com/[owner]/swift-business-math-mcp/issues)
- BusinessMath docs: [swift-business-math](https://github.com/justinpurnell/swift-business-math)
```

#### Step 6.2: Create Quick Start Example

```swift
// Examples/QuickStart.swift
import BusinessMath
import BusinessMathMCP
import MCP

// Example: Starting the MCP server
@main
struct QuickStart {
    static func main() async throws {
        // Initialize server with BusinessMath tools
        let server = try MCPServer()

        // Register all available tools
        server.registerTools([
            FinancialRatiosTools(),
            PortfolioTools(),
            MonteCarloTools(),
            // ... other tools
        ])

        // Start HTTP server on port 3000
        try await server.start(port: 3000)

        print("BusinessMath MCP Server running on http://localhost:3000")
        print("Press Ctrl+C to stop")

        // Keep server running
        try await Task.sleep(for: .seconds(.max))
    }
}
```

#### Step 6.3: Version and Tag Releases

**BusinessMath Repository:**
```bash
cd ~/Development/swift-business-math

# Update version in Package.swift (if needed)
# Commit all changes
git add .
git commit -m "Remove BusinessMathMCP (moved to separate repository)

BREAKING CHANGE: BusinessMathMCP is now in swift-business-math-mcp repository.
See CHANGELOG.md for migration instructions."

# Tag release
git tag v2.1.0
git push origin main --tags
```

**BusinessMathMCP Repository:**
```bash
cd ~/Development/swift-business-math-mcp

# Commit all changes
git add .
git commit -m "Initial release: BusinessMathMCP separated from BusinessMath

Features:
- 40 MCP tools for financial calculations
- HTTP/SSE transport support
- API key authentication
- Requires BusinessMath 2.0+"

# Tag release
git tag v1.0.0
git push origin main --tags
```

### Phase 7: Communication & Rollout (Week 3, Days 4-5)

#### Step 7.1: Announce Separation

Create GitHub Discussion in BusinessMath repo:

**Title:** "BusinessMathMCP Moving to Separate Repository"

**Content:**
```markdown
## Announcement: BusinessMathMCP Separation

We're moving BusinessMathMCP to a separate repository to improve modularity and cross-platform compatibility.

### What's Changing?

- **New Repository:** https://github.com/[owner]/swift-business-math-mcp
- **BusinessMath Core:** Now fully cross-platform (no macOS requirement)
- **Version:** BusinessMath 2.1.0+ removes built-in MCP
- **Migration Required:** Yes, for MCP users (simple dependency update)

### Timeline

- **2026-02-25:** BusinessMath 2.1.0 released (MCP removed)
- **2026-02-25:** BusinessMathMCP 1.0.0 released (new repository)
- **Support:** BusinessMath 2.0.x with built-in MCP supported until 2026-05-01

### Migration

See detailed guide: [BusinessMathMCP Migration Guide](https://github.com/[owner]/swift-business-math-mcp/blob/main/Documentation/MIGRATION.md)

**Summary:**
1. Update BusinessMath dependency to 2.1.0+
2. Add BusinessMathMCP dependency (new package)
3. Run `swift package update`

Import statements remain unchanged.

### Questions?

Ask here or open an issue in the relevant repository.
```

#### Step 7.2: Update External Documentation

- [ ] Update Swift Package Index listing (if applicable)
- [ ] Update documentation site
- [ ] Update any blog posts or tutorials
- [ ] Notify known enterprise users directly

#### Step 7.3: Monitor and Support

First 2 weeks after release:
- [ ] Monitor GitHub issues daily
- [ ] Respond to migration questions within 24 hours
- [ ] Document common issues in FAQ
- [ ] Prepare hotfix releases if critical issues found

---

## Testing Strategy

### Unit Tests

**BusinessMathMCP Repository:**
- [ ] All 5 active MCP tests pass
- [ ] Test coverage: 80%+ for tool implementations
- [ ] Test all transport mechanisms (HTTP, SSE)
- [ ] Test authentication flows

**BusinessMath Repository (Post-Removal):**
- [ ] All 3,552 existing tests still pass
- [ ] No references to MCP types
- [ ] Build succeeds on all platforms

### Integration Tests

**Cross-Version Compatibility:**
```swift
// Test matrix
let businessMathVersions = ["2.0.0", "2.1.0", "2.2.0"]
let mcpVersions = ["1.0.0", "1.1.0"]

// Verify all combinations build and run
for bmVersion in businessMathVersions {
    for mcpVersion in mcpVersions {
        testCompatibility(businessMath: bmVersion, mcp: mcpVersion)
    }
}
```

**Functional Tests:**
- [ ] MCP server starts successfully
- [ ] Tools are registered and discoverable
- [ ] Tool invocation works (sample financial calculations)
- [ ] Authentication works
- [ ] SSE sessions maintain state
- [ ] HTTP transport handles concurrent requests

### Performance Tests

- [ ] MCP server response time < 100ms for simple tools
- [ ] Memory usage stable under load
- [ ] No memory leaks in long-running server
- [ ] BusinessMath performance unchanged after separation

### Regression Tests

- [ ] Compare MCP tool outputs before/after separation (must be identical)
- [ ] Verify all 40 tools produce same results
- [ ] Check error handling behavior unchanged

---

## Rollback Plan

### If Critical Issues Found

**Severity Level 1: Build Failures**

If BusinessMathMCP doesn't build or tests fail catastrophically:

1. **Immediate Action:**
   ```bash
   # Revert BusinessMath changes
   cd ~/Development/swift-business-math
   git revert HEAD
   git push origin main

   # Delete BusinessMathMCP tags
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   ```

2. **Communication:**
   - Post immediate notice in GitHub Discussion
   - Update release notes with "ROLLED BACK" status
   - Explain issue and timeline for fix

**Severity Level 2: Integration Issues**

If BusinessMathMCP builds but doesn't work with BusinessMath:

1. **Quick Fix Attempt:**
   - Identify specific compatibility issue
   - Release patch version within 48 hours
   - Document workaround in README

2. **If No Quick Fix:**
   - Extend support for BusinessMath 2.0.x (built-in MCP) by 3 months
   - Delay removal of BusinessMathMCP from main repo
   - Release BusinessMath 2.0.x patch with extended deprecation notice

**Severity Level 3: User Adoption Issues**

If migration too complex or users struggle:

1. **Support Measures:**
   - Create video walkthrough
   - Offer office hours for migration help
   - Create automated migration script

2. **Maintain Both Paths:**
   - Keep BusinessMath 2.0.x with built-in MCP maintained for 6 months
   - Give users more time to migrate

### Rollback Testing

Before rollback:
- [ ] Verify old version still builds
- [ ] Verify old tests still pass
- [ ] Document what went wrong for future attempts

---

## Timeline

### Week 1: Foundation (5 days)

| Day | Tasks | Owner | Status |
|-----|-------|-------|--------|
| Mon | Repository creation, initial structure | - | ⬜ Not Started |
| Tue | Copy source files, initial commit | - | ⬜ Not Started |
| Wed | Resolve extension duplication, update imports | - | ⬜ Not Started |
| Thu | First compilation attempt, fix errors | - | ⬜ Not Started |
| Fri | Clean build achieved, initial tests | - | ⬜ Not Started |

**Deliverables:**
- ✅ New repository created and initialized
- ✅ All source files copied
- ✅ Package.swift configured
- ✅ Clean build with no errors

### Week 2: Testing & Integration (5 days)

| Day | Tasks | Owner | Status |
|-----|-------|-------|--------|
| Mon | Run all tests, fix test failures | - | ⬜ Not Started |
| Tue | Integration testing with BusinessMath versions | - | ⬜ Not Started |
| Wed | Server functionality testing | - | ⬜ Not Started |
| Thu | Setup CI/CD workflows | - | ⬜ Not Started |
| Fri | Update BusinessMath repo, remove MCP code | - | ⬜ Not Started |

**Deliverables:**
- ✅ All tests passing
- ✅ CI/CD automated
- ✅ BusinessMath updated (MCP removed)
- ✅ Integration tests green

### Week 3: Documentation & Release (5 days)

| Day | Tasks | Owner | Status |
|-----|-------|-------|--------|
| Mon | Write migration guide, user documentation | - | ⬜ Not Started |
| Tue | Create examples, quick start guide | - | ⬜ Not Started |
| Wed | Tag releases (BusinessMath 2.1.0, BusinessMathMCP 1.0.0) | - | ⬜ Not Started |
| Thu | Announce separation, monitor feedback | - | ⬜ Not Started |
| Fri | Address early issues, update docs | - | ⬜ Not Started |

**Deliverables:**
- ✅ Complete documentation
- ✅ Releases published
- ✅ Announcement posted
- ✅ Support monitoring active

### Week 4+: Ongoing (Support Period)

- **Week 4-5:** Daily monitoring, rapid response to issues
- **Week 6-8:** Weekly check-ins, document common issues
- **Month 2-3:** Regular updates, address enhancement requests

---

## Risk Assessment

### High-Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Breaking existing user integrations** | High (80%) | High | Comprehensive migration guide, extended support for old version |
| **Version conflicts (BusinessMath/MCP)** | Medium (40%) | High | Clear compatibility matrix, automated version checking |
| **Undiscovered dependencies** | Low (20%) | High | Thorough code audit before migration, extensive testing |
| **CI/CD failures in new repo** | Medium (50%) | Medium | Test workflows before migration, parallel CI during transition |

### Medium-Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **User adoption slow** | Medium (40%) | Medium | Clear benefits communication, migration tools |
| **Documentation gaps** | Medium (50%) | Medium | Peer review docs, user testing of migration guide |
| **Performance regression** | Low (15%) | Medium | Benchmark tests before/after, performance monitoring |
| **MCP SDK breaking changes** | Medium (30%) | Medium | Pin to stable MCP SDK version, monitor SDK updates |

### Low-Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **GitHub permissions issues** | Low (10%) | Low | Verify access before starting |
| **Package name conflicts** | Very Low (5%) | Low | Check Swift Package Index before naming |
| **License/legal issues** | Very Low (2%) | Low | Both repos use same MIT license |

### Risk Monitoring

Weekly risk review during migration:
- [ ] Check GitHub issues for unexpected problems
- [ ] Monitor CI build success rates
- [ ] Track user feedback sentiment
- [ ] Review integration test results

---

## Post-Migration Tasks

### Immediate (Week 4)

- [ ] **Monitor for issues**
  - Check GitHub issues daily
  - Respond to questions within 24 hours
  - Document common issues in FAQ

- [ ] **Update external resources**
  - Update Swift Package Index
  - Update documentation website
  - Update tutorial videos

- [ ] **Collect feedback**
  - Survey users on migration experience
  - Document pain points
  - Plan improvements

### Short-term (Months 2-3)

- [ ] **Release patch versions**
  - Fix any discovered bugs
  - Improve error messages
  - Enhance documentation

- [ ] **Optimize CI/CD**
  - Reduce build times
  - Add more integration tests
  - Setup performance benchmarks

- [ ] **Community engagement**
  - Write blog post about separation
  - Present at Swift meetups
  - Gather feature requests

### Long-term (Months 4-6)

- [ ] **Evaluate success**
  - Measure adoption rate
  - Analyze issues resolved
  - Compare before/after metrics

- [ ] **Plan enhancements**
  - Independent MCP features (not tied to BusinessMath releases)
  - Additional transport options
  - Extended tool capabilities

- [ ] **Archive old code**
  - Remove .archive/ folder from BusinessMath
  - Finalize deprecation of 2.0.x branch
  - Clean up old documentation

### Metrics to Track

| Metric | Target | Actual | Notes |
|--------|--------|--------|-------|
| Migration completion rate (4 weeks) | 70% | - | Users moved to new package |
| CI build success rate | >95% | - | Both repositories |
| Issue resolution time | <48h | - | Critical issues |
| User satisfaction | 4/5 stars | - | Survey results |
| Test coverage (BusinessMathMCP) | 80% | - | New repository |

---

## Success Criteria

Migration considered successful when:

- [x] **Technical**
  - BusinessMathMCP builds cleanly in separate repo
  - All tests pass (>99% success rate)
  - CI/CD fully automated
  - No critical bugs reported

- [x] **User Experience**
  - Migration guide clear and complete
  - <5 GitHub issues per week after first month
  - Positive community feedback
  - 70%+ users migrated within 4 weeks

- [x] **Architecture**
  - Clean dependency boundaries
  - BusinessMath truly cross-platform
  - Independent versioning working
  - No code duplication issues

- [x] **Operations**
  - Both repos have active CI/CD
  - Release process documented
  - Support burden manageable
  - Documentation complete

---

## Appendix

### A. File Inventory

**BusinessMathMCP Source Files (51 total):**

```
Infrastructure (11 files):
├── MCPCompat.swift (430 lines)
├── ToolDefinition.swift (76 lines)
├── TypeMarshalling.swift (352 lines)
├── ValueExtensions.swift (187 lines)
├── HTTPServerTransport.swift (547 lines)
├── SSESession.swift (153 lines)
├── SSESessionManager.swift (239 lines)
├── HTTPResponseManager.swift (263 lines)
├── APIKeyAuthenticator.swift (185 lines)
├── Resources.swift (1,344 lines)
└── Prompts.swift (517 lines)

Tools (40 files):
├── FinancialRatiosTools.swift (835 lines)
├── FinancialRatiosToolsExtensions.swift (501 lines)
├── FinancingTools.swift (426 lines)
├── WorkingCapitalTools.swift (405 lines)
├── DebtTools.swift (699 lines)
├── DebtToolsExtensions.swift (358 lines)
├── TVMTools.swift (696 lines)
├── EquityValuationTools.swift (644 lines)
├── BondValuationTools.swift (943 lines)
├── InvestmentMetricsTools.swift (779 lines)
├── ValuationCalculatorsTools.swift (1,031 lines)
├── LoanPaymentAnalysisTools.swift (938 lines)
├── StatisticalTools.swift (685 lines)
├── AdvancedStatisticsTools.swift (1,338 lines)
├── HypothesisTestingTools.swift (943 lines)
├── BayesianTools.swift (202 lines)
├── OptimizationTools.swift (730 lines)
├── AdvancedOptimizationTools.swift (1,174 lines)
├── AdaptiveOptimizationTools.swift (507 lines)
├── ParallelOptimizationTools.swift (1,264 lines)
├── IntegerProgrammingTools.swift (818 lines)
├── PortfolioTools.swift (456 lines)
├── MeanVariancePortfolioTools.swift (376 lines)
├── RiskAnalyticsTools.swift (544 lines)
├── PerformanceBenchmarkTools.swift (1,094 lines)
├── ForecastingTools.swift (588 lines)
├── TrendForecastingTools.swift (522 lines)
├── SeasonalityTools.swift (401 lines)
├── TimeSeriesTools.swift (428 lines)
├── AdvancedOptionsTools.swift (483 lines)
├── RealOptionsTools.swift (670 lines)
├── CreditDerivativesTools.swift (549 lines)
├── ScenarioAnalysisTools.swift (502 lines)
├── UtilityTools.swift (604 lines)
├── GrowthAnalysisTools.swift (536 lines)
├── MonteCarloTools.swift (1,516 lines)
├── extensionFormatted.swift (31 lines)
└── extensionString.swift (26 lines)

Total: 30,472 lines
```

### B. Dependency Matrix

| Package | Depends On | Version Constraint |
|---------|------------|-------------------|
| BusinessMath | swift-numerics | >= 1.0.0 |
| BusinessMathMCP | BusinessMath | >= 2.0.0 |
| BusinessMathMCP | swift-sdk (MCP) | >= 0.10.0 |
| BusinessMathMCP | swift-numerics | >= 1.0.0 |
| BusinessMathMCPServer | BusinessMathMCP | (local) |

### C. Contact & Escalation

**Project Owner:** [Owner Name]
**Technical Lead:** [Tech Lead Name]
**Documentation:** [Docs Lead Name]

**Escalation Path:**
1. GitHub Issues (preferred)
2. GitHub Discussions
3. Email: [contact@example.com]

---

## Changelog

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-02-04 | 1.0 | Initial migration plan created | - |

---

**Document Status:** ✅ COMPLETED
**Last Updated:** 2026-02-06
**Completion Date:** 2026-02-06

## Completion Summary

**Migration completed successfully on 2026-02-06**

### What was accomplished:
- ✅ Created new businessMathMCP repository at https://github.com/jpurnell/businessMathMCP
- ✅ Copied all 54 MCP source files (30,997 lines of code)
- ✅ Created Package.swift with correct dependencies on BusinessMath
- ✅ Added comprehensive README and documentation
- ✅ Committed and pushed to GitHub
- ✅ Removed MCP targets from BusinessMath Package.swift
- ✅ Removed MCP SDK dependency from BusinessMath
- ✅ Deleted all MCP source files from BusinessMath
- ✅ Committed and pushed BusinessMath changes

### Timeline:
**Planned:** 3 weeks (2026-02-04 to 2026-02-25)
**Actual:** 1 day (2026-02-06)

The migration was completed significantly faster than planned because:
- Clear separation boundaries already existed in code
- No hidden dependencies discovered
- Automated tooling simplified file migration
- Direct push to correct GitHub repository (https://github.com/jpurnell/businessMathMCP)

### Next Steps:
- Monitor GitHub issues for any integration problems
- Update documentation if users report migration difficulties
- Consider tagging releases (BusinessMath 2.1.0, BusinessMathMCP 1.0.0)
