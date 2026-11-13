#!/usr/bin/env python3
"""Hand-written mutation check of the metric registry layer (ADR-006 step 3).

Each mutant is one textual edit to one source file of the OUTSIDE-THE-REPO lab built by make_lab.sh.
The script applies the edit, runs `swift test`, restores the file, and records KILLED (a test failed
or the run hung), BUILD ERROR (invalid mutant) or SURVIVED.

    ./make_lab.sh <worktree> /private/tmp/claude-501/mut3
    python3 mutate.py /private/tmp/claude-501/mut3 > mutation_output.txt
"""
import subprocess, sys, re, os, signal

ROOT = sys.argv[1]
ONLY = sys.argv[2] if len(sys.argv) > 2 else None
SRC = ROOT + "/Sources/BusinessMath/Network/"
S, R, A, REC = "Metrics/StandardMetrics.swift", "Metrics/Protocol/MetricRegistry.swift", "Metrics/Protocol/AnyGraphMetric.swift", "Metrics/Protocol/MetricRecord.swift"
B, C = "Weighted/BurtConstraint.swift", "Weighted/WeightedCentrality.swift"

def ver(ident, old, new):
    return (f"V {ident} version {old} to {new}", S, f'identifier: "{ident}", version: {old},', f'identifier: "{ident}", version: {new},')
def ident(a, b, v):
    return (f"I {a} identifier to {b}", S, f'identifier: "{a}", version: {v},', f'identifier: "{b}", version: {v},')

