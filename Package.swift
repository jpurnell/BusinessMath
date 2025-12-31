// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "BusinessMath",
    platforms: [
		.iOS(.v14),
		.macOS(.v13),
		.tvOS(.v14),
		.watchOS(.v7),
		.visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BusinessMath",
            targets: ["BusinessMath"]),
        .library(
            name: "BusinessMathMCP",
            targets: ["BusinessMathMCP"]),
        .library(
            name: "BusinessMathMacros",
            targets: ["BusinessMathMacros"]),
        .library(
            name: "BusinessMathDSL",
            targets: ["BusinessMathDSL"]),
        .executable(
            name: "businessmath-mcp-server",
            targets: ["BusinessMathMCPServer"]),
        .executable(
            name: "performance-profiling",
            targets: ["PerformanceProfilingBaseline"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BusinessMath",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics")
            ],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		),
        .target(
            name: "BusinessMathMCP",
            dependencies: [
                "BusinessMath",
                .product(name: "Numerics", package: "swift-numerics"),
				.product(name: "MCP", package: "swift-sdk", condition: .when(platforms: [.macOS]))
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "BusinessMathMCPServer",
            dependencies: ["BusinessMathMCP"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "PerformanceProfilingBaseline",
            dependencies: ["BusinessMath"],
            path: "Examples",
            sources: ["PerformanceProfilingBaseline.swift"]
        ),
        .macro(
            name: "BusinessMathMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
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
        ),
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
        .testTarget(
            name: "BusinessMathTests",
            dependencies: [
                "BusinessMath",
                "BusinessMathMCP",
                "BusinessMathDSL"
            ]),
        .testTarget(
            name: "BusinessMathMacrosTests",
            dependencies: [
                "BusinessMathMacros",
                "BusinessMathMacrosImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
    ]
)
