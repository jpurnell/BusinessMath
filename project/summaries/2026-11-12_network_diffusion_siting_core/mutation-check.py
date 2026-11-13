#!/usr/bin/env python3
"""Hand-written mutation check of the ported diffusion and siting code.

Run from anywhere:  python3 mutation-check.py [mutant-id ...]   (no ids = every mutant)

It works on a scratch copy of the code under test (see sync.sh in this folder), never on the
repository: /private/tmp/claude-501/mutlab holds a small package whose module is also called
BusinessMath and which contains only the diffusion and siting sources, WeightedGraph (their one
dependency) and the ported tests, so a mutant compiles and runs in seconds.

For each mutant: apply one textual change (asserted to match exactly once), build, run every
ported suite, and record KILLED (a test failed, the build of the tests failed after a type-correct
change, the process crashed or hung) or SURVIVED. Survivors are classified by hand in the report.
"""
import subprocess, sys, os, shutil, time, re

LAB = "/private/tmp/claude-501/mutlab"
SRC = LAB + "/Sources/BusinessMath/Network/"
T = "\t"

# (id, file, old, new, description)
M = []
def m(i, f, old, new, d): M.append((i, f, old, new, d))

TR = "Diffusion/TrialRandomness.swift"
DM = "Diffusion/DiffusionModel.swift"
SE = "Diffusion/SpreadEstimator.swift"
DG = "Diffusion/DiffusionGraph.swift"
SP = "Siting/SiteProblem.swift"
PM = "Siting/PMedian.swift"
SA = "Siting/SiteAssignment.swift"

# ---- TrialRandomness: stream derivation and draw mapping
m("T1", TR, "masterSeed &+ UInt64(truncatingIfNeeded: trial) &* Self.goldenRatioIncrement)", "masterSeed &+ UInt64(truncatingIfNeeded: trial))", "trial not scaled by the golden-ratio increment: neighbouring (seed, trial) pairs collide")
m("T2", TR, "masterSeed &+ UInt64(truncatingIfNeeded: trial) &* Self.goldenRatioIncrement)", "masterSeed ^ UInt64(truncatingIfNeeded: trial) &* Self.goldenRatioIncrement)", "seed combined with xor instead of addition")
m("T3", TR, "return draw(salt: 0x1, slot: slot)", "return draw(salt: 0x2, slot: slot)", "edge draws share the node salt")
m("T4", TR, "UInt64(truncatingIfNeeded: from) << 32)", "UInt64(truncatingIfNeeded: from) << 31)", "edge packing shifts by 31 instead of 32")
m("T5", TR, "& 0xFFFF_FFFF)", "& 0xFFFF)", "target index masked to 16 bits")
m("T6", TR, "generator.next() >> 11) * 0x1p-53", "generator.next() >> 12) * 0x1p-53", "draw uses 52 bits: range [0, 1/2)")
m("T7", TR, "* 0x1p-53", "* 0x1p-52", "draw scaled to [0, 2)")
m("T8", TR, "(key ^ (salt &* 0xD6E8_FEB8_6659_FD93))", "(key &+ (salt &* 0xD6E8_FEB8_6659_FD93))", "key combined with salt by addition instead of xor")
m("T9", TR, "&+ (slot &* Self.goldenRatioIncrement))", "&+ slot)", "slot not scaled by the golden-ratio increment")
m("T10", TR, "self.key = generator.next()", "_ = generator.next()\n\t\tself.key = generator.next()", "trial key is the second output of the generator, not the first")

