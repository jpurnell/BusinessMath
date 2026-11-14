#!/bin/bash
# Builds the OUTSIDE-THE-REPO mutation lab for step 4: a small SwiftPM package whose "BusinessMath"
# target holds copies of just the Network sources the step-4 suites need, so a mutant rebuilds in
# seconds instead of rebuilding the whole library.   Usage: make_lab.sh <worktree> <lab-dir>
set -euo pipefail
WT="$1"; LAB="$2"
rm -rf "$LAB/Sources" "$LAB/Tests"
mkdir -p "$LAB/Sources/BusinessMath/Network" "$LAB/Tests/TestSupport" "$LAB/Tests/BusinessMathTests"
N="$WT/Sources/BusinessMath/Network"
cp "$N/Graph.swift" "$N/Traversal.swift" "$LAB/Sources/BusinessMath/Network/"
cp -R "$N/Weighted" "$N/Metrics" "$N/Diffusion" "$N/Siting" "$LAB/Sources/BusinessMath/Network/"
cp "$N/Centrality/Centrality.swift" "$LAB/Sources/BusinessMath/Network/UnweightedCentrality.swift"
cp "$N/Community/Community.swift" "$LAB/Sources/BusinessMath/Network/UnweightedCommunity.swift"
for f in ReferenceGraphs SeededRNG IndependentImplementations DensePageRank; do cp "$WT/Tests/TestSupport/$f.swift" "$LAB/Tests/TestSupport/"; done
cat > "$LAB/Tests/TestSupport/Traits.swift" <<'EOT'
import Foundation
import Testing
extension Trait where Self == ConditionTrait {
	public static var benchmarkOnly: Self {
		.enabled(if: ProcessInfo.processInfo.environment["RUN_BENCHMARKS"] != nil, "Set RUN_BENCHMARKS=1 to enable.")
	}
}
EOT
T="$WT/Tests/BusinessMathTests/Network Tests"
cp "$T/Metrics/"*.swift "$LAB/Tests/BusinessMathTests/"
for f in SyntheticGraphs PageRankConvergenceTests PageRankDampingTests ModularityPartitionValidationTests \
         UnweightedLouvainTieMarginTests EigenvectorDisconnectedTests EigenvectorConvergenceTests StoppingRuleBoundaryTests \
         WeightedCentralityMutationTests WeightedCommunityMutationTests UnweightedWeightedCrossCheckTests \
         WeightedCrossCheckTests GoldenMeasureData GoldenMeasureRunner GoldenMeasureTests WeightConsumerRegistryTests \
         BurtConstraintMetricTests; do
  cp "$T/Weighted/$f.swift" "$LAB/Tests/BusinessMathTests/"
done
cat > "$LAB/Package.swift" <<PKG
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "mut5",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "$WT/.build/checkouts/swift-numerics"),
        .package(path: "/Users/jpurnell/Dropbox/Computer/Development/Swift/Tools/SwiftDeterminism"),
    ],
    targets: [
        .target(name: "BusinessMath", dependencies: [
            .product(name: "Numerics", package: "swift-numerics"),
            .product(name: "SwiftDeterminism", package: "SwiftDeterminism")],
            path: "Sources/BusinessMath", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "TestSupport", dependencies: ["BusinessMath"], path: "Tests/TestSupport", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "BusinessMathTests", dependencies: [
            "BusinessMath", "TestSupport", .product(name: "SwiftDeterminism", package: "SwiftDeterminism")],
            path: "Tests/BusinessMathTests", swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
PKG
echo "lab at $LAB"
