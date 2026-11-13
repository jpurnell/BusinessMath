#!/usr/bin/env python3
"""Hand-written mutation check of the ported seed selection, sweep, SeedSweep codec, SiteAssignment
conformance and siting-from-scores (step 3, part 2).

Run:  python3 mutation-check.py [mutant-id ...]   (no ids = every mutant)

It works on a scratch copy of the code under test (see mutation-lab-sync.sh in this folder), never on the
repository: /private/tmp/claude-501/mutlab2 holds a small package whose module is also called BusinessMath
and which contains the diffusion, siting and metric-value sources, WeightedGraph (their one dependency) and
the ported tests, so a mutant compiles and runs quickly.

For each mutant: apply one textual change (asserted to match exactly once), build, run every ported suite,
and record KILLED (a test failed, the tests failed to build after a type-correct change, the process crashed
or hung) or SURVIVED. Survivors are classified by hand in the report.
"""
import subprocess, sys, time, re

import os
LAB = os.environ.get("MUT_LAB", "/private/tmp/claude-501/mutlab2")
SRC = LAB + "/Sources/BusinessMath/Network/"

M = []
def m(i, f, old, new, d): M.append((i, f, old, new, d))

SS = "Diffusion/SeedSelector.swift"
SA = "Siting/SiteAssignment.swift"
SP = "Siting/SiteProblem.swift"
GM = "Metrics/Protocol/GraphMetric.swift"

# ---- Validation and early exits (SeedSelector.makeEngine, select)
m("V1", SS, "guard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }", "guard trials > 1 else { throw DiffusionError.invalidTrialCount(trials) }", "one trial rejected")
m("V2", SS, "guard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }", "guard trials >= 0 else { throw DiffusionError.invalidTrialCount(trials) }", "zero trials accepted")
m("V3", SS, "guard budget >= 0 else { throw DiffusionError.invalidBudget(budget) }", "guard budget > 0 else { throw DiffusionError.invalidBudget(budget) }", "budget 0 rejected")
m("V4", SS, "guard budget >= 0 else { throw DiffusionError.invalidBudget(budget) }", "guard budget >= -1 else { throw DiffusionError.invalidBudget(budget) }", "budget -1 accepted")
m("V5", SS, "\t\tguard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }\n\t\tguard budget >= 0 else { throw DiffusionError.invalidBudget(budget) }", "\t\tguard budget >= 0 else { throw DiffusionError.invalidBudget(budget) }\n\t\tguard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }", "budget validated before trials")
m("V6", SS, "guard budget > 0, graph.nodeCount > 0 else { return nil }", "guard budget >= 0, graph.nodeCount > 0 else { return nil }", "budget 0 builds an engine (selects nothing either way)")
m("V7", SS, "guard budget > 0, graph.nodeCount > 0 else { return nil }", "guard budget > 0, graph.nodeCount >= 0 else { return nil }", "empty graph builds an engine (selects nothing either way)")
m("V8", SS, "\t\tguard trials > 0 else { return NodeSelection([]) }\n\t\tlet target", "\t\tguard trials > 1 else { return NodeSelection([]) }\n\t\tlet target", "select returns nothing for a single trial")
m("V9", SS, "let target = min(budget, n)", "let target = min(budget, n - 1)", "one pick short of every node")
m("V10", SS, "let target = min(budget, n)", "let target = budget", "budget above node count not clamped")

# ---- Common random numbers and totals
m("R1", SS, "self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }", "self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0 + 1) }", "trials numbered from 1")
m("R2", SS, "self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }", "self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed &+ UInt64($0), trial: 0) }", "streams keyed by seed plus trial, trial fixed")
m("R3", SS, "self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }", "self.randomness = (0..<max(1, trials - 1)).map { TrialRandomness(masterSeed: seed, trial: $0) }", "last trial dropped from the totals")
m("R4", SS, "sum += model.simulate(on: graph, seeds: seeds, randomness: trial)", "sum = model.simulate(on: graph, seeds: seeds, randomness: trial)", "only the last trial counted")
m("R5", SS, "range.map { total(of: [$0]) }", "range.map { total(of: [$0 + 1]) }", "first pass scores the next node")
m("R6", SS, "range.map { total(of: [$0]) }", "range.map { _ in total(of: []) }", "first pass scores the empty set")

