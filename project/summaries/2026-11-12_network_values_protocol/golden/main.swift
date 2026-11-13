import Foundation
import SwiftGraphMetrics

let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys]
func show<T: Encodable>(_ name: String, _ v: T) throws {
    print("\(name)\t\(String(decoding: try enc.encode(v), as: UTF8.self))")
}
let report = ConvergenceReport(iterations: 151, converged: true, residual: 8.2e-11, tolerance: 1e-10, maxIterations: 200)
let miss = ConvergenceReport(iterations: 200, converged: false, residual: 0.047, tolerance: 1e-10, maxIterations: 200)
let scores = NodeScores<String>(["a": 3, "b": 1.5, "c": 0.25])
let intScores = NodeScores<Int>([7: 0.5])
let partition = NodePartition<String>(["a": 0, "b": 0, "c": 1])
let selection = NodeSelection<String>(picks: [("b", 3.5), ("a", 1.25)])
let emptySel = NodeSelection<String>([])
let withConv = DiagnosedScores<String>(scores: scores, convergence: report)
let missConv = DiagnosedScores<String>(scores: scores, convergence: miss)
let noConv = DiagnosedScores<String>(scores: scores, convergence: nil)
try show("report", report)
try show("missReport", miss)
try show("scores", scores)
try show("intScores", intScores)
try show("emptyScores", NodeScores<String>([:]))
try show("partition", partition)
try show("selection", selection)
try show("emptySelection", emptySel)
try show("diagWith", withConv)
try show("diagMiss", missConv)
try show("diagWithout", noConv)
try show("envScores", try MetricEnvelope(scores))
try show("envIntScores", try MetricEnvelope(intScores))
try show("envPartition", try MetricEnvelope(partition))
try show("envSelection", try MetricEnvelope(selection))
try show("envDiagWith", try MetricEnvelope(withConv))
try show("envDiagMiss", try MetricEnvelope(missConv))
try show("envDiagWithout", try MetricEnvelope(noConv))
let unknown = MetricEnvelope(kind: "assignment", payload: .object([
  "sites": .array([.string("x"), .string("y")]), "cost": .number(5.2078), "ok": .bool(true), "none": .null]))
try show("envUnknown", unknown)
print("convWith\t\(String(describing: try MetricEnvelope(withConv).convergence))")
print("convWithout\t\(String(describing: try MetricEnvelope(noConv).convergence))")
print("sentenceOK\t\(ConvergenceNote.sentence(report))")
print("sentenceMiss\t\(ConvergenceNote.sentence(miss))")
print("sentenceNil\t\(ConvergenceNote.sentence(nil))")
print("kinds\t\(NodeScores<String>.kind) \(NodePartition<String>.kind) \(NodeSelection<String>.kind) \(DiagnosedScores<String>.kind)")
// NaN behaviour
do { _ = try MetricEnvelope(NodeScores<String>(["a": .nan])); print("nan\tNO THROW") } catch { print("nan\tthrows \(type(of: error))") }
do { _ = try MetricEnvelope(NodeScores<String>(["a": .infinity])); print("inf\tNO THROW") } catch { print("inf\tthrows \(type(of: error))") }
do { _ = try enc.encode(NodeScores<String>(["a": .nan])); print("rawnan\tNO THROW") } catch { print("rawnan\tthrows \(type(of: error))") }
let nanRanked = NodeScores<String>(["a": .nan, "b": 1, "c": 2, "d": .nan, "e": .infinity, "f": -.infinity])
print("nanRanked\t\(nanRanked.ranked.map(\.node))")
func rep(_ i: Int, _ c: Bool, _ r: Double, _ t: Double, _ m: Int) -> ConvergenceReport { ConvergenceReport(iterations: i, converged: c, residual: r, tolerance: t, maxIterations: m) }
print("s1\t\(ConvergenceNote.sentence(rep(1, true, 0, 1e-10, 200)))")
print("s2\t\(ConvergenceNote.sentence(rep(0, true, 0, 1e-3, 200)))")
print("s3\t\(ConvergenceNote.sentence(rep(2, true, 123456, 0.5, 200)))")
print("s4\t\(ConvergenceNote.sentence(rep(1, false, 1e-3, 1e-10, 1)))")
print("s5\t\(ConvergenceNote.sentence(rep(5, false, 0.99949, 1e-10, 5)))")