# ---- Cascade support and independent cascade
m("C1", DM, "for seed in seeds where seed >= 0 && seed < nodeCount && !active[seed] {", "for seed in seeds where seed > 0 && seed < nodeCount && !active[seed] {", "seed 0 is not a valid seed")
m("C2", DM, "for seed in seeds where seed >= 0 && seed < nodeCount && !active[seed] {", "for seed in seeds where seed >= 0 && seed <= nodeCount && !active[seed] {", "seed == nodeCount accepted")
m("C3", DM, "for seed in seeds where seed >= 0 && seed < nodeCount && !active[seed] {", "for seed in seeds where seed >= 0 && seed < nodeCount {", "duplicate seeds counted twice")
m("C4", DM, "guard randomness.uniform(from: source, to: target) < probability else { continue }", "guard randomness.uniform(from: source, to: target) <= probability else { continue }", "draw <= p instead of draw < p")
m("C5", DM, "guard randomness.uniform(from: source, to: target) < probability else { continue }", "guard randomness.uniform(from: target, to: source) < probability else { continue }", "edge draw taken in the reverse direction")
m("C6", DM, "guard randomness.uniform(from: source, to: target) < probability else { continue }", "guard randomness.uniform(forNode: target) < probability else { continue }", "node draw used for an edge")
m("C7", DM, "\t\t\t\tguard !active[target] else { continue }\n\t\t\t\tlet probability", "\t\t\t\tlet probability", "cascade may re-activate an active node")
m("C8", DM, "min(1, base * graph.weights[slot] * scale)", "base * graph.weights[slot] * scale", "weight-scaled probability not capped at 1")
m("C9", DM, "scale = graph.maxWeight > 0 ? 1 / graph.maxWeight : 0", "scale = graph.maxWeight > 0 ? graph.maxWeight : 0", "scale is maxWeight, not its reciprocal")
m("C10", DM, "scale = graph.maxWeight > 0 ? 1 / graph.maxWeight : 0", "scale = graph.maxWeight > 0 ? 1 / graph.maxWeight : 1", "scale 1 when no edge has weight")
m("C11", DM, "\t\tguard n > 0 else { return 0 }\n\t\tvar active = [Bool](repeating: false, count: n)\n\t\tvar queue = CascadeSupport.activate(seeds: seeds, nodeCount: n, active: &active)\n\n\t\t// Probability", "\t\tguard n > 1 else { return 0 }\n\t\tvar active = [Bool](repeating: false, count: n)\n\t\tvar queue = CascadeSupport.activate(seeds: seeds, nodeCount: n, active: &active)\n\n\t\t// Probability", "a one-node graph is skipped by the cascade")
m("C12", DM, "\t\tfor head in 0..<n {\n\t\t\tguard head < queue.count else { break }\n\t\t\tlet source = queue[head]\n\t\t\tfor slot in graph.offsets[source]..<graph.offsets[source + 1] {\n\t\t\t\tlet target = graph.targets[slot]\n\t\t\t\tguard !active[target] else { continue }\n\t\t\t\tlet probability", "\t\tfor head in 0..<(n - 1) {\n\t\t\tguard head < queue.count else { break }\n\t\t\tlet source = queue[head]\n\t\t\tfor slot in graph.offsets[source]..<graph.offsets[source + 1] {\n\t\t\t\tlet target = graph.targets[slot]\n\t\t\t\tguard !active[target] else { continue }\n\t\t\t\tlet probability", "cascade queue walk stops one position early")
m("C13", DM, "guard p.isFinite, p >= 0, p <= 1 else", "guard p >= 0, p <= 1 else", "isFinite check removed from probability validation")
m("C14", DM, "guard p.isFinite, p >= 0, p <= 1 else", "guard p.isFinite, p > 0, p <= 1 else", "probability 0 rejected")
m("C15", DM, "guard p.isFinite, p >= 0, p <= 1 else", "guard p.isFinite, p >= 0, p < 1 else", "probability 1 rejected")
m("C16", DM, "public var hasSubmodularTrials: Bool { true }", "public var hasSubmodularTrials: Bool { false }", "IndependentCascade stops declaring submodular trials")
m("C17", DM, "extension DiffusionModel {\n\n\t/// `false`: assume nothing, so seed selection stays exactly greedy.\n\tpublic var hasSubmodularTrials: Bool { false }", "extension DiffusionModel {\n\n\t/// `false`: assume nothing, so seed selection stays exactly greedy.\n\tpublic var hasSubmodularTrials: Bool { true }", "protocol default becomes true")
m("C18", DM, "let randomness = TrialRandomness(masterSeed: rng.next(), trial: 0)", "let randomness = TrialRandomness(masterSeed: rng.next(), trial: 1)", "generator overload uses trial 1")
m("C19", DM, "let randomness = TrialRandomness(masterSeed: rng.next(), trial: 0)", "let randomness = TrialRandomness(masterSeed: 0, trial: 0)", "generator overload ignores the generator")

