//
//  MetricEnvelopeTests.swift
//  BusinessMath
//
//  The envelope, JSONValue, ConvergenceReport, ConvergenceNote and DiagnosedScores. Ported
//  from SwiftGraphMetrics (ValueTests, EigenvectorDiagnosticsTests, the value-type mutation
//  audit) and extended. Synthetic data only.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private func report(
	_ iterations: Int, _ converged: Bool, _ residual: Double, _ tolerance: Double, _ ceiling: Int
) -> ConvergenceReport {
	ConvergenceReport(
		iterations: iterations, converged: converged, residual: residual,
		tolerance: tolerance, maxIterations: ceiling)
}

@Suite("MetricEnvelope: round trips and unknown kinds")
struct MetricEnvelopeTests {

	@Test("Each built-in value round-trips through its envelope exactly")
	func envelopeRoundTrip() throws {
		let scores = NodeScores(["a": 0.1, "b": 0.2, "c": 0.30000000000000004])
		let partition = NodePartition(["a": 0, "b": 1])
		let selection = NodeSelection<String>(picks: [("a", 0.1), ("b", 0.2)])
		let diagnosed = DiagnosedScores(scores: scores, convergence: report(9, true, 1e-12, 1e-10, 50))

		#expect(try MetricEnvelope(scores).value(as: NodeScores<String>.self) == scores)
		#expect(try MetricEnvelope(partition).value(as: NodePartition<String>.self) == partition)
		#expect(try MetricEnvelope(selection).value(as: NodeSelection<String>.self) == selection)
		#expect(try MetricEnvelope(diagnosed).value(as: DiagnosedScores<String>.self) == diagnosed)
	}

	@Test("The envelope carries the kind of what it wraps")
	func kindCarried() throws {
		#expect(try MetricEnvelope(NodeScores(["a": 1.0])).kind == "scores")
		#expect(try MetricEnvelope(NodePartition(["a": 1])).kind == "partition")
		#expect(try MetricEnvelope(NodeSelection<String>(picks: [("a", 1)])).kind == "selection")
		#expect(try MetricEnvelope(DiagnosedScores(scores: NodeScores(["a": 1.0]), convergence: nil)).kind == "scores")
	}

	@Test("A node type that is not a string still round-trips")
	func integerNodeEnvelope() throws {
		let scores = NodeScores<Int>([1: 0.5, 2: 0.25])
		let envelope = try MetricEnvelope(scores)
		let data = try JSONEncoder().encode(envelope)
		let back = try JSONDecoder().decode(MetricEnvelope.self, from: data)
		#expect(try back.value(as: NodeScores<Int>.self) == scores)
	}

	@Test("Seeded: random values survive value to envelope to JSON text to envelope to value",
		arguments: [UInt64(1), 2, 3, 4, 5, 6, 7, 8])
	func seededRoundTrip(seed: UInt64) throws {
		let rng = SeededRNG(seed: seed)
		var table: [String: Double] = [:]
		var groups: [String: Int] = [:]
		var picks: [NodeSelection<String>.Pick] = []
		for index in 0..<25 {
			table["n\(index)"] = rng.next() * 1000 - 500
			groups["n\(index)"] = Int(rng.next() * 5)
			picks.append(NodeSelection<String>.Pick(node: "n\(index)", marginalGain: rng.next()))
		}
		let scores = NodeScores(table)
		let partition = NodePartition(groups)
		let selection = NodeSelection<String>(picks)
		let convergence = report(Int(rng.next() * 200), rng.next() < 0.5, rng.next(), 1e-10, 200)
		let diagnosed = DiagnosedScores(scores: scores, convergence: convergence)

		func trip<Value: MetricValue>(_ value: Value) throws -> Value? {
			let wire = try JSONEncoder().encode(try MetricEnvelope(value))
			return try JSONDecoder().decode(MetricEnvelope.self, from: wire).value(as: Value.self)
		}
		#expect(try trip(scores) == scores, "seed \(seed)")
		#expect(try trip(partition) == partition, "seed \(seed)")
		#expect(try trip(selection) == selection, "seed \(seed)")
		#expect(try trip(diagnosed) == diagnosed, "seed \(seed)")

		// Direct coding, without the envelope, agrees as well.
		let direct = try JSONDecoder().decode(
			DiagnosedScores<String>.self, from: try JSONEncoder().encode(diagnosed))
		#expect(direct == diagnosed, "seed \(seed)")
		let envelope = try MetricEnvelope(diagnosed)
		#expect(envelope.convergence == convergence, "seed \(seed)")
	}

