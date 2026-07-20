// swift-tools-version: 6.2
// legibility:description: Production-ready Swift library for financial analysis, forecasting, and quantitative modeling.
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

// MARK: - Products

var products: [Product] = [
	.library(
		name: "BusinessMath",
		targets: ["BusinessMath"]
	),
	.library(
		name: "BusinessMathDSL",
		targets: ["BusinessMathDSL"]
	)
]

#if !os(Linux)
	products.append(
		.library(
			name: "BusinessMathMacros",
			type: .static,
			targets: ["BusinessMathMacros"]
		)
	)
#endif

// MARK: - Dependencies

var dependencies: [Package.Dependency] = [
	.package(
		url: "https://github.com/apple/swift-numerics",
		from: "1.1.1"
	),
	.package(
		url: "https://github.com/swiftlang/swift-syntax.git",
		from: "600.0.0"
	),
	// Swift Collections provides Deque for O(1) removeFirst operations
	// Cross-platform: works on macOS, iOS, Linux, and all other Swift platforms
	.package(
		url: "https://github.com/apple/swift-collections.git",
		from: "1.1.0"
	),
	.package(
		url: "https://github.com/swiftlang/swift-docc-plugin",
		from: "1.4.3"
	)
]

// swift-crypto backs `import Crypto` on platforms without a built-in CryptoKit (Linux, Android).
// Declared UNCONDITIONALLY: a package manifest's `#if os(...)` reflects the build *host*, not the
// target, so the old `#if os(Linux)` never fired when cross-compiling from an Apple host (which
// broke Android and cross-built Linux alike). The product is only *linked* where needed — see
// the `.when(platforms:)` condition in businessMathDeps below — so Apple builds pay no cost.
dependencies.append(
	.package(
		url: "https://github.com/apple/swift-crypto.git",
		from: "3.0.0"
	)
)

// MARK: - Targets

// Prepare BusinessMath dependencies
var businessMathDeps: [Target.Dependency] = [
	.product(name: "Numerics", package: "swift-numerics"),
	.product(name: "Collections", package: "swift-collections")
]

// Link swift-crypto's Crypto only where CryptoKit is absent. `.when(platforms:)` is evaluated
// against the TARGET triple, so it works under cross-compilation — unlike the host-based
// `#if os(Linux)` it replaces. Apple targets keep using built-in CryptoKit via `canImport`.
businessMathDeps.append(
	.product(
		name: "Crypto",
		package: "swift-crypto",
		condition: .when(platforms: [.linux, .android])
	)
)

var targets: [Target] = [

	// Core library (NO macro dependency to avoid Playground crashes)
	// Macros are available separately via BusinessMathMacros product
	.target(
		name: "BusinessMath",
		dependencies: businessMathDeps,
		exclude: [
			// Exclude Metal shaders to avoid Metal Toolchain requirement in Playgrounds/Xcode
			// GPU acceleration is optional - only needed for large-scale optimizations
			"Optimization/Heuristic/GPU/Shaders.metal",
			"Simulation/MonteCarlo/GPU/MonteCarloKernel.metal",
			"Simulation/MonteCarlo/GPU/MonteCarloRNG.metal",
			"Simulation/MonteCarlo/GPU/MonteCarloDistributions.metal",
			"Statistics/Regression/MatrixOperations/MatrixOperations.metal"
		],
		resources: [
			.process("BusinessMath.docc")
		],
		cSettings: [
			// Use new Accelerate LAPACK interface (macOS 13.3+) to silence deprecation warnings
			.define("ACCELERATE_NEW_LAPACK"),
			.define("ACCELERATE_LAPACK_ILP64")
		],
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	),

	// DSL
	.target(
		name: "BusinessMathDSL",
		dependencies: [
			"BusinessMath",
			.product(name: "Numerics", package: "swift-numerics")
		],
		exclude: [
			"README.md"
		],
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	),

	// Test Support (cross-platform utilities)
	.target(
		name: "TestSupport",
		dependencies: ["BusinessMath"],
		path: "Tests/TestSupport"
	),

	// Tests (core)
	.testTarget(
		name: "BusinessMathTests",
		dependencies: [
			"BusinessMath",
			"BusinessMathDSL",
			"TestSupport"
		],
		exclude: [
			"DocumentationExamples/README.md"
		],
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	)
]

// MARK: - Macro Targets (non-Linux only)

#if !os(Linux)
	targets += [

		.macro(
			name: "BusinessMathMacrosImpl",
			dependencies: [
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
				.product(name: "SwiftSyntax", package: "swift-syntax"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
				.product(name: "SwiftDiagnostics", package: "swift-syntax")
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		),

		.target(
			name: "BusinessMathMacros",
			dependencies: ["BusinessMathMacrosImpl"],
			exclude: [
				"README.md",
				"ValidationMacros-README.md"
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		)

		// BusinessMathMacrosTests target removed - all test files are currently disabled (.swift.disabled)
	]
#endif

// MARK: - Package

let package = Package(
	name: "BusinessMath",
	platforms: [
		.iOS(.v17),
		.macOS(.v14),
		.tvOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1)
	],
	products: products,
	dependencies: dependencies,
	targets: targets
)
