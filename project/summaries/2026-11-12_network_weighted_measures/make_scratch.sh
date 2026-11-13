#!/bin/bash
# Builds the OUTSIDE-THE-REPO scratch package the mutation check runs against: a small SwiftPM
# package whose "BusinessMath" target holds copies of just the Network sources the weighted-measures
# suites need, so a mutant rebuilds in seconds instead of rebuilding the 526-file library.
# Usage: make_scratch.sh <worktree> <scratch-dir>
set -euo pipefail
WT="$1"; OUT="$2"
rm -rf "$OUT"; mkdir -p "$OUT/Sources/BusinessMath" "$OUT/Sources/TestSupport" "$OUT/Tests/BusinessMathTests"
N="$WT/Sources/BusinessMath/Network"
cp "$N/Graph.swift" "$N/Traversal.swift" "$OUT/Sources/BusinessMath/"
cp "$N/Centrality/Centrality.swift" "$OUT/Sources/BusinessMath/UnweightedCentrality.swift"
cp "$N/Community/Community.swift" "$OUT/Sources/BusinessMath/UnweightedCommunity.swift"
cp "$N"/Weighted/*.swift "$OUT/Sources/BusinessMath/"
cp "$N"/Metrics/Values/*.swift "$N"/Metrics/Protocol/*.swift "$OUT/Sources/BusinessMath/"
cp "$WT/Tests/TestSupport/ReferenceGraphs.swift" "$WT/Tests/TestSupport/IndependentImplementations.swift" "$OUT/Sources/TestSupport/"
cp "$WT/Tests/BusinessMathTests/Network Tests/Weighted/"*.swift "$OUT/Tests/BusinessMathTests/"
# step-1 suites (graph structure, bridges, validation) are not what this check targets and need other TestSupport files
rm -f "$OUT/Tests/BusinessMathTests/"{WeightedGraphPropertyTests,WeightedGraphTests,GraphBridgeTests,WeightValidationTests}.swift
cat > "$OUT/Package.swift" <<PKG
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "mut2",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "$WT/.build/checkouts/swift-numerics"),
        .package(path: "/Users/jpurnell/Dropbox/Computer/Development/Swift/Tools/SwiftDeterminism"),
    ],
    targets: [
        .target(name: "BusinessMath", dependencies: [
            .product(name: "Numerics", package: "swift-numerics"),
            .product(name: "SwiftDeterminism", package: "SwiftDeterminism")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "TestSupport", dependencies: ["BusinessMath"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "BusinessMathTests", dependencies: [
            "BusinessMath", "TestSupport",
            .product(name: "SwiftDeterminism", package: "SwiftDeterminism")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
PKG
echo "scratch package at $OUT"