	@Test("Typed access is nil for a different known kind and never throws for it")
	func wrongKind() throws {
		let envelope = try MetricEnvelope(NodePartition(["a": 0]))
		#expect(try envelope.value(as: NodeScores<String>.self) == nil)
		#expect(try envelope.value(as: NodeSelection<String>.self) == nil)
		let same = try #require(try envelope.value(as: NodePartition<String>.self))
		#expect(same == NodePartition(["a": 0]))
	}

	/// A reader who has never heard of a kind must not fail on it.
	@Test("An unknown kind decodes as an opaque envelope and survives re-encoding")
	func unknownKind() throws {
		let json = #"{"kind":"assignment","payload":{"sites":["x","y"],"cost":5.2078}}"#
		let envelope = try JSONDecoder().decode(MetricEnvelope.self, from: Data(json.utf8))
		#expect(envelope.kind == "assignment")
		#expect(try envelope.value(as: NodeScores<String>.self) == nil)
		#expect(try envelope.value(as: NodePartition<String>.self) == nil)
		#expect(envelope.convergence == nil)

		let again = try JSONDecoder().decode(
			MetricEnvelope.self, from: try JSONEncoder().encode(envelope))
		#expect(again == envelope)
		#expect(again.payload == .object([
			"sites": .array([.string("x"), .string("y")]), "cost": .number(5.2078),
		]))
	}

	@Test("A known kind with a malformed payload throws")
	func malformedPayload() {
		let envelope = MetricEnvelope(kind: "scores", payload: .string("not scores"))
		#expect(throws: (any Error).self) {
			try envelope.value(as: NodeScores<String>.self)
		}
		let wrongShape = MetricEnvelope(kind: "partition", payload: .object(["communities": .string("x")]))
		#expect(throws: (any Error).self) {
			try wrongShape.value(as: NodePartition<String>.self)
		}
	}

	@Test("An envelope missing its kind or its payload does not decode")
	func incompleteEnvelope() {
		let noKind = Data(#"{"payload":{}}"#.utf8)
		let noPayload = Data(#"{"kind":"scores"}"#.utf8)
		#expect(throws: (any Error).self) { try JSONDecoder().decode(MetricEnvelope.self, from: noKind) }
		#expect(throws: (any Error).self) { try JSONDecoder().decode(MetricEnvelope.self, from: noPayload) }
	}

	@Test("The raw initialiser keeps its parts")
	func rawInit() {
		let envelope = MetricEnvelope(kind: "k", payload: .number(1))
		#expect(envelope.kind == "k")
		#expect(envelope.payload == .number(1))
		#expect(envelope != MetricEnvelope(kind: "k", payload: .number(2)))
		#expect(envelope != MetricEnvelope(kind: "j", payload: .number(1)))
	}

	@Test("A custom value type travels through an envelope")
	func customValue() throws {
		struct Count: MetricValue {
			static let kind = "count"
			let value: Int
		}
		let envelope = try MetricEnvelope(Count(value: 2))
		#expect(envelope.kind == "count")
		#expect(try envelope.value(as: Count.self)?.value == 2)
		#expect(try envelope.value(as: NodeScores<String>.self) == nil)
	}

	@Test("A null payload decodes as null and re-encodes")
	func nullPayload() throws {
		let json = #"{"kind":"nothing","payload":null}"#
		let envelope = try JSONDecoder().decode(MetricEnvelope.self, from: Data(json.utf8))
		#expect(envelope.payload == .null)
		let again = try JSONDecoder().decode(
			MetricEnvelope.self, from: try JSONEncoder().encode(envelope))
		#expect(again == envelope)
	}

	@Test("JSONValue decodes every JSON shape and encodes it back")
	func jsonValueShapes() throws {
		func decode(_ text: String) throws -> JSONValue {
			try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
		}
		#expect(try decode("null") == .null)
		#expect(try decode("true") == .bool(true))
		#expect(try decode("false") == .bool(false))
		#expect(try decode("1.5") == .number(1.5))
		#expect(try decode("-3") == .number(-3))
		#expect(try decode("\"x\"") == .string("x"))
		#expect(try decode("[null,\"x\"]") == .array([.null, .string("x")]))
		#expect(try decode("{\"a\":{\"b\":[1,true]}}")
			== .object(["a": .object(["b": .array([.number(1), .bool(true)])])]))
		#expect(try decode("[]") == .array([]))
		#expect(try decode("{}") == .object([:]))

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		let value = JSONValue.object([
			"z": .null, "a": .bool(false), "m": .array([.number(0.5), .string("s")]),
		])
		#expect(String(decoding: try encoder.encode(value), as: UTF8.self)
			== #"{"a":false,"m":[0.5,"s"],"z":null}"#)
	}

	@Test("A number is never read as a boolean, nor a boolean as a number")
	func numbersAndBooleans() throws {
		let decoded = try JSONDecoder().decode(
			JSONValue.self, from: Data("[0,1,true,false]".utf8))
		#expect(decoded == .array([.number(0), .number(1), .bool(true), .bool(false)]))
	}
}

