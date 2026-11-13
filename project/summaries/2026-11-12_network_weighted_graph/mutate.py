import subprocess, shutil, sys, re
W='Sources/BusinessMath/WeightedGraph.swift'; B='Sources/BusinessMath/GraphBridges.swift'
muts=[
("M01 NaN/inf check dropped (isFinite removed)",W,"guard weight.isFinite, weight >= 0 else","guard weight >= 0 else"),
("M02 NaN-only: !isNaN instead of isFinite",W,"guard weight.isFinite, weight >= 0 else","guard !weight.isNaN, weight >= 0 else"),
("M03 negative check dropped",W,"guard weight.isFinite, weight >= 0 else","guard weight.isFinite else"),
("M04 negative check flipped to >0 (zero refused)",W,"guard weight.isFinite, weight >= 0 else","guard weight.isFinite, weight > 0 else"),
("M05 negative check weakened to >= -1",W,"guard weight.isFinite, weight >= 0 else","guard weight.isFinite, weight >= -1 else"),
("M06 overflow: total check dropped",W,"guard totalWeight.isFinite, adjacency.indices","guard adjacency.indices"),
("M07 overflow: degree check dropped",W,"guard totalWeight.isFinite, adjacency.indices.allSatisfy({ weightedDegree($0).isFinite }) else","guard totalWeight.isFinite else"),
("M08 overflow: whole guard negated",W,"guard totalWeight.isFinite, adjacency","guard !totalWeight.isFinite, adjacency"),
("M09 self-loop drop removed",W,"guard from != to else { continue }","guard true else { continue }"),
("M10 self-loop node dropped too (names inserted after guard)",W,"\t\t\tnames.insert(from)\n\t\t\tnames.insert(to)\n\t\t\tguard from != to else { continue }","\t\t\tguard from != to else { continue }\n\t\t\tnames.insert(from)\n\t\t\tnames.insert(to)"),
("M11 dedupe overwrites instead of sums (forward)",W,"merged[from, default: [:]][to, default: 0] += weight","merged[from, default: [:]][to] = weight"),
("M12 dedupe overwrites (reverse)",W,"merged[to, default: [:]][from, default: 0] += weight","merged[to, default: [:]][from] = weight"),
("M13 reverse direction not recorded",W,"\t\t\tmerged[to, default: [:]][from, default: 0] += weight\n",""),
("M14 nodes unsorted-by-name (descending)",W,"names.sorted()","names.sorted(by: >)"),
("M15 adjacency sort dropped",W,".sorted { $0.neighbour < $1.neighbour }",".sorted { $0.neighbour > $1.neighbour }"),
("M16 edgeCount off by one",W,"lists.reduce(0) { $0 + $1.count } / 2","(lists.reduce(0) { $0 + $1.count } + 1) / 2"),
("M17 edgeCount not halved",W,"lists.reduce(0) { $0 + $1.count } / 2","lists.reduce(0) { $0 + $1.count }"),
("M18 totalWeight not halved",W,"self.totalWeight = total / 2","self.totalWeight = total"),
("M19 weightedDegree sum wrong (count)",W,"adjacency[index].reduce(0) { $0 + $1.weight }","adjacency[index].reduce(0) { $0 + ($1.weight > 0 ? 1 : 0) }"),
("M20 weightedDegree off by index",W,"adjacency[index].reduce(0) { $0 + $1.weight }","adjacency[(index + 1) % adjacency.count].reduce(0) { $0 + $1.weight }"),
("M21 weightedDegree max instead of sum",W,"adjacency[index].reduce(0) { $0 + $1.weight }","adjacency[index].reduce(0) { max($0, $1.weight) }"),
("M22 isolated nodes ignored",W,"var names: Set<Node> = Set(isolatedNodes)","var names: Set<Node> = []"),
("M23 unweighted weight 2",W,"($0.0, $0.1, 1.0)","($0.0, $0.1, 2.0)"),
("M24 degree(of:) returns 0 for unknown",W,"guard let index = indexOf[node] else { return nil }","guard let index = indexOf[node] else { return 0 }"),
("M25 neighbourCount off by one",W,"adjacency[index].count }","adjacency[index].count + 1 }"),
("M26 invalidWeight names edge swapped",W,"from: String(describing: from), to: String(describing: to), weight: weight)","from: String(describing: to), to: String(describing: from), weight: weight)"),
("M27 invalidWeight reports weight 0",W,"to: String(describing: to), weight: weight)","to: String(describing: to), weight: 0)"),
("M28 validation skips first edge",W,"for (from, to, weight) in edges {\n\t\t\tguard weight.isFinite","for (from, to, weight) in edges.dropFirst() {\n\t\t\tguard weight.isFinite"),
("M29 validation skips self-loops",W,"guard weight.isFinite, weight >= 0 else","guard from == to || (weight.isFinite && weight >= 0) else"),
("M30 bridge: weight 2",B,"unweightedEdges: pairs,","edges: pairs.map { ($0.0, $0.1, 2.0) },"),
("M31 bridge: isolated nodes dropped",B,"isolatedNodes: graph.nodes)","isolatedNodes: [])"),
("M32 bridge: self-loops kept (no from != to)",B,"where from != to {","{"),
("M33 bridge: reciprocal edges doubled (no dedupe)",B,"if seen.insert(key).inserted { pairs.append((key[0], key[1])) }","pairs.append((key[0], key[1]))"),
("M34 bridge back: one direction only",B,"map[node] = weighted.adjacency[index].map { weighted.nodes[$0.neighbour] }","map[node] = weighted.adjacency[index].filter { $0.neighbour > index }.map { weighted.nodes[$0.neighbour] }"),
("M35 bridge back: isolated dropped",B,"for (index, node) in weighted.nodes.enumerated() {","for (index, node) in weighted.nodes.enumerated() where !weighted.adjacency[index].isEmpty {"),
("M36 bridge back: zero-weight ties dropped",B,"weighted.adjacency[index].map {","weighted.adjacency[index].filter { $0.weight > 0 }.map {"),
]
sel=sys.argv[1:]
for name,f,old,new in muts:
    if sel and name.split()[0] not in sel: continue
    src=open(f).read()
    if old not in src: print(name,"=> PATTERN NOT FOUND"); continue
    open(f,'w').write(src.replace(old,new,1))
    r=subprocess.run(['swift','test'],capture_output=True,text=True)
    out=r.stdout+r.stderr
    if 'error:' in out and 'Compiling' not in out and 'recorded an issue' not in out and 'Test run' not in out:
        status='COMPILE ERROR'
    else:
        m=re.findall(r'Test run with .* (passed|failed)',out)
        status='KILLED' if (m and m[-1]=='failed') or r.returncode!=0 else 'SURVIVED'
        fails=sorted(set(re.findall(r'Test "([^"]+)" (?:with \d+ test cases )?failed',out)))
        if status=='KILLED': status+=' by '+str(len(fails))+': '+'; '.join(x[:60] for x in fails[:2])
    open(f,'w').write(src)
    print(name,'=>',status,flush=True)
