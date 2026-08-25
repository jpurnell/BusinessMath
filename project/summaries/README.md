# BusinessMath Library Summaries & Metrics

> **Metrics tooling removed, 2026-08-24.** The generator scripts this file used to
> index wrote to pre-v2 paths (`Instruction Set/05_SUMMARIES`,
> `development-guidelines/05_SUMMARIES`) that the v2 migration deleted, so they had
> not run since April 2026. Their output is preserved in `library_metrics.json` and
> `history/`. `quality-gate generate-pulse` and the `doc-coverage` checker cover the
> same ground and are actually run.


This directory contains tools for tracking and reporting on the BusinessMath library's health and statistics.

## Quick Start

### Generate Library Metrics
```bash
cd "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
swift "Instruction Set/project/summaries/generate_library_metrics.swift"
```

---

## 1. Library Metrics Tool

**File**: `generate_library_metrics.swift`

Generates comprehensive statistics about the BusinessMath library itself.

### What It Tracks

#### Code Metrics
- **Source Files**: Count of `.swift` files in `/Sources`
- **Test Files**: Count of test files in `/Tests`
- **Lines of Code**: Total, source, and test lines
- **Public APIs**: Count of public functions, types, etc.
- **Modules**: Number of library modules
- **Test-to-Code Ratio**: Ratio of test code to source code

#### Test Coverage
- **Total Tests**: Number of test functions
- **Code Coverage %**: Percentage of code covered by tests
- **Covered/Executable Lines**: Actual line coverage numbers

*Note*: Run `swift test --enable-code-coverage` before generating metrics to get coverage data.

#### Documentation Coverage
- **Documented APIs**: Count of public APIs with `///` documentation
- **Total Public APIs**: All public declarations
- **Coverage %**: Percentage of APIs with documentation
- **Missing Docs**: Number of undocumented APIs

#### Build Health
- **Build Status**: Whether the package builds successfully
- **Warnings**: Count of compiler warnings
- **Errors**: Count of compiler errors
- **Dependencies**: Number of external dependencies

#### Performance Benchmarks
- **Benchmark Tests**: Count of performance/benchmark test functions
- **Historical Tracking**: Tracks metrics over time (see `history/` directory)

#### Git Statistics
- **Total Commits**: Repository commit count
- **Contributors**: Number of unique contributors
- **Last Commit**: When the last commit was made
- **Current Branch**: Active git branch

#### Library Health Score
Composite score (0-100%) based on:
- Test Coverage (30% weight)
- Documentation Coverage (30% weight)
- Build Health (20% weight)
- Test Ratio (20% weight)

**Grading**:
- A: 90-100%
- B: 80-89%
- C: 70-79%
- D: 60-69%
- F: Below 60%

### Output Files

#### Current Metrics
`library_metrics.json` - Latest metrics snapshot
```json
{
  "timestamp": "2026-02-08T...",
  "code_metrics": { ... },
  "test_coverage": { ... },
  "health_score": {
    "overall": 85.3,
    "grade": "B"
  }
}
```

#### Historical Tracking
`history/metrics_YYYY-MM-DD_HHMMSS.json` - Timestamped snapshots

Track metrics over time by running the generator regularly (e.g., on each commit, weekly, or before releases).

### Use Cases

1. **Pre-Release Checks**: Verify library health before publishing
2. **CI/CD Integration**: Run in GitHub Actions to track quality metrics
3. **Documentation Audits**: Find undocumented APIs
4. **Regression Detection**: Compare historical metrics to catch quality degradation
5. **Contributor Onboarding**: Show library statistics to new contributors

### Interpretation Guide

| Metric | Good | Warning | Action Needed |
|--------|------|---------|---------------|
| Test Coverage | >80% | 60-80% | <60% |
| Doc Coverage | >70% | 50-70% | <50% |
| Test Ratio | >1.0x | 0.5-1.0x | <0.5x |
| Build Warnings | <5 | 5-20 | >20 |
| Health Score | A-B | C | D-F |

---


## Automation & CI/CD Integration

### GitHub Actions Example