# ---- Linear threshold
m("L1", DM, "guard influence[target] + 1e-12 >= randomness.uniform(forNode: target) else { continue }", "guard influence[target] + 1e-9 >= randomness.uniform(forNode: target) else { continue }", "tolerance 1e-9")
m("L2", DM, "guard influence[target] + 1e-12 >= randomness.uniform(forNode: target) else { continue }", "guard influence[target] - 1e-12 >= randomness.uniform(forNode: target) else { continue }", "tolerance sign flipped")
m("L3", DM, "guard influence[target] + 1e-12 >= randomness.uniform(forNode: target) else { continue }", "guard influence[target] + 1e-12 > randomness.uniform(forNode: target) else { continue }", "threshold comparison strict")
m("L4", DM, "guard influence[target] + 1e-12 >= randomness.uniform(forNode: target) else { continue }", "guard influence[target] + 1e-12 >= randomness.uniform(forNode: source) else { continue }", "threshold drawn for the source node")
m("L5", DM, "influence[target] += graph.weights[slot] / degree", "influence[target] += 1 / degree", "share ignores the edge weight")
m("L6", DM, "influence[target] += graph.weights[slot] / degree", "influence[target] += graph.weights[slot]", "share not divided by weighted degree")
m("L7", DM, "\t\t\t\tguard !active[target] else { continue }\n\t\t\t\tlet degree", "\t\t\t\tlet degree", "linear threshold may re-activate an active node")
m("L8", DM, "\t\t\t\tguard degree > 0 else { continue }\n", "", "zero-degree guard removed")
m("L9", DM, "\t\tguard n > 0 else { return 0 }\n\t\tvar active = [Bool](repeating: false, count: n)\n\t\tvar influence", "\t\tguard n > 1 else { return 0 }\n\t\tvar active = [Bool](repeating: false, count: n)\n\t\tvar influence", "a one-node graph is skipped by the threshold model")

# ---- SpreadEstimator
m("E1", SE, "guard trials >= 1 else", "guard trials >= 0 else", "zero trials accepted")
m("E2", SE, "guard trials >= 1 else", "guard trials > 1 else", "one trial rejected")
m("E3", SE, "for trial in 0..<trials {", "for trial in 0..<(trials - 1) {", "last trial skipped")
m("E4", SE, "randomness: TrialRandomness(masterSeed: seed, trial: trial))", "randomness: TrialRandomness(masterSeed: seed, trial: trial + 1))", "trials indexed from one")
m("E5", SE, "sumOfSquares += count * count", "sumOfSquares += count", "sum of squares uses the count")
m("E6", SE, "guard trials > 0 else { return SpreadEstimate(mean: 0, standardError: 0, trials: 0) }", "guard trials >= 0 else { return SpreadEstimate(mean: 0, standardError: 0, trials: 0) }", "zero-trial guard weakened")
m("E7", SE, "guard trials > 1 else { return SpreadEstimate(mean: mean, standardError: 0, trials: trials) }", "guard trials > 2 else { return SpreadEstimate(mean: mean, standardError: 0, trials: trials) }", "two trials report zero error")
m("E8", SE, "Double(trials * sumOfSquares - sum * sum)", "Double(trials * sumOfSquares + sum * sum)", "variance numerator sign")
m("E9", SE, "numerator / (n * (n - 1))", "numerator / (n * n)", "population variance instead of sample variance")
m("E10", SE, "(variance / n).squareRoot()", "variance.squareRoot()", "standard deviation instead of standard error")
m("E11", SE, "let variance = numerator > 0 ? numerator / (n * (n - 1)) : 0", "let variance = numerator >= 0 ? numerator / (n * (n - 1)) : 0", "non-strict sign test on the numerator")

# ---- DiffusionGraph
m("G1", DG, "largest = max(largest, edge.weight)", "largest = min(largest, edge.weight)", "maxWeight takes the minimum")
m("G2", DG, "degrees[node] += edge.weight", "degrees[node] += 1", "weighted degree counts edges")
m("G3", DG, "offsets[node + 1] = targets.count", "offsets[node + 1] = targets.count + 1", "offsets shifted")
m("G4", DG, "guard node >= 0, node < nodeCount else { return [] }", "guard node > 0, node < nodeCount else { return [] }", "node 0 has no neighbours")
m("G5", DG, "guard node >= 0, node < nodeCount else { return [] }", "guard node >= 0, node <= nodeCount else { return [] }", "node == nodeCount reads past the offsets")
m("G6", DG, "weights.append(edge.weight)", "weights.append(1)", "weights flattened to one")

