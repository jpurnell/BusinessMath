// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BusinessMath",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BusinessMath",
            targets: ["BusinessMath"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.2"),
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
        .testTarget(
            name: "BusinessMathTests",
            dependencies: ["BusinessMath"]),
    ]
)
