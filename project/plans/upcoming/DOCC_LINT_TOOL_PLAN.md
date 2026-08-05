# DocC Lint Tool Implementation Plan

**Created**: 2026-03-11
**Status**: Planning
**Target Location**: `/usr/local/custom/bin/docc-lint`

---

## Executive Summary

A Swift-based command-line tool that validates DocC documentation across any Swift codebase, providing actionable diagnostics with source file mapping, incremental scanning via content hashing, and multiple output formats for CI/CD integration.

---

## Problem Statement

1. Xcode's DocC diagnostics JSON lacks file names - only line/column numbers
2. Identifying which files cause warnings requires manual detective work
3. No incremental validation - full rebuilds waste time
4. No standardized output for CI/CD pipelines
5. No automated fix capabilities despite diagnostics containing fix suggestions

---

## Goals

| Goal | Success Criteria |
|------|------------------|
| Source Mapping | Every diagnostic includes exact file path + line + content snippet |
| Incremental Scanning | Only process changed files (via SHA256 hash cache) |
| Dual Validation Modes | `--full` (with symbol graphs) and `--syntax-only` (fast) |
| Multiple Output Formats | JSON, CSV, SARIF (GitHub), Terminal (colored) |
| Auto-Fix Support | `--fix` flag applies suggested replacements |
| Cross-Platform | macOS and Linux compatible |
| CI/CD Ready | Exit codes: 0=clean, 1=warnings, 2=errors |

---

## Architecture

```
docc-lint/
├── Package.swift
├── Sources/
│   └── DocCLint/
│       ├── Main.swift                    # Entry point, ArgumentParser setup
│       ├── Commands/
│       │   ├── LintCommand.swift         # Main lint command
│       │   ├── FixCommand.swift          # Auto-fix command
│       │   └── CacheCommand.swift        # Cache management (clear, status)
│       ├── Core/
│       │   ├── Scanner.swift             # File discovery, .docc detection
│       │   ├── HashCache.swift           # SHA256 caching, persistence
│       │   ├── SymbolGraphGenerator.swift # swiftc -emit-symbol-graph wrapper
│       │   ├── DocCProcessor.swift       # xcrun docc convert wrapper
│       │   └── DiagnosticParser.swift    # JSON parsing, source mapping
│       ├── Reporters/
│       │   ├── Reporter.swift            # Protocol
│       │   ├── JSONReporter.swift        # Machine-readable JSON
│       │   ├── CSVReporter.swift         # Spreadsheet-compatible
│       │   ├── SARIFReporter.swift       # GitHub Code Scanning
│       │   └── TerminalReporter.swift    # Human-readable, ANSI colors
│       ├── Fixers/
│       │   ├── AutoFixer.swift           # Apply diagnostic replacements
│       │   └── FixPreview.swift          # Dry-run fix preview
│       ├── Models/
│       │   ├── Diagnostic.swift          # Parsed diagnostic with source info
│       │   ├── SourceLocation.swift      # File + line + column + content
│       │   ├── ScanResult.swift          # Per-file scan results
│       │   └── CacheEntry.swift          # Hash + timestamp + path
│       └── Extensions/
│           ├── FileManager+Hashing.swift
│           ├── Process+Async.swift
│           └── String+ANSI.swift
├── Tests/
│   └── DocCLintTests/
│       ├── ScannerTests.swift
│       ├── DiagnosticParserTests.swift
│       └── HashCacheTests.swift
├── Resources/
│   └── default-config.yml                # Default configuration
└── Scripts/
    └── install.sh                        # Install to /usr/local/custom/bin
```

---

## Command-Line Interface

### Primary Commands

```bash
# Full validation (compiles code, generates symbol graphs)
docc-lint /path/to/project --full

# Syntax-only validation (fast, no compilation)
docc-lint /path/to/project --syntax-only

# Auto-fix issues
docc-lint /path/to/project --fix

# Preview fixes without applying
docc-lint /path/to/project --fix --dry-run
```

### Options

