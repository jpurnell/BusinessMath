//
//  FakeDataSimulationExample.swift
//  BusinessMath Examples
//
//  Demonstrates fake-data simulation for model validation.
//  Based on Andrew Gelman's blog post on checking models using simulated data.
//
//  Reference: https://statmodeling.stat.columbia.edu/2025/12/15/simulating-from-and-checking-a-model-in-stan/
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Parameter Recovery Check

/// This example demonstrates the core workflow from Gelman's article:
/// 1. Specify true parameter values
/// 2. Simulate fake data from the model
/// 3. Fit the model to recover parameters
/// 4. Check if recovery was successful
func example1_BasicParameterRecovery() {
	print("=" * 60)
	print("Example 1: Basic Parameter Recovery Check")
	print("=" * 60)
	print()

	// Step 1: Define true parameters (same as Stan example)
	let trueA = 0.2
	let trueB = 0.3
	let trueSigma = 0.2

	print("True Parameters:")
	print("  a = \(trueA)")
	print("  b = \(trueB)")
	print("  sigma = \(trueSigma)")
	print()

	// Step 2-4: Run parameter recovery check
	do {
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: trueA,
			trueB: trueB,
			trueSigma: trueSigma,
			n: 100,              // 100 observations (same as Stan example)
			xRange: 0.0...10.0,  // x uniform on [0, 10]
			tolerance: 0.10       // 10% relative error tolerance
		)

		print(report.summary)

	} catch {
		print("❌ Error during fitting: \(error)")
	}
}

// MARK: - Example 2: Understanding What Can Go Wrong

/// This example shows what happens when you use a poorly-specified model
/// (e.g., flat priors that lead to non-identification)
func example2_WhatCanGoWrong() {
	print("\n")
	print("=" * 60)
	print("Example 2: What Happens with Poor Specification")
	print("=" * 60)
	print()

	print("Gelman mentions: 'try the above example with flat priors")
	print("on a and b and it will indeed blow up.'")
	print()
	print("In our optimization framework, poor initialization can")
	print("lead to convergence failure. Let's try with bad initial values:")
	print()

	// Simulate data
	let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.2)
	let data = simulator.simulate(n: 100, xRange: 0.0...10.0)

	// Try fitting with terrible initial guess
	let fitter = ReciprocalRegressionFitter<Double>()

	do {
		let result = try fitter.fit(
			data: data,
			initialGuess: ReciprocalRegressionModel<Double>.Parameters(
				a: 10.0,    // Way off!
				b: 10.0,    // Way off!
				sigma: 5.0  // Way off!
			),
			learningRate: 0.001,
			maxIterations: 100  // Fewer iterations
		)

		print("Fitting with poor initialization:")
		print("  Converged: \(result.converged ? "Yes" : "No")")
		print("  Iterations: \(result.iterations)")
		print("  Recovered a: \(String(format: "%.4f", result.parameters.a))")
		print("  Recovered b: \(String(format: "%.4f", result.parameters.b))")
		print("  Recovered sigma: \(String(format: "%.4f", result.parameters.sigma))")
		print()

		if !result.converged {
			print("⚠️  As expected, poor initialization can cause problems!")
		}

	} catch {
		print("❌ Fitting failed: \(error)")
		print("   This is exactly what Gelman warns about!")
	}
}

// MARK: - Example 3: Multiple Replicates

/// Run the check multiple times to see variability in parameter recovery
/// (closer to full simulation-based calibration)
func example3_MultipleReplicates() {
	print("\n")
	print("=" * 60)
	print("Example 3: Multiple Replicates")
	print("=" * 60)
	print()

	print("Running 10 independent simulations to check")
	print("average parameter recovery performance...")
	print()

	do {
		let reports = try ReciprocalParameterRecoveryCheck.runMultiple(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.2,
			replicates: 10,
			n: 100,
			xRange: 0.0...10.0,
			tolerance: 0.10
		)

		print(ReciprocalParameterRecoveryCheck.summarizeReplicates(reports))

		// Show details of any failures
		let failures = reports.enumerated().filter { !$0.element.passed }
		if !failures.isEmpty {
			print("\nFailed Replicates:")
			for (index, _) in failures {
				print("  Replicate \(index + 1)")
			}
		}

	} catch {
		print("❌ Error: \(error)")
	}
}

// MARK: - Example 4: Manual Step-by-Step Workflow

