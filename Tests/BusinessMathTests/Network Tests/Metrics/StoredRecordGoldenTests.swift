//
//  StoredRecordGoldenTests.swift
//  BusinessMath
//
//  The stored-record contract. The JSON below was produced by SwiftGraphMetrics's encoder
//  (JSONEncoder with .sortedKeys) before these types moved into BusinessMath, by a scratch
//  program kept at project/summaries/2026-11-12_network_values_protocol/golden/. A
//  MetricEnvelope serialised by the old package must decode identically here, and what is
//  encoded here must be byte-for-byte what the old package wrote. If one of these tests
//  fails, a stored record has changed meaning: fix the code, never the constant.
//
//  Doubles are chosen to be exactly representable or to print in their shortest form
//  (8.2e-11, 1e-10, 0.047), so the text does not depend on the platform's formatter beyond
//  the shortest round-trip rule. Dictionary keys are strings, which .sortedKeys orders;
//  integer-keyed dictionaries are not part of the golden set because their key order
//  is not defined.
//

import Foundation
import Testing
@testable import BusinessMath

private enum Golden {
	static let report = #"{"converged":true,"iterations":151,"maxIterations":200,"residual":8.2e-11,"tolerance":1e-10}"#
	static let missReport = #"{"converged":false,"iterations":200,"maxIterations":200,"residual":0.047,"tolerance":1e-10}"#
	static let scores = #"{"scores":{"a":3,"b":1.5,"c":0.25}}"#
	static let emptyScores = #"{"scores":{}}"#
	static let partition = #"{"communities":{"a":0,"b":0,"c":1}}"#
	static let selection = #"{"picks":[{"marginalGain":3.5,"node":"b"},{"marginalGain":1.25,"node":"a"}]}"#
	static let emptySelection = #"{"picks":[]}"#
	static let diagWith = #"{"convergence":{"converged":true,"iterations":151,"maxIterations":200,"residual":8.2e-11,"tolerance":1e-10},"scores":{"a":3,"b":1.5,"c":0.25}}"#
	static let diagMiss = #"{"convergence":{"converged":false,"iterations":200,"maxIterations":200,"residual":0.047,"tolerance":1e-10},"scores":{"a":3,"b":1.5,"c":0.25}}"#
	static let diagWithout = #"{"scores":{"a":3,"b":1.5,"c":0.25}}"#
	static let envScores = #"{"kind":"scores","payload":{"scores":{"a":3,"b":1.5,"c":0.25}}}"#
	static let envPartition = #"{"kind":"partition","payload":{"communities":{"a":0,"b":0,"c":1}}}"#
	static let envSelection = #"{"kind":"selection","payload":{"picks":[{"marginalGain":3.5,"node":"b"},{"marginalGain":1.25,"node":"a"}]}}"#
	static let envDiagWith = #"{"kind":"scores","payload":{"convergence":{"converged":true,"iterations":151,"maxIterations":200,"residual":8.2e-11,"tolerance":1e-10},"scores":{"a":3,"b":1.5,"c":0.25}}}"#
	static let envDiagMiss = #"{"kind":"scores","payload":{"convergence":{"converged":false,"iterations":200,"maxIterations":200,"residual":0.047,"tolerance":1e-10},"scores":{"a":3,"b":1.5,"c":0.25}}}"#
	static let envDiagWithout = #"{"kind":"scores","payload":{"scores":{"a":3,"b":1.5,"c":0.25}}}"#
	static let envUnknown = #"{"kind":"assignment","payload":{"cost":5.2078,"none":null,"ok":true,"sites":["x","y"]}}"#

	static let reportValue = ConvergenceReport(
		iterations: 151, converged: true, residual: 8.2e-11, tolerance: 1e-10, maxIterations: 200)
	static let missValue = ConvergenceReport(
		iterations: 200, converged: false, residual: 0.047, tolerance: 1e-10, maxIterations: 200)
	static let scoresValue = NodeScores<String>(["a": 3, "b": 1.5, "c": 0.25])
	static let partitionValue = NodePartition<String>(["a": 0, "b": 0, "c": 1])
	static let selectionValue = NodeSelection<String>(picks: [("b", 3.5), ("a", 1.25)])
}

private func encoded<Value: Encodable>(_ value: Value) throws -> String {
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.sortedKeys]
	return String(decoding: try encoder.encode(value), as: UTF8.self)
}

private func decoded<Value: Decodable>(_ type: Value.Type, _ text: String) throws -> Value {
	try JSONDecoder().decode(type, from: Data(text.utf8))
}

@Suite("Stored-record golden: the JSON the previous package wrote")
struct StoredRecordGoldenTests {

	@Test("The values encode to exactly the stored text")
	func valuesEncode() throws {
		#expect(try encoded(Golden.reportValue) == Golden.report)
		#expect(try encoded(Golden.missValue) == Golden.missReport)
		#expect(try encoded(Golden.scoresValue) == Golden.scores)
		#expect(try encoded(NodeScores<String>([:])) == Golden.emptyScores)
		#expect(try encoded(Golden.partitionValue) == Golden.partition)
		#expect(try encoded(Golden.selectionValue) == Golden.selection)
		#expect(try encoded(NodeSelection<String>([])) == Golden.emptySelection)
		#expect(try encoded(DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.reportValue)) == Golden.diagWith)
		#expect(try encoded(DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.missValue)) == Golden.diagMiss)
		#expect(try encoded(DiagnosedScores(scores: Golden.scoresValue, convergence: nil)) == Golden.diagWithout)
	}

