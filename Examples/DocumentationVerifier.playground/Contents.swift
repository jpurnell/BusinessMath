import BusinessMath
import OSLog
import PlaygroundSupport

let simulator = ReciprocalRegressionSimulator<Double>(
	a: 0.2,
	b: 0.3,
	sigma: 0.2
)

// Generate 100 observations with x uniform on [0, 10]
let data = simulator.simulate(n: 100, xRange: 0.0...10.0)

// Each data point contains (x, y)
for point in data.prefix(5) {
	print("x = \(point.x), y = \(point.y)")
}

	// For each x, generate y according to:
	// y = 1/(a + b*x) + noise, where noise ~ Normal(0, sigma)

	// With a=0.2, b=0.3, this creates specific y patterns:
	let x1 = 1.0
	let mu1 = 1.0 / (0.2 + 0.3 * x1)  // = 1/0.5 = 2.0

	let x5 = 5.0
	let mu5 = 1.0 / (0.2 + 0.3 * x5)  // = 1/1.7 ≈ 0.588

	let x10 = 10.0
	let mu10 = 1.0 / (0.2 + 0.3 * x10)  // = 1/3.2 ≈ 0.313

	// The pattern of y values across different x values encodes a, b, sigma!
	// Maximum likelihood finds the a, b, sigma that best explain this pattern

let fitter = ReciprocalRegressionFitter<Double>()

let result = try fitter.fit(
	data: data,
	initialGuess: ReciprocalRegressionModel<Double>.Parameters(
		a: 0.5, b: 0.5, sigma: 0.5
	),
	learningRate: 0.001,
	maxIterations: 1000
)

print("Fitted parameters:")
print("  a = \(result.parameters.a)")
print("  b = \(result.parameters.b)")
print("  sigma = \(result.parameters.sigma)")
print("  Converged: \(result.converged)")

let trueParams = ["a": 0.2, "b": 0.3, "sigma": 0.2]
let recoveredParams = [
	"a": result.parameters.a,
	"b": result.parameters.b,
	"sigma": result.parameters.sigma
]

for (name, trueValue) in trueParams {
	let recovered = recoveredParams[name]!
	let relError = abs(recovered - trueValue) / abs(trueValue)
	let status = relError <= 0.10 ? "✓ PASS" : "✗ FAIL"

	print("\(name): true = \(trueValue), recovered = \(recovered) \(status)")
}

let report = try ReciprocalParameterRecoveryCheck.run(
	trueA: 0.2,
	trueB: 0.3,
	trueSigma: 0.2,
	n: 100,
	xRange: 0.0...10.0,
	tolerance: 0.10  // 10% relative error
)

print(report.summary)

let reports = try ReciprocalParameterRecoveryCheck.runMultiple(
	trueA: 0.2,
	trueB: 0.3,
	trueSigma: 0.2,
	replicates: 10,
	n: 100
)

print(ReciprocalParameterRecoveryCheck.summarizeReplicates(reports))

let sampleSizes = [20, 50, 100, 200, 500]

for n in sampleSizes {
	let report = try ReciprocalParameterRecoveryCheck.run(
		trueA: 0.2, trueB: 0.3, trueSigma: 0.2,
		n: n
	)

	print("N = \(n): \(report.passed ? "✓" : "✗")")
}

	// 1. High noise
	let largeSigmaReport = try ReciprocalParameterRecoveryCheck.run(
		trueA: 0.2, trueB: 0.3, trueSigma: 1.0  // Large sigma
	)
	print("Large Parameters:\n\n\(largeSigmaReport.summary)")

	// 2. Extreme parameter values
	let extraParameterReport = try ReciprocalParameterRecoveryCheck.run(
		trueA: 0.001, trueB: 10.0, trueSigma: 0.1
	)
	print("Extra Parameters:\n\n\(extraParameterReport.summary)")

	// 3. Poor initialization
//	let fitter = ReciprocalRegressionFitter<Double>()
	let poor = try fitter.fit(
		data: data,
		initialGuess: ReciprocalRegressionModel<Double>.Parameters(a: 10.0, b: 10.0, sigma: 5.0),  // Way off
		maxIterations: 100
	)
print("Poor initialization:\n\n\(poor)")

let reportSample = try ReciprocalParameterRecoveryCheck.run(trueA: 0.2, trueB: 0.3, trueSigma: 0.2)

if reportSample.passed {
	print("✓ Model validation passed!")
	print("  All parameters recovered within \(reportSample.tolerance.percent()) tolerance")
} else {
	print("✗ Model validation failed!")
	print("  Check which parameters failed:")
	for (name, passed) in reportSample.withinTolerance {
		if !passed {
			print("  - \(name): \(reportSample.relativeErrors[name]!.percent()) error")
		}
	}
}
