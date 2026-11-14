#!/usr/bin/env python3
"""Hand-written mutation check of the step-4 changes (ADR-009): PageRank convergence and damping
validation, modularity partition validation, the unweighted Louvain tie margin, and the eigenvector
refusal of a disconnected graph, with their metric versions and the error type.

Each mutant is one textual edit (optionally to the nth occurrence of a pattern) to one source file of
the OUTSIDE-THE-REPO lab built by make_lab.sh. The script applies it, runs `swift test`, restores the
file, and records KILLED (a test failed or the run hung), BUILD ERROR (an invalid mutant, not counted)
or SURVIVED.

    ./make_lab.sh <worktree> <lab-dir>
    python3 mutate.py <lab-dir> [name-filter] > mutation_output.txt
"""
import subprocess, sys, re, os, signal

ROOT = sys.argv[1]
ONLY = sys.argv[2] if len(sys.argv) > 2 else None
SRC = ROOT + "/Sources/BusinessMath/Network/"
C, M, S, E = "Weighted/WeightedCentrality.swift", "Weighted/WeightedCommunity.swift", "Metrics/StandardMetrics.swift", "Weighted/GraphMeasureError.swift"
U = "UnweightedCommunity.swift"

# (name, file, old, new[, nth])   nth is 1-based among the occurrences of `old`.
MUTANTS = [
 # ---- damping validation
 ("D01 isFinite dropped from the damping check", C, "guard damping.isFinite, damping >= 0, damping < 1 else {", "guard damping >= 0, damping < 1 else {"),
 ("D02 zero damping refused (>= 0 to > 0)", C, "damping.isFinite, damping >= 0, damping < 1", "damping.isFinite, damping > 0, damping < 1"),
 ("D03 damping of one accepted (< 1 to <= 1)", C, "damping >= 0, damping < 1 else", "damping >= 0, damping <= 1 else"),
 ("D04 damping capped at 0.999 again (< 1 to < 0.999)", C, "damping >= 0, damping < 1 else", "damping >= 0, damping < 0.999 else"),
 ("D05 negative damping accepted", C, "damping.isFinite, damping >= 0, damping < 1", "damping.isFinite, damping > -1, damping < 1"),
 ("D06 validation always passes", C, "guard damping.isFinite, damping >= 0, damping < 1 else {", "guard true else {"),
 ("D07 refusal carries the wrong value", C, "throw GraphMeasureError.invalidDamping(damping)", "throw GraphMeasureError.invalidDamping(0)"),
 ("D08 refusal comes after the empty-graph shortcut", C, "		guard damping.isFinite, damping >= 0, damping < 1 else {\n			throw GraphMeasureError.invalidDamping(damping)\n		}\n		let count = graph.nodeCount\n		guard count > 0 else { return (0, true, 0, NodeScores([:])) }\n		let teleport", "		let count = graph.nodeCount\n		guard count > 0 else { return (0, true, 0, NodeScores([:])) }\n		guard damping.isFinite, damping >= 0, damping < 1 else {\n			throw GraphMeasureError.invalidDamping(damping)\n		}\n		let teleport"),
 ("D09 pageRank swallows the refusal", C, "		try pageRankConvergence(\n			graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores", "		(try? pageRankConvergence(\n			graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores) ?? NodeScores([:])"),
 # ---- PageRank loop and report
 ("P01 teleport not divided by n", C, "let teleport = (1 - damping) / Double(count)", "let teleport = (1 - damping)"),
 ("P02 dangling spread not divided by n", C, "let spread = damping * danglingMass / Double(count)", "let spread = damping * danglingMass"),
 ("P03 dangling mass dropped", C, "let spread = damping * danglingMass / Double(count)", "let spread = 0.0"),
 ("P04 share not divided by degree", C, "let share = damping * current[index] / degree", "let share = damping * current[index]"),
 ("P05 edge weight ignored in the spread", C, "next[neighbour] += share * weight", "next[neighbour] += share"),
 ("P06 zero-degree nodes treated as having ties", C, "guard degree > 0 else { continue }", "guard degree >= 0 else { continue }"),
 ("P07 dangling test < instead of <=", C, "for index in 0..<count where degrees[index] <= 0 {", "for index in 0..<count where degrees[index] < 0 {"),
 ("P08 stop test < to <= (pagerank)", C, "			residual = delta\n			if delta < tolerance {\n				converged = true\n				break\n			}\n		}\n\n		var scores: [Node: Double] = [:]\n		for (index, node) in graph.nodes.enumerated() { scores[node] = current[index] }", "			residual = delta\n			if delta <= tolerance {\n				converged = true\n				break\n			}\n		}\n\n		var scores: [Node: Double] = [:]\n		for (index, node) in graph.nodes.enumerated() { scores[node] = current[index] }"),
 ("P09 pagerank converged flag never set", C, "if delta < tolerance {\n				converged = true\n				break\n			}", "if delta < tolerance {\n				break\n			}", 2),
 ("P10 pagerank break dropped after convergence", C, "if delta < tolerance {\n				converged = true\n				break\n			}", "if delta < tolerance {\n				converged = true\n			}", 2),
 ("P11 pagerank iterations not counted", C, "			current = next\n			iterations += 1\n			residual = delta", "			current = next\n			residual = delta", 2),
 ("P12 pagerank residual not recorded", C, "			iterations += 1\n			residual = delta\n			if delta < tolerance {", "			iterations += 1\n			if delta < tolerance {", 2),
 ("P13 pagerank delta L1 to L-inf", C, "for index in 0..<count { delta += abs(next[index] - current[index]) }", "for index in 0..<count { delta = max(delta, abs(next[index] - current[index])) }", 2),
 ("P14 empty graph reports not converged", C, "guard count > 0 else { return (0, true, 0, NodeScores([:])) }", "guard count > 0 else { return (0, false, 0, NodeScores([:])) }", 2),
 ("P15 max(1, ceiling) dropped in pagerank loop", C, "for _ in 0..<max(1, maxIterations) {\n			var next = [Double]", "for _ in 0..<maxIterations {\n			var next = [Double]"),
 ("P16 pageRank default damping 0.85 to 0.9", C, "_ graph: WeightedGraph<Node>, damping: Double = 0.85,\n		maxIterations: Int = 200, tolerance: Double = 1e-12\n	) throws -> NodeScores<Node> {", "_ graph: WeightedGraph<Node>, damping: Double = 0.9,\n		maxIterations: Int = 200, tolerance: Double = 1e-12\n	) throws -> NodeScores<Node> {"),
 ("P17 pageRankConvergence default ceiling 200 to 100", C, "_ graph: WeightedGraph<Node>, damping: Double = 0.85,\n		maxIterations: Int = 200, tolerance: Double = 1e-12\n	) throws -> (iterations", "_ graph: WeightedGraph<Node>, damping: Double = 0.85,\n		maxIterations: Int = 100, tolerance: Double = 1e-12\n	) throws -> (iterations"),
 ("P18 pageRankConvergence default tolerance 1e-12 to 1e-9", C, "maxIterations: Int = 200, tolerance: Double = 1e-12\n	) throws -> (iterations", "maxIterations: Int = 200, tolerance: Double = 1e-9\n	) throws -> (iterations"),
 ("P19 pageRank ignores the tolerance it is given", C, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores", "graph, damping: damping, maxIterations: maxIterations, tolerance: 1e-3).scores"),
 ("P20 pageRank ignores the ceiling it is given", C, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores", "graph, damping: damping, maxIterations: 3, tolerance: tolerance).scores"),
 ("P21 pageRank ignores the damping it is given", C, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores", "graph, damping: 0.85, maxIterations: maxIterations, tolerance: tolerance).scores"),
 ("P22 start vector not uniform (pagerank)", C, "var current = [Double](repeating: 1 / Double(count), count: count)\n		let degrees", "var current = [Double](repeating: 1, count: count)\n		let degrees"),
 # ---- PageRank metric
 ("K01 pagerank version 3 to 2", S, 'identifier: "pagerank", version: 3,', 'identifier: "pagerank", version: 2,'),
 ("K02 pagerank version 3 to 4", S, 'identifier: "pagerank", version: 3,', 'identifier: "pagerank", version: 4,'),
 ("K03 PageRankMetric default damping 0.85 to 0.9", S, "init(damping: Double = 0.85,", "init(damping: Double = 0.9,"),
 ("K04 PageRankMetric default ceiling 200 to 100", S, "init(damping: Double = 0.85, maxIterations: Int = 200,", "init(damping: Double = 0.85, maxIterations: Int = 100,"),
 ("K05 PageRankMetric default tolerance 1e-12 to 1e-9", S, "tolerance: Double = 1e-12) {", "tolerance: Double = 1e-9) {"),
 ("K06 PageRankMetric ignores its damping", S, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance)", "graph, damping: 0.85, maxIterations: maxIterations, tolerance: tolerance)"),
 ("K07 PageRankMetric ignores its ceiling", S, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance)", "graph, damping: damping, maxIterations: 200, tolerance: tolerance)"),
 ("K08 PageRankMetric ignores its tolerance", S, "graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance)", "graph, damping: damping, maxIterations: maxIterations, tolerance: 1e-12)"),
 ("K09 PageRankMetric reports a fixed tolerance", S, "tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness", "tolerance: 1e-12, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness"),
 ("K10 PageRankMetric reports the raw ceiling", S, "tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness", "tolerance: tolerance, maxIterations: maxIterations))\n	}\n}\n\n/// Betweenness"),
 ("K11 PageRankMetric reports converged always true", S, "iterations: run.iterations, converged: run.converged, residual: run.residual,\n				tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness", "iterations: run.iterations, converged: true, residual: run.residual,\n				tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness"),
 ("K12 PageRankMetric reports a zero residual", S, "iterations: run.iterations, converged: run.converged, residual: run.residual,\n				tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness", "iterations: run.iterations, converged: run.converged, residual: 0,\n				tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness"),
 ("K13 PageRankMetric reports no convergence", S, "		return DiagnosedScores(\n			scores: run.scores,\n			convergence: ConvergenceReport(\n				iterations: run.iterations, converged: run.converged, residual: run.residual,\n				tolerance: tolerance, maxIterations: max(1, maxIterations)))\n	}\n}\n\n/// Betweenness", "		return DiagnosedScores(scores: run.scores, convergence: nil)\n	}\n}\n\n/// Betweenness"),
 # ---- modularity partition validation
 ("M01 foreign nodes no longer refused", M, "guard missing.isEmpty, unknown.isEmpty else {", "guard missing.isEmpty else {"),
 ("M02 missing nodes no longer refused", M, "guard missing.isEmpty, unknown.isEmpty else {", "guard unknown.isEmpty else {"),
 ("M03 validation always passes", M, "guard missing.isEmpty, unknown.isEmpty else {", "guard true else {"),
 ("M04 missing test inverted", M, "for node in graph.nodes where partition[node] == nil {", "for node in graph.nodes where partition[node] != nil {"),
 ("M05 foreign test inverted", M, "for node in partition.communities.keys where graph.indexOf[node] == nil {", "for node in partition.communities.keys where graph.indexOf[node] != nil {"),
 ("M06 refusal drops the foreign names", M, "unknown: unknown.sorted().map { String(describing: $0) })", "unknown: [])"),
 ("M07 refusal drops the missing names", M, "missing: missing, unknown: unknown.sorted()", "missing: [], unknown: unknown.sorted()"),
 ("M08 foreign names not sorted", M, "unknown: unknown.sorted().map { String(describing: $0) })", "unknown: unknown.map { String(describing: $0) })"),
 ("M09 refusal replaced by the edgeless shortcut ahead of it", M, "		// Validate before anything else, so an edgeless graph with a wrong partition is refused too.\n", "		guard graph.totalWeight > 0 else { return 0 }\n"),
 # ---- unweighted Louvain tie margin
 ("L01 margin is a raw 1e-12 (not scaled by 2m)", U, "let threshold: Double = twiceEdges > 0 ? moveMargin / twiceEdges : 0", "let threshold: Double = moveMargin"),
 ("L02 no margin", U, "let threshold: Double = twiceEdges > 0 ? moveMargin / twiceEdges : 0", "let threshold: Double = 0"),
 ("L03 margin multiplied by 2m", U, "moveMargin / twiceEdges : 0", "moveMargin * twiceEdges : 0"),
 ("L04 margin constant 1e-12 to 1e-9", U, "static var moveMargin: Double { 1e-12 }", "static var moveMargin: Double { 1e-9 }"),
 ("L05 margin constant 1e-12 to 1e-15", U, "static var moveMargin: Double { 1e-12 }", "static var moveMargin: Double { 1e-15 }"),
 ("L06 move test > to >=", U, "if gain > bestGain + threshold {", "if gain >= bestGain + threshold {"),
 ("L07 best gain not updated after a move", U, "if gain > bestGain + threshold {\n				bestGain = gain\n				bestGroup = group", "if gain > bestGain + threshold {\n				bestGroup = group"),
 ("L08 margin applied to the baseline instead of the candidate", U, "if gain > bestGain + threshold {", "if gain + threshold > bestGain {"),
 ("L09 margin subtracted", U, "if gain > bestGain + threshold {", "if gain > bestGain - threshold {"),
 # ---- eigenvector refusal
 ("V01 refusal needs three components", C, "guard components == 1 else {", "guard components <= 2 else {"),
 ("V02 never refuses", C, "guard components == 1 else {", "guard components > 0 else {"),
 ("V03 refuses a connected graph", C, "guard components == 1 else {", "guard components == 0 else {"),
 ("V04 zero-weight ties connect", C, "where weight > 0 && !seen[neighbour] {", "where weight >= 0 && !seen[neighbour] {"),
 ("V05 every tie is ignored", C, "where weight > 0 && !seen[neighbour] {", "where weight > 1e300 && !seen[neighbour] {"),
 ("V06 refusal carries the wrong component count", C, "throw GraphMeasureError.disconnectedGraph(components: components)", "throw GraphMeasureError.disconnectedGraph(components: 1)"),
 ("V07 components counted twice each", C, "			components += 1\n			seen[start] = true", "			components += 2\n			seen[start] = true"),
 ("V08 search never grows past the start", C, "					seen[neighbour] = true\n					queue.append(neighbour)", "					seen[neighbour] = true"),
 ("V09 neighbours not marked seen", C, "					seen[neighbour] = true\n					queue.append(neighbour)", "					queue.append(neighbour)"),
 ("V10 single node goes through the iteration", C, "guard count > 1 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }", "guard count > 2 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }"),
 ("V11 empty graph reports not converged (eigenvector)", C, "guard count > 0 else { return (0, true, 0, NodeScores([:])) }", "guard count > 0 else { return (0, false, 0, NodeScores([:])) }", 1),
 ("V12 eigenvector version 5 to 4", S, 'identifier: "eigenvector-centrality", version: 5,', 'identifier: "eigenvector-centrality", version: 4,'),
 ("V13 eigenvector version 5 to 6", S, 'identifier: "eigenvector-centrality", version: 5,', 'identifier: "eigenvector-centrality", version: 6,'),
 ("V14 eigenvector shortcut for a lone node dropped", C, "guard count > 1 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }\n", ""),
 ("V15 eigenvector wrapper ignores the ceiling", C, "try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: tolerance).scores", "try eigenvectorConvergence(graph, maxIterations: 200, tolerance: tolerance).scores"),
 # ---- the error type
 ("G01 NaN damping errors no longer equal", E, "return (left.isNaN && right.isNaN) || left.isEqual(to: right)", "return left.isEqual(to: right)"),
 ("G02 damping errors always equal", E, "return (left.isNaN && right.isNaN) || left.isEqual(to: right)", "return true"),
 ("G03 partition errors equal if either list matches", E, "return leftMissing == rightMissing && leftUnknown == rightUnknown", "return leftMissing == rightMissing || leftUnknown == rightUnknown"),
 ("G04 partition errors compare only the missing list", E, "return leftMissing == rightMissing && leftUnknown == rightUnknown", "return leftMissing == rightMissing"),
 ("G05 component errors always equal", E, "case (.disconnectedGraph(let left), .disconnectedGraph(let right)):\n			return left == right", "case (.disconnectedGraph(_), .disconnectedGraph(_)):\n			return true"),
 ("G06 different error cases compare equal", E, "		default:\n			return false", "		default:\n			return true"),
]

