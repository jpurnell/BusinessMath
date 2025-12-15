# Documentation Migration Guide

**Effective Date**: [Version with reorganized documentation]

## Overview

The BusinessMath documentation has been reorganized into a book-like structure with five main parts and numbered chapters. This migration guide helps you find content under the new organization.

## Why the Change?

The previous flat structure with 44 guides in a single list made it difficult to:
- Understand the learning progression
- Find related topics
- Navigate between beginner and advanced content

The new structure organizes documentation like a book with five parts:
1. **Part I: Basics & Foundations** (Chapters 1.1-1.7)
2. **Part II: Analysis & Statistics** (Chapters 2.1-2.4)
3. **Part III: Modeling** (Chapters 3.1-3.14)
4. **Part IV: Simulation & Uncertainty** (Chapters 4.1-4.2)
5. **Part V: Optimization** (Chapters 5.1-5.15)

## Quick Reference: Old Name → New Name

### Part I: Basics & Foundations

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `GettingStarted` | `1.1-GettingStarted` | `<doc:1.1-GettingStarted>` |
| `TimeSeries` | `1.2-TimeSeries` | `<doc:1.2-TimeSeries>` |
| `TimeValueOfMoney` | `1.3-TimeValueOfMoney` | `<doc:1.3-TimeValueOfMoney>` |
| `FluentAPIGuide` | `1.4-FluentAPIGuide` | `<doc:1.4-FluentAPIGuide>` |
| `TemplateGuide` | `1.5-TemplateGuide` | `<doc:1.5-TemplateGuide>` |
| `DebuggingGuide` | `1.6-DebuggingGuide` | `<doc:1.6-DebuggingGuide>` |
| `ErrorHandlingGuide` | `1.7-ErrorHandlingGuide` | `<doc:1.7-ErrorHandlingGuide>` |

### Part II: Analysis & Statistics

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `DataTableAnalysis` | `2.1-DataTableAnalysis` | `<doc:2.1-DataTableAnalysis>` |
| `FinancialRatiosGuide` | `2.2-FinancialRatiosGuide` | `<doc:2.2-FinancialRatiosGuide>` |
| `RiskAnalyticsGuide` | `2.3-RiskAnalyticsGuide` | `<doc:2.3-RiskAnalyticsGuide>` |
| `VisualizationGuide` | `2.4-VisualizationGuide` | `<doc:2.4-VisualizationGuide>` |

### Part III: Modeling

#### General Modeling

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `GrowthModeling` | `3.1-GrowthModeling` | `<doc:3.1-GrowthModeling>` |
| `ForecastingGuide` | `3.2-ForecastingGuide` | `<doc:3.2-ForecastingGuide>` |

#### Financial Modeling

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `BuildingRevenueModel` | `3.3-BuildingRevenueModel` | `<doc:3.3-BuildingRevenueModel>` |
| `BuildingFinancialReports` | `3.4-BuildingFinancialReports` | `<doc:3.4-BuildingFinancialReports>` |
| `FinancialStatementsGuide` | `3.5-FinancialStatementsGuide` | `<doc:3.5-FinancialStatementsGuide>` |
| `LeaseAccountingGuide` | `3.6-LeaseAccountingGuide` | `<doc:3.6-LeaseAccountingGuide>` |
| `LoanAmortization` | `3.7-LoanAmortization` | `<doc:3.7-LoanAmortization>` |

#### Valuation & Investment

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `InvestmentAnalysis` | `3.8-InvestmentAnalysis` | `<doc:3.8-InvestmentAnalysis>` |
| `EquityValuationGuide` | `3.9-EquityValuationGuide` | `<doc:3.9-EquityValuationGuide>` |
| `BondValuationGuide` | `3.10-BondValuationGuide` | `<doc:3.10-BondValuationGuide>` |
| `CreditDerivativesGuide` | `3.11-CreditDerivativesGuide` | `<doc:3.11-CreditDerivativesGuide>` |
| `RealOptionsGuide` | `3.12-RealOptionsGuide` | `<doc:3.12-RealOptionsGuide>` |