@Suite("MetricEnvelope.convergence and DiagnosedScores")
struct ConvergenceEnvelopeTests {

	private let reportValue = report(151, true, 8.2e-11, 1e-10, 200)

	@Test("The convergence accessor reads a diagnosed scores envelope")
	func accessorReads() throws {
		let diagnosed = DiagnosedScores(scores: NodeScores(["a": 1.0]), convergence: reportValue)
		let envelope = try MetricEnvelope(diagnosed)
		#expect(envelope.convergence == reportValue)
		let found = try #require(envelope.convergence)
		#expect(found.iterations == 151)
		#expect(found.converged)
		#expect(found.residual.isEqual(to: 8.2e-11))
		#expect(found.tolerance.isEqual(to: 1e-10))
		#expect(found.maxIterations == 200)
	}

	@Test("A stored version 3 envelope decodes, and its convergence reads as unknown")
	func oldShapeDecodes() throws {
		let stored = #"{"kind":"scores","payload":{"scores":{"a":1,"b":0.5}}}"#
		let envelope = try JSONDecoder().decode(MetricEnvelope.self, from: Data(stored.utf8))
		#expect(envelope.convergence == nil)
		let typed = try #require(try envelope.value(as: DiagnosedScores<String>.self))
		#expect(typed.convergence == nil)
		#expect(typed.scores == NodeScores(["a": 1, "b": 0.5]))
		// A consumer that only knows plain scores reads the same payload.
		#expect(try envelope.value(as: NodeScores<String>.self) == NodeScores(["a": 1, "b": 0.5]))
		#expect(ConvergenceNote.sentence(envelope.convergence)
			== "Convergence was not recorded for this result.")
	}

	@Test("A version 4 envelope is still readable as plain NodeScores")
	func plainReaderStillWorks() throws {
		let envelope = try MetricEnvelope(
			DiagnosedScores(scores: NodeScores(["a": 1.0, "b": 2.0]), convergence: reportValue))
		let plain = try #require(try envelope.value(as: NodeScores<String>.self))
		#expect(plain == NodeScores(["a": 1.0, "b": 2.0]))
	}

	@Test("Only a scores envelope is read for convergence, whatever another kind's payload holds")
	func otherKindWithLookalikeKey() throws {
		let payload = #"""
		{"convergence":{"iterations":3,"converged":true,"residual":0,"tolerance":1e-10,"maxIterations":200}}
		"""#
		let lookalike = MetricEnvelope(
			kind: "something-else",
			payload: try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8)))
		#expect(lookalike.convergence == nil)
		let real = MetricEnvelope(kind: "scores", payload: lookalike.payload)
		#expect(real.convergence?.iterations == 3)
		let partition = MetricEnvelope(kind: "partition", payload: lookalike.payload)
		#expect(partition.convergence == nil)
	}

	@Test("Convergence reads as unknown for a non-object payload, a null or a malformed report")
	func unreadableConvergence() {
		#expect(MetricEnvelope(kind: "scores", payload: .null).convergence == nil)
		#expect(MetricEnvelope(kind: "scores", payload: .array([])).convergence == nil)
		#expect(MetricEnvelope(kind: "scores", payload: .object(["convergence": .null])).convergence == nil)
		#expect(MetricEnvelope(kind: "scores", payload: .object(["convergence": .string("x")])).convergence == nil)
		#expect(MetricEnvelope(kind: "scores", payload: .object([
			"convergence": .object(["iterations": .number(1)]),
		])).convergence == nil)
		#expect(MetricEnvelope(kind: "scores", payload: .object(["scores": .object([:])])).convergence == nil)
	}

	@Test("Decoding DiagnosedScores directly: absent and null convergence are nil, malformed throws")
	func diagnosedDecoding() throws {
		func decode(_ text: String) throws -> DiagnosedScores<String> {
			try JSONDecoder().decode(DiagnosedScores<String>.self, from: Data(text.utf8))
		}
		#expect(try decode(#"{"scores":{"a":1}}"#).convergence == nil)
		#expect(try decode(#"{"scores":{"a":1},"convergence":null}"#).convergence == nil)
		let full = try decode(
			#"{"scores":{"a":1},"convergence":{"iterations":2,"converged":false,"residual":0.5,"tolerance":1e-10,"maxIterations":2}}"#)
		#expect(full.convergence == report(2, false, 0.5, 1e-10, 2))
		#expect(throws: (any Error).self) { try decode(#"{"convergence":null}"#) }
		#expect(throws: (any Error).self) { try decode(#"{"scores":{"a":1},"convergence":{"iterations":2}}"#) }
	}

	@Test("A nil convergence is omitted from the encoding, not written as null")
	func nilConvergenceOmitted() throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		let text = String(
			decoding: try encoder.encode(DiagnosedScores(scores: NodeScores(["a": 1.0]), convergence: nil)),
			as: UTF8.self)
		#expect(text == #"{"scores":{"a":1}}"#)
		#expect(text.contains("convergence") == false)
	}

	@Test("ConvergenceReport round-trips and compares field by field")
	func reportCoding() throws {
		let original = report(7, false, 0.125, 1e-6, 9)
		let back = try JSONDecoder().decode(
			ConvergenceReport.self, from: try JSONEncoder().encode(original))
		#expect(back == original)
		#expect(original != report(8, false, 0.125, 1e-6, 9))
		#expect(original != report(7, true, 0.125, 1e-6, 9))
		#expect(original != report(7, false, 0.25, 1e-6, 9))
		#expect(original != report(7, false, 0.125, 1e-7, 9))
		#expect(original != report(7, false, 0.125, 1e-6, 10))
	}

	@Test("Seeded: DiagnosedScores with and without a report round-trip through JSON",
		arguments: [UInt64(21), 22, 23, 24])
	func seededDiagnosed(seed: UInt64) throws {
		let rng = SeededRNG(seed: seed)
		var table: [String: Double] = [:]
		for index in 0..<10 { table["n\(index)"] = rng.next() }
		for convergence in [nil, report(Int(rng.next() * 300), rng.next() < 0.5, rng.next() * 1e-3, 1e-10, 300)] {
			let value = DiagnosedScores(scores: NodeScores(table), convergence: convergence)
			let back = try JSONDecoder().decode(
				DiagnosedScores<String>.self, from: try JSONEncoder().encode(value))
			#expect(back == value, "seed \(seed)")
			#expect(back.scores == value.scores, "seed \(seed)")
			#expect(back.convergence == convergence, "seed \(seed)")
		}
	}

	@Test("The sentence says which it was, with the numbers")
	func sentences() {
		#expect(ConvergenceNote.sentence(report(151, true, 8.2e-11, 1e-10, 200))
			== "Converged in 151 passes (final change 8.20E-11, tolerance 1.00E-10).")
		#expect(ConvergenceNote.sentence(report(1, true, 0, 1e-10, 200))
			== "Converged in 1 pass (final change 0.00E0, tolerance 1.00E-10).")
		#expect(ConvergenceNote.sentence(report(0, true, 0, 1e-3, 200))
			== "Converged in 0 passes (final change 0.00E0, tolerance 1.00E-3).")
		#expect(ConvergenceNote.sentence(report(2, true, 123456, 0.5, 200))
			== "Converged in 2 passes (final change 1.23E5, tolerance 5.00E-1).")
		#expect(ConvergenceNote.sentence(report(3, true, 1e-11, 1e-10, 200)).hasPrefix("Converged in 3 passes ("))
		#expect(ConvergenceNote.sentence(nil) == "Convergence was not recorded for this result.")
	}

	@Test("A miss names the ceiling, not the passes run, and says what to do")
	func missSentences() {
		#expect(ConvergenceNote.sentence(report(200, false, 4.7e-2, 1e-10, 200))
			== "Did not converge: stopped at the 200-pass ceiling with a final change of 4.70E-2 "
			+ "against a tolerance of 1.00E-10, so these scores may be far from the true "
			+ "eigenvector. Raise maxIterations to check.")
		#expect(ConvergenceNote.sentence(report(1, false, 1e-3, 1e-10, 1))
			== "Did not converge: stopped at the 1-pass ceiling with a final change of 1.00E-3 "
			+ "against a tolerance of 1.00E-10, so these scores may be far from the true "
			+ "eigenvector. Raise maxIterations to check.")
		#expect(ConvergenceNote.sentence(report(5, false, 0.99949, 1e-10, 5))
			== "Did not converge: stopped at the 5-pass ceiling with a final change of 9.99E-1 "
			+ "against a tolerance of 1.00E-10, so these scores may be far from the true "
			+ "eigenvector. Raise maxIterations to check.")
		// The ceiling and the passes run are different numbers when a report says so.
		let early = ConvergenceNote.sentence(report(150, false, 1e-3, 1e-10, 200))
		#expect(early.contains("the 200-pass ceiling"))
		#expect(early.contains("150") == false)
	}
}