```bash
docc-lint [PATH] [OPTIONS]

Arguments:
  PATH                      Project root (default: current directory)

Validation Mode (mutually exclusive):
  --full                    Full validation with symbol graph generation
  --syntax-only             Fast markdown/task-group validation only (default)

Output Options:
  -f, --format <FORMAT>     Output format: terminal, json, csv, sarif (default: terminal)
  -o, --output <FILE>       Write output to file (default: stdout)
  --no-color                Disable ANSI colors in terminal output

Filtering:
  --include-swift-docs      Also lint /// doc comments in Swift files
  --ignore <PATTERN>        Glob pattern to ignore (can be repeated)
  --severity <LEVEL>        Minimum severity: error, warning, note (default: warning)

Caching:
  --no-cache                Disable incremental caching
  --clear-cache             Clear cache before running
  --cache-path <PATH>       Custom cache location (default: .docc-lint-cache)

Fix Options:
  --fix                     Apply suggested fixes automatically
  --dry-run                 Preview fixes without applying (requires --fix)

CI/CD:
  --strict                  Treat warnings as errors (exit code 2)
  --github-actions          Output GitHub Actions workflow commands

Other:
  -v, --verbose             Verbose output
  -q, --quiet               Only output errors
  --version                 Print version
  -h, --help                Show help
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, no issues |
| 1 | Warnings found |
| 2 | Errors found (or warnings with `--strict`) |
| 3 | Tool error (invalid arguments, file access, etc.) |

---

## Core Algorithms

### 1. File Discovery (Scanner.swift)

```swift
func discoverFiles(at root: URL, options: ScanOptions) async -> [DiscoveredFile] {
    // 1. Find all .docc catalogs
    // 2. Find all .md files within catalogs
    // 3. Optionally find .swift files with /// comments
    // 4. Apply ignore patterns
    // 5. Return with file type classification
}

enum FileType {
    case doccCatalog(URL)           // The .docc bundle itself
    case markdownInCatalog(URL)     // .md inside .docc
    case standaloneMarkdown(URL)    // .md outside .docc
    case swiftSource(URL)           // .swift with doc comments
}
```

### 2. Hash Caching (HashCache.swift)

```swift
struct CacheEntry: Codable {
    let path: String
    let contentHash: String         // SHA256 of file contents
    let modificationTime: Date
    let lastScanResult: ScanResultSummary?
}

class HashCache {
    private var entries: [String: CacheEntry]
    private let cachePath: URL

    func needsScan(_ file: URL) -> Bool {
        guard let entry = entries[file.path] else { return true }
        let currentHash = computeHash(file)
        return entry.contentHash != currentHash
    }

    func updateEntry(_ file: URL, result: ScanResult) { ... }
    func persist() throws { ... }
    func load() throws { ... }
}
```

### 3. Symbol Graph Generation (SymbolGraphGenerator.swift)

```swift
func generateSymbolGraphs(for target: String, at projectRoot: URL) async throws -> URL {
    // 1. Detect build system (SwiftPM vs Xcode project)
    // 2. For SwiftPM:
    //    swift build --target <target>
    //    Find symbol graphs in .build/
    // 3. For Xcode:
    //    xcodebuild -scheme <scheme> -derivedDataPath <temp>
    //    Find symbol graphs in DerivedData
    // 4. Return path to symbol graph directory
}
```

### 4. Source Mapping (DiagnosticParser.swift)

**The Critical Algorithm**: Map line numbers back to source files

```swift
func mapDiagnosticsToSources(
    diagnostics: [RawDiagnostic],
    catalog: DocCCatalog
) -> [MappedDiagnostic] {

    // Strategy 1: For .docc catalogs, docc processes files in deterministic order
    // Build ordered file list matching docc's processing order
    let orderedFiles = catalog.filesInProcessingOrder()

    // Strategy 2: Use column width as fingerprint
    // Match diagnostic's column count to actual line lengths in files

    // Strategy 3: For ambiguous cases, search for content patterns
    // Use the replacement text as a search key

    return diagnostics.map { diag in
        let sourceFile = findSourceFile(for: diag, in: orderedFiles)
        let contentSnippet = extractSnippet(file: sourceFile, line: diag.line)
        return MappedDiagnostic(
            file: sourceFile,
            line: diag.line,
            column: diag.column,
            content: contentSnippet,
            message: diag.summary,
            severity: diag.severity,
            suggestedFix: diag.solutions.first
        )
    }
}
```

### 5. Parallel Processing

```swift
func processFiles(_ files: [DiscoveredFile], options: LintOptions) async -> [ScanResult] {
    await withTaskGroup(of: ScanResult.self) { group in
        // Limit concurrency to avoid overwhelming system
        let maxConcurrency = ProcessInfo.processInfo.activeProcessorCount
        var results: [ScanResult] = []

        for file in files {
            group.addTask {
                await self.processFile(file, options: options)
            }
        }

        for await result in group {
            results.append(result)
        }

        return results
    }
}
```

---

## Output Formats

### Terminal Output (default)

```
DocC Lint Results
=================