# ---- Chunking and parallel collection (the result must not depend on it)
m("P1", SS, "let size = max(1, (n + wanted - 1) / wanted)", "let size = max(1, n / wanted)", "chunk size rounds down (output is chunk-independent)")
m("P2", SS, "ProcessInfo.processInfo.activeProcessorCount * 4)\n\t\tlet size", "ProcessInfo.processInfo.activeProcessorCount * 1)\n\t\tlet size", "fewer chunks (output is chunk-independent)")
m("P3", SS, "return stride(from: 0, to: n, by: size).map { $0..<min(n, $0 + size) }", "return stride(from: 0, to: n, by: size).map { $0..<min(n - 1, $0 + size) }", "last node never scored in the first pass")
m("P4", SS, "\t\tguard position >= 0, position < slots.count else { return }\n\t\tslots[position] = totals", "\t\tguard position >= 0, position < slots.count else { return }\n\t\tslots[0] = totals", "every chunk written to slot 0")
m("P5", SS, "for await (position, totals) in group { ordered[position] = totals }", "for await (position, totals) in group { ordered[0] = totals }", "async chunks all land in slot 0")
m("P6", SS, "return engine.select(firstPass: ordered.flatMap { $0 }, graph: graph)", "return engine.select(firstPass: ordered.reversed().flatMap { $0 }, graph: graph)", "async first pass in reverse chunk order")
m("P7", SS, "guard candidates.count > 1 else { return candidates.map { total(of: seeds + [$0]) } }", "guard candidates.count > 0 else { return candidates.map { total(of: seeds + [$0]) } }", "single candidate goes through the parallel path (output-equivalent)")
m("P8", SS, "collector.store([total(of: seeds + [candidates[position]])], at: position)", "collector.store([total(of: seeds)], at: position)", "refresh forgets the candidate")
m("P9", SS, "collector.store([total(of: seeds + [candidates[position]])], at: position)", "collector.store([total(of: seeds + [candidates[0]])], at: position)", "refresh scores the first candidate for every slot")

