// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription
import Foundation

let isLinux = ProcessInfo.processInfo.operatingSystemVersionString
	.lowercased()
	.contains("linux")

// MARK: - Products

var products: [Product] = [
	.library(
		name: "BusinessMath",
		targets: ["BusinessMath"]
	),
	.library(
		name: "BusinessMathMCP",
		targets: ["BusinessMathMCP"]
	),
	.library(
		name: "BusinessMathDSL",
		targets: ["BusinessMathDSL"]
	),
	.executable(
		name: "businessmath-mcp-server",
		targets: ["BusinessMathMCPServer"]
	)
]

if !isLinux {
	products.append(
		.library(
			name: "BusinessMathMacros",
			type: .static,
			targets: ["BusinessMathMacros"]
		)
	)
}

// MARK: - Dependencies

let dependencies: [Package.Dependency] = [
	.package(
		url: "https://github.com/apple/swift-numerics",
		from: "1.1.1"
	),
	.package(
		url: "https://github.com/modelcontextprotocol/swift-sdk.git",
		from: "0.10.0"
	),
	.package(
		url: "https://github.com/apple/swift-syntax.git",
		from: "509.0.0"
	)
]

// MARK: - Targets

var targets: [Target] = [

	// Core library (NO macro dependency to avoid Playground crashes)
	// Macros are available separately via BusinessMathMacros product
	.target(
		name: "BusinessMath",
		dependencies: [
			.product(name: "Numerics", package: "swift-numerics")
		],
		exclude: [
			// Exclude Metal shaders to avoid Metal Toolchain requirement in Playgrounds/Xcode
			// GPU acceleration is optional - only needed for large-scale optimizations
			"Optimization/Heuristic/GPU/Shaders.metal"
		],
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	),

	// MCP integration
	.target(
		name: "BusinessMathMCP",
		dependencies: [
			"BusinessMath",
			.product(name: "Numerics", package: "swift-numerics"),
			.product(
				name: "MCP",
				package: "swift-sdk",
				condition: .when(platforms: [.macOS])
			)
		],
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	),

	// MCP server executable
	.executableTarget(
		name: "BusinessMathMCPServer",
		dependencies: ["BusinessMathMCP"],
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
		swiftSettings: [
			.enableUpcomingFeature("StrictConcurrency")
		]
	),

	// Tests (core)
	.testTarget(
		name: "BusinessMathTests",
		dependencies: [
			"BusinessMath",
			"BusinessMathMCP",
			"BusinessMathDSL"
		]
	)
]

// MARK: - Macro Targets (non-Linux only)

if !isLinux {
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
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		)

		// BusinessMathMacrosTests target removed - all test files are currently disabled (.swift.disabled)
	]
}

// MARK: - Package

let package = Package(
	name: "BusinessMath",
	platforms: [
		.iOS(.v14),
		.macOS(.v13),
		.tvOS(.v14),
		.watchOS(.v7),
		.visionOS(.v1)
	],
	products: products,
	dependencies: dependencies,
	targets: targets
)