❌ Sources/BusinessMath/BusinessMath.docc/Part5-Optimization.md
   Line 53, Column 1-38
   │
53 │ ### For Business Users (FP&A, Finance):
   │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   │
   ⚠ Only links are allowed in task group list items

   💡 Suggested fix: Remove non-link item
      - ### For Business Users (FP&A, Finance):
      + **For Business Users (FP&A, Finance):**

─────────────────────────────────────────────────

Summary: 2 files, 20 warnings, 0 errors
```

### JSON Output

```json
{
  "version": "1.0.0",
  "timestamp": "2026-03-11T02:30:00Z",
  "summary": {
    "filesScanned": 45,
    "filesWithIssues": 2,
    "totalWarnings": 20,
    "totalErrors": 0
  },
  "diagnostics": [
    {
      "file": "Sources/BusinessMath/BusinessMath.docc/Part5-Optimization.md",
      "line": 53,
      "column": 1,
      "endColumn": 38,
      "severity": "warning",
      "message": "Only links are allowed in task group list items",
      "content": "### For Business Users (FP&A, Finance):",
      "ruleId": "task-group-links-only",
      "suggestedFix": {
        "description": "Remove non-link item",
        "replacement": ""
      }
    }
  ]
}
```

### CSV Output

```csv
file,line,column,severity,message,content,rule_id
Sources/BusinessMath/BusinessMath.docc/Part5-Optimization.md,53,1,warning,Only links are allowed in task group list items,"### For Business Users (FP&A, Finance):",task-group-links-only
```

### SARIF Output (GitHub Code Scanning)

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "docc-lint",
        "version": "1.0.0",
        "rules": [...]
      }
    },
    "results": [...]
  }]
}
```

---

## Configuration File

`.docc-lint.yml` (optional, auto-detected in project root)

```yaml
# docc-lint configuration

# Validation mode (can be overridden by CLI)
mode: syntax-only  # or "full"

# Files to ignore
ignore:
  - "**/Pods/**"
  - "**/build/**"
  - "**/.build/**"

# Include Swift doc comments
include_swift_docs: false

# Severity settings
severity:
  minimum: warning
  treat_warnings_as_errors: false

# Rule-specific overrides
rules:
  task-group-links-only:
    severity: error
  missing-documentation:
    enabled: false

# Cache settings
cache:
  enabled: true
  path: .docc-lint-cache

# Output defaults
output:
  format: terminal
  color: auto  # auto, always, never
```

---

## Implementation Phases

### Phase 1: Foundation (MVP)
**Estimated Time**: 4-6 hours

- [ ] Project setup with SwiftPM + ArgumentParser
- [ ] Basic CLI structure (LintCommand)
- [ ] File discovery (Scanner) - find .docc catalogs
- [ ] Hash cache implementation
- [ ] Basic docc convert wrapper (syntax-only mode)
- [ ] Terminal reporter with basic output
- [ ] Install script

**Deliverable**: Working `docc-lint --syntax-only` with basic terminal output