# ---- Lazy greedy: refresh logic, stale bounds, tie-breaks
m("G1", SS, "if round[best] == pick {", "if round[best] <= pick {", "stale bound accepted as fresh")
m("G2", SS, "if round[best] == pick {", "if round[best] != pick {", "freshness test inverted")
m("G3", SS, "var round = [Int](repeating: 0, count: n)", "var round = [Int](repeating: 1, count: n)", "first-pass gains look one round ahead")
m("G4", SS, "currentTotal += gain[best]", "currentTotal = gain[best]", "current total replaced, not accumulated")
m("G5", SS, "gain[candidate] = totals[position] - currentTotal", "gain[candidate] = totals[position]", "refreshed gain not net of the current total")
m("G6", SS, "gain[candidate] = totals[position] - currentTotal", "gain[candidate] = totals[position] - currentTotal - 1", "refreshed gain one too low")
m("G7", SS, "round[candidate] = pick\n", "round[candidate] = pick + 1\n", "refreshed candidate stamped with the next round")
m("G8", SS, "let stale = front.filter { round[$0] != pick }", "let stale = front", "fresh candidates refreshed again (wasted work, same values)")
m("G9", SS, "let stale = front.filter { round[$0] != pick }", "let stale = front.filter { round[$0] < pick - 1 }", "only candidates two rounds old refreshed")
m("G10", SS, "marginalGain: Double(gain[best]) / Double(trials)))", "marginalGain: Double(gain[best])))", "gain not divided by the trial count")
m("G11", SS, "marginalGain: Double(gain[best]) / Double(trials)))", "marginalGain: Double(gain[best]) / Double(trials + 1)))", "gain divided by trials + 1")
m("G12", SS, "node: source.nodes[best], marginalGain", "node: source.nodes[min(best + 1, n - 1)], marginalGain", "node label off by one")
m("G13", SS, "seeds.append(best)\n", "seeds.append(best)\n\t\t\t\t\tseeds.append(best)\n", "seed recorded twice (cascade seeds are a set)")
m("G14", SS, "chosen[best] = true", "chosen[best] = false", "chosen node stays eligible")
m("G15", SS, "for _ in 0...n {", "for _ in 0..<n {", "refresh loop one pass shorter (still enough passes)")
m("G16", SS, "for _ in 0...n {", "for _ in 0..<1 {", "refresh loop limited to a single pass")
m("G17", SS, "let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 < $1 }", "let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] < gain[$1] : $0 < $1 }", "lowest gain first")
m("G18", SS, "let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 < $1 }", "let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 > $1 }", "ties go to the higher index")
m("G19", SS, "let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 < $1 }", "let ordered = open.sorted { gain[$0] >= gain[$1] }", "ties by an unstable comparison (>=)")
m("G20", SS, "let open = (0..<gain.count).filter { !chosen[$0] }", "let open = Array(0..<gain.count)", "chosen nodes eligible again")
m("G21", SS, "return Array(ordered.prefix(count))", "return Array(ordered.prefix(count + 1))", "front one wider than the batch (output-equivalent)")
m("G22", SS, "return Array(ordered.prefix(count))", "return Array(ordered.prefix(max(1, count - 1)))", "front one narrower than the batch")

# ---- The submodularity gate (ADR-005) and refresh batching
m("B1", SS, "guard model.hasSubmodularTrials else { return max(1, graph.nodeCount) }", "guard model.hasSubmodularTrials else { return 1 }", "undeclared model refreshed one at a time")
m("B2", SS, "guard model.hasSubmodularTrials else { return max(1, graph.nodeCount) }", "guard !model.hasSubmodularTrials else { return max(1, graph.nodeCount) }", "gate inverted")
m("B3", SS, "guard model.hasSubmodularTrials else { return max(1, graph.nodeCount) }", "guard true else { return max(1, graph.nodeCount) }", "gate removed: every model lazy")
m("B4", SS, "guard model.hasSubmodularTrials else { return max(1, graph.nodeCount) }", "guard model.hasSubmodularTrials else { return max(1, graph.nodeCount - 1) }", "undeclared batch one short of every node (output-equivalent)")
m("B5", SS, "return max(1, refreshBatch ?? ProcessInfo.processInfo.activeProcessorCount)", "return max(1, refreshBatch ?? 1)", "default batch is one, not one per core (output-equivalent)")
m("B6", SS, "return max(1, refreshBatch ?? ProcessInfo.processInfo.activeProcessorCount)", "return max(1, ProcessInfo.processInfo.activeProcessorCount)", "the batch override is ignored")
m("B7", SS, "return max(1, refreshBatch ?? ProcessInfo.processInfo.activeProcessorCount)", "return max(2, refreshBatch ?? ProcessInfo.processInfo.activeProcessorCount)", "batch of at least two")
m("B8", SS, "self.init(model: model, budget: budget, trials: trials, seed: seed, lazyRefreshBatch: nil)", "self.init(model: model, budget: budget, trials: trials, seed: seed, lazyRefreshBatch: 1)", "public init is as lazy as possible (output-equivalent)")
m("B9", SS, "self.lazyRefreshBatch = lazyRefreshBatch\n", "self.lazyRefreshBatch = nil\n", "internal batch override dropped")

