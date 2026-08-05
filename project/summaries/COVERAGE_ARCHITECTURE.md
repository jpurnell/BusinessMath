# Coverage Analysis System Architecture

**Purpose**: Identify specific gaps in test coverage and documentation at file, function, and line levels.

---

## Design Principles

1. **Modular**: Each component does one thing well and can be tested independently
2. **TDD-Friendly**: Generate actionable TODO lists for systematic gap filling
3. **Incremental**: Can run individual analyzers or the full suite
4. **Fast**: Lightweight analysis without requiring full builds (where possible)

---

## System Components (In Sequence)

### Phase 1: Data Collection (Read-Only)

These components gather raw data about the codebase:

#### 1.1 File Mapper (`file_test_mapper.swift`)
**Purpose**: Map source files to test files
**Input**: Sources directory, Tests directory
**Output**: JSON mapping showing which files have/lack tests
**Runtime**: ~1 second
**Dependencies**: None

```json
{
  "files_with_tests": ["Portfolio.swift", "Statistics.swift"],
  "files_without_tests": ["NewFeature.swift"],
  "mapping": {
    "Portfolio.swift": "Tests/PortfolioTests.swift"
  }
}
```

#### 1.2 Documentation Analyzer (`doc_gap_analyzer.swift`)
**Purpose**: Find public APIs without documentation
**Input**: Source files
**Output**: List of undocumented APIs with file:line references
**Runtime**: ~5-10 seconds
**Dependencies**: None

```json
{
  "undocumented_apis": [
    {
      "file": "Sources/BusinessMath/Portfolio.swift",
      "line": 45,
      "type": "func",
      "name": "calculateReturns"
    }
  ]
}
```

#### 1.3 Line Coverage Extractor (`line_coverage_extractor.swift`)
**Purpose**: Extract detailed coverage from llvm-cov
**Input**: Test coverage data (.profdata)
**Output**: File-by-file line coverage with uncovered regions
**Runtime**: ~10-30 seconds
**Dependencies**: Requires `swift test --enable-code-coverage` run first

```json
{
  "files": [
    {
      "path": "Sources/BusinessMath/Portfolio.swift",
      "coverage_percent": 65.3,
      "uncovered_lines": [45, 67, 89-92]
    }
  ]
}
```

---

### Phase 2: Analysis & Prioritization

These components process the raw data:

#### 2.1 Gap Prioritizer (`gap_prioritizer.swift`)
**Purpose**: Combine data and rank gaps by importance
**Input**: Outputs from Phase 1 components
**Output**: Prioritized list of gaps
**Runtime**: ~1 second
**Dependencies**: Phase 1 outputs

**Prioritization criteria**:
1. Files with 0% coverage (no tests)
2. Public APIs with 0% documentation
3. Files with <50% line coverage
4. Files with 50-80% line coverage
5. Undocumented internal APIs

---

### Phase 3: Action Generation

These components create actionable outputs:

#### 3.1 TODO Generator (`todo_generator.swift`)
**Purpose**: Create LLM-friendly TODO list from prioritized gaps
**Input**: Prioritized gaps from Phase 2
**Output**: `COVERAGE_TODO.md` with checkboxes and clear instructions
**Runtime**: ~1 second
**Dependencies**: Phase 2 output

```markdown
## Task 1: Create tests for Portfolio.swift
- [ ] Create Tests/PortfolioTests.swift
- [ ] Test calculateReturns() happy path
- [ ] Test calculateReturns() edge cases
- [ ] Achieve >80% coverage
```

#### 3.2 TDD Workflow Guide (`tdd_workflow_generator.swift`)
**Purpose**: Generate step-by-step TDD instructions for filling gaps
**Input**: Specific gap (file or function)
**Output**: TDD workflow markdown
**Runtime**: <1 second
**Dependencies**: None (generates templates)

```markdown
# TDD Workflow: Add tests for Portfolio.swift

## Step 1: Write failing test
Create Tests/PortfolioTests.swift with:
- Test setup
- Test case for calculateReturns()
- Expected behavior

## Step 2: Run test (should fail)
`swift test --filter PortfolioTests`

## Step 3: Implement minimum code to pass
...
```

---

### Phase 4: Integration & Orchestration