# ---- SiteProblem
m("S1", SP, "guard weight.isFinite, weight >= 0 else", "guard weight.isFinite, weight > 0 else", "zero demand weight rejected")
m("S2", SP, "guard weight.isFinite, weight >= 0 else", "guard weight >= 0 else", "non-finite demand weight accepted")
m("S3", SP, "guard total > 0 else { throw SiteError.noPositiveWeight }", "guard total >= 0 else { throw SiteError.noPositiveWeight }", "all-zero demand accepted")
m("S4", SP, "guard !sites.isEmpty else { throw SiteError.noCandidateSites }", "guard sites.count >= 0 else { throw SiteError.noCandidateSites }", "no candidate sites accepted")
m("S5", SP, "guard seen.insert(site).inserted else {", "guard seen.insert(site).inserted || true else {", "duplicate sites accepted")
m("S6", SP, "guard value.isFinite, value >= 0 else {", "guard value.isFinite, value > 0 else {", "zero cost rejected")
m("S7", SP, "guard value.isFinite, value >= 0 else {", "guard value >= 0 else {", "infinite cost accepted")
m("S8", SP, "total += weight * (try validatedCost(point, site))", "total += (try validatedCost(point, site))", "cost not weighted")
m("S9", SP, "return try weightedCost(at: site) / weight", "return try weightedCost(at: site)", "mean cost not divided by weight")
m("S10", SP, "guard !demand.isEmpty else { throw SiteError.noDemand }", "guard demand.count >= 0 else { throw SiteError.noDemand }", "empty demand accepted")

# ---- PMedian
m("P1", PM, "guard count >= 1, count <= available else {", "guard count >= 0, count <= available else {", "count 0 accepted")
m("P2", PM, "guard count >= 1, count <= available else {", "guard count >= 1, count < available else {", "count equal to the site count rejected")
m("P3", PM, "let sites = problem.sites.sorted()", "let sites = problem.sites", "candidate order not normalised")
m("P4", PM, "total += weights[d] * best", "total += best", "objective ignores the demand weights")
m("P5", PM, "for s in subset where cost[d][s] < best { best = cost[d][s] }", "for s in subset where cost[d][s] <= best { best = cost[d][s] }", "non-strict minimum")
m("P6", PM, "let exact = Self.subsetCount(available, count, cap: enumerationLimit) <= enumerationLimit", "let exact = Self.subsetCount(available, count, cap: enumerationLimit) < enumerationLimit", "exact decision strict at the limit")
m("P7", PM, "if value > cap { return cap + 1 }", "if value > cap { return cap }", "saturation returns cap, not cap + 1")
m("P8", PM, "let r = min(k, n - k)", "let r = k", "binomial not folded to the smaller side")
m("P9", PM, "guard !overflow else { return Int.max }", "guard !overflow || true else { return Int.max }", "overflow ignored")
m("P10", PM, "guard r >= 0 else { return 0 }", "guard r >= -1 else { return 0 }", "k above n not reported as zero subsets")
m("P11", PM, "for _ in 1..<max(1, subsets) {", "for _ in 1..<max(1, subsets - 1) {", "last subset never visited")
m("P12", PM, "for _ in 1..<max(1, subsets) {", "for _ in 0..<max(1, subsets) {", "one extra enumeration step")
m("P13", PM, "if value < bestValue {\n\t\t\t\tbestValue = value\n\t\t\t\tbest = current", "if value <= bestValue {\n\t\t\t\tbestValue = value\n\t\t\t\tbest = current", "enumeration keeps the last of equal subsets")
m("P14", PM, "for j in (i + 1)..<max(i + 1, k) { current[j] = current[j - 1] + 1 }", "for j in (i + 1)..<max(i + 1, k) { current[j] = current[j - 1] + 2 }", "successor subset skips sites")
m("P15", PM, "while i >= 0 && current[i] == n - k + i { i -= 1 }", "while i >= 0 && current[i] >= n - k + i { i -= 1 }", "successor test non-strict (>= for ==)")
m("P16", PM, "for s in 0..<n where !chosen.contains(s) {\n\t\t\t\tlet value = objective(chosen + [s])\n\t\t\t\tif value < bestValue {", "for s in 0..<n where !chosen.contains(s) {\n\t\t\t\tlet value = objective(chosen + [s])\n\t\t\t\tif value <= bestValue {", "greedy ties go to the highest index")
m("P17", PM, "for s in 0..<n where !chosen.contains(s) {\n\t\t\t\tlet value = objective(chosen + [s])", "for s in 0..<n {\n\t\t\t\tlet value = objective(chosen + [s])", "greedy may pick a chosen site again")
m("P18", PM, "guard bestSite >= 0 else { break }", "guard bestSite >= -1 else { break }", "greedy appends a missing site")
m("P19", PM, "if value < bestValue - 1e-12 * max(1, abs(current)) {", "if value < bestValue - 1e-9 * max(1, abs(current)) {", "swap tolerance 1e-9")
m("P20", PM, "if value < bestValue - 1e-12 * max(1, abs(current)) {", "if value < bestValue - 1e-12 * max(0, abs(current)) {", "swap tolerance without the floor of 1")
m("P21", PM, "if value < bestValue - 1e-12 * max(1, abs(current)) {", "if value <= bestValue - 1e-12 * max(1, abs(current)) {", "swap acceptance non-strict")
m("P22", PM, "if value < bestValue - 1e-12 * max(1, abs(current)) {", "if value < bestValue - 1e-12 * max(1, abs(bestValue)) {", "tolerance scaled by the candidate, not the current value")
m("P23", PM, "current = bestValue\n\t\t}\n\t\treturn chosen", "}\n\t\treturn chosen", "current objective never updated after a swap")
m("P24", PM, "static let maxSwapPasses = 10_000", "static let maxSwapPasses = 1", "one swap pass only")
m("P25", PM, "for position in chosen.indices {\n\t\t\t\tfor s in 0..<n where !chosen.contains(s) {", "for position in chosen.indices.prefix(1) {\n\t\t\t\tfor s in 0..<n where !chosen.contains(s) {", "only the first position is swapped")
m("P26", PM, "for position in chosen.indices {\n\t\t\t\tfor s in 0..<n where !chosen.contains(s) {", "for position in chosen.indices {\n\t\t\t\tfor s in 0..<n {", "swap may bring in a chosen site")
m("P27", PM, "for s in chosenSorted where cost[d][s] < cost[d][bestSite] { bestSite = s }", "for s in chosenSorted where cost[d][s] <= cost[d][bestSite] { bestSite = s }", "assignment ties go to the later site")
m("P28", PM, "chosen: (exact ? chosenSorted : picked).map { sites[$0] },", "chosen: picked.map { sites[$0] },", "exact result not re-sorted")
m("P29", PM, "chosen: (exact ? chosenSorted : picked).map { sites[$0] },", "chosen: chosenSorted.map { sites[$0] },", "heuristic result sorted, losing pick order")
m("P30", PM, "self.enumerationLimit = max(0, enumerationLimit)", "self.enumerationLimit = enumerationLimit", "negative limit kept")
m("P31", PM, "public static let defaultEnumerationLimit = 200_000", "public static let defaultEnumerationLimit = 200_001", "default limit changed")