MUTANTS = [
 # ---- versions and identifiers (the stored-record contract)
 ver("degree", 1, 2), ver("eigenvector-centrality", 4, 3), ver("pagerank", 2, 1), ver("pagerank", 2, 3),
 ver("betweenness-centrality", 1, 2), ver("closeness-centrality", 1, 2), ver("k-core", 1, 2),
 ver("louvain", 1, 2), ver("harmonic-centrality", 1, 2), ver("clustering", 1, 2), ver("components", 1, 2),
 ("V burt-constraint version 1 to 2", B, 'identifier: "burt-constraint", version: 1,', 'identifier: "burt-constraint", version: 2,'),
 ident("degree", "degrees", 1), ident("eigenvector-centrality", "eigenvector", 4), ident("pagerank", "page-rank", 2),
 ident("betweenness-centrality", "betweenness", 1), ident("closeness-centrality", "closeness", 1),
 ident("k-core", "kcore", 1), ident("louvain", "louvain-communities", 1), ident("harmonic-centrality", "harmonic", 1),
 ident("clustering", "clustering-coefficient", 1), ident("components", "connected-components", 1),
 ("I burt-constraint identifier to burt", B, 'identifier: "burt-constraint"', 'identifier: "burt"'),
 # ---- descriptor text
 ("D degree title changed", S, 'version: 1, title: "Degree",', 'version: 1, title: "Degrees",'),
 ("D k-core lowMeans loses its call-and-ask wording", S, "The outreach target.", "The target."),
 ("D descriptor interpretation of pagerank emptied", S, '"Who is connected to well-connected classmates. "\n\t\t\t\t+ "The measure to use for bringers."', '""'),
 # ---- eigenvector metric
 ("E01 default ceiling 200 to 100", S, "init(maxIterations: Int = 200,", "init(maxIterations: Int = 100,"),
 ("E02 default tolerance 1e-10 to 1e-9", S, "tolerance: Double = 1e-10) {", "tolerance: Double = 1e-9) {"),
 ("E03 reported ceiling max(1, n) to n", S, "maxIterations: max(1, maxIterations)))", "maxIterations: maxIterations))"),
 ("E04 reported tolerance fixed at 1e-10", S, "tolerance: tolerance, maxIterations: max(1", "tolerance: 1e-10, maxIterations: max(1"),
 ("E05 reported iterations is the ceiling", S, "iterations: run.iterations, converged:", "iterations: maxIterations, converged:"),
 ("E06 reported converged always true", S, "converged: run.converged, residual:", "converged: true, residual:"),
 ("E07 reported residual always zero", S, "residual: run.residual,\n", "residual: 0,\n"),
 ("E08 ceiling not passed to the iteration", S, "graph, maxIterations: maxIterations, tolerance: tolerance)", "graph, maxIterations: 200, tolerance: tolerance)"),
 ("E09 tolerance not passed to the iteration", S, "graph, maxIterations: maxIterations, tolerance: tolerance)", "graph, maxIterations: maxIterations, tolerance: 1e-10)"),
 ("E10 scores emptied", S, "scores: run.scores,", "scores: NodeScores([:]),"),
 # ---- wiring of each metric to its measure
 ("W01 pagerank wired to eigenvector", S, "Centrality.pageRank(graph)", "Centrality.eigenvector(graph)"),
 ("W02 pagerank at damping 0.9", S, "Centrality.pageRank(graph)", "Centrality.pageRank(graph, damping: 0.9)"),
 ("W03 betweenness unnormalised", S, "Centrality.betweenness(graph)", "Centrality.betweenness(graph, normalized: false)"),
 ("W04 closeness wired to harmonic", S, "Centrality.closeness(graph)", "Centrality.harmonic(graph)"),
 ("W05 harmonic wired to closeness", S, "Centrality.harmonic(graph)", "Centrality.closeness(graph)"),
 ("W06 clustering wired to degree", S, "Centrality.clustering(graph)", "Centrality.degree(graph)"),
 ("W07 k-core wired to degree", S, "Community.kCore(graph)", "Centrality.degree(graph)"),
 ("W08 louvain wired to components", S, "Community.louvain(graph)", "Community.connectedComponents(graph)"),
 ("W09 components wired to louvain", S, "Community.connectedComponents(graph)", "Community.louvain(graph)"),
 ("W10 degree wired to clustering", S, "Centrality.degree(graph)", "Centrality.clustering(graph)"),
 ("W11 burt wired to degree", B, "Brokerage.constraint(graph)\n\t}\n}\n", "Centrality.degree(graph)\n\t}\n}\n"),
 ("W12 louvain at resolution 2", S, "Community.louvain(graph)", "Community.louvain(graph, resolution: 2.0)"),
 ("W13 louvain with one pass", S, "Community.louvain(graph)", "Community.louvain(graph, maxPasses: 1)"),
 # ---- registry
 ("R01 first wins to last wins", R, "uniquingKeysWith: { first, _ in first }", "uniquingKeysWith: { _, last in last }"),
 ("R02 registering puts the new metric first", R, "MetricRegistry(Array(metrics.values) + [AnyGraphMetric(metric)])", "MetricRegistry([AnyGraphMetric(metric)] + Array(metrics.values))"),
 ("R03 available not sorted", R, "metrics.values.map(\\.descriptor).sorted { $0.identifier < $1.identifier }", "metrics.values.map(\\.descriptor)"),
 ("R04 available sorted descending", R, "$0.identifier < $1.identifier", "$0.identifier > $1.identifier"),
 ("R05 registering returns self", R, "MetricRegistry(Array(metrics.values) + [AnyGraphMetric(metric)])", "self"),
 ("R06 metric(for:) always nil", R, "\t\tmetrics[identifier]\n\t}", "\t\tnil\n\t}"),
 ("R07 record version bumped", R, "metricVersion: metric.descriptor.version,", "metricVersion: metric.descriptor.version + 1,"),
 ("R08 record clock ignored", R, "computedAt: now,", "computedAt: Date(timeIntervalSince1970: 0),"),
 ("R09 record uses the argument as the metric name (equivalent)", R, "metric: metric.descriptor.identifier,", "metric: identifier,"),
 ("R10 record output is a different metric's run", R, "output: try metric.compute(on: graph)", "output: try metrics[\"degree\"]?.compute(on: graph) ?? metric.compute(on: graph)"),
 ("R11 run swallows errors", R, "try metrics[identifier]?.compute(on: graph)\n", "try? metrics[identifier]?.compute(on: graph)\n"),
 ("R12 unknown record identifier gives a record anyway", R, "guard let metric = metrics[identifier] else { return nil }", "guard let metric = metrics[identifier] ?? metrics[\"degree\"] else { return nil }"),
 # ---- standard registry membership (one removed at a time)
] + [
 (f"M{i:02d} standard registry drops {name}", R, f"\t\t\tAnyGraphMetric({name}<Node>()),\n", "")
 for i, name in enumerate(["DegreeMetric", "EigenvectorMetric", "PageRankMetric", "BetweennessMetric", "ClosenessMetric",
                            "KCoreMetric", "LouvainMetric", "HarmonicMetric", "ClusteringMetric", "ComponentsMetric", "BurtConstraint"], 1)
] + [
 # ---- AnyGraphMetric and MetricRecord
 ("A01 erased descriptor version bumped", A, "self.descriptor = M.descriptor", "self.descriptor = MetricDescriptor(identifier: M.descriptor.identifier, version: M.descriptor.version + 1, title: M.descriptor.title, interpretation: M.descriptor.interpretation, highMeans: M.descriptor.highMeans, lowMeans: M.descriptor.lowMeans)"),
 ("A02 erased compute returns an empty envelope", A, "try MetricEnvelope(metric.compute(on: graph))", "MetricEnvelope(kind: \"scores\", payload: .null)"),
 ("Q01 record keeps no metric name", REC, "self.metric = metric", 'self.metric = ""'),
 ("Q02 record version fixed at 1", REC, "self.metricVersion = metricVersion", "self.metricVersion = 1"),
 ("Q03 record clock dropped", REC, "self.computedAt = computedAt", "self.computedAt = Date(timeIntervalSince1970: 0)"),
 ("Q04 record output kind lost", REC, "self.output = output", "self.output = MetricEnvelope(kind: output.kind, payload: .null)"),
 # ---- the measures underneath: the golden records must notice (cross-layer)
 ("G01 eigenvector shift halved", C, "let shift = 2 * graph.totalWeight / Double(count)", "let shift = graph.totalWeight / Double(count)"),
 ("G02 pagerank default damping 0.85 to 0.9", C, "damping: Double = 0.85,", "damping: Double = 0.9,"),
 ("G03 betweenness halving dropped", C, "if normalized, pairs > 0 { value /= (pairs / 2) }", "if normalized, pairs > 0 { value /= pairs }"),
 ("G04 closeness fraction dropped", C, "scores[graph.nodes[source]] = reachableFraction / meanDistance", "scores[graph.nodes[source]] = 1 / meanDistance"),
 ("G05 eigenvector L2 to L1 norm", C, "let norm = sqrt(next.reduce(0) { $0 + $1 * $1 })", "let norm = next.reduce(0) { $0 + abs($1) }"),
 ("G06 pagerank share not divided by degree", C, "let share = clampedDamping * current[index] / degree", "let share = clampedDamping * current[index]"),
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

def main():
    killed = survived = broken = 0
    for name, f, old, new in MUTANTS:
        if ONLY and ONLY not in name:
            continue
        path = SRC + f
        original = open(path).read()
        if original.count(old) != 1:
            print(f"{name}: PATTERN MISMATCH ({original.count(old)} matches)", flush=True)
            broken += 1
            continue
        open(path, "w").write(original.replace(old, new))
        try:
            status, out = run()
        finally:
            open(path, "w").write(original)
        detail = ""
        if status == "KILLED":
            failing = re.findall(r'Test "(.*?)" (?:with \d+ test cases )?(?:failed|recorded an issue)', out)
            detail = (failing[0] if failing else out[:80])[:90]
            killed += 1
        elif status == "SURVIVED":
            survived += 1
        else:
            broken += 1
            detail = " | ".join(l for l in out.splitlines() if "error:" in l)[:200]
        print(f"{name}: {status}  {detail}", flush=True)
    print(f"\nTOTAL {len(MUTANTS)}  killed {killed}  survived {survived}  not-counted {broken}")

main()