#### 4.1 Master Script (`analyze_all_gaps.swift`)
**Purpose**: Run all analyzers in sequence and generate all reports
**Input**: Command-line flags (e.g., --quick, --full, --with-coverage)
**Output**: All JSON files + Markdown reports
**Runtime**: Varies (1 sec quick, 30 sec full)
**Dependencies**: All Phase 1-3 components

**Modes**:
- `--quick`: File mapping + doc gaps only (no coverage)
- `--full`: All analyzers including line coverage
- `--update-only`: Refresh existing data without re-analyzing

---

## File Structure

```
Instruction Set/project/summaries/
├── COVERAGE_ARCHITECTURE.md          # This file
├── README.md                          # Main documentation
├── QUICKSTART.md                      # Quick reference

# Phase 1: Data Collection
├── analyzers/
│   ├── file_test_mapper.swift         # Maps files to tests
│   ├── doc_gap_analyzer.swift         # Finds undocumented APIs
│   └── line_coverage_extractor.swift  # Extracts line coverage

# Phase 2: Analysis
├── prioritizer/
│   └── gap_prioritizer.swift          # Prioritizes gaps

# Phase 3: Action Generation
├── generators/
│   ├── todo_generator.swift           # Creates TODO list
│   └── tdd_workflow_generator.swift   # Creates TDD guides

# Phase 4: Integration
├── analyze_all_gaps.swift             # Master orchestrator

# Outputs
├── data/
│   ├── file_mapping.json              # File-test mapping
│   ├── doc_gaps.json                  # Documentation gaps
│   ├── line_coverage.json             # Line coverage data
│   └── prioritized_gaps.json          # Analyzed priorities
├── COVERAGE_TODO.md                   # LLM-actionable TODO list
├── COVERAGE_GAPS.md                   # Human-readable report
└── TDD_WORKFLOWS/                     # Per-file TDD guides
    ├── Portfolio_TDD.md
    └── Statistics_TDD.md
```

---

## Development Sequence

### Sprint 1: File-Level Analysis (Day 1)
**Goal**: Identify which files lack tests

1. ✅ Create `file_test_mapper.swift`
2. ✅ Test with sample files
3. ✅ Verify JSON output format
4. ✅ Run on full codebase
5. ✅ Document usage

**Deliverable**: Know exactly which 100+ files need tests

### Sprint 2: Documentation Analysis (Day 1-2)
**Goal**: Identify undocumented APIs

1. Create `doc_gap_analyzer.swift`
2. Parse Swift syntax for public declarations
3. Check for preceding `///` comments
4. Generate report with file:line references
5. Test on sample files, then full codebase

**Deliverable**: List of 839 undocumented APIs with locations

### Sprint 3: Line Coverage Analysis (Day 2-3)
**Goal**: Extract detailed coverage from tests

1. Create `line_coverage_extractor.swift`
2. Parse llvm-cov JSON export
3. Identify uncovered regions per file
4. Generate human-readable report
5. Test with existing coverage data

**Deliverable**: Know which specific lines lack coverage

### Sprint 4: Prioritization (Day 3)
**Goal**: Rank gaps by importance

1. Create `gap_prioritizer.swift`
2. Implement scoring algorithm
3. Combine file, doc, and line coverage data
4. Sort by priority
5. Test prioritization logic

**Deliverable**: Ordered list of what to fix first

### Sprint 5: TODO Generation (Day 4)
**Goal**: Create actionable LLM tasks

1. Create `todo_generator.swift`
2. Template system for different gap types
3. Generate checkboxes and instructions
4. Test output format
5. Verify LLM can parse and act on it

**Deliverable**: `COVERAGE_TODO.md` with ~150 tasks

### Sprint 6: TDD Workflows (Day 4-5)
**Goal**: Provide TDD guidance for each gap

1. Create `tdd_workflow_generator.swift`
2. Red-Green-Refactor templates
3. Gap-specific instructions
4. Example code snippets
5. Integration with TODO list

**Deliverable**: TDD guide for systematic development

### Sprint 7: Integration (Day 5)
**Goal**: Tie it all together

1. Create `analyze_all_gaps.swift`
2. Command-line interface
3. Progress reporting
4. Error handling
5. Performance optimization

**Deliverable**: One-command analysis of all gaps

---