# ---- Sweep
m("W1", SS, "guard !probabilities.isEmpty else { throw DiffusionError.emptySweep }", "guard probabilities.count > 1 else { throw DiffusionError.emptySweep }", "a one-point sweep refused")
m("W2", SS, "guard !probabilities.isEmpty else { throw DiffusionError.emptySweep }", "guard true else { throw DiffusionError.emptySweep }", "an empty sweep accepted")
m("W3", SS, "model: try model(probability), budget: budget, trials: trials, seed: seed)", "model: try model(probability), budget: budget, trials: trials, seed: seed &+ UInt64(points.count))", "each sweep point uses a different master seed")
m("W4", SS, "model: try model(probability), budget: budget, trials: trials, seed: seed)", "model: try model(probabilities[0]), budget: budget, trials: trials, seed: seed)", "every point built with the first probability")
m("W5", SS, "SweepPoint(probability: probability, selection: try selector.compute(on: graph)))", "SweepPoint(probability: probability / 2, selection: try selector.compute(on: graph)))", "recorded probability halved")
m("W6", SS, "for probability in probabilities {\n\t\t\tlet selector", "for probability in probabilities.reversed() {\n\t\t\tlet selector", "points in reverse order")
m("W7", SS, "model: @Sendable (Double) throws -> any DiffusionModel = { try IndependentCascade(probability: $0) }", "model: @Sendable (Double) throws -> any DiffusionModel = { try IndependentCascade(weightScaledProbability: $0) }", "default builder is the weight-scaled cascade")
m("W8", SS, "model: @Sendable (Double) throws -> any DiffusionModel = { try IndependentCascade(probability: $0) }", "model: @Sendable (Double) throws -> any DiffusionModel = { _ in LinearThreshold() }", "default builder ignores the probability")

# ---- SeedSweep summary
m("J1", SS, "let denominator = Double(max(1, results.count))", "let denominator = Double(results.count + 1)", "frequency denominator is points + 1")
m("J2", SS, "let denominator = Double(max(1, results.count))", "let denominator = Double(max(1, results.count - 1))", "frequency denominator is points - 1")
m("J3", SS, "for set in sets { for node in set { counts[node, default: 0] += 1 } }", "for set in sets { for node in set { counts[node, default: 0] += 2 } }", "frequency counts doubled")
m("J4", SS, "let sets = results.map { Set($0.selection.nodes) }", "let sets = results.map { Set($0.selection.nodes.prefix(1)) }", "only the first pick of each point compared")
m("J5", SS, "repeating: [Double](repeating: 1.0, count: sets.count), count: sets.count)", "repeating: [Double](repeating: 0.0, count: sets.count), count: sets.count)", "diagonal 0, not 1")
m("J6", SS, "for j in (i + 1)..<max(i + 1, sets.count) {", "for j in i..<max(i + 1, sets.count) {", "pairs include each point with itself")
m("J7", SS, "matrix[j][i] = overlap\n", "", "matrix not symmetric")
m("J8", SS, "matrix[i][j] = overlap\n", "", "upper triangle not filled")
m("J9", SS, "total += overlap\n", "total += 1.0\n", "mean counts every pair as identical")
m("J10", SS, "pairs += 1\n", "pairs += 2\n", "pair count doubled")
m("J11", SS, "self.meanPairwiseJaccard = pairs > 0 ? total / Double(pairs) : 1.0", "self.meanPairwiseJaccard = pairs > 0 ? total / Double(pairs) : 0.0", "a single point reports 0, not 1")
m("J12", SS, "self.meanPairwiseJaccard = pairs > 0 ? total / Double(pairs) : 1.0", "self.meanPairwiseJaccard = pairs > 1 ? total / Double(pairs) : 1.0", "two points (one pair) report 1")
m("J13", SS, "guard union > 0 else { return 1.0 }", "guard union > 0 else { return 0.0 }", "two empty sets are disjoint")
m("J14", SS, "guard union > 0 else { return 1.0 }", "guard union > 1 else { return 1.0 }", "a union of one node counts as identical")
m("J15", SS, "return Double(a.intersection(b).count) / Double(union)", "return Double(a.intersection(b).count) / Double(a.count)", "overlap over the first set, not the union")
m("J16", SS, "return Double(a.intersection(b).count) / Double(union)", "return Double(a.symmetricDifference(b).count) / Double(union)", "symmetric difference over the union")
m("J17", SS, "let union = a.union(b).count", "let union = a.count + b.count", "union counted with multiplicity")
m("J18", SS, "topKFrequency.filter { $0.value >= 1.0 }.keys.sorted()", "topKFrequency.filter { $0.value > 1.0 }.keys.sorted()", "always-picked needs more than every point")
m("J19", SS, "topKFrequency.filter { $0.value >= 1.0 }.keys.sorted()", "topKFrequency.filter { $0.value >= 0.5 }.keys.sorted()", "always-picked means at least half")
m("J20", SS, "topKFrequency.filter { $0.value >= 1.0 }.keys.sorted()", "topKFrequency.filter { $0.value >= 1.0 }.keys.sorted(by: >)", "always-picked in descending node order")
m("J21", SS, "topKFrequency.filter { $0.value >= 1.0 }.keys.sorted()", "Array(topKFrequency.filter { $0.value >= 1.0 }.keys)", "always-picked unsorted")