	@Test("The stored text decodes to equal values")
	func valuesDecode() throws {
		#expect(try decoded(ConvergenceReport.self, Golden.report) == Golden.reportValue)
		#expect(try decoded(ConvergenceReport.self, Golden.missReport) == Golden.missValue)
		#expect(try decoded(NodeScores<String>.self, Golden.scores) == Golden.scoresValue)
		#expect(try decoded(NodeScores<String>.self, Golden.emptyScores) == NodeScores<String>([:]))
		#expect(try decoded(NodePartition<String>.self, Golden.partition) == Golden.partitionValue)
		#expect(try decoded(NodeSelection<String>.self, Golden.selection) == Golden.selectionValue)
		#expect(try decoded(NodeSelection<String>.self, Golden.emptySelection) == NodeSelection<String>([]))
		#expect(try decoded(DiagnosedScores<String>.self, Golden.diagWith)
			== DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.reportValue))
		#expect(try decoded(DiagnosedScores<String>.self, Golden.diagMiss)
			== DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.missValue))
		#expect(try decoded(DiagnosedScores<String>.self, Golden.diagWithout)
			== DiagnosedScores(scores: Golden.scoresValue, convergence: nil))
	}

	@Test("Envelopes of each value encode to exactly the stored text")
	func envelopesEncode() throws {
		#expect(try encoded(try MetricEnvelope(Golden.scoresValue)) == Golden.envScores)
		#expect(try encoded(try MetricEnvelope(Golden.partitionValue)) == Golden.envPartition)
		#expect(try encoded(try MetricEnvelope(Golden.selectionValue)) == Golden.envSelection)
		#expect(try encoded(try MetricEnvelope(
			DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.reportValue))) == Golden.envDiagWith)
		#expect(try encoded(try MetricEnvelope(
			DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.missValue))) == Golden.envDiagMiss)
		#expect(try encoded(try MetricEnvelope(
			DiagnosedScores(scores: Golden.scoresValue, convergence: nil))) == Golden.envDiagWithout)
		let unknown = MetricEnvelope(kind: "assignment", payload: .object([
			"sites": .array([.string("x"), .string("y")]), "cost": .number(5.2078),
			"ok": .bool(true), "none": .null,
		]))
		#expect(try encoded(unknown) == Golden.envUnknown)
	}

	@Test("Stored envelopes decode, yield equal typed values and the same convergence")
	func envelopesDecode() throws {
		let scores = try decoded(MetricEnvelope.self, Golden.envScores)
		#expect(scores.kind == "scores")
		#expect(try scores.value(as: NodeScores<String>.self) == Golden.scoresValue)
		#expect(scores.convergence == nil)

		let partition = try decoded(MetricEnvelope.self, Golden.envPartition)
		#expect(partition.kind == "partition")
		#expect(try partition.value(as: NodePartition<String>.self) == Golden.partitionValue)

		let selection = try decoded(MetricEnvelope.self, Golden.envSelection)
		#expect(selection.kind == "selection")
		#expect(try selection.value(as: NodeSelection<String>.self) == Golden.selectionValue)

		let with = try decoded(MetricEnvelope.self, Golden.envDiagWith)
		#expect(try with.value(as: DiagnosedScores<String>.self)
			== DiagnosedScores(scores: Golden.scoresValue, convergence: Golden.reportValue))
		#expect(with.convergence == Golden.reportValue)

		let miss = try decoded(MetricEnvelope.self, Golden.envDiagMiss)
		#expect(miss.convergence == Golden.missValue)
		#expect(miss.convergence?.converged == false)

		let without = try decoded(MetricEnvelope.self, Golden.envDiagWithout)
		#expect(try without.value(as: DiagnosedScores<String>.self)?.convergence == nil)
		#expect(without.convergence == nil)
		// The same payload as plain scores: no convergence key, so the version 3 shape.
		#expect(without == scores)

		let unknown = try decoded(MetricEnvelope.self, Golden.envUnknown)
		#expect(unknown.kind == "assignment")
		#expect(try unknown.value(as: NodeScores<String>.self) == nil)
	}

	@Test("Re-encoding a decoded stored envelope reproduces the stored text")
	func envelopesReencode() throws {
		for text in [
			Golden.envScores, Golden.envPartition, Golden.envSelection, Golden.envDiagWith,
			Golden.envDiagMiss, Golden.envDiagWithout, Golden.envUnknown,
		] {
			#expect(try encoded(try decoded(MetricEnvelope.self, text)) == text)
		}
	}

	@Test("The sentences for the stored reports are the ones the previous package wrote")
	func storedSentences() {
		#expect(ConvergenceNote.sentence(Golden.reportValue)
			== "Converged in 151 passes (final change 8.20E-11, tolerance 1.00E-10).")
		#expect(ConvergenceNote.sentence(Golden.missValue)
			== "Did not converge: stopped at the 200-pass ceiling with a final change of 4.70E-2 "
			+ "against a tolerance of 1.00E-10, so these scores may be far from the true "
			+ "eigenvector. Raise maxIterations to check.")
		#expect(ConvergenceNote.sentence(nil) == "Convergence was not recorded for this result.")
	}
}