## Testing Strategy

### Unit Tests
Each analyzer should have tests:

```swift
// Tests/AnalyzerTests/FileTestMapperTests.swift
func testMapsKnownFilesToTests() {
  // Given sample source and test files
  // When mapper runs
  // Then correct mapping is produced
}

func testIdentifiesFilesWithoutTests() {
  // Given source files with no corresponding test
  // When mapper runs
  // Then files_without_tests is populated
}
```

### Integration Tests
Test the full pipeline:

```swift
func testFullAnalysisPipeline() {
  // Given sample project structure
  // When all analyzers run
  // Then TODO list contains expected tasks
}
```

### Smoke Tests
Quick validation:

```bash
# Does it run without errors?
swift analyzers/file_test_mapper.swift > /dev/null

# Does it produce valid JSON?
swift analyzers/file_test_mapper.swift | jq . > /dev/null

# Does the TODO list have tasks?
swift analyze_all_gaps.swift && grep -c "- \[ \]" COVERAGE_TODO.md
```

---

## Usage Examples

### Quick Check (No Coverage Data Needed)
```bash
# Just see which files lack tests and docs
swift analyzers/file_test_mapper.swift
swift analyzers/doc_gap_analyzer.swift
```

### Full Analysis
```bash
# First, generate coverage
swift test --enable-code-coverage

# Then run full analysis
swift analyze_all_gaps.swift --full

# Review outputs
cat COVERAGE_TODO.md
cat COVERAGE_GAPS.md
```

### Work on Specific Gap
```bash
# Generate TDD workflow for specific file
swift generators/tdd_workflow_generator.swift Portfolio.swift

# Follow the red-green-refactor steps
cat TDD_WORKFLOWS/Portfolio_TDD.md
```

### Continuous Integration
```bash
# Run quick check on every commit
swift analyze_all_gaps.swift --quick

# Fail if gaps increase
python scripts/check_gap_regression.py
```

---

## TDD-Friendly Workflow

### For Human Developers

1. **Pick a task** from `COVERAGE_TODO.md`
2. **Generate TDD workflow**: `swift generators/tdd_workflow_generator.swift <file>`
3. **Write failing test** (Red)
4. **Make it pass** (Green)
5. **Refactor**
6. **Re-run analysis** to see progress
7. **Check off task** in TODO list

### For LLM Agents

The TODO list is structured for LLM consumption:

```markdown
## Task 42: Create tests for Portfolio.swift

**File**: `Sources/BusinessMath/Finance/Portfolio/Portfolio.swift`
**Current coverage**: 0% (no tests)
**Priority**: HIGH (public API, no coverage)

### Checklist
- [ ] Read the source file to understand the API
- [ ] Create `Tests/BusinessMathTests/Finance Tests/PortfolioTests.swift`
- [ ] Write test for `init()`
- [ ] Write test for `addAsset()`
- [ ] Write test for `calculateReturns()`
- [ ] Write edge case tests
- [ ] Run `swift test --filter PortfolioTests`
- [ ] Verify coverage >80%

### Success Criteria
- All tests pass
- Coverage >80%
- No new warnings
```

---

## Next Steps

1. **Start small**: Build file_test_mapper.swift first
2. **Test thoroughly**: Verify on sample data before full codebase
3. **Iterate**: Get one component working before building the next
4. **Integrate gradually**: Add components to master script as they're completed
5. **Document**: Keep this architecture doc updated

---

## Benefits of This Approach

✅ **Modular**: Each component is <200 lines, easy to understand
✅ **Testable**: Can unit test each analyzer independently
✅ **Fast**: Can run quick checks without full analysis
✅ **Incremental**: Can improve one component without touching others
✅ **TDD-Ready**: Outputs guide red-green-refactor workflow
✅ **LLM-Friendly**: TODO lists are structured for automation
✅ **Maintainable**: Clear separation of concerns

---

## Current Status

- [ ] Architecture documented (this file)
- [ ] File test mapper
- [ ] Documentation analyzer
- [ ] Line coverage extractor
- [ ] Gap prioritizer
- [ ] TODO generator
- [ ] TDD workflow generator
- [ ] Master orchestrator script
- [ ] Testing suite
- [ ] CI/CD integration

---

*Last updated: 2026-02-10*