# ---- SiteAssignment
m("A1", SA, "total += item.weight * item.cost", "total += item.cost", "total ignores weights")
m("A2", SA, "self.meanWeightedCost = weightSum > 0 ? total / weightSum : 0", "self.meanWeightedCost = weightSum >= 0 ? total / weightSum : 0", "zero-weight mean is NaN")
m("A3", SA, "let sorted = assignments.sorted { $0.demand < $1.demand }", "let sorted = assignments", "assignments not sorted by demand")
m("A4", SA, ".sorted { $0.site < $1.site }", ".sorted { $0.site > $1.site }", "loads sorted descending")
m("A5", SA, "loadBySite[item.site, default: 0] += item.weight", "loadBySite[item.site, default: 0] += item.cost", "loads sum costs")

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
            print(f"{i}: PATTERN MATCHED {original.count(old)} TIMES, skipped: {d}"); results.append((i, "INVALID", d, "")); continue
        open(path, "w").write(original.replace(old, new))
        t0 = time.time()
        try:
            rc, out, to = run(["swift", "build", "--build-tests"], 600)
            if rc != 0:
                results.append((i, "BUILD-ERROR", d, "")); print(f"{i}: BUILD ERROR (invalid mutant): {d}")
                continue
            rc, out, to = run(["swift", "test", "--skip-build"], 240)
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
    ks = sum(1 for r in results if r[1] == "KILLED"); sv = [r for r in results if r[1] == "SURVIVED"]
    inv = [r for r in results if r[1] in ("INVALID", "BUILD-ERROR")]
    print(f"\nTOTAL {len(results)}  KILLED {ks}  SURVIVED {len(sv)}  INVALID/BUILD-ERROR {len(inv)}")
    for r in sv: print("SURVIVOR", r[0], r[2])
    for r in inv: print("INVALID", r[0], r[2])

if __name__ == "__main__":
    main()