#### Capital Structure

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `EquityFinancingGuide` | `3.13-EquityFinancingGuide` | `<doc:3.13-EquityFinancingGuide>` |
| `DebtAndFinancingGuide` | `3.14-DebtAndFinancingGuide` | `<doc:3.14-DebtAndFinancingGuide>` |

### Part IV: Simulation & Uncertainty

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `MonteCarloTimeSeriesGuide` | `4.1-MonteCarloTimeSeriesGuide` | `<doc:4.1-MonteCarloTimeSeriesGuide>` |
| `ScenarioAnalysisGuide` | `4.2-ScenarioAnalysisGuide` | `<doc:4.2-ScenarioAnalysisGuide>` |

**Note**: `ScenarioAnalysisGuide` moved from Analysis section to Simulation section to better reflect its purpose.

### Part V: Optimization

#### Fundamentals

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `OptimizationGuide` | `5.1-OptimizationGuide` | `<doc:5.1-OptimizationGuide>` |
| `PortfolioOptimizationGuide` | `5.2-PortfolioOptimizationGuide` | `<doc:5.2-PortfolioOptimizationGuide>` |

#### Phase Tutorials (Deep Dive)

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `PHASE_1_TUTORIAL` | `5.3-Phase1-CoreEnhancements` | `<doc:5.3-Phase1-CoreEnhancements>` |
| `PHASE_2_TUTORIAL` | `5.4-Phase2-VectorOperations` | `<doc:5.4-Phase2-VectorOperations>` |
| `PHASE_3_TUTORIAL` | `5.5-Phase3-MultivariateOptimization` | `<doc:5.5-Phase3-MultivariateOptimization>` |
| `PHASE_4_TUTORIAL` | `5.6-Phase4-ConstrainedOptimization` | `<doc:5.6-Phase4-ConstrainedOptimization>` |
| `PHASE_5_TUTORIAL` | `5.7-Phase5-BusinessOptimization` | `<doc:5.7-Phase5-BusinessOptimization>` |
| `PHASE_6.2_INTEGER_PROGRAMMING_TUTORIAL` | `5.8-Phase6-IntegerProgramming` | `<doc:5.8-Phase6-IntegerProgramming>` |
| `PHASE_7_ADAPTIVE_SELECTION_TUTORIAL` | `5.9-Phase7-AdaptiveSelection` | `<doc:5.9-Phase7-AdaptiveSelection>` |
| `PHASE_7_PARALLEL_OPTIMIZATION_TUTORIAL` | `5.10-Phase7-ParallelOptimization` | `<doc:5.10-Phase7-ParallelOptimization>` |
| `PHASE_7_PERFORMANCE_BENCHMARK_TUTORIAL` | `5.11-Phase7-PerformanceBenchmarking` | `<doc:5.11-Phase7-PerformanceBenchmarking>` |
| `PHASE_8.1_SPARSE_MATRIX_TUTORIAL` | `5.12-Phase8-SparseMatrix` | `<doc:5.12-Phase8-SparseMatrix>` |
| `PHASE_8.3_MULTI_PERIOD_TUTORIAL` | `5.13-Phase8-MultiPeriod` | `<doc:5.13-Phase8-MultiPeriod>` |
| `PHASE_8.4_ROBUST_OPTIMIZATION_TUTORIAL` | `5.14-Phase8-RobustOptimization` | `<doc:5.14-Phase8-RobustOptimization>` |

#### Specialized Topics

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `inequality` | `5.15-InequalityConstraints` | `<doc:5.15-InequalityConstraints>` |

### Appendices

| Old Name | New Name | DocC Link |
|----------|----------|-----------|
| `ReidsRaisinsExample` | `Appendix-A-ReidsRaisinsExample` | `<doc:Appendix-A-ReidsRaisinsExample>` |