# ---- SeedSweep codec and kind strings
m("K1", SS, "private enum CodingKeys: String, CodingKey { case results }", "private enum CodingKeys: String, CodingKey { case results = \"points\" }", "stored key renamed")
m("K2", SS, "try container.encode(results, forKey: .results)", "try container.encode(results.reversed(), forKey: .results)", "points encoded in reverse")
m("K3", SS, "self.init(results: try container.decode([SweepPoint<Node>].self, forKey: .results))", "self.init(results: Array(try container.decode([SweepPoint<Node>].self, forKey: .results).dropFirst()))", "first point lost on decode")
m("K4", SS, "public static var kind: String { \"seed-sweep\" }", "public static var kind: String { \"seed_sweep\" }", "kind string altered")
m("K5", SS, "public static var kind: String { \"seed-sweep\" }", "public static var kind: String { \"sweep\" }", "kind string shortened")
m("K6", SA, "public static var kind: String { \"site-assignment\" }", "public static var kind: String { \"site_assignment\" }", "SiteAssignment kind altered")
m("K7", SA, "public static var kind: String { \"site-assignment\" }", "public static var kind: String { \"selection\" }", "SiteAssignment filed under another shape's kind")

# ---- Descriptor
m("D1", SS, "identifier: \"seed-selection\", version: 1, title: \"Seed Selection\",", "identifier: \"seed_selection\", version: 1, title: \"Seed Selection\",", "descriptor identifier altered")
m("D2", SS, "identifier: \"seed-selection\", version: 1, title: \"Seed Selection\",", "identifier: \"seed-selection\", version: 2, title: \"Seed Selection\",", "descriptor version bumped")
m("D3", SS, "identifier: \"seed-selection\", version: 1, title: \"Seed Selection\",", "identifier: \"seed-selection\", version: 1, title: \"Seed selection\",", "descriptor title re-cased")
m("D4", SS, "interpretation: \"EXPLORATORY. Which few nodes", "interpretation: \"Which few nodes", "the EXPLORATORY label dropped")
m("D5", SS, "\"always gain less than earlier ones.\"", "\"always gain more than earlier ones.\"", "lowMeans states the opposite")
m("D6", GM, "public var descriptor: MetricDescriptor { Self.descriptor }", "public var descriptor: MetricDescriptor { MetricDescriptor(identifier: \"\", version: 0, title: \"\", interpretation: \"\", highMeans: \"\", lowMeans: \"\") }", "instance descriptor is empty")

