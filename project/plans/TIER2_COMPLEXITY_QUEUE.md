# Tier 2 — the complexity queue

Captured from `quality-gate --no-cache --check all` on `39ed2885`, 2026-09-18 00:04.
The complexity checker **PASSED**; every line below is an `ℹ️ note`, not a warning.
It is a work queue, not a defect list — but Tier 2 has so far found a defect in
roughly every function it opened, so treat a high score as *unexamined*, not as *ugly*.

205 functions over the threshold of 15: 179 in `Sources/`, 25 in `Tests/`, 1 elsewhere.

This file is a snapshot. Re-run the gate rather than trusting it after any refactor.

## Sources

| Score | Function | Est. | Location |
|---:|---|---|---|
| 291 | `solveRelaxation` | O(n^4) | `Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift:848` |
| 160 | `solve` | O(n^4) | `Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift:315` |
| 131 | `fitGeneralLME` | O(n^4) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:28` |
| 131 | `icc` | O(n^4) | `Sources/BusinessMath/Statistics/Descriptors/Agreement/iccMissingData.swift:80` |
| 121 | `generalAIREMLUpdate` | O(n^5) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:653` |
| 104 | `evaluate` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/Compilation/MonteCarloExpressionModel.swift:209` |
| 101 | `bayesianICC` | O(n^4) | `Sources/BusinessMath/Statistics/Estimation/bayesianICC.swift:415` |
| 95 | `extractVariableShift` | O(n³) | `Sources/BusinessMath/Optimization/IntegerProgramming/VariableShift.swift:207` |
| 85 | `gStudy` | O(n³) | `Sources/BusinessMath/Statistics/Reliability/gStudy.swift:133` |
| 79 | `bootstrap` | O(n³) | `Sources/BusinessMath/Valuation/Curves/DiscountCurve.swift:254` |
| 77 | `next` | — | `Sources/BusinessMath/Time Series/Period.swift:1051` |
| 68 | `buildBlock` | O(n³) | `Sources/BusinessMathDSL/ScenarioAnalysis.swift:292` |
| 62 | `solveShape` | O(n^4) | `Sources/BusinessMath/Simulation/distributionMomentFit.swift:435` |
| 59 | `generalEMUpdate` | O(n^5) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:537` |
| 59 | `linearRobustCounterpart` | O(n²) | `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift:651` |
| 57 | `detect` | O(n³) | `Sources/BusinessMath/Forecasting/AnomalyDetection.swift:155` |
| 55 | `louvainCommunities` | O(n³) | `Sources/BusinessMath/Network/Community/Community.swift:105` |
| 55 | `multiWayANOVA` | O(n^4) | `Sources/BusinessMath/Statistics/ANOVA/multiWayANOVA.swift:50` |
| 55 | `multipleLinearRegression` | O(n^6) | `Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift:232` |
| 54 | `bayesianICC` | O(n^4) | `Sources/BusinessMath/Statistics/Estimation/bayesianICC.swift:211` |
| 49 | `algebraicSimplificationPass` | O(n) | `Sources/BusinessMath/Simulation/MonteCarlo/Compilation/BytecodeOptimizer.swift:290` |
| 49 | `optimizeWithProgress` | O(n³) | `Sources/BusinessMath/Optimization/AsyncGradientDescentOptimizer.swift:196` |
| 48 | `gaussianSolveDetailed` | O(n³) | `Sources/BusinessMath/Core/LinearAlgebra/GaussianElimination.swift:135` |
| 45 | `sequentialTypeOneError` | O(n³) | `Sources/BusinessMath/Statistics/Experiment/SequentialTesting.swift:97` |
| 45 | `standardisedMoments` | O(n²) | `Sources/BusinessMath/Simulation/distributionMomentFit.swift:311` |
| 44 | `nestedANOVA` | O(n³) | `Sources/BusinessMath/Statistics/ANOVA/nestedANOVA.swift:85` |
| 44 | `optimize` | O(n³) | `Sources/BusinessMath/Optimization/GradientDescentOptimizer.swift:176` |
| 42 | `dualRobustCounterpart` | O(n²) | `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift:405` |
| 42 | `nelderMead` | O(n³) | `Sources/BusinessMath/Valuation/Derivatives/VolatilitySurface.swift:225` |
| 41 | `optimizeDetailed` | O(n³) | `Sources/BusinessMath/Optimization/Heuristic/NelderMead.swift:158` |
| 40 | `pageRank` | O(n³) | `Sources/BusinessMath/Network/Centrality/Centrality.swift:162` |
| 40 | `solveRelaxation` | O(n²) | `Sources/BusinessMath/Optimization/IntegerProgramming/SimplexRelaxationSolver.swift:147` |
| 38 | `buildConstraints` | O(n³) | `Sources/BusinessMath/BusinessOptimization/ResourceAllocation.swift:371` |
| 38 | `init` | — | `Sources/BusinessMath/Financial Statements/FinancialPeriodSummary.swift:597` |
| 38 | `init` | O(n²) | `Sources/BusinessMath/Streaming/AsyncAlignedSequence.swift:148` |
| 38 | `isIntegerFeasible` | O(n²) | `Sources/BusinessMath/Optimization/IntegerProgramming/IntegerSpecification.swift:45` |
| 38 | `minimize` | O(n³) | `Sources/BusinessMath/Optimization/Nonsmooth/CuttingPlaneMaster.swift:119` |
| 38 | `optimizeDetailed` | O(n³) | `Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift:236` |
| 36 | `eigenvectorCentrality` | O(n³) | `Sources/BusinessMath/Network/Centrality/Centrality.swift:227` |
| 35 | `constantFoldingPass` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/Compilation/BytecodeOptimizer.swift:130` |
| 35 | `solveWithProgress` | O(n) | `Sources/BusinessMath/Optimization/LinearProgramming/AsyncSimplexSolver.swift:236` |
| 35 | `tokenise` | O(n²) | `Sources/BusinessMath/Time Series/FormulaEvaluator.swift:610` |
| 34 | `next` | O(n³) | `Sources/BusinessMath/Streaming/AsyncTimeWindowedSequence.swift:225` |
| 34 | `restoreFeasibility` | O(n³) | `Sources/BusinessMath/Optimization/Constrained/PenaltyConstrainedSolve.swift:152` |
| 34 | `solve` | O(n³) | `Sources/BusinessMath/Simulation/Fitting/ParameterSolve.swift:33` |
| 33 | `customerLifetimeValue` | O(n²) | `Sources/BusinessMath/Marketing/Value/CustomerLifetimeValue.swift:162` |
| 33 | `distribute` | O(n²) | `Sources/BusinessMath/Financial Statements/Waterfall/LiquidationWaterfall.swift:67` |
| 33 | `distribute` | O(n²) | `Sources/BusinessMathDSL/LiquidationWaterfall.swift:96` |
| 33 | `optimize` | O(n²) | `Sources/BusinessMath/Optimization/Algorithms/NewtonRaphsonOptimizer.swift:141` |
| 33 | `validate` | — | `Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift:1078` |
| 32 | `fit` | O(n^4) | `Sources/BusinessMath/Statistics/Regression/LogisticRegression.swift:137` |
| 32 | `optimizeDetailed` | O(n²) | `Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift:184` |
| 32 | `optimizeDetailed` | O(n³) | `Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift:214` |
| 31 | `optimizeWithProgress` | O(n²) | `Sources/BusinessMath/Optimization/Algorithms/AsyncConjugateGradientOptimizer.swift:159` |
| 31 | `qrDecomposition` | O(n³) | `Sources/BusinessMath/Statistics/Regression/MatrixOperations/CPUMatrixBackend.swift:161` |
| 30 | `generatePeriods` | O(n) | `Sources/BusinessMath/Financial Statements/DebtInstrument.swift:215` |
| 30 | `piotroskiScore` | O(n) | `Sources/BusinessMath/Financial Statements/CreditMetrics.swift:407` |
| 30 | `searchETSParameters` | O(n³) | `Sources/BusinessMath/Forecasting/ETS/ETSParameterSearch.swift:166` |
| 29 | `interpolate` | O(n²) | `Sources/BusinessMath/Time Series/TimeSeriesOperations.swift:221` |
| 29 | `optimize` | O(n²) | `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift:165` |
| 29 | `optimizeWithQuadraticPenalty` | O(n³) | `Sources/BusinessMath/Optimization/Algorithms/InequalityOptimizer.swift:175` |
| 29 | `runCorrelated` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift:861` |
| 28 | `aggregate` | O(n²) | `Sources/BusinessMath/Time Series/TimeSeriesOperations.swift:309` |
| 28 | `extractScore` | O(n²) | `Sources/BusinessMath/Optimization/DEA/DEASolver.swift:414` |
| 28 | `init` | O(n²) | `Sources/BusinessMath/Network/Projection/BipartiteProjection.swift:74` |
| 28 | `inverseRegularizedLowerIncompleteGamma` | O(n²) | `Sources/BusinessMath/Statistics/SpecialFunctions/inverseRegularizedLowerIncompleteGamma.swift:58` |
| 28 | `numericalHessian` | O(n²) | `Sources/BusinessMath/Optimization/NumericalDifferentiation.swift:187` |
| 28 | `penaltyConstrainedSolve` | O(n^6) | `Sources/BusinessMath/Optimization/Constrained/PenaltyConstrainedSolve.swift:425` |
| 28 | `phaseII` | O(n³) | `Sources/BusinessMath/Optimization/LinearProgramming/SimplexSolver.swift:969` |
| 28 | `runGenerationGPU` | O(n² log n) | `Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift:566` |
| 27 | `buildObjectiveFunction` | O(n) | `Sources/BusinessMath/BusinessOptimization/ResourceAllocation.swift:290` |
| 27 | `degree` | O(n) | `Sources/BusinessMath/Model Definition/CycleForm.swift:119` |
| 27 | `milliseconds` | O(n) | `Sources/BusinessMath/Time Series/Period.swift:995` |
| 27 | `optimizeWithProgress` | O(n²) | `Sources/BusinessMath/Optimization/Algorithms/AsyncLBFGSOptimizer.swift:133` |
| 27 | `plotTornadoDiagram` | O(n) | `Sources/BusinessMath/Visualization/CommandLineVisualization.swift:219` |
| 27 | `validate` | — | `Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift:692` |
| 26 | `convertToStandardForm` | O(n³) | `Sources/BusinessMath/Optimization/LinearProgramming/SimplexSolver.swift:538` |
| 26 | `formatted` | O(n) | `Sources/BusinessMath/Diagnostics/ModelDebugger.swift:891` |
| 26 | `generalGLSEstimate` | O(n^4) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:447` |
| 26 | `generalizedGStudy` | O(n²) | `Sources/BusinessMath/Statistics/Reliability/generalizedGStudy.swift:22` |
| 26 | `remlVarianceComponents` | O(n²) | `Sources/BusinessMath/Statistics/Estimation/remlVarianceComponents.swift:70` |
| 25 | `buildObjectiveFunction` | O(n²) | `Sources/BusinessMath/BusinessOptimization/ProductionPlanning.swift:314` |
| 25 | `concordanceAnalysis` | O(n³) | `Sources/BusinessMath/Statistics/Comparison Statistics/kendallW.swift:184` |
| 25 | `expansion` | O(n³) | `Sources/BusinessMathMacrosImpl/ValidationMacros.swift:97` |
| 24 | `cashFlowSchedule` | O(n³) | `Sources/BusinessMath/Valuation/Debt/BondPricing.swift:857` |
| 24 | `concordanceAnalysisNA` | O(n³) | `Sources/BusinessMath/Statistics/Comparison Statistics/kendallW.swift:350` |
| 24 | `init` | O(n) | `Sources/BusinessMath/Marketing/Response/Uplift.swift:193` |
| 24 | `modularity` | O(n³) | `Sources/BusinessMath/Network/Community/Community.swift:38` |
| 24 | `seconds` | O(n) | `Sources/BusinessMath/Time Series/Period.swift:948` |
| 24 | `snapshot` | O(n²) | `Sources/BusinessMath/Diagnostics/ModelDebugger.swift:697` |
| 24 | `tukeyHSD` | O(n²) | `Sources/BusinessMath/Statistics/ANOVA/postHocTests.swift:378` |
| 24 | `upliftByBucket` | O(n²) | `Sources/BusinessMath/Marketing/Response/Uplift.swift:348` |
| 23 | `affineForm` | O(n) | `Sources/BusinessMath/Model Definition/LinearCycleSolver.swift:198` |
| 23 | `buildConstraints` | O(n²) | `Sources/BusinessMath/BusinessOptimization/ProductionPlanning.swift:380` |
| 23 | `calculate` | O(n) | `Sources/BusinessMath/Derivatives/Hedging/HedgePnL.swift:75` |
| 23 | `choleskyDecomposition` | O(n³) | `Sources/BusinessMath/Simulation/CorrelationMatrix.swift:166` |
| 23 | `frequentItemsets` | O(n^4) | `Sources/BusinessMath/Marketing/Basket/AssociationRules.swift:202` |
| 23 | `identifyUnusedComponents` | O(n³) | `Sources/BusinessMath/Developer Tools/ModelInspector.swift:190` |
| 22 | `init` | O(n²) | `Sources/BusinessMath/Statistics/Survival/LogRank.swift:66` |
| 22 | `minimize` | O(n²) | `Sources/BusinessMath/Optimization/Algorithms/MultivariateGradientDescent.swift:305` |
| 22 | `next` | O(n) | `Sources/BusinessMath/Streaming/StreamingStatistics.swift:1611` |
| 22 | `optimize` | O(n²) | `Sources/BusinessMath/Portfolio/RiskParity.swift:166` |
| 22 | `performBinarySegmentation` | O(n³) | `Sources/BusinessMath/Streaming/StreamingAnomalyDetection.swift:971` |
| 22 | `periodicRate` | O(n²) | `Sources/BusinessMath/Time Series/TVM/SolvingTheAnnuity.swift:157` |
| 22 | `run` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift:583` |
| 22 | `weights` | O(n) | `Sources/BusinessMath/Marketing/Attribution/AttributionModel.swift:269` |
| 21 | `autocorrelation` | O(n) | `Sources/BusinessMath/Stochastic/AutoregressiveMovingAverage.swift:280` |
| 21 | `buildDirections` | O(n³) | `Sources/BusinessMath/Simulation/Sampling/SobolSequence.swift:111` |
| 21 | `call` | O(n²) | `Sources/BusinessMath/Time Series/FormulaEvaluator.swift:277` |
| 21 | `inverseRegularizedIncompleteBeta` | O(n²) | `Sources/BusinessMath/Statistics/SpecialFunctions/inverseRegularizedIncompleteBeta.swift:56` |
| 21 | `minimizeAdam` | O(n²) | `Sources/BusinessMath/Optimization/Algorithms/MultivariateGradientDescent.swift:505` |
| 21 | `minutes` | O(n) | `Sources/BusinessMath/Time Series/Period.swift:902` |
| 21 | `multiLevelNestedANOVA` | O(n²) | `Sources/BusinessMath/Statistics/ANOVA/nestedANOVA.swift:400` |
| 21 | `validate` | — | `Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift:863` |
| 21 | `variableDecliningBalanceDepreciation` | O(n²) | `Sources/BusinessMath/Time Series/TVM/Depreciation.swift:205` |
| 20 | `aggregate` | O(n²) | `Sources/BusinessMath/Time Series/PeriodSequence.swift:151` |
| 20 | `distance` | — | `Sources/BusinessMath/Time Series/PeriodArithmetic.swift:104` |
| 20 | `generalizedDStudy` | O(n²) | `Sources/BusinessMath/Statistics/Reliability/generalizedDStudy.swift:29` |
| 20 | `liquidationWaterfall` | O(n) | `Sources/BusinessMath/Financial Statements/EquityFinancing.swift:332` |
| 20 | `run` | O(n³) | `Sources/BusinessMath/Simulation/MonteCarlo/ScenarioAnalysis.swift:208` |
| 20 | `runIterationGPU` | O(n²) | `Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift:465` |
| 20 | `schedule` | O(n) | `Sources/BusinessMath/Financial Statements/DebtInstrument.swift:94` |
| 20 | `selectBranchingVariable` | O(n²) | `Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift:1475` |
| 20 | `selectProjects` | O(n²) | `Sources/BusinessMath/BusinessOptimization/CapitalBudgeting.swift:213` |
| 20 | `validate` | O(n²) | `Sources/BusinessMath/Simulation/Fitting/PercentileParameterisable.swift:238` |
| 19 | `evolvePopulationGPU` | O(n²) | `Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift:598` |
| 19 | `generalEnsurePSD` | O(n²) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:940` |
| 19 | `init` | O(n³) | `Sources/BusinessMath/Simulation/distributionMVNormal.swift:86` |
| 19 | `initialize` | O(n³) | `Sources/BusinessMath/Optimization/Heuristic/InitializationStrategies.swift:290` |
| 19 | `next` | O(n³) | `Sources/BusinessMath/Streaming/AsyncTimeWindowedSequence.swift:88` |
| 19 | `optimize` | O(n²) | `Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift:305` |
| 19 | `projectToStructuralSpace` | O(n²) | `Sources/BusinessMath/Optimization/LinearProgramming/SimplexSolver.swift:184` |
| 19 | `twoWayANOVA` | O(n²) | `Sources/BusinessMath/Statistics/ANOVA/twoWayANOVA.swift:52` |
| 19 | `validate` | O(n²) | `Sources/BusinessMath/Optimization/DEA/DEASolver.swift:214` |
| 18 | `affineModel` | O(n²) | `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift:576` |
| 18 | `backtest` | O(n²) | `Sources/BusinessMath/Forecasting/Evaluation/RollingOriginBacktest.swift:31` |
| 18 | `besselAscendingSeries` | O(n) | `Sources/BusinessMath/Statistics/SpecialFunctions/BesselKernels.swift:127` |
| 18 | `bfgsUpdate` | O(n³) | `Sources/BusinessMath/Optimization/Algorithms/MultivariateNewtonRaphson.swift:452` |
| 18 | `gaussianElimination` | O(n³) | `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:544` |
| 18 | `generateCoverCut` | O(n²) | `Sources/BusinessMath/Optimization/IntegerProgramming/CuttingPlaneGenerator.swift:660` |
| 18 | `getOrCalculate` | O(n) | `Sources/BusinessMath/Performance/CalculationCache.swift:278` |
| 18 | `hours` | O(n) | `Sources/BusinessMath/Time Series/Period.swift:857` |
| 18 | `qrDecomposition` | O(n²) | `Sources/BusinessMath/Statistics/Regression/MatrixOperations/AccelerateMatrixBackend.swift:172` |
| 18 | `resampleToRegularGrid` | O(n²) | `Sources/BusinessMath/Streaming/StreamingFrequencyDomain.swift:214` |
| 18 | `rollingMax` | O(n³) | `Sources/BusinessMath/Time Series/TimeSeriesAnalytics.swift:610` |
| 18 | `rollingMin` | O(n³) | `Sources/BusinessMath/Time Series/TimeSeriesAnalytics.swift:561` |
| 17 | `analyzeInput` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/ScenarioAnalysis.swift:418` |
| 17 | `byFeatures` | O(n²) | `Sources/BusinessMath/Marketing/Segmentation/BehaviouralSegments.swift:141` |
| 17 | `calculateCenteredMovingAverage` | O(n²) | `Sources/BusinessMath/Time Series/Growth/Seasonality.swift:685` |
| 17 | `fit` | O(n) | `Sources/BusinessMath/Time Series/Growth/TrendModel.swift:1119` |
| 17 | `generateEMSTable` | O(n³) | `Sources/BusinessMath/Statistics/Reliability/emsTableGenerator.swift:19` |
| 17 | `generateSummary` | O(n³) | `Sources/BusinessMath/Developer Tools/ModelInspector.swift:302` |
| 17 | `getOrCalculate` | O(n) | `Sources/BusinessMath/Performance/CalculationCache.swift:480` |
| 17 | `icc` | O(n²) | `Sources/BusinessMath/Statistics/Descriptors/Agreement/icc.swift:93` |
| 17 | `init` | O(n³) | `Sources/BusinessMath/Simulation/distributionMetalog.swift:160` |
| 17 | `next` | O(n) | `Sources/BusinessMath/Streaming/AsyncValueStream.swift:308` |
| 17 | `optimize` | O(n) | `Sources/BusinessMath/AdvancedOptimization/ScenarioOptimizer.swift:233` |
| 17 | `recommended` | O(n) | `Sources/BusinessMath/Operations/InventoryAdvisor.swift:132` |
| 17 | `run` | O(n²) | `Sources/BusinessMath/Model Definition/PeriodDriver.swift:104` |
| 17 | `singleVariableLowerBound` | O(n²) | `Sources/BusinessMath/Optimization/IntegerProgramming/VariableShift.swift:343` |
| 17 | `turningPoints` | O(n²) | `Sources/BusinessMath/Simulation/distributionMetalogShape.swift:123` |
| 17 | `validateLinearModel` | O(n²) | `Sources/BusinessMath/Optimization/LinearityValidation.swift:66` |
| 16 | `besselK` | O(n) | `Sources/BusinessMath/Statistics/SpecialFunctions/besselK.swift:64` |
| 16 | `crossValidationBandwidth` | O(n³) | `Sources/BusinessMath/Statistics/Descriptors/Agreement/kernelWeights.swift:158` |
| 16 | `generalFixedEffectsSE` | O(n^4) | `Sources/BusinessMath/Statistics/MixedModels/Fitting/fitGeneralLME.swift:866` |
| 16 | `getGPUDistributionConfigs` | O(n²) | `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift:1021` |
| 16 | `init` | O(n²) | `Sources/BusinessMath/Statistics/Experiment/SequentialTesting.swift:234` |
| 16 | `init` | O(n²) | `Sources/BusinessMath/Network/Markov/TransitionMatrix.swift:70` |
| 16 | `init` | O(n) | `Sources/BusinessMath/Simulation/AliasTable.swift:61` |
| 16 | `liabilitySchedule` | O(n) | `Sources/BusinessMath/Financial Statements/LeaseAccounting.swift:409` |
| 16 | `minimizeBFGS` | O(n³) | `Sources/BusinessMath/Optimization/Algorithms/MultivariateNewtonRaphson.swift:218` |
| 16 | `next` | O(n) | `Sources/BusinessMath/Streaming/StreamingStatistics.swift:1478` |
| 16 | `next` | O(n) | `Sources/BusinessMath/Streaming/StreamingForecasting.swift:627` |
| 16 | `optimizeIntegerProjects` | O(n²) | `Sources/BusinessMath/Optimization/CapitalAllocationOptimizer.swift:238` |
| 16 | `step` | O(n) | `Sources/BusinessMath/Model Definition/IterativeCycleSolver.swift:273` |
| 16 | `validate` | — | `Sources/BusinessMath/Diagnostics/ModelDebugger.swift:1041` |
| 16 | `validate` | — | `Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift:221` |
| 16 | `validatedConversions` | O(n²) | `Sources/BusinessMath/Marketing/Attribution/AttributionModel.swift:125` |
| 16 | `weightedPercentile` | O(n log n) | `Sources/BusinessMath/Statistics/Descriptors/Central Tendency/weightedPercentile.swift:24` |

