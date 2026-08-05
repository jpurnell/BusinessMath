# Quick Start Guide - Library Metrics

## TL;DR

```bash
# Generate full library metrics (includes build - takes 2-5 minutes)
cd "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
swift "Instruction Set/project/summaries/generate_library_metrics.swift"

# Generate portfolio case study statistics (fast - under 1 second)
swift "Instruction Set/project/summaries/generate_portfolio_statistics.swift"
```

## What Gets Generated

### Library Metrics (`library_metrics.json`)
```json
{
  "code_metrics": {
    "source_files": 355,
    "test_files": 120,
    "public_apis": 450,
    "test_to_code_ratio": 1.2
  },
  "test_coverage": {
    "total_tests": 580,
    "coverage_percent": 75.3
  },
  "documentation_coverage": {
    "coverage_percent": 68.2
  },
  "health_score": {
    "overall": 82.5,
    "grade": "B"
  }
}
```

### Portfolio Statistics (`portfolio_statistics.json`)
```json
{
  "annual_value": {
    "total_annual_value": 2012500,
    "tracking_error_value": 1012500,
    "transaction_cost_savings": 1000000
  },
  "improvements": {
    "tracking_error_improvement_percent": 49.09,
    "transaction_cost_reduction_percent": 28.57,
    "time_speedup": 1000
  }
}
```

## Day-to-Day Usage

### Before Committing Code
```bash
# Quick check of library health
swift "Instruction Set/project/summaries/generate_library_metrics.swift" | grep "Health Score"
```

### Before Publishing Blog Post
```bash
# Regenerate case study statistics
swift "Instruction Set/project/summaries/generate_portfolio_statistics.swift"

# Copy output to blog post markdown file
```

### Weekly Review
```bash
# Generate full metrics with historical tracking
swift "Instruction Set/project/summaries/generate_library_metrics.swift"

# Compare to last week
diff \
  "Instruction Set/project/summaries/history/metrics_$(date -v-7d +%Y-%m-%d)*.json" \
  "Instruction Set/project/summaries/library_metrics.json"
```

## Understanding the Health Score

| Score | Grade | Meaning | Action |
|-------|-------|---------|--------|
| 90-100 | A | Excellent | Maintain quality |
| 80-89 | B | Good | Minor improvements |
| 70-79 | C | Fair | Address weak areas |
| 60-69 | D | Poor | Needs attention |
| <60 | F | Critical | Immediate action |

### Score Components
- **30%** Test Coverage (target: >80%)
- **30%** Documentation Coverage (target: >70%)
- **20%** Build Health (clean build)
- **20%** Test Ratio (target: >1.0x)

## Common Issues

### "Coverage not available"
**Problem**: No coverage data found
**Solution**: Run tests with coverage first:
```bash
swift test --enable-code-coverage
```

### Slow Generation
**Problem**: Metrics take 3-5 minutes
**Cause**: Package builds during generation
**Solution**: This is normal. Build ensures accurate warning/error counts.

### Historical Files Growing
**Problem**: Too many snapshots in `history/`
**Solution**: Archive old snapshots:
```bash
# Keep only last 30 days
find "Instruction Set/project/summaries/history" -name "*.json" -mtime +30 -delete
```

## Integration with Workflow

### Git Pre-Commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run quick metrics (no build)
echo "Checking code quality..."

# Count undocumented APIs
UNDOC=$(grep -r 'public ' Sources --include='*.swift' -B 1 | \
  grep -v '///' | grep 'public' | wc -l | tr -d ' ')

if [ "$UNDOC" -gt 50 ]; then
  echo "⚠️  $UNDOC undocumented APIs - consider adding documentation"
fi
```

### VS Code Task
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Generate Library Metrics",
      "type": "shell",
      "command": "swift",
      "args": [
        "Instruction Set/project/summaries/generate_library_metrics.swift"
      ],
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    }
  ]
}
```

## Next Steps

1. ✅ Generate initial baseline metrics
2. ✅ Review health score and recommendations
3. 📝 Address any critical issues (F grade items)
4. 📊 Set up weekly metrics generation
5. 🔄 Integrate into CI/CD pipeline (see main README)

## Files Reference

```
project/summaries/
├── README.md                           # Full documentation
├── QUICKSTART.md                       # This file
├── generate_library_metrics.swift     # Main metrics tool
├── generate_portfolio_statistics.swift # Case study stats
├── library_metrics.json                # Latest metrics
├── portfolio_statistics.json           # Latest case study stats
└── history/                            # Historical snapshots
    └── metrics_YYYY-MM-DD_HHMMSS.json
```

## Getting Help

- **Full Documentation**: See `README.md` in this directory
- **Interpretation Guide**: Check `README.md` "Interpretation Guide" section
- **CI/CD Examples**: See `README.md` "Automation & CI/CD Integration"
- **Troubleshooting**: See `README.md` "Troubleshooting" section
