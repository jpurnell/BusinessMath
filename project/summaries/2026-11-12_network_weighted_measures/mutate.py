#!/usr/bin/env python3
"""Hand-written mutation check of the ported weighted measures (Centrality, Community, Brokerage).

Each mutant is one textual edit to one source file of the OUTSIDE-THE-REPO scratch package built by
make_scratch.sh. The script applies the edit, runs the suites with `swift test`, restores the file,
and records KILLED (a test failed), BUILD ERROR (the edit did not compile: an invalid mutant, fixed
before the run is counted) or SURVIVED.

    ./make_scratch.sh <worktree> /private/tmp/claude-501/mut2
    python3 mutate.py /private/tmp/claude-501/mut2 > mutation_output.txt
"""
import subprocess, sys, re

ROOT = sys.argv[1]
SRC = ROOT + "/Sources/BusinessMath/"
C, M, B = "WeightedCentrality.swift", "WeightedCommunity.swift", "BurtConstraint.swift"
T = "\t"

MUTANTS = [
 # ---- eigenvector / convergence
 ("E01 shift: 2*total/n to total/n", C, "let shift = 2 * graph.totalWeight / Double(count)", "let shift = graph.totalWeight / Double(count)"),
 ("E02 shift dropped (plain A)", C, "let shift = 2 * graph.totalWeight / Double(count)", "let shift = 0.0"),
 ("E03 start vector 1/n to 1", C, "var current = [Double](repeating: 1 / Double(count), count: count)\n\t\tlet shift", "var current = [Double](repeating: 1, count: count)\n\t\tlet shift"),
 ("E04 default ceiling 200 to 100 (eigenvectorConvergence)", C, "maxIterations: Int = 200, tolerance: Double = 1e-10\n\t) -> (iterations", "maxIterations: Int = 100, tolerance: Double = 1e-10\n\t) -> (iterations"),
 ("E05 default tolerance 1e-10 to 1e-9 (convergence)", C, "maxIterations: Int = 200, tolerance: Double = 1e-10\n\t) -> (iterations", "maxIterations: Int = 200, tolerance: Double = 1e-9\n\t) -> (iterations"),
 ("E06 default ceiling of eigenvector 200 to 150", C, "maxIterations: Int = 200, tolerance: Double = 1e-10\n\t) -> NodeScores<Node> {\n\t\teigenvectorConvergence", "maxIterations: Int = 150, tolerance: Double = 1e-10\n\t) -> NodeScores<Node> {\n\t\teigenvectorConvergence"),
 ("E07 default tolerance of eigenvector 1e-10 to 1e-8", C, "maxIterations: Int = 200, tolerance: Double = 1e-10\n\t) -> NodeScores<Node> {\n\t\teigenvectorConvergence", "maxIterations: Int = 200, tolerance: Double = 1e-8\n\t) -> NodeScores<Node> {\n\t\teigenvectorConvergence"),
 ("E08 max(1, maxIterations) to maxIterations", C, "for _ in 0..<max(1, maxIterations) {\n\t\t\t// Iterate", "for _ in 0..<maxIterations {\n\t\t\t// Iterate"),
 ("E09 L2 norm to L1 norm", C, "let norm = sqrt(next.reduce(0) { $0 + $1 * $1 })", "let norm = next.reduce(0) { $0 + abs($1) }"),
 ("E10 normalisation skipped", C, "for index in 0..<count { next[index] /= norm }", ""),
 ("E11 delta L1 to L-inf", C, "for index in 0..<count { delta += abs(next[index] - current[index]) }\n\t\t\tcurrent = next\n\t\t\titerations += 1", "for index in 0..<count { delta = max(delta, abs(next[index] - current[index])) }\n\t\t\tcurrent = next\n\t\t\titerations += 1"),
 ("E12 stop test < to <=", C, "if delta < tolerance {\n\t\t\t\tconverged = true", "if delta <= tolerance {\n\t\t\t\tconverged = true"),
 ("E13 stop test < to >", C, "if delta < tolerance {\n\t\t\t\tconverged = true", "if delta > tolerance {\n\t\t\t\tconverged = true"),
 ("E14 iterations not counted", C, "\t\t\tcurrent = next\n\t\t\titerations += 1\n\t\t\tresidual = delta", "\t\t\tcurrent = next\n\t\t\tresidual = delta"),
 ("E15 residual not recorded", C, "\t\t\titerations += 1\n\t\t\tresidual = delta\n", "\t\t\titerations += 1\n"),
 ("E16 converged never set on tolerance", C, "if delta < tolerance {\n\t\t\t\tconverged = true\n\t\t\t\tbreak", "if delta < tolerance {\n\t\t\t\tbreak"),
 ("E17 break dropped after convergence", C, "if delta < tolerance {\n\t\t\t\tconverged = true\n\t\t\t\tbreak\n\t\t\t}", "if delta < tolerance {\n\t\t\t\tconverged = true\n\t\t\t}"),
 ("E18 max-normalisation of output dropped", C, "scores[node] = peak > 0 ? current[index] / peak : 0", "scores[node] = current[index]"),
 ("E19 peak > 0 to peak >= 0", C, "scores[node] = peak > 0 ? current[index] / peak : 0", "scores[node] = peak >= 0 ? current[index] / peak : 0"),
 ("E20 single node score 1 to 0", C, "return (0, true, 0, NodeScores([graph.nodes[0]: 1]))", "return (0, true, 0, NodeScores([graph.nodes[0]: 0]))"),
 ("E21 count > 1 guard to >= 1", C, "guard count > 1 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }", "guard count >= 1 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }"),
 ("E22 norm == 0 branch: converged true to false", C, "iterations += 1\n\t\t\t\tconverged = true\n\t\t\t\tresidual = 0", "iterations += 1\n\t\t\t\tconverged = false\n\t\t\t\tresidual = 0"),
 ("E23 norm == 0 branch: iteration not counted", C, "iterations += 1\n\t\t\t\tconverged = true\n\t\t\t\tresidual = 0", "converged = true\n\t\t\t\tresidual = 0"),
 ("E24 adjacency weight ignored in product", C, "next[index] += weight * current[neighbour]", "next[index] += current[neighbour]"),
 ("E25 empty graph converged true to false", C, "guard count > 0 else { return (0, true, 0, NodeScores([:])) }", "guard count > 0 else { return (0, false, 0, NodeScores([:])) }"),
 # ---- PageRank
 ("P01 damping clamp upper 0.999 to 1.0", C, "min(max(damping, 0), 0.999)", "min(max(damping, 0), 1.0)"),
 ("P02 damping clamp lower dropped", C, "min(max(damping, 0), 0.999)", "min(damping, 0.999)"),
 ("P03 damping clamp upper 0.999 to 0.99", C, "min(max(damping, 0), 0.999)", "min(max(damping, 0), 0.99)"),
 ("P04 teleport (1-d)/n to (1-d)", C, "let teleport = (1 - clampedDamping) / Double(count)", "let teleport = (1 - clampedDamping)"),
 ("P05 dangling test <= 0 to < 0", C, "for index in 0..<count where degrees[index] <= 0 {", "for index in 0..<count where degrees[index] < 0 {"),
 ("P06 dangling mass not spread", C, "let spread = clampedDamping * danglingMass / Double(count)", "let spread = 0.0"),
 ("P07 dangling spread without damping", C, "let spread = clampedDamping * danglingMass / Double(count)", "let spread = danglingMass / Double(count)"),
 ("P08 dangling spread not divided by n", C, "let spread = clampedDamping * danglingMass / Double(count)", "let spread = clampedDamping * danglingMass"),
 ("P09 share not divided by degree", C, "let share = clampedDamping * current[index] / degree", "let share = clampedDamping * current[index]"),
 ("P10 edge weight ignored", C, "next[neighbour] += share * weight", "next[neighbour] += share"),
 ("P11 default damping 0.85 to 0.9", C, "damping: Double = 0.85,", "damping: Double = 0.9,"),
 ("P12 default tolerance 1e-12 to 1e-6", C, "maxIterations: Int = 200, tolerance: Double = 1e-12\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tguard count > 0 else { return NodeScores([:]) }\n\t\tlet clampedDamping", "maxIterations: Int = 200, tolerance: Double = 1e-6\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tguard count > 0 else { return NodeScores([:]) }\n\t\tlet clampedDamping"),
 ("P13 default ceiling 200 to 100 (pageRank)", C, "maxIterations: Int = 200, tolerance: Double = 1e-12\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tguard count > 0 else { return NodeScores([:]) }\n\t\tlet clampedDamping", "maxIterations: Int = 100, tolerance: Double = 1e-12\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tguard count > 0 else { return NodeScores([:]) }\n\t\tlet clampedDamping"),
 ("P14 pageRank stop test < to <=", C, "current = next\n\t\t\tif delta < tolerance { break }", "current = next\n\t\t\tif delta <= tolerance { break }"),
 ("P15 pageRank stop never fires", C, "current = next\n\t\t\tif delta < tolerance { break }", "current = next"),
 ("P16 pageRank max(1, ) dropped", C, "for _ in 0..<max(1, maxIterations) {\n\t\t\tvar next = [Double](repeating: teleport", "for _ in 0..<maxIterations {\n\t\t\tvar next = [Double](repeating: teleport"),
 ("P17 pageRank delta L1 to L-inf", C, "for index in 0..<count { delta += abs(next[index] - current[index]) }\n\t\t\tcurrent = next\n\t\t\tif delta", "for index in 0..<count { delta = max(delta, abs(next[index] - current[index])) }\n\t\t\tcurrent = next\n\t\t\tif delta"),
 # ---- betweenness
 ("B01 distance init -1 test < 0 to <= 0", C, "if distance[neighbour] < 0 {\n\t\t\t\t\t\tdistance[neighbour] = distance[node] + 1\n\t\t\t\t\t\tqueue.append", "if distance[neighbour] <= 0 {\n\t\t\t\t\t\tdistance[neighbour] = distance[node] + 1\n\t\t\t\t\t\tqueue.append"),
 ("B02 predecessor distance + 1 to + 2", C, "if distance[neighbour] == distance[node] + 1 {\n\t\t\t\t\t\tpathCount", "if distance[neighbour] == distance[node] + 2 {\n\t\t\t\t\t\tpathCount"),
 ("B03 path count not accumulated", C, "pathCount[neighbour] += pathCount[node]", "pathCount[neighbour] += 1"),
 ("B04 dependency (1 + d) to d", C, "(pathCount[predecessor] / pathCount[node]) * (1 + dependency[node])", "(pathCount[predecessor] / pathCount[node]) * (dependency[node])"),
 ("B05 dependency ratio inverted", C, "(pathCount[predecessor] / pathCount[node]) * (1 + dependency[node])", "(pathCount[node] / pathCount[predecessor]) * (1 + dependency[node])"),
 ("B06 source credited too", C, "if node != source { centrality[node] += dependency[node] }", "centrality[node] += dependency[node]"),
 ("B07 stack not reversed", C, "for node in stack.reversed() {", "for node in stack {"),
 ("B08 pairs (n-1)(n-2) to (n-1)n", C, "let pairs = Double((count - 1) * (count - 2))", "let pairs = Double((count - 1) * count)"),
 ("B09 halving dropped", C, "var value = centrality[index] / 2", "var value = centrality[index]"),
 ("B10 normalisation divisor pairs/2 to pairs", C, "value /= (pairs / 2)", "value /= pairs"),
 ("B11 normalised flag ignored", C, "if normalized, pairs > 0 {", "if pairs > 0 {"),
 ("B12 small-graph guard count > 2 to > 3", C, "guard count > 2 else {\n\t\t\treturn NodeScores(Dictionary(\n\t\t\t\tuniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))\n\t\t}\n\n\t\tfor source", "guard count > 3 else {\n\t\t\treturn NodeScores(Dictionary(\n\t\t\t\tuniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))\n\t\t}\n\n\t\tfor source"),
 ("B13 default normalized true to false", C, "_ graph: WeightedGraph<Node>, normalized: Bool = true\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tvar centrality", "_ graph: WeightedGraph<Node>, normalized: Bool = false\n\t) -> NodeScores<Node> {\n\t\tlet count = graph.nodeCount\n\t\tvar centrality"),
 # ---- closeness / harmonic
 ("W01 Wasserman-Faust fraction dropped", C, "scores[graph.nodes[source]] = reachableFraction / meanDistance", "scores[graph.nodes[source]] = 1 / meanDistance"),
 ("W02 divisor n-1 to n", C, "let others = Double(count - 1)\n\t\t\tguard others > 0 else {\n\t\t\t\tscores[graph.nodes[source]] = 0\n\t\t\t\tcontinue\n\t\t\t}\n\t\t\tlet reachableFraction", "let others = Double(count)\n\t\t\tguard others > 0 else {\n\t\t\t\tscores[graph.nodes[source]] = 0\n\t\t\t\tcontinue\n\t\t\t}\n\t\t\tlet reachableFraction"),
 ("W03 mean distance divisor reached to n", C, "let meanDistance = Double(total) / reachedCount", "let meanDistance = Double(total) / Double(count)"),
 ("W04 distance total not accumulated", C, "total += distance[neighbour]\n\t\t\t\t\treached += 1", "total += 1\n\t\t\t\t\treached += 1"),
 ("W05 reached not counted", C, "total += distance[neighbour]\n\t\t\t\t\treached += 1", "total += distance[neighbour]\n\t\t\t\t\treached += 0"),
 ("W06 closeness small-graph guard > 1 to > 2", C, "guard count > 1 else {\n\t\t\treturn NodeScores(Dictionary(\n\t\t\t\tuniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))\n\t\t}\n\n\t\tfor source in 0..<count {\n\t\t\tvar distance = [Int](repeating: -1, count: count)\n\t\t\tdistance[source] = 0\n\t\t\tvar queue = [source]\n\t\t\tvar head = 0\n\t\t\tvar total = 0\n", "guard count > 2 else {\n\t\t\treturn NodeScores(Dictionary(\n\t\t\t\tuniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))\n\t\t}\n\n\t\tfor source in 0..<count {\n\t\t\tvar distance = [Int](repeating: -1, count: count)\n\t\t\tdistance[source] = 0\n\t\t\tvar queue = [source]\n\t\t\tvar head = 0\n\t\t\tvar total = 0\n"),
 ("W07 harmonic reciprocal 1/hops to 1/(hops+1)", C, "total += 1.0 / hops", "total += 1.0 / (hops + 1)"),
 ("W08 harmonic divisor n-1 to n", C, "let others = Double(count - 1)\n\t\t\tguard others > 0 else { scores[graph.nodes[source]] = 0; continue }", "let others = Double(count)\n\t\t\tguard others > 0 else { scores[graph.nodes[source]] = 0; continue }"),
 ("W09 harmonic distance not incremented", C, "distance[neighbour] = distance[node] + 1\n\t\t\t\t\tlet hops", "distance[neighbour] = distance[node]\n\t\t\t\t\tlet hops"),
 # ---- clustering
 ("K01 clustering denominator d(d-1) to d(d+1)", C, "let possible = Double(degree * (degree - 1))", "let possible = Double(degree * (degree + 1))"),
 ("K02 clustering degree guard > 1 to > 2", C, "guard degree > 1 else { scores[node] = 0; continue }", "guard degree > 2 else { scores[node] = 0; continue }"),
 ("K03 clustering counts the node itself", C, "where other != index && neighbourSet.contains(other) {", "where neighbourSet.contains(other) {"),
 ("K04 clustering counts non-neighbours", C, "where other != index && neighbourSet.contains(other) {", "where other != index {"),
 ("K05 clustering links halved", C, "scores[node] = Double(links) / possible", "scores[node] = Double(links) / (2 * possible)"),
 ("K06 degree: weighted degree to neighbour count", C, "scores[node] = graph.weightedDegree(index)\n\t\t}\n\t\treturn NodeScores(scores)\n\t}\n\n\t/// Eigenvector", "scores[node] = Double(graph.neighbourCount(index))\n\t\t}\n\t\treturn NodeScores(scores)\n\t}\n\n\t/// Eigenvector"),
 # ---- modularity
 ("Q01 modularity: internal edge halving dropped", M, "score += (inside / 2) / total - pow(degree / (2 * total), 2)", "score += inside / total - pow(degree / (2 * total), 2)"),
 ("Q02 modularity: expected term 2m to m", M, "score += (inside / 2) / total - pow(degree / (2 * total), 2)", "score += (inside / 2) / total - pow(degree / total, 2)"),
 ("Q03 modularity: minus to plus", M, "score += (inside / 2) / total - pow(degree / (2 * total), 2)", "score += (inside / 2) / total + pow(degree / (2 * total), 2)"),
 ("Q04 modularity: edgeless guard total > 0 to >= 0", M, "guard total > 0 else { return 0 }", "guard total >= 0 else { return 0 }"),
 ("Q05 modularity: same-community test inverted", M, "other == community else { continue }", "other != community else { continue }"),
 ("Q06 modularity: degree sum omitted", M, "degreeSum[community, default: 0] += graph.weightedDegree(index)", "degreeSum[community, default: 0] += 0"),
 ("Q07 modularity: edgeless communities penalty dropped", M, "score -= pow(degree / (2 * total), 2)", "score -= 0"),
 ("Q08 modularity: edgeless-community filter inverted", M, "where internalWeight[community] == nil {", "where internalWeight[community] != nil {"),
 ("Q09 modularity: weight ignored in internal sum", M, "internalWeight[community, default: 0] += weight", "internalWeight[community, default: 0] += 1"),
 # ---- Louvain
 ("L01 tie margin 1e-12 to 0", M, "if gain > bestGain + 1e-12 {", "if gain > bestGain {"),
 ("L02 tie margin 1e-12 to 1e-3", M, "if gain > bestGain + 1e-12 {", "if gain > bestGain + 1e-3 {"),
 ("L03 move test > to >=", M, "if gain > bestGain + 1e-12 {", "if gain >= bestGain + 1e-12 {"),
 ("L04 candidates unsorted-reversed", M, "for candidate in weightTo.keys.sorted() where candidate != own {", "for candidate in weightTo.keys.sorted().reversed() where candidate != own {"),
 ("L05 resolution ignored for own community", M, "var bestGain = (weightTo[own] ?? 0)\n\t\t\t\t\t\t- resolution * communityTotal[own]", "var bestGain = (weightTo[own] ?? 0)\n\t\t\t\t\t\t- 1.0 * communityTotal[own]"),
 ("L06 resolution ignored for candidates", M, "- resolution * communityTotal[candidate] * degrees[index]", "- 1.0 * communityTotal[candidate] * degrees[index]"),
 ("L07 expected term 2m to m", M, "* degrees[index]\n\t\t\t\t\t\t\t\t/ (2 * totalWeight)", "* degrees[index]\n\t\t\t\t\t\t\t\t/ (totalWeight)"),
 ("L08 sweeps ceiling 50 to 1", M, "while moved && sweeps < 50 {", "while moved && sweeps < 1 {"),
 ("L09 sweeps ceiling 50 to 2", M, "while moved && sweeps < 50 {", "while moved && sweeps < 2 {"),
 ("L10 community totals not updated on move", M, "communityTotal[bestCommunity] += degrees[index]\n\t\t\t\t\tif bestCommunity != own {", "communityTotal[own] += degrees[index]\n\t\t\t\t\tif bestCommunity != own {"),
 ("L11 own community not removed before scoring", M, "communityTotal[own] -= degrees[index]\n", ""),
 ("L12 improved flag never set", M, "moved = true\n\t\t\t\t\t\timproved = true", "moved = true"),
 ("L13 improved guard removed", M, "guard improved else { break }", ""),
 ("L14 renumber guard newCount < levelCount to <=", M, "guard newCount < levelCount else { break }", "guard newCount <= levelCount else { break }"),
 ("L15 contraction self-loop weight/2 to weight", M, "newSelfLoops[source] += weight / 2", "newSelfLoops[source] += weight"),
 ("L16 contraction carries old self-loops: dropped", M, "newSelfLoops[source] += levelSelfLoops[index]", "newSelfLoops[source] += 0"),
 ("L17 contraction inter-community weight not summed", M, "newAdjacency[source][target, default: 0] += weight", "newAdjacency[source][target] = weight"),
 ("L18 degree self-loop factor 2 to 1", M, "levelAdjacency[index].reduce(0) { $0 + $1.1 } + 2 * levelSelfLoops[index]", "levelAdjacency[index].reduce(0) { $0 + $1.1 } + levelSelfLoops[index]"),
 ("L19 membership not followed through collapse", M, "assignment[index] = compact[assignment[index]]", "assignment[index] = compact[index]"),
 ("L20 renumbering order: first appearance to last", M, "for value in community where renumbered[value] == nil {", "for value in community.reversed() where renumbered[value] == nil {"),
 ("L21 maxPasses max(1,) dropped", M, "for _ in 0..<max(1, maxPasses) {", "for _ in 0..<maxPasses {"),
 ("L22 default maxPasses 20 to 1", M, "resolution: Double = 1.0, maxPasses: Int = 20", "resolution: Double = 1.0, maxPasses: Int = 1"),
 ("L23 default resolution 1.0 to 1.5", M, "resolution: Double = 1.0, maxPasses: Int = 20", "resolution: Double = 1.5, maxPasses: Int = 20"),
 ("L24 edgeless: every node alone to all together", M, "uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) }))\n\t\t}\n\n\t\t// Community membership", "uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, 0) }))\n\t\t}\n\n\t\t// Community membership"),
 ("L25 edgeless guard totalWeight > 0 to >= 0", M, "guard graph.totalWeight > 0 else {", "guard graph.totalWeight >= 0 else {"),
 ("L26 level totalWeight guard > 0 removed", M, "guard totalWeight > 0 else { break }", ""),
 # ---- k-core
 ("R01 kCore: degree decrement guard > to >=", M, "where !removed[neighbour] && degree[neighbour] > lowest {", "where !removed[neighbour] && degree[neighbour] >= lowest {"),
 ("R02 kCore: removed check dropped", M, "where !removed[neighbour] && degree[neighbour] > lowest {", "where degree[neighbour] > lowest {"),
 ("R03 kCore: lowest selection < to <=", M, "where !removed[index] && degree[index] < lowest {", "where !removed[index] && degree[index] <= lowest {"),
 ("R04 kCore: core records degree not lowest", M, "core[next] = lowest", "core[next] = degree[next] + 1"),
 ("R05 kCore: peeled node not marked removed", M, "removed[next] = true", ""),
 ("R06 kCore: decrement by 2", M, "degree[neighbour] -= 1", "degree[neighbour] -= 2"),
 ("R07 kCore: core number is running max dropped (uses 0)", M, "core[next] = lowest", "core[next] = 0"),
 # ---- components
 ("N01 components: unvisited test < 0 to <= 0", M, "for (neighbour, _) in graph.adjacency[node] where component[neighbour] < 0 {", "for (neighbour, _) in graph.adjacency[node] where component[neighbour] <= 0 {"),
 ("N02 components: next label not incremented", M, "next += 1\n\t\t}\n\n\t\tvar result", "}\n\n\t\tvar result"),
 ("N03 components: BFS does not enqueue", M, "component[neighbour] = next\n\t\t\t\t\tqueue.append(neighbour)", "component[neighbour] = next"),
 # ---- Burt
 ("T01 Burt: indirect uses strengthQ replaced by strength", B, "indirect[j] += share * (weightQJ / strengthQ)", "indirect[j] += share * (weightQJ / strength)"),
 ("T02 Burt: positive-weight contact test > 0 to >= 0 (stamp loop)", B, "for (j, weight) in graph.adjacency[i] where weight > 0 {\n\t\t\t\tstamp[j] = i", "for (j, weight) in graph.adjacency[i] where weight >= 0 {\n\t\t\t\tstamp[j] = i"),
 ("T03 Burt: positive-weight test dropped (total loop)", B, "for (j, weight) in graph.adjacency[i] where weight > 0 {\n\t\t\t\tlet investment", "for (j, weight) in graph.adjacency[i] {\n\t\t\t\tlet investment"),
 ("T04 Burt: indirect q loop zero-weight filter dropped", B, "for (q, weightIQ) in graph.adjacency[i] where weightIQ > 0 {", "for (q, weightIQ) in graph.adjacency[i] {"),
 ("T05 Burt: strength guard > 0 to >= 0", B, "guard strength > 0 else { continue }", "guard strength >= 0 else { continue }"),
 ("T06 Burt: square dropped", B, "total += investment * investment", "total += investment"),
 ("T07 Burt: indirect omitted", B, "let investment = direct[j] + indirect[j]", "let investment = direct[j]"),
 ("T08 Burt: direct share weight not divided", B, "direct[j] = weight / strength", "direct[j] = weight"),
 ("T09 Burt: self excluded test j != i dropped", B, "where j != i && stamp[j] == i {", "where stamp[j] == i {"),
 ("T10 Burt: stamp test dropped", B, "where j != i && stamp[j] == i {", "where j != i {"),
 ("T11 Burt: indirect reset dropped", B, "direct[j] = weight / strength\n\t\t\t\tindirect[j] = 0", "direct[j] = weight / strength"),
 ("T12 Burt: indirect uses weightIQ instead of share", B, "indirect[j] += share * (weightQJ / strengthQ)", "indirect[j] += weightIQ * (weightQJ / strengthQ)"),
]