```yaml
name: Library Metrics

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  metrics:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Generate Coverage
        run: swift test --enable-code-coverage

      - name: Generate Metrics
        run: swift "Instruction Set/project/summaries/generate_library_metrics.swift"

      - name: Upload Metrics
        uses: actions/upload-artifact@v3
        with:
          name: library-metrics
          path: Instruction Set/project/summaries/library_metrics.json

      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const metrics = JSON.parse(fs.readFileSync('Instruction Set/project/summaries/library_metrics.json'));
            const score = metrics.health_score.overall.toFixed(1);
            const grade = metrics.health_score.grade;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Library Health Score: ${score}% (${grade})\n\nSee artifacts for full metrics.`
            });
```

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-push

echo "Checking library health..."
swift "Instruction Set/project/summaries/generate_library_metrics.swift" > /dev/null

# Read health score from JSON
SCORE=$(jq -r '.health_score.overall' "Instruction Set/project/summaries/library_metrics.json")

if (( $(echo "$SCORE < 70" | bc -l) )); then
    echo "❌ Health score too low: $SCORE%"
    echo "Consider improving tests or documentation before pushing."
    exit 1
fi

echo "✅ Health score: $SCORE%"
```

---

## Historical Analysis

### View Metrics Over Time

```bash
# List all historical snapshots
ls -lh "Instruction Set/project/summaries/history/"

# Compare two snapshots
diff \
  "Instruction Set/project/summaries/history/metrics_2026-02-01_120000.json" \
  "Instruction Set/project/summaries/history/metrics_2026-02-08_120000.json"

# Extract health scores over time
jq -r '.health_score.overall' Instruction\ Set/project/summaries/history/*.json
```

### Visualize Trends (Python Example)

```python
import json
import glob
import matplotlib.pyplot as plt
from datetime import datetime

files = sorted(glob.glob('Instruction Set/project/summaries/history/*.json'))
dates = []
scores = []

for f in files:
    with open(f) as file:
        data = json.load(file)
        dates.append(datetime.fromisoformat(data['timestamp']))
        scores.append(data['health_score']['overall'])

plt.plot(dates, scores)
plt.xlabel('Date')
plt.ylabel('Health Score (%)')
plt.title('BusinessMath Library Health Over Time')
plt.show()
```

---

## Maintenance

### Regular Schedule

- **Daily**: Run metrics in CI/CD
- **Weekly**: Review trends and address declining metrics
- **Pre-Release**: Verify health score is acceptable (>80%)
- **Post-Release**: Generate baseline for next development cycle

### What to Monitor

1. **Test Coverage Trending Down**: Add more tests
2. **Documentation Coverage Low**: Document new APIs
3. **Build Warnings Increasing**: Technical debt accumulation
4. **Health Score Dropping**: Quality regression

---

## Files in This Directory

```
project/summaries/
├── README.md                              # This file
├── generate_library_metrics.swift         # Library health metrics
├── library_metrics.json                   # Latest library metrics
└── history/                               # Historical metric snapshots
    ├── metrics_2026-02-01_120000.json
    ├── metrics_2026-02-08_143022.json
    └── ...
```

---

## Troubleshooting

### "Coverage not available"
Run `swift test --enable-code-coverage` first.

### "Build failed" in metrics
Fix compilation errors before generating metrics.

### Historical metrics not saving
Check write permissions on `history/` directory.

### Inaccurate API counts
The tool uses heuristics (grep patterns). For exact counts, use `SourceKit` APIs.

---

## Future Enhancements

- [ ] Automated trend analysis and alerts
- [ ] Integration with dashboard/web UI
- [ ] Benchmark performance regression detection
- [ ] Automated documentation generation for undocumented APIs
- [ ] Code complexity metrics (cyclomatic complexity)
- [ ] Dependency vulnerability scanning
- [ ] Binary size tracking
- [ ] Compilation time tracking

---

## Related Documentation

- [BusinessMath Test Guide](../Tests/README.md)
- [Documentation Style Guide](../Documentation.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Release Process](../RELEASING.md)