## Tests

| Score | Function | Est. | Location |
|---:|---|---|---|
| 50 | `solutionsSatisfyTheIdentity` | O(n²) | `Tests/BusinessMathTests/Financial Tests/AnnuitySolvingTests.swift:91` |
| 46 | `cumulativePaymentsMatchReference` | O(n) | `Tests/BusinessMathTests/Financial Tests/CashFlowParityTests.swift:90` |
| 41 | `referenceSetAttainsTheScore` | O(n^5) | `Tests/BusinessMathTests/Optimization Tests/DEACertificateTests.swift:193` |
| 37 | `discreteDistributions` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:123` |
| 35 | `distribution` | — | `Tests/BusinessMathTests/Distribution Function Tests/RiskSolverScipyParityTests.swift:74` |
| 35 | `reportedScoreIsBoundedByTheScan` | O(n^5) | `Tests/BusinessMathTests/Optimization Tests/DEACertificateTests.swift:272` |
| 28 | `rankingMatchesReference` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:263` |
| 27 | `remainingDistributions` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:147` |
| 24 | `efficiencyIsUnitsInvariant` | O(n³) | `Tests/BusinessMathTests/Optimization Tests/DEACertificateTests.swift:357` |
| 23 | `variableDecliningBalanceMatchesReference` | O(n) | `Tests/BusinessMathTests/Financial Tests/DepreciationTests.swift:82` |
| 22 | `fDistribution` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:87` |
| 22 | `normal` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:55` |
| 22 | `studentT` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:71` |
| 21 | `periodicRateMatchesReference` | O(n²) | `Tests/BusinessMathTests/Financial Tests/AnnuitySolvingTests.swift:46` |
| 19 | `decliningBalanceMatchesReference` | O(n) | `Tests/BusinessMathTests/Financial Tests/DepreciationTests.swift:69` |
| 19 | `satisfies` | O(n²) | `Tests/BusinessMathTests/Integer Programming Tests/IntegerProgrammingCertificateTests.swift:163` |
| 18 | `predictionMatchesReference` | O(n) | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:215` |
| 18 | `scoresAndSlacksAreWellFormed` | O(n^4) | `Tests/BusinessMathTests/Optimization Tests/DEACertificateTests.swift:482` |
| 17 | `choleskyMatchesLAPACK` | O(n³) | `Tests/BusinessMathTests/Statistics Tests/MixedModels Tests/LinearAlgebraReferenceTests.swift:102` |
| 17 | `numberOfPeriodsMatchesReference` | O(n²) | `Tests/BusinessMathTests/Financial Tests/AnnuitySolvingTests.swift:31` |
| 16 | `complementarySlacknessHolds` | O(n³) | `Tests/BusinessMathTests/Optimization Tests/LinearProgrammingCertificateTests.swift:500` |
| 16 | `descriptiveStatistics` | — | `Tests/BusinessMathTests/Statistics Tests/ExcelBindableParityTests.swift:171` |
| 16 | `locationScaleFamilies` | O(n) | `Tests/BusinessMathTests/Distribution Function Tests/PercentileFittingCoverageTests.swift:50` |
| 16 | `positiveParameterFamilies` | O(n) | `Tests/BusinessMathTests/Distribution Function Tests/PercentileFittingCoverageTests.swift:79` |
| 16 | `shiftScaleShapeFamilies` | O(n) | `Tests/BusinessMathTests/Distribution Function Tests/PercentileFittingCoverageTests.swift:151` |

## Other

| Score | Function | Est. | Location |
|---:|---|---|---|
| 19 | `optimize` | O(n²) | `project/reference/NewtonRaphsonOptimization_ALT.swift:26` |

