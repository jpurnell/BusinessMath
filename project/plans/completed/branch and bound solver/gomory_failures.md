􀢄 Test "LP is re-solved after adding cuts" recorded an issue at NodeCutLoopTests.swift:112:9: Expectation failed: (result.status == .optimal → false) || (result.status == .feasible → false)

􀢄 Test "Cuts strengthen LP relaxation bound" recorded an issue at NodeCutLoopTests.swift:267:9: Expectation failed: (resultWithCuts.status → .infeasible) == .optimal

􀢄 Test "Cuts strengthen LP relaxation bound" recorded an issue at NodeCutLoopTests.swift:270:9: Expectation failed: (abs(resultNoCuts.objectiveValue - resultWithCuts.objectiveValue) → inf) < (1e-6 → 1e-06)

􀢄 Test "Cuts tighten bounds but preserve feasibility" recorded an issue at BranchAndCutTier1Tests.swift:246:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Global cuts are propagated to all child nodes" recorded an issue at BranchAndCutTier1Tests.swift:113:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cuts preserve all vertices of integer hull" recorded an issue at BranchAndCutTier1Tests.swift:77:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Generated cuts do not eliminate integer feasible solutions" recorded an issue at BranchAndCutTier1Tests.swift:40:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cuts are normalized to unit norm" recorded an issue at CutScalingTests.swift:40:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Extreme coefficient magnitudes handled robustly" recorded an issue at CutScalingTests.swift:101:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Normalization preserves cut validity" recorded an issue at CutScalingTests.swift:134:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Stagnation with improving then flat bounds" recorded an issue at DegeneracyProtectionTests.swift:240:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Stagnation detection terminates when no improvement" recorded an issue at DegeneracyProtectionTests.swift:38:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Both detections disabled allows full cutting rounds" recorded an issue at DegeneracyProtectionTests.swift:175:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cycling detection terminates on repeated solutions" recorded an issue at DegeneracyProtectionTests.swift:107:9: Expectation failed: (result.status → .infeasible) == (IntegerSolutionStatus.optimal → .optimal)

􀢄 Test "Stagnation detection works on multi-variable problems" recorded an issue at DegeneracyProtectionTests.swift:206:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Stagnation tolerance prevents premature termination" recorded an issue at DegeneracyProtectionTests.swift:72:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cycling window size affects detection sensitivity" recorded an issue at DegeneracyProtectionTests.swift:141:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cut pool maintains reasonable size" recorded an issue at BranchAndCutTier2Tests.swift:304:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "MIR cuts are generated for mixed-integer constraints" recorded an issue at BranchAndCutTier2Tests.swift:44:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Dominated cuts are not added to LP" recorded an issue at BranchAndCutTier2Tests.swift:207:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Inactive cuts are removed after aging limit" recorded an issue at BranchAndCutTier2Tests.swift:273:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "Cover cuts generated for knapsack constraints" recorded an issue at BranchAndCutTier2Tests.swift:138:9: Expectation failed: (result.status → .infeasible) == .optimal

􀢄 Test "LP is re-solved after adding cuts" failed after 145.800 seconds with 1 issue.

􀢄 Test "Cuts strengthen LP relaxation bound" failed after 145.800 seconds with 2 issues.

􀢄 Test "Cuts tighten bounds but preserve feasibility" failed after 146.183 seconds with 1 issue.

􀢄 Test "Global cuts are propagated to all child nodes" failed after 146.183 seconds with 1 issue.

􀢄 Test "Cuts preserve all vertices of integer hull" failed after 146.183 seconds with 1 issue.

􀢄 Test "Generated cuts do not eliminate integer feasible solutions" failed after 146.183 seconds with 1 issue.

􀢄 Test "Cuts are normalized to unit norm" failed after 146.188 seconds with 1 issue.

􀢄 Test "Extreme coefficient magnitudes handled robustly" failed after 146.187 seconds with 1 issue.

􀢄 Test "Normalization preserves cut validity" failed after 146.187 seconds with 1 issue.

􀢄 Test "Stagnation with improving then flat bounds" failed after 146.188 seconds with 1 issue.

􀢄 Test "Stagnation detection terminates when no improvement" failed after 146.188 seconds with 1 issue.

􀢄 Test "Both detections disabled allows full cutting rounds" failed after 146.188 seconds with 1 issue.

􀢄 Test "Cycling detection terminates on repeated solutions" failed after 146.189 seconds with 1 issue.

􀢄 Test "Stagnation detection works on multi-variable problems" failed after 146.189 seconds with 1 issue.

􀢄 Test "Stagnation tolerance prevents premature termination" failed after 146.188 seconds with 1 issue.

􀢄 Test "Cycling window size affects detection sensitivity" failed after 146.189 seconds with 1 issue.

􀢄 Test "Cut pool maintains reasonable size" failed after 146.189 seconds with 1 issue.

􀢄 Test "MIR cuts are generated for mixed-integer constraints" failed after 146.188 seconds with 1 issue.

􀢄 Test "Dominated cuts are not added to LP" failed after 146.189 seconds with 1 issue.

􀢄 Test "Inactive cuts are removed after aging limit" failed after 146.189 seconds with 1 issue.

􀢄 Test "Cover cuts generated for knapsack constraints" failed after 146.189 seconds with 1 issue.

􀢄 Test "Verify parallel execution completes faster" recorded an issue at ParallelOptimizerTests.swift:460:3: Expectation failed: (elapsed → 145.9364720582962) < 60.0

􀢄 Test "Verify parallel execution completes faster" failed after 157.491 seconds with 1 issue.

􀢄 Suite "Node-Level Cut Loop Tests" failed after 157.612 seconds with 3 issues.

􀢄 Suite "Branch-and-Cut Tier 1: Mathematical Correctness" failed after 157.734 seconds with 4 issues.

􀢄 Suite "Cut Scaling and Normalization" failed after 157.778 seconds with 3 issues.

􀢄 Suite "Degeneracy and Cycling Protection" failed after 157.780 seconds with 7 issues.

􀢄 Suite "Branch-and-Cut Tier 2: Algorithmic Completeness" failed after 157.783 seconds with 5 issues.

􀢄 Suite "Parallel Optimizer Performance Tests" failed after 157.923 seconds with 1 issue.

􀢄 Test "Debounce with separated values" recorded an issue at StreamingCompositionTests.swift:145:9: Expectation failed: (debounced.count → 1) == 2

􀢄 Test "Debounce with separated values" failed after 159.208 seconds with 1 issue.

􀢄 Suite "Streaming Composition Tests" failed after 161.336 seconds with 1 issue.

􀢄 Test "MultiStartOptimizer runs optimizations in parallel" recorded an issue at MultiStartOptimizerTests.swift:136:9: Expectation failed: (elapsed → 101.32808775 seconds) < (.seconds(1) → 1.0 seconds)

􀢄 Test "MultiStartOptimizer runs optimizations in parallel" failed after 161.797 seconds with 1 issue.

􀢄 Suite "MultiStartOptimizer Tests" failed after 163.855 seconds with 1 issue.

􀢄 Test run with 4174 tests in 330 suites failed after 207.251 seconds with 25 issues.
