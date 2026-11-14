#!/usr/bin/env python3
"""Hand-written mutation run over the by-component eigenvector code (ADR-010): the measure, its value
types, the metric and its registration. Adapted from project/summaries/2026-11-13_network_explicit_behaviours/mutate.py.

Each mutant is one textual edit (optionally to the nth occurrence of a pattern) to one source file of the
OUTSIDE-THE-REPO lab built by make_lab.sh. The script applies it, runs `swift test --filter <suites>`,
restores the file, and records KILLED (a test failed or the run hung), BUILD ERROR (an invalid mutant, not
counted) or SURVIVED.

    ./make_lab.sh <worktree> <lab-dir>
    python3 mutate.py <lab-dir> [name-filter] > mutants.out
"""
import subprocess, sys, re, os, signal

ROOT = sys.argv[1]
ONLY = sys.argv[2] if len(sys.argv) > 2 else None
SRC = ROOT + "/Sources/BusinessMath/Network/"
FILTER = "EigenvectorByComponent|MetricRegistryTests|MetricRecordGoldenTests|RegistryListingGoldenTests"
E = "Weighted/EigenvectorByComponent.swift"
V = "Metrics/Values/ComponentwiseScores.swift"
M = "Metrics/ComponentwiseEigenvectorMetric.swift"
R = "Metrics/Protocol/MetricRegistry.swift"

TRIV = "iterations: 0, converged: true, residual: 0, tolerance: tolerance, maxIterations: ceiling),\n\t\t\t\tcomponents: [], isolatedCount: isolated)"
WHOLE = "tolerance: tolerance, maxIterations: ceiling)\n\t\t\treturn ComponentwiseScores(\n\t\t\t\tscores: run.scores"
WORST = "tolerance: tolerance, maxIterations: ceiling)\n\t\treturn ComponentwiseScores(\n\t\t\tscores: NodeScores(scores)"