/// Shows each step of the workflow explicitly for educational purposes
func example4_StepByStepWorkflow() {
	print("\n")
	print("=" * 60)
	print("Example 4: Step-by-Step Workflow")
	print("=" * 60)
	print()

	// Step 1: Specify true parameters
	print("Step 1: Specify true parameters")
	let trueA = 0.2
	let trueB = 0.3
	let trueSigma = 0.2
	print("  a = \(trueA), b = \(trueB), sigma = \(trueSigma)")
	print()

	// Step 2: Create simulator
	print("Step 2: Create simulator with true parameters")
	let simulator = ReciprocalRegressionSimulator<Double>(
		a: trueA,
		b: trueB,
		sigma: trueSigma
	)
	print("  ✓ Simulator created")
	print()

	// Step 3: Simulate data
	print("Step 3: Simulate fake data")
	let data = simulator.simulate(n: 100, xRange: 0.0...10.0)
	print("  ✓ Generated \(data.count) observations")
	print("  Sample points (first 5):")
	for (i, point) in data.prefix(5).enumerated() {
		print("    [\(i)]: x = \(String(format: "%.3f", point.x)), y = \(String(format: "%.3f", point.y))")
	}
	print()

	// Step 4: Create fitter
	print("Step 4: Create model fitter")
	let fitter = ReciprocalRegressionFitter<Double>()
	print("  ✓ Fitter created")
	print()

	// Step 5: Fit model
	print("Step 5: Fit model to simulated data")
	do {
		let result = try fitter.fit(
			data: data,
			initialGuess: ReciprocalRegressionModel<Double>.Parameters(a: 0.5, b: 0.5, sigma: 0.5),
			learningRate: 0.001,
			maxIterations: 1000
		)

		print("  ✓ Fitting completed")
		print("  Converged: \(result.converged)")
		print("  Iterations: \(result.iterations)")
		print("  Log-likelihood: \(String(format: "%.4f", result.logLikelihood))")
		print()

		// Step 6: Compare true vs recovered
		print("Step 6: Compare true vs recovered parameters")
		print()
		print("  Parameter | True    | Recovered | Abs Error | Rel Error")
		print("  " + String(repeating: "-", count: 58))

		let params = [
			("a", trueA, result.parameters.a),
			("b", trueB, result.parameters.b),
			("sigma", trueSigma, result.parameters.sigma)
		]

		for (name, trueVal, recoveredVal) in params {
			let absError = abs(recoveredVal - trueVal)
			let relError = absError / abs(trueVal)
			let status = relError <= 0.10 ? "✓" : "✗"

			print(String(format: "  %-9s | %.5f | %.5f   | %.5f   | %5.1f%% %@",
				name, trueVal, recoveredVal, absError, relError * 100, status))
		}
		print()

	} catch {
		print("  ❌ Fitting failed: \(error)")
	}
}

// MARK: - Example 5: Testing Different Sample Sizes

/// Investigate how sample size affects parameter recovery
func example5_SampleSizeEffect() {
	print("\n")
	print("=" * 60)
	print("Example 5: Effect of Sample Size on Recovery")
	print("=" * 60)
	print()

	let sampleSizes = [20, 50, 100, 200, 500]

	print("Testing recovery with different sample sizes...")
	print()
	print("  N   | Passed? | Avg Rel Error (a, b, sigma)")
	print("  " + String(repeating: "-", count: 50))

	for n in sampleSizes {
		do {
			let report = try ReciprocalParameterRecoveryCheck.run(
				trueA: 0.2,
				trueB: 0.3,
				trueSigma: 0.2,
				n: n,
				xRange: 0.0...10.0,
				tolerance: 0.15
			)

			let avgError = (
				report.relativeErrors["a"]! +
				report.relativeErrors["b"]! +
				report.relativeErrors["sigma"]!
			) / 3.0

			let status = report.passed ? "✓" : "✗"

			print(String(format: "  %-3d | %-7s | %.1f%%, %.1f%%, %.1f%%",
				n,
				status,
				report.relativeErrors["a"]! * 100,
				report.relativeErrors["b"]! * 100,
				report.relativeErrors["sigma"]! * 100
			))

		} catch {
			print("  \(n) | ✗       | Error: \(error)")
		}
	}

	print()
	print("Observation: Larger sample sizes generally lead to better")
	print("parameter recovery (lower relative errors).")
}

// MARK: - Main

/// Run all examples
func runAllExamples() {
	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║" + " ".padding(toLength: 58, withPad: " ", startingAt: 0) + "║")
	print("║  Fake-Data Simulation for Model Validation                ║")
	print("║  Based on Andrew Gelman's Blog Post                        ║")
	print("║" + " ".padding(toLength: 58, withPad: " ", startingAt: 0) + "║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()

	example1_BasicParameterRecovery()
	example2_WhatCanGoWrong()
	example3_MultipleReplicates()
	example4_StepByStepWorkflow()
	example5_SampleSizeEffect()

	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Key Takeaways                                             ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()
	print("1. Always check your model on simulated data before using real data")
	print("2. If you can't recover parameters from fake data, something is wrong:")
	print("   - Poor identification (model structure issue)")
	print("   - Poor mixing (optimization/sampling issue)")
	print("   - Coding bugs")
	print("   - Algorithmic problems")
	print("3. Success on fake data is necessary but not sufficient:")
	print("   - It doesn't prove your model is good for real data")
	print("   - It's a minimum sanity check")
	print("4. Generative simulation clarifies what your model actually does")
	print()
}

// Uncomment to run:
// runAllExamples()

// Or run individual examples:
// example1_BasicParameterRecovery()
// example2_WhatCanGoWrong()
// example3_MultipleReplicates()
// example4_StepByStepWorkflow()
// example5_SampleSizeEffect()