## New Navigation Features

### Part Introduction Pages

Each of the five parts now has an introduction page:

- `<doc:Part1-Basics>` - Overview of foundational concepts
- `<doc:Part2-Analysis>` - Overview of analytical techniques
- `<doc:Part3-Modeling>` - Overview of financial modeling
- `<doc:Part4-Simulation>` - Overview of simulation methods
- `<doc:Part5-Optimization>` - Overview of optimization

These introduction pages provide:
- Overview of what you'll learn in that part
- Suggested reading order
- Prerequisites
- Key concepts
- Next steps

### Learning Path Guide

New comprehensive learning path with four specialized tracks:

- `<doc:LearningPath>` - Main learning path guide
  - **Financial Analyst Track** (15-20 hours)
  - **Risk Manager Track** (12-15 hours)
  - **Quantitative Developer Track** (20-25 hours)
  - **General Business Track** (10-12 hours)

Each track provides a curated sequence with checkpoints to validate progress.

## Breaking Changes

### DocC Links

If you have bookmarks or external links to the documentation:

**Old format**: `<doc:GettingStarted>`
**New format**: `<doc:1.1-GettingStarted>`

The old links will break. Update them using the mapping table above.

### File Locations

All Phase tutorials previously in `Tutorials/` subdirectory are now in the root `.docc` directory with new names:

**Old**: `Sources/BusinessMath/BusinessMath.docc/Tutorials/PHASE_1_TUTORIAL.md`
**New**: `Sources/BusinessMath/BusinessMath.docc/5.3-Phase1-CoreEnhancements.md`

### Cross-References in Code Comments

If your code includes comments with documentation references:

```swift
// See BusinessMath documentation: GettingStarted guide
```

Update to:

```swift
// See BusinessMath documentation: 1.1-GettingStarted
```

## Migration Strategies

### For Users with Bookmarks

Search this guide for your old bookmark name and update to the new name.

### For Documentation Contributors

When writing new guides or updating existing ones:
1. Use the new numbered naming convention
2. Place files in appropriate parts (1.x, 2.x, 3.x, 4.x, 5.x)
3. Reference other guides using the new names: `<doc:X.Y-Name>`

### For External Links

If you've linked to BusinessMath documentation from:
- Blog posts
- Stack Overflow answers
- Project documentation
- Academic papers

Update links using the mapping table above. The URL structure should remain similar, just with the new file names.

## What Stayed the Same

### API References

All API symbol references remain unchanged. Only documentation guide names have changed.

### Content

The actual content of guides remains the same (with minor updates). Only the organization and naming has changed.

### File Formats

All files remain Markdown (`.md`) with DocC formatting.

## Benefits of the New Structure

### Clearer Organization

The five-part structure makes it obvious where to find content:
- Basics → Part I
- Analysis → Part II
- Modeling → Part III
- Simulation → Part IV
- Optimization → Part V

### Better Discoverability

Chapter numbering makes the learning progression clear. You know that 3.1 comes before 3.9.

### Role-Based Learning

The new Learning Path guide provides role-specific tracks, so you only read what's relevant to your work.

### Improved Cross-References

With numbered chapters, cross-references are more meaningful:
- "See Part I for foundations" is clearer than "See GettingStarted"
- "After 3.8, proceed to 3.9" shows clear progression

## Need Help?

If you can't find something after the reorganization:

1. **Check this guide** - Use the mapping table above
2. **Use the main index** - The reorganized `BusinessMath.md` has "I want to..." quick references
3. **Search by topic** - Each part introduction lists all chapters in that part
4. **GitHub Issues** - If something is genuinely missing or broken, file an issue

## Timeline

- **Before**: Flat structure with 44 guides in single list
- **After**: Book structure with 5 parts and numbered chapters
- **Transition**: This migration guide remains available indefinitely

---

**Last Updated**: [Date]
**Applies to**: BusinessMath v[X.X.X] and later