# (name, file, old, new[, nth])   nth is 1-based among the occurrences of `old`.
MUTANTS = [
 # ---- settings and the trivial branch
 ("E01 ceiling not clamped", E, "let ceiling = max(1, maxIterations)", "let ceiling = maxIterations"),
 ("E02 trivial guard flipped", E, "guard !scored.isEmpty else {", "guard scored.isEmpty else {"),
 ("E03 trivial guard needs two components", E, "guard !scored.isEmpty else {", "guard scored.count > 1 else {"),
 ("E04 trivial: one pass reported", E, TRIV, TRIV.replace("iterations: 0", "iterations: 1")),
 ("E05 trivial: reported not converged", E, TRIV, TRIV.replace("converged: true", "converged: false")),
 ("E06 trivial: isolated count dropped", E, TRIV, TRIV.replace("isolatedCount: isolated", "isolatedCount: 0")),
 ("E07 trivial: ceiling unclamped", E, TRIV, TRIV.replace("maxIterations: ceiling", "maxIterations: maxIterations")),
 ("E08 trivial: tolerance fixed", E, TRIV, TRIV.replace("tolerance: tolerance", "tolerance: 1e-10")),
 ("E09 trivial: residual one", E, TRIV, TRIV.replace("residual: 0", "residual: 1")),
 # ---- one component, no isolate
 ("E10 whole graph taken for one component with isolates", E, "if scored.count == 1 && isolated == 0 {", "if scored.count == 1 {"),
 ("E11 whole graph branch on || ", E, "if scored.count == 1 && isolated == 0 {", "if scored.count == 1 || isolated == 0 {"),
 ("E12 whole graph with one isolate allowed", E, "if scored.count == 1 && isolated == 0 {", "if scored.count == 1 && isolated <= 1 {"),
 ("E13 whole: scale half", E, "convergence: report, scale: 1)],", "convergence: report, scale: 0.5)],"),
 ("E14 whole: anchor is the last node", E, "anchor: graph.nodes[0], size: graph.nodeCount", "anchor: graph.nodes[graph.nodeCount - 1], size: graph.nodeCount"),
 ("E15 whole: size one short", E, "size: graph.nodeCount, convergence: report", "size: graph.nodeCount - 1, convergence: report"),
 ("E16 whole: ceiling unclamped", E, WHOLE, WHOLE.replace("maxIterations: ceiling", "maxIterations: maxIterations")),
 ("E17 whole: tolerance fixed", E, WHOLE, WHOLE.replace("tolerance: tolerance", "tolerance: 1e-10")),
 ("E18 whole: isolated count one", E, "isolatedCount: 0)\n\t\t}", "isolatedCount: 1)\n\t\t}"),
 ("E19 whole: score through the component path (rescaled)", E, "scores: run.scores, convergence: report,", "scores: NodeScores(run.scores.scores.mapValues { $0 * 0.999 }), convergence: report,"),
 # ---- the scale
 ("E20 rms without the square root", E, "meanSquare.squareRoot()))", "meanSquare))"),
 ("E21 mean over n + 1", E, "/ Double(max(1, values.count))", "/ Double(max(1, values.count) + 1)"),
 ("E22 sum of scores, not squares", E, "$0 + $1 * $1", "$0 + $1"),
 ("E23 shared scale is the largest rms", E, ".filter { $0 > 0 }.min()", ".filter { $0 > 0 }.max()"),
 ("E24 shared scale: no fallback needed, a zero rms is guarded", E, "if let smallest, part.rms > 0 {", "if let smallest {"),
 ("E25 scale inverted", E, "scale = smallest / part.rms", "scale = part.rms / smallest"),
 ("E26 scale guard accepts zero rms", E, "if let smallest, part.rms > 0 {", "if let smallest, part.rms >= 0 {"),
 ("E27 zero-rms component scale 1 to 0", E, "\t\t\t} else {\n\t\t\t\tscale = 1\n", "\t\t\t} else {\n\t\t\t\tscale = 0\n"),
 ("E28 score divided by the scale", E, "part.scores[offset] * scale", "part.scores[offset] / scale"),
 ("E29 every member takes the first score", E, "part.scores[offset] * scale", "part.scores[0] * scale"),
 ("E30 unassigned nodes default to 1", E, "for node in graph.nodes { scores[node] = 0 }", "for node in graph.nodes { scores[node] = 1 }"),
 ("E31 score lookup default 0 to 1", E, "run.scores[$0] ?? 0", "run.scores[$0] ?? 1"),
 # ---- component detail
 ("E32 anchor is the highest member", E, "anchor: graph.nodes[part.members[0]]", "anchor: graph.nodes[part.members[part.members.count - 1]]"),
 ("E33 size one over", E, "size: part.members.count,", "size: part.members.count + 1,"),
 ("E34 detail carries the aggregate scale 1", E, "convergence: part.report, scale: scale))", "convergence: part.report, scale: 1))"),
 # ---- worst case
 ("E35 worst iterations is the least", E, "iterations: parts.map(\\.report.iterations).max() ?? 0,", "iterations: parts.map(\\.report.iterations).min() ?? 0,"),
 ("E36 worst converged if any converged", E, "converged: parts.allSatisfy { $0.report.converged },", "converged: parts.contains { $0.report.converged },"),
 ("E37 worst converged judged by the first component", E, "converged: parts.allSatisfy { $0.report.converged },", "converged: parts.first?.report.converged ?? true,"),
 ("E38 worst converged judged by the last component", E, "converged: parts.allSatisfy { $0.report.converged },", "converged: parts.last?.report.converged ?? true,"),
 ("E39 worst residual is the least", E, "residual: parts.map(\\.report.residual).max() ?? 0,", "residual: parts.map(\\.report.residual).min() ?? 0,"),
 ("E40 worst iterations is the first component's", E, "iterations: parts.map(\\.report.iterations).max() ?? 0,", "iterations: parts.first?.report.iterations ?? 0,"),
 ("E41 worst: ceiling unclamped", E, WORST, WORST.replace("maxIterations: ceiling", "maxIterations: maxIterations")),
 ("E42 worst: tolerance fixed", E, WORST, WORST.replace("tolerance: tolerance", "tolerance: 1e-10")),
 ("E43 component report: tolerance fixed", E, "tolerance: tolerance, maxIterations: ceiling),\n\t\t\t\tmeanSquare", "tolerance: 1e-10, maxIterations: ceiling),\n\t\t\t\tmeanSquare"),
 ("E44 component report: ceiling unclamped", E, "tolerance: tolerance, maxIterations: ceiling),\n\t\t\t\tmeanSquare", "tolerance: tolerance, maxIterations: maxIterations),\n\t\t\t\tmeanSquare"),
 ("E45 component iteration ignores the ceiling", E, "let run = try eigenvectorConvergence(sub, maxIterations: maxIterations, tolerance: tolerance)", "let run = try eigenvectorConvergence(sub, maxIterations: 200, tolerance: tolerance)"),
 ("E46 component iteration ignores the tolerance", E, "let run = try eigenvectorConvergence(sub, maxIterations: maxIterations, tolerance: tolerance)", "let run = try eigenvectorConvergence(sub, maxIterations: maxIterations, tolerance: 1e-10)"),
 ("E47 whole iteration ignores the ceiling", E, "let run = try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: tolerance)", "let run = try eigenvectorConvergence(graph, maxIterations: 200, tolerance: tolerance)"),
 ("E48 whole iteration ignores the tolerance", E, "let run = try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: tolerance)", "let run = try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: 1e-10)"),
 # ---- components and subgraphs
 ("E49 a zero-weight tie connects", E, "where weight > 0 && !seen[neighbour] {", "where !seen[neighbour] {"),
 ("E50 members left unsorted", E, "groups.append(members.sorted())", "groups.append(members)"),
 ("E51 isolates counted as components", E, "groups.filter { $0.count > 1 }", "groups.filter { $0.count >= 1 }"),
 ("E52 isolated count is every group", E, "groups.count - scored.count", "groups.count"),
 ("E53 components found from the last node", E, "for start in 0..<graph.nodeCount where !seen[start] {", "for start in (0..<graph.nodeCount).reversed() where !seen[start] {"),
 ("E54 start node not marked seen", E, "\t\t\tseen[start] = true\n\t\t\tvar members = [start]", "\t\t\tvar members = [start]"),
 ("E55 subgraph keeps zero-weight ties", E, "where weight > 0 && index < neighbour {", "where index < neighbour {"),
 ("E56 subgraph emits every tie twice", E, "where weight > 0 && index < neighbour {", "where weight > 0 && index != neighbour {"),
 ("E57 subgraph emits each tie from the higher end", E, "where weight > 0 && index < neighbour {", "where weight > 0 && index > neighbour {"),
 ("E58 subgraph drops one tie in four", E, "edges.append((graph.nodes[index], graph.nodes[neighbour], weight))", "edges.append((graph.nodes[index], graph.nodes[neighbour], weight * 0.75))"),
 ("E59 mean denominator unguarded", E, "Double(max(1, values.count))", "Double(values.count)"),
 ("E60 worst iterations default 0 to 1", E, "iterations: parts.map(\\.report.iterations).max() ?? 0,", "iterations: parts.map(\\.report.iterations).max() ?? 1,"),
 # ---- value types
 ("V01 unconverged lists the converged", V, "components.filter { !$0.convergence.converged }", "components.filter { $0.convergence.converged }"),
 ("V02 diagnosed drops the report", V, "DiagnosedScores(scores: scores, convergence: convergence)", "DiagnosedScores(scores: scores, convergence: nil)"),
 ("V03 kind renamed", V, 'public static var kind: String { "scores" }', 'public static var kind: String { "component-scores" }'),
 ("V04 isolatedCount key renamed (encode and decode)", V, "case scores, convergence, components, isolatedCount", "case scores, convergence, components, isolatedCount = \"isolated\""),
 ("V05 encode drops the components", V, "try container.encode(components, forKey: .components)\n", ""),
 ("V06 encode drops the isolated count", V, "try container.encode(isolatedCount, forKey: .isolatedCount)\n", ""),
 ("V07 decode forgets the isolated count", V, "self.isolatedCount = try container.decode(Int.self, forKey: .isolatedCount)", "self.isolatedCount = 0"),
 ("V08 decode forgets the convergence", V, "self.convergence = try container.decode(ConvergenceReport.self, forKey: .convergence)", "self.convergence = ConvergenceReport(iterations: 0, converged: true, residual: 0, tolerance: 1e-10, maxIterations: 200)"),
 ("V09 init drops the components", V, "\t\tself.components = components\n", "\t\tself.components = []\n"),
 ("V10 component init swaps size", V, "\t\tself.size = size\n", "\t\tself.size = size + 1\n"),
 # ---- the metric and its registration
 ("M01 identifier changed", M, 'public static var identifier: String { "eigenvector-centrality-by-component" }', 'public static var identifier: String { "eigenvector-centrality-by-components" }'),
 ("M02 version two", M, 'identifier: identifier, version: 1,', 'identifier: identifier, version: 2,'),
 ("M03 title changed", M, 'title: "Eigenvector Centrality (by component)"', 'title: "Eigenvector Centrality"'),
 ("M04 metric ignores its ceiling", M, "maxIterations: maxIterations, tolerance: tolerance)\n\t}", "maxIterations: 200, tolerance: tolerance)\n\t}"),
 ("M05 metric ignores its tolerance", M, "maxIterations: maxIterations, tolerance: tolerance)\n\t}", "maxIterations: maxIterations, tolerance: 1e-10)\n\t}"),
 ("M06 default ceiling 200 to 100", M, "public init(maxIterations: Int = 200,", "public init(maxIterations: Int = 100,"),
 ("M07 default tolerance 1e-10 to 1e-9", M, "tolerance: Double = 1e-10) {", "tolerance: Double = 1e-9) {"),
 ("M08 interpretation wording changed", M, "scored within each", "scored inside each"),
 ("R01 not registered in the standard registry", R, "\t\t\tAnyGraphMetric(ComponentwiseEigenvectorMetric<Node>()),\n", ""),
 ("R02 registered with a lower ceiling", R, "AnyGraphMetric(ComponentwiseEigenvectorMetric<Node>()),", "AnyGraphMetric(ComponentwiseEigenvectorMetric<Node>(maxIterations: 100)),"),
 ("R03 registered twice", R, "\t\t\tAnyGraphMetric(ComponentwiseEigenvectorMetric<Node>()),\n", "\t\t\tAnyGraphMetric(ComponentwiseEigenvectorMetric<Node>()),\n\t\t\tAnyGraphMetric(ComponentwiseEigenvectorMetric<Node>()),\n"),
]

def run():
    p = subprocess.Popen(["swift", "test", "--filter", FILTER], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
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
        if old == new:
            print(f"{name}: IDENTICAL EDIT", flush=True)
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
