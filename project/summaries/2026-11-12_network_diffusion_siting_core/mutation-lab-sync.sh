#!/bin/bash
# Copies the code under test and its tests from the worktree into the mutation lab (pristine state).
set -euo pipefail
WT=/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath-wt-diffusion
LAB=/private/tmp/claude-501/mutlab
rm -rf "$LAB/Sources" "$LAB/Tests"
mkdir -p "$LAB/Sources/BusinessMath/Network" "$LAB/Tests/TestSupport" "$LAB/Tests/BusinessMathTests"
cp -R "$WT/Sources/BusinessMath/Network/Diffusion" "$WT/Sources/BusinessMath/Network/Siting" "$LAB/Sources/BusinessMath/Network/"
cp "$WT/Sources/BusinessMath/Network/Weighted/WeightedGraph.swift" "$LAB/Sources/BusinessMath/Network/"
cp "$WT/Tests/TestSupport/ReferenceGraphs.swift" "$LAB/Tests/TestSupport/"
cp "$WT/Tests/BusinessMathTests/Network Tests/Diffusion/"*.swift "$LAB/Tests/BusinessMathTests/"
for f in "$WT/Tests/BusinessMathTests/Network Tests/Siting/"*.swift; do
  case "$f" in *IntegerProgram*) ;; *) cp "$f" "$LAB/Tests/BusinessMathTests/";; esac
done
