#!/usr/bin/env python3
"""Hand-written mutation check of Network/Metrics (values protocol step).

Each mutant is one textual edit to one source file. The script backs the file up, applies the
edit, runs the metrics test suites, restores the file, and records KILLED (a test failed or
the build broke on a behavioural change) or SURVIVED. Run from the worktree root:

    python3 project/summaries/2026-11-12_network_values_protocol/mutate.py > mutation_output.txt
"""
import subprocess, sys, shutil, os

R = "Sources/BusinessMath/Network/Metrics/"
FILTER = "NodeScoresTests|PartitionAndSelectionTests|MetricEnvelopeTests|ConvergenceEnvelopeTests|StoredRecordGoldenTests"

M = [
 # NodeScores
 ("M01 ranked: score comparator > to <", "Values/NodeScores.swift", "$0.value > $1.value", "$0.value < $1.value"),
 ("M02 ranked: tie-break < to >", "Values/NodeScores.swift", "$0.key < $1.key : $0.value", "$0.key > $1.key : $0.value"),
 ("M03 ranked: tie test == to !=", "Values/NodeScores.swift", "$0.value == $1.value ?", "$0.value != $1.value ?"),
 ("M04 top: prefix to suffix", "Values/NodeScores.swift", "Array(ranked.prefix(max(0, count)))", "Array(ranked.suffix(max(0, count)))"),
 ("M05 top: off by one (count+1)", "Values/NodeScores.swift", "ranked.prefix(max(0, count))", "ranked.prefix(max(0, count + 1))"),
 ("M06 top: off by one (count-1)", "Values/NodeScores.swift", "ranked.prefix(max(0, count))", "ranked.prefix(max(0, count - 1))"),
 ("M07 top: max(0,) dropped", "Values/NodeScores.swift", "ranked.prefix(max(0, count))", "ranked.prefix(count)"),
 ("M08 bottom: reversed dropped", "Values/NodeScores.swift", "ranked.suffix(max(0, count)).reversed()", "ranked.suffix(max(0, count))"),
 ("M09 bottom: off by one (count+1)", "Values/NodeScores.swift", "ranked.suffix(max(0, count)).reversed()", "ranked.suffix(max(0, count + 1)).reversed()"),
 ("M10 bottom: max(0,) dropped", "Values/NodeScores.swift", "ranked.suffix(max(0, count)).reversed()", "ranked.suffix(count).reversed()"),
 ("M11 NodeScores kind string", "Values/NodeScores.swift", '"scores" }', '"score" }'),
 ("M12 NodePartition kind string", "Values/NodePartition.swift", '"partition" }', '"partitions" }'),
 ("M13 NodeSelection kind string", "Values/NodeSelection.swift", '"selection" }', '"selections" }'),
 ("M14 DiagnosedScores kind string", "Values/DiagnosedScores.swift", '"scores" }', '"diagnosed" }'),
 # NodePartition / NodeSelection
 ("M15 groups: size order > to <", "Values/NodePartition.swift", "$0.members.count > $1.members.count", "$0.members.count < $1.members.count"),
 ("M16 groups: community tie-break < to >", "Values/NodePartition.swift", "$0.community < $1.community", "$0.community > $1.community"),
 ("M17 groups: members unsorted", "Values/NodePartition.swift", "members: $0.value.sorted()", "members: $0.value"),
 ("M18 communityCount: keys instead of values", "Values/NodePartition.swift", "Set(communities.values).count", "communities.count"),
 ("M19 groups: missing-community fallback -1 to 0", "Values/NodePartition.swift", "communities[$0] ?? -1", "communities[$0] ?? 0"),
 ("M20 totalGain: ignores gain", "Values/NodeSelection.swift", "$0 + $1.marginalGain", "$0 + $1.marginalGain * 2"),
 ("M21 nodes: reversed", "Values/NodeSelection.swift", "picks.map(\\.node) }", "picks.map(\\.node).reversed() }"),
 ("M22 init(picks:) swaps nothing but drops last", "Values/NodeSelection.swift", "self.picks = picks.map {", "self.picks = picks.dropLast().map {"),
 # coding keys / convergence decoding
 ("M23 DiagnosedScores: coding key 'scores' renamed", "Values/DiagnosedScores.swift", "case scores, convergence", 'case scores = "score", convergence'),
 ("M24 DiagnosedScores: decodeIfPresent to decode", "Values/DiagnosedScores.swift", "decodeIfPresent(ConvergenceReport.self", "decode(ConvergenceReport.self"),
 ("M25 DiagnosedScores: encodeIfPresent to encode", "Values/DiagnosedScores.swift", "encodeIfPresent(convergence", "encode(convergence"),
 ("M26 DiagnosedScores: convergence dropped on decode", "Values/DiagnosedScores.swift", "try container.decodeIfPresent(ConvergenceReport.self, forKey: .convergence)", "nil"),
 ("M27 DiagnosedScores: convergence dropped on encode", "Values/DiagnosedScores.swift", "try container.encodeIfPresent(convergence, forKey: .convergence)", "_ = convergence"),
 ("M28 envelope.convergence: kind guard removed", "Protocol/MetricEnvelope.swift", "guard kind == DiagnosedScores<String>.kind,\n\t\t\t  case", "guard case"),
 ("M29 envelope.convergence: key renamed", "Protocol/MetricEnvelope.swift", 'fields["convergence"]', 'fields["converge"]'),
 ("M30 envelope.convergence: try? to fatal-free default report", "Protocol/MetricEnvelope.swift", "return try? JSONDecoder().decode(ConvergenceReport.self, from: data)", "return (try? JSONDecoder().decode(ConvergenceReport.self, from: data)) ?? ConvergenceReport(iterations: 0, converged: false, residual: 0, tolerance: 0, maxIterations: 0)"),
 ("M31 envelope.value: kind guard inverted", "Protocol/MetricEnvelope.swift", "guard kind == Value.kind else { return nil }", "guard kind != Value.kind else { return nil }"),
 ("M32 envelope.value: kind guard removed", "Protocol/MetricEnvelope.swift", "guard kind == Value.kind else { return nil }", ""),
 ("M33 envelope init: kind taken from payload type name", "Protocol/MetricEnvelope.swift", "self.kind = Value.kind", "self.kind = String(describing: Value.self)"),
 ("M34 JSONValue: bool decode skipped", "Protocol/MetricEnvelope.swift", "} else if let value = try? container.decode(Bool.self) {\n\t\t\tself = .bool(value)\n\t\t} else if", "} else if"),
 ("M35 JSONValue: number rounded to Int on encode", "Protocol/MetricEnvelope.swift", "case .number(let value): try container.encode(value)", "case .number(let value): try container.encode(Int(value))"),
 ("M36 JSONValue: null decodes to empty object", "Protocol/MetricEnvelope.swift", "self = .null", "self = .object([:])"),
 # ConvergenceNote
 ("M37 note: converged branch flipped", "Values/ConvergenceReport.swift", "if report.converged {", "if !report.converged {"),
 ("M38 note: singular 'pass' condition == 1 to == 0", "Values/ConvergenceReport.swift", "report.iterations == 1 ?", "report.iterations == 0 ?"),
 ("M39 note: singular 'pass' condition == 1 to <= 1", "Values/ConvergenceReport.swift", "report.iterations == 1 ?", "report.iterations <= 1 ?"),
 ("M40 note: ceiling text uses iterations", "Values/ConvergenceReport.swift", "stopped at the \\(report.maxIterations)-pass", "stopped at the \\(report.iterations)-pass"),
 ("M41 note: change and tolerance swapped", "Values/ConvergenceReport.swift", "let change = scientific(report.residual)", "let change = scientific(report.tolerance)"),
 ("M42 note: nil sentence text", "Values/ConvergenceReport.swift", "Convergence was not recorded for this result.", "Convergence was not recorded for this result"),
 ("M43 note: 'Did not converge' text", "Values/ConvergenceReport.swift", "Did not converge: stopped", "Did not converge, stopped"),
 ("M44 note: three significant digits to four", "Values/ConvergenceReport.swift", "significantDigits(3)", "significantDigits(4)"),
 ("M45 note: locale POSIX to French", "Values/ConvergenceReport.swift", 'Locale(identifier: "en_US_POSIX")', 'Locale(identifier: "fr_FR")'),
 ("M46 note: scientific notation to automatic", "Values/ConvergenceReport.swift", ".number.notation(.scientific)", ".number.notation(.automatic)"),
 ("M47 note: advice text dropped", "Values/ConvergenceReport.swift", " Raise maxIterations to check.", ""),
]

def run():
    r = subprocess.run(["swift", "test", "--filter", FILTER], capture_output=True, text=True)
    out = r.stdout + r.stderr
    built = "error:" not in out or "Test run" in out
    failed = ("failed after" in out) or r.returncode != 0
    return failed, built, out

only = set(sys.argv[1:])
for name, f, old, new in M:
    if only and name.split()[0] not in only:
        continue
    path = R + f
    src = open(path).read()
    if src.count(old) != 1:
        print(f"{name}: BAD MUTANT (pattern found {src.count(old)} times)", flush=True)
        continue
    shutil.copy(path, path + ".orig")
    try:
        open(path, "w").write(src.replace(old, new, 1))
        failed, built, out = run()
        if "Test run" not in out:
            print(f"{name}: COMPILE-ERROR (not counted as killed)", flush=True)
        else:
            print(f"{name}: {'KILLED' if failed else 'SURVIVED'}", flush=True)
    finally:
        shutil.move(path + ".orig", path)
