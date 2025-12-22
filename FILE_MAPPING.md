# Documentation Reorganization: File Mapping

This document tracks the OLD_NAME → NEW_NAME mapping for all files in the documentation reorganization.

## Part I: Basics & Foundations (1.x)

| Old Name | New Name | Status |
|----------|----------|--------|
| GettingStarted.md | 1.1-GettingStarted.md | Pending |
| TimeSeries.md | 1.2-TimeSeries.md | Pending |
| TimeValueOfMoney.md | 1.3-TimeValueOfMoney.md | Pending |
| FluentAPIGuide.md | 1.4-FluentAPIGuide.md | Pending |
| TemplateGuide.md | 1.5-TemplateGuide.md | Pending |
| DebuggingGuide.md | 1.6-DebuggingGuide.md | Pending |
| ErrorHandlingGuide.md | 1.7-ErrorHandlingGuide.md | Pending |

## Part II: Analysis & Statistics (2.x)

| Old Name | New Name | Status |
|----------|----------|--------|
| DataTableAnalysis.md | 2.1-DataTableAnalysis.md | Pending |
| FinancialRatiosGuide.md | 2.2-FinancialRatiosGuide.md | Pending |
| RiskAnalyticsGuide.md | 2.3-RiskAnalyticsGuide.md | Pending |
| VisualizationGuide.md | 2.4-VisualizationGuide.md | Pending |

## Part III: Modeling (3.x)

### General Modeling
| Old Name | New Name | Status |
|----------|----------|--------|
| GrowthModeling.md | 3.1-GrowthModeling.md | Pending |
| ForecastingGuide.md | 3.2-ForecastingGuide.md | Pending |

### Financial Modeling
| Old Name | New Name | Status |
|----------|----------|--------|
| BuildingRevenueModel.md | 3.3-BuildingRevenueModel.md | Pending |
| BuildingFinancialReports.md | 3.4-BuildingFinancialReports.md | Pending |
| FinancialStatementsGuide.md | 3.5-FinancialStatementsGuide.md | Pending |
| LeaseAccountingGuide.md | 3.6-LeaseAccountingGuide.md | Pending |
| LoanAmortization.md | 3.7-LoanAmortization.md | Pending |

### Valuation & Investment Analysis
| Old Name | New Name | Status |
|----------|----------|--------|
| InvestmentAnalysis.md | 3.8-InvestmentAnalysis.md | Pending |
| EquityValuationGuide.md | 3.9-EquityValuationGuide.md | Pending |
| BondValuationGuide.md | 3.10-BondValuationGuide.md | Pending |
| CreditDerivativesGuide.md | 3.11-CreditDerivativesGuide.md | Pending |
| RealOptionsGuide.md | 3.12-RealOptionsGuide.md | Pending |

### Capital Structure
| Old Name | New Name | Status |
|----------|----------|--------|
| EquityFinancingGuide.md | 3.13-EquityFinancingGuide.md | Pending |
| DebtAndFinancingGuide.md | 3.14-DebtAndFinancingGuide.md | Pending |

## Part IV: Simulation & Uncertainty (4.x)

| Old Name | New Name | Status |
|----------|----------|--------|
| MonteCarloTimeSeriesGuide.md | 4.1-MonteCarloTimeSeriesGuide.md | Pending |
| ScenarioAnalysisGuide.md | 4.2-ScenarioAnalysisGuide.md | Pending |

## Part V: Optimization (5.x)

### Fundamentals
| Old Name | New Name | Status |
|----------|----------|--------|
| OptimizationGuide.md | 5.1-OptimizationGuide.md | Pending |
| PortfolioOptimizationGuide.md | 5.2-PortfolioOptimizationGuide.md | Pending |

### Phase Tutorials (from Tutorials/ directory)
| Old Name | New Name | Status |
|----------|----------|--------|
| Tutorials/PHASE_1_TUTORIAL.md | 5.3-CoreOptimization.md | Pending |
| Tutorials/PHASE_2_TUTORIAL.md | 5.4-VectorOperations.md | Pending |
| Tutorials/PHASE_3_TUTORIAL.md | 5.5-MultivariateOptimization.md | Pending |
| PHASE_4_TUTORIAL.md | 5.6-ConstrainedOptimization.md | Pending |
| Tutorials/PHASE_5_TUTORIAL.md | 5.6-BusinessOptimization.md | Pending |
| Tutorials/PHASE_6.2_INTEGER_PROGRAMMING_TUTORIAL.md | 5.8-IntegerProgramming.md | Pending |
| Tutorials/PHASE_7_ADAPTIVE_SELECTION_TUTORIAL.md | 5.9-AdaptiveSelection.md | Pending |
| Tutorials/PHASE_7_PARALLEL_OPTIMIZATION_TUTORIAL.md | 5.10-ParallelOptimization.md | Pending |
| Tutorials/PHASE_7_PERFORMANCE_BENCHMARK_TUTORIAL.md | 5.11-PerformanceBenchmarking.md | Pending |
| Tutorials/PHASE_8.1_SPARSE_MATRIX_TUTORIAL.md | 5.12-SparseMatrix.md | Pending |
| Tutorials/PHASE_8.3_MULTI_PERIOD_TUTORIAL.md | 5.13-MultiPeriod.md | Pending |
| Tutorials/PHASE_8.4_ROBUST_OPTIMIZATION_TUTORIAL.md | 5.14-RobustOptimization.md | Pending |

### Specialized
| Old Name | New Name | Status |
|----------|----------|--------|
| Tutorials/inequality.md | 5.15-InequalityConstraints.md | Pending |

## Appendices

| Old Name | New Name | Status |
|----------|----------|--------|
| ReidsRaisinsExample.md | Appendix-A-ReidsRaisinsExample.md | Pending |

## Summary

- **Total files to rename**: 44
- **Part I (Basics)**: 7 files
- **Part II (Analysis)**: 4 files
- **Part III (Modeling)**: 14 files
- **Part IV (Simulation)**: 2 files
- **Part V (Optimization)**: 16 files
- **Appendices**: 1 file

## DocC Reference Format

When updating cross-references, use the NEW NAME with full prefix:
- Old: `<doc:GettingStarted>`
- New: `<doc:1.1-GettingStarted>`
- Old: `<doc:PHASE_1_TUTORIAL>`
- New: `<doc:5.3-CoreOptimization>`

## Progress Tracking

As files are renamed and cross-references are updated, mark the status column as "Complete".