# ---- Siting from NodeScores
m("N1", SP, "try self.init(demand: scores.scores, sites: sites, cost: cost)", "try self.init(demand: scores.scores.mapValues { $0 * 2 }, sites: sites, cost: cost)", "scores doubled into weights")
m("N2", SP, "try self.init(demand: scores.scores, sites: sites, cost: cost)", "try self.init(demand: scores.scores, sites: sites.reversed(), cost: cost)", "sites reversed")
m("N3", SP, "try self.init(demand: scores.scores, sites: sites, cost: cost)", "try self.init(demand: scores.scores, sites: sites, cost: { demand, site in cost(demand, site) + 1 })", "cost shifted by one")
m("N4", SP, "try self.init(demand: scores.scores, sites: sites, cost: cost)", "try self.init(demand: scores.scores.filter { $0.value > 0 }, sites: sites, cost: cost)", "zero-weight demand points dropped (a score of zero)")
m("N5", SP, "try self.init(demand: scores.scores, sites: sites, cost: cost)", "try self.init(demand: scores.scores.mapValues { max(0, $0) }, sites: sites, cost: cost)", "negative scores clipped (validation bypassed)")

# ---- SiteAssignment conformance: the Codable shape must not change
m("A1", SA, "\t\tpublic let site: Site\n\t\t/// The cost per unit of demand.", "\t\tpublic let site: Site\n\t\t/// The cost per unit of demand.\n\t\tprivate enum CodingKeys: String, CodingKey { case demand, site = \"location\", cost, weight }\n\t\t/// (mutant)", "assignment's site key renamed")

def run(cmd, timeout):
    try:
        p = subprocess.run(cmd, cwd=LAB, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr, False
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        return -9, out, True

def main():
    ids = sys.argv[1:]
    chosen = [x for x in M if not ids or x[0] in ids]
    results = []
    for (i, f, old, new, d) in chosen:
        path = SRC + f
        original = open(path).read()
        if original.count(old) != 1:
            print(f"{i}: PATTERN MATCHED {original.count(old)} TIMES, skipped: {d}", flush=True)
            results.append((i, "INVALID", d, ""))
            continue
        open(path, "w").write(original.replace(old, new))
        t0 = time.time()
        try:
            rc, out, to = run(["swift", "build", "--build-tests"], 900)
            if rc != 0:
                results.append((i, "BUILD-ERROR", d, ""))
                print(f"{i}: BUILD ERROR (invalid mutant): {d}", flush=True)
                continue
            rc, out, to = run(["swift", "test", "--skip-build"], 420)
            failed = sorted(set(re.findall(r'Test "([^"]*)"[^\n]*recorded an issue', out)))
            if to:
                status, note = "KILLED", "hang (timeout)"
            elif "Fatal error" in out or "unexpected signal" in out or "exited with" in out:
                status, note = "KILLED", "crash; " + "; ".join(failed[:3])
            elif rc != 0 or failed:
                status, note = "KILLED", "; ".join(failed[:4]) + (f" (+{len(failed)-4} more)" if len(failed) > 4 else "")
            else:
                status, note = "SURVIVED", ""
            results.append((i, status, d, note))
            print(f"{i}: {status} [{time.time()-t0:.0f}s] {d} -- {note}", flush=True)
        finally:
            open(path, "w").write(original)
    ks = sum(1 for r in results if r[1] == "KILLED")
    sv = [r for r in results if r[1] == "SURVIVED"]
    inv = [r for r in results if r[1] in ("INVALID", "BUILD-ERROR")]
    print(f"\nTOTAL {len(results)}  KILLED {ks}  SURVIVED {len(sv)}  INVALID/BUILD-ERROR {len(inv)}")
    for r in sv: print("SURVIVOR", r[0], r[2])
    for r in inv: print("INVALID", r[0], r[2])

if __name__ == "__main__":
    main()
