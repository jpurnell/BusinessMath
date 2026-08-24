# BusinessMath Library Statistics

> Generated 2026-04-14 by tooling removed on 2026-08-24. Kept as the last
> published snapshot; see `README.md` for what replaced it.


**Last Updated**: February 8, 2026

## Overview

BusinessMath is a comprehensive Swift library for business mathematics, optimization, simulation, and financial modeling.

## Library Size

| Metric | Value |
|--------|-------|
| **Source Files** | 376 |
| **Test Files** | 277 |
| **Total Lines of Code** | 203,546 |
| **Source Lines** | 96,403 |
| **Test Lines** | 107,143 |
| **Test-to-Code Ratio** | 1.11x |

## API Surface

| Metric | Value |
|--------|-------|
| **Public APIs** | 4,360 |
| **Modules** | 8 |
| **Documented APIs** | 3,521 (80.8%) |
| **Undocumented APIs** | 839 |

## Test Coverage

| Metric | Value |
|--------|-------|
| **Total Test Functions** | 859 |
| **Code Coverage** | *Run with coverage to measure* |

> **Note**: To generate code coverage, run:
> ```bash
> swift test --enable-code-coverage
> ```

## Quality Metrics

| Metric | Status | Grade |
|--------|--------|-------|
| **Documentation Coverage** | 80.8% | 🟢 Excellent |
| **Test-to-Code Ratio** | 1.11x | 🟢 Excellent |
| **Overall Health** | 85.0% | **B** |

### Health Score Breakdown

- **Documentation Coverage** (30%): 80.8% - Above target (70%)
- **Test Ratio** (20%): 100% - Exceeds target (1.0x)
- **Test Coverage** (30%): Not measured
- **Build Health** (20%): Not measured

## Modules

1. **BusinessMath** - Core library
2. **BusinessMathDSL** - Domain-specific language
3. **BusinessMathMacros** - Swift macros
4. **BusinessMathMCP** - Model Context Protocol
5. *Additional modules...*

## Development

| Metric | Value |
|--------|-------|
| **Total Commits** | 7,358 |
| **Contributors** | 2 |
| **Current Branch** | main |
| **Dependencies** | 8 |

## Key Features

### Optimization Algorithms
- Gradient Descent (univariate & multivariate)
- Newton-Raphson
- L-BFGS (Limited-memory BFGS)
- Simplex Method (Linear Programming)
- Nelder-Mead
- Particle Swarm Optimization (PSO)
- Adaptive Optimizer (auto-selects best algorithm)

### Monte Carlo Simulation
- GPU-accelerated simulation via Metal
- Custom expression language with bytecode compiler
- Distribution support: Normal, LogNormal, Uniform, Triangular, etc.
- Correlation matrix handling

### Financial Analysis
- Option pricing (Black-Scholes, Binomial Trees)
- Real options analysis
- Financial statement modeling
- DuPont analysis
- Time series forecasting

### Statistics
- Descriptive statistics
- Linear & nonlinear regression
- Hypothesis testing
- Distribution functions
- Streaming analytics

## Performance

| Metric | Value |
|--------|-------|
| **Benchmark Tests** | 12 |
| **GPU Acceleration** | ✅ Metal support |
| **Parallel Processing** | ✅ Swift Concurrency |

## Documentation Quality

### Well-Documented Areas
- Core optimization algorithms
- Monte Carlo simulation
- Financial modeling
- Distribution functions

### Areas for Improvement
- 839 APIs still need documentation
- Focus on newer features (PSO, streaming analytics)

## Recommendations

### High Priority
1. ✅ **Documentation**: Already at 80.8% - excellent! Focus on remaining 839 APIs
2. ✅ **Test Ratio**: 1.11x is excellent (more tests than source code)
3. ⚠️ **Code Coverage**: Run coverage analysis to establish baseline

### Medium Priority
4. 📊 **Performance Benchmarks**: Expand benchmark suite beyond current 12 tests
5. 📖 **API Examples**: Add usage examples for complex APIs

### Low Priority
6. 🔧 **Build Analysis**: Run full metrics to capture warnings/errors

## Historical Trends

*Track these metrics over time by running:*
```bash
swift "Instruction Set/project/summaries/generate_library_metrics.swift"
```

Historical snapshots are saved to `Instruction Set/project/summaries/history/`

## Usage in Documentation

### README Badge Example

```markdown
![Lines of Code](https://img.shields.io/badge/lines-203k-blue)
![Tests](https://img.shields.io/badge/tests-859-green)
![Documentation](https://img.shields.io/badge/docs-80.8%25-brightgreen)
![Health](https://img.shields.io/badge/health-B-yellowgreen)
```

### For Contributors

When contributing to BusinessMath:
- Maintain or improve the **1.11x test ratio** - write tests for your code!
- Document all public APIs - we're at **80.8%** and aiming higher
- Run tests with coverage: `swift test --enable-code-coverage`
- Check metrics before submitting PR

## Related Files

- **Metrics Generator**: `generate_library_metrics.swift`
- **Quick Start Guide**: `QUICKSTART.md`
- **Full Documentation**: `README.md`
- **Latest Metrics**: `library_metrics.json`

---

*This document is automatically generated. To update, run:*
```bash
swift "Instruction Set/project/summaries/generate_library_metrics.swift"
```
