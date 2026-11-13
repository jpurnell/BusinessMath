#!/bin/bash
# Copies the code under test and its tests from the worktree into the mutation lab (pristine state).
set -euo pipefail
WT=/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath-wt-diffpart2
LAB=${MUT_LAB:-/private/tmp/claude-501/mutlab2}
rm -rf "$LAB/Sources" "$LAB/Tests"
mkdir -p "$LAB/Sources/BusinessMath/Network" "$LAB/Tests/TestSupport" "$LAB/Tests/BusinessMathTests"
cp -R "$WT/Sources/BusinessMath/Network/Diffusion" "$WT/Sources/BusinessMath/Network/Siting" "$WT/Sources/BusinessMath/Network/Metrics" "$LAB/Sources/BusinessMath/Network/"
cp "$WT/Sources/BusinessMath/Network/Weighted/WeightedGraph.swift" "$LAB/Sources/BusinessMath/Network/"
cp "$WT/Tests/TestSupport/ReferenceGraphs.swift" "$LAB/Tests/TestSupport/"
# benchmarkOnly trait, without the Metal-dependent traits
cat > "$LAB/Tests/TestSupport/Traits.swift" <<'EOT'
import Foundation
import Testing

extension Trait where Self == ConditionTrait {
	public static var benchmarkOnly: Self {
		.enabled(if: ProcessInfo.processInfo.environment["RUN_BENCHMARKS"] != nil, "Set RUN_BENCHMARKS=1 to enable.")
	}
}
EOT
cp "$WT/Tests/BusinessMathTests/Network Tests/Diffusion/"*.swift "$LAB/Tests/BusinessMathTests/"
for f in "$WT/Tests/BusinessMathTests/Network Tests/Siting/"*.swift; do
  case "$f" in *IntegerProgram*) ;; *) cp "$f" "$LAB/Tests/BusinessMathTests/";; esac
done