def run():
    r = subprocess.run(["swift", "test"], cwd=ROOT, capture_output=True, text=True, timeout=900)
    out = re.sub(r"\x1b\[[0-9;]*m", "", r.stdout + r.stderr)
    if re.search(r"error: .*\.swift:\d+", out) or "error: fatalError" in out or "Compiling failed" in out:
        if "Test run with" not in out:
            return "BUILD ERROR", out
    m = re.search(r"Test run with (\d+) tests.*?(passed|failed)", out)
    if m and m.group(2) == "failed":
        return "KILLED", out
    if m:
        return "SURVIVED", out
    return "BUILD ERROR", out

def main():
    killed = survived = broken = 0
    for name, f, old, new in MUTANTS:
        path = SRC + f
        original = open(path).read()
        if original.count(old) != 1:
            print(f"{name}: PATTERN MISMATCH ({original.count(old)} matches)", flush=True)
            broken += 1
            continue
        open(path, "w").write(original.replace(old, new))
        try:
            status, out = run()
        except subprocess.TimeoutExpired:
            status, out = "KILLED", "timeout (hang is a detected change)"
        finally:
            open(path, "w").write(original)
        detail = ""
        if status == "KILLED":
            failing = re.findall(r'Test "(.*?)" (?:with \d+ test cases )?(?:failed|recorded an issue)', out)
            detail = (failing[0] if failing else "")[:90]
            killed += 1
        elif status == "SURVIVED":
            survived += 1
        else:
            broken += 1
            detail = " | ".join(l for l in out.splitlines() if "error:" in l)[:200]
        print(f"{name}: {status}  {detail}", flush=True)
    print(f"\nTOTAL {len(MUTANTS)}  killed {killed}  survived {survived}  not-counted {broken}")

main()