def run():
    p = subprocess.Popen(["swift", "test"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        out, _ = p.communicate(timeout=420)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        return "KILLED", "timeout (a hang is a detected change)"
    out = re.sub(r"\x1b\[[0-9;]*m", "", out)
    m = re.search(r"Test run with (\d+) tests.*?(passed|failed)", out)
    if m is None:
        return "BUILD ERROR", out
    return ("KILLED" if m.group(2) == "failed" else "SURVIVED"), out

def replace_nth(text, old, new, nth):
    index = -1
    for _ in range(nth):
        index = text.find(old, index + 1)
        if index < 0:
            return None
    return text[:index] + new + text[index + len(old):]

def main():
    killed = survived = broken = 0
    for entry in MUTANTS:
        name, f, old, new = entry[:4]
        nth = entry[4] if len(entry) > 4 else 1
        if ONLY and ONLY not in name:
            continue
        path = SRC + f
        original = open(path).read()
        count = original.count(old)
        if count < nth or (len(entry) <= 4 and count != 1):
            print(f"{name}: PATTERN MISMATCH ({count} matches)", flush=True)
            broken += 1
            continue
        open(path, "w").write(replace_nth(original, old, new, nth))
        try:
            status, out = run()
        finally:
            open(path, "w").write(original)
        detail = ""
        if status == "KILLED":
            failing = re.findall(r'Test "(.*?)" (?:with \d+ test cases )?(?:failed|recorded an issue)', out)
            detail = (failing[0] if failing else out[:80])[:100]
            killed += 1
        elif status == "SURVIVED":
            survived += 1
        else:
            broken += 1
            detail = " | ".join(l for l in out.splitlines() if "error:" in l)[:200]
        print(f"{name}: {status}  {detail}", flush=True)
    print(f"\nTOTAL {len(MUTANTS)}  killed {killed}  survived {survived}  not-counted {broken}")

main()
