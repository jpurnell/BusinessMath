# Coverage Gap Analysis - Quick Start Guide

**Purpose**: Find exactly which files, functions, and lines need tests or documentation.

---

## Quick Commands

### Run All Analyses (No Coverage Data Needed)
```bash
cd "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"

# Find files without tests (~2 seconds)
swift "Instruction Set/project/summaries/analyzers/file_test_mapper.swift"

# Find undocumented APIs (~10 seconds)
swift "Instruction Set/project/summaries/analyzers/doc_gap_analyzer.swift"
```

### View Results
```bash
# Human-readable output is printed to console
# Machine-readable JSON is saved to:
cat "Instruction Set/project/summaries/data/file_mapping.json"
cat "Instruction Set/project/summaries/data/doc_gaps.json"
```

---

## What You Get

### 1. File-Test Mapping
**Tool**: `analyzers/file_test_mapper.swift`
**Output**: `data/file_mapping.json`

**Tells you**:
- Which 206 files (58.2%) have NO tests
- Which 148 files (41.8%) have tests
- Suggested test file paths for uncovered files

**Example output**:
```
📊 Results:
- Total source files: 354
- Files WITHOUT tests: 206 (58.2%)

📋 Files without tests:
  1. AdvancedOptimization/MultiPeriodOptimizer.swift
  2. AdvancedOptimization/RobustOptimizer.swift
  ...
```

### 2. Documentation Gaps
**Tool**: `analyzers/doc_gap_analyzer.swift`
**Output**: `data/doc_gaps.json`

**Tells you**:
- Which 1,108 public APIs (24.7%) lack documentation
- File:line locations for each undocumented API
- Breakdown by type (func, struct, enum, etc.)

**Example output**:
```
📊 Results:
- Total public APIs: 4,491
- Undocumented: 1,108 (24.7%)

By type:
  - func: 363
  - let: 278
  - init: 154
  ...

📋 Top files with undocumented APIs:
  1. Streaming/StreamingComposition.swift (90 undocumented)
  2. Streaming/StreamingStatistics.swift (82 undocumented)
  ...
```

### 3. Line Coverage (Coming Soon)
**Tool**: `analyzers/line_coverage_extractor.swift` (in development)
**Output**: `data/line_coverage.json`

**Will tell you**:
- Which specific lines lack coverage
- Files with <80% coverage
- Uncovered code regions

---

## Common Workflows

### Find Which Files Need Tests
```bash
swift "Instruction Set/project/summaries/analyzers/file_test_mapper.swift"
# Pick a file from the output
# Create corresponding test file
# Write tests
```

### Find Which APIs Need Documentation
```bash
swift "Instruction Set/project/summaries/analyzers/doc_gap_analyzer.swift"
# Open a file with many undocumented APIs
# Add /// comments above public declarations
# Re-run to verify improvement
```

### Generate TODO List for LLM (Coming Soon)
```bash
swift "Instruction Set/project/summaries/generators/todo_generator.swift"
# Creates COVERAGE_TODO.md with actionable tasks
# Each task has clear success criteria
# LLM can work through tasks systematically
```

---

## Integration with Existing Metrics

You already have `generate_library_metrics.swift` which provides:
- Overall health score
- Test-to-code ratio
- Build health
- Git statistics

The **new coverage analyzers** provide:
- **Specific gaps**: Exact files/functions/lines that need attention
- **Actionable output**: File:line references for precise fixes
- **LLM-friendly**: Structured JSON for automation

### Run Both
```bash
# Get overall health
swift "Instruction Set/project/summaries/generate_library_metrics.swift"

# Get specific gaps
swift "Instruction Set/project/summaries/analyzers/file_test_mapper.swift"
swift "Instruction Set/project/summaries/analyzers/doc_gap_analyzer.swift"
```

---

## JSON Output Structure

### file_mapping.json
```json
{
  "summary": {
    "total_files": 354,
    "files_with_tests": 148,
    "files_without_tests": 206,
    "coverage_percent": 41.8
  },
  "files_without_tests": [
    {
      "source": "AdvancedOptimization/MultiPeriodOptimizer.swift",
      "suggested_test": "Tests/.../MultiPeriodOptimizerTests.swift"
    }
  ]
}
```

### doc_gaps.json
```json
{
  "summary": {
    "total_public_apis": 4491,
    "undocumented": 1108,
    "documentation_coverage_percent": 75.3
  },
  "undocumented_apis": [
    {
      "file": "Sources/.../Portfolio.swift",
      "line": 45,
      "type": "func",
      "name": "calculateReturns",
      "declaration": "public func calculateReturns() -> Double"
    }
  ]
}
```

---

## Next Steps

1. ✅ **File mapping** - DONE
2. ✅ **Doc gaps** - DONE
3. ⏳ **Line coverage** - Coming soon
4. ⏳ **TODO generator** - Coming soon
5. ⏳ **TDD workflow guide** - Coming soon

**Current Status**: You can identify files without tests and APIs without docs!

---

## Troubleshooting

### "No such file or directory"
Make sure you're in the package root:
```bash
cd "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
```

### "Permission denied"
Make scripts executable:
```bash
chmod +x "Instruction Set/project/summaries/analyzers/"*.swift
```

### JSON parsing errors
Validate JSON output:
```bash
cat "Instruction Set/project/summaries/data/file_mapping.json" | jq .
```

---

## More Information

- **Architecture**: See `COVERAGE_ARCHITECTURE.md` for system design
- **Full Guide**: See `README.md` for comprehensive documentation
- **Metrics**: See `generate_library_metrics.swift` for overall health tracking

---

*Last updated: 2026-02-10*