### Phase 2: Source Mapping
**Estimated Time**: 3-4 hours

- [ ] Diagnostic JSON parser
- [ ] Source file mapping algorithm
- [ ] Content snippet extraction
- [ ] Enhanced terminal output with code snippets

**Deliverable**: Diagnostics show exact file + line + content

### Phase 3: Full Validation Mode
**Estimated Time**: 3-4 hours

- [ ] Symbol graph generation (SwiftPM)
- [ ] Symbol graph generation (Xcode projects)
- [ ] Full validation pipeline
- [ ] `--full` flag implementation

**Deliverable**: `docc-lint --full` matches Xcode's validation

### Phase 4: Additional Reporters
**Estimated Time**: 2-3 hours

- [ ] JSON reporter
- [ ] CSV reporter
- [ ] SARIF reporter
- [ ] `--format` and `--output` options

**Deliverable**: All output formats working

### Phase 5: Auto-Fix
**Estimated Time**: 2-3 hours

- [ ] Fix application logic
- [ ] Dry-run preview
- [ ] Backup creation before fixing
- [ ] `--fix` and `--dry-run` flags

**Deliverable**: Automated fix capability

### Phase 6: Swift Doc Comments
**Estimated Time**: 2-3 hours

- [ ] Swift file parsing for /// comments
- [ ] Doc comment extraction
- [ ] Integration with validation pipeline
- [ ] `--include-swift-docs` flag

**Deliverable**: Swift doc comment linting

### Phase 7: Configuration & Polish
**Estimated Time**: 2-3 hours

- [ ] YAML config file support
- [ ] GitHub Actions output mode
- [ ] Verbose/quiet modes
- [ ] Error handling improvements
- [ ] Linux compatibility testing

**Deliverable**: Production-ready tool

### Phase 8: Testing & Documentation
**Estimated Time**: 2-3 hours

- [ ] Unit tests for core components
- [ ] Integration tests
- [ ] README.md
- [ ] Usage examples
- [ ] Man page (optional)

**Deliverable**: Fully tested and documented

---

## Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),  // YAML parsing
    .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),  // SHA256
]
```

---

## Linux Compatibility Notes

1. **No `xcrun`**: Use `docc` directly (must be in PATH)
2. **No Xcode**: Only SwiftPM projects supported on Linux
3. **Path differences**: Handle `/` vs `\` (not an issue Swift<->Swift)
4. **Process execution**: Use `Process` API (works cross-platform)

Detection:
```swift
#if os(Linux)
let doccPath = "/usr/bin/docc"  // Or find via `which docc`
#else
let doccPath = try shellOutput("xcrun --find docc")
#endif
```

---

## Success Metrics

1. **Accuracy**: 100% of Xcode-reported warnings also found by tool
2. **Performance**: < 5 seconds for syntax-only on 100-file project (warm cache)
3. **Usability**: Clear, actionable output with exact file locations
4. **Reliability**: No false positives

---

## Future Enhancements (Post-v1.0)

1. **Watch mode**: `docc-lint --watch` for continuous validation
2. **IDE integration**: VSCode/Xcode extensions
3. **Custom rules**: Plugin system for project-specific rules
4. **Metrics dashboard**: Track documentation health over time
5. **Pre-commit hook**: Git hook for automated validation

---

## References

- [DocC Documentation](https://www.swift.org/documentation/docc/)
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- [SARIF Specification](https://sarifweb.azurewebsites.net/)
- [Symbol Graph Format](https://github.com/apple/swift/blob/main/docs/SymbolGraph.md)

---

## Appendix: Known DocC Diagnostic Types

| Rule ID | Message | Common Cause |
|---------|---------|--------------|
| `task-group-links-only` | Only links are allowed in task group list items | Text after ``` ``Symbol`` ``` or `<doc:>` |
| `extraneous-content` | Extraneous content found after a link | Description after link in task group |
| `unresolved-reference` | Can't resolve reference | Broken ``` ``Symbol`` ``` link |
| `missing-article` | Article not found | Broken `<doc:Article>` link |
