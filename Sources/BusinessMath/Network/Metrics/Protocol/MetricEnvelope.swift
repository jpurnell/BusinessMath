//
//  MetricEnvelope.swift
//  BusinessMath
//

import Foundation

/// A JSON value, held without interpretation.
///
/// What a ``MetricEnvelope`` keeps of a result whose type the reader does not know. Numbers
/// are held as `Double`, so integers are exact up to 2^53, which covers every identifier
/// and count these metrics produce.
///
/// ```swift
/// let value = JSONValue.object(["n": .number(2), "tags": .array([.string("x")])])
/// print(value == .object(["n": .number(2), "tags": .array([.string("x")])]))   // true
/// ```
public enum JSONValue: Sendable, Codable, Hashable {
	/// JSON `null`.
	case null
	/// A boolean.
	case bool(Bool)
	/// A number.
	case number(Double)
	/// A string.
	case string(String)
	/// An array.
	case array([JSONValue])
	/// An object.
	case object([String: JSONValue])

	/// Decodes any JSON value.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .bool(value)
		} else if let value = try? container.decode(Double.self) {
			self = .number(value)
		} else if let value = try? container.decode(String.self) {
			self = .string(value)
		} else if let value = try? container.decode([JSONValue].self) {
			self = .array(value)
		} else {
			self = .object(try container.decode([String: JSONValue].self))
		}
	}

	/// Encodes as the equivalent JSON.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .null: try container.encodeNil()
		case .bool(let value): try container.encode(value)
		case .number(let value): try container.encode(value)
		case .string(let value): try container.encode(value)
		case .array(let value): try container.encode(value)
		case .object(let value): try container.encode(value)
		}
	}
}

/// A metric result with its concrete type erased: `{ "kind": ..., "payload": ... }`.
///
/// ## Why an envelope
///
/// A registry holds metrics of different result shapes, and a stored result outlives the
/// code that wrote it. The envelope files the payload under its ``MetricValue/kind``, so:
///
/// - a reader that knows the kind recovers the typed value with ``value(as:)``;
/// - a reader that does not know it still decodes the envelope — the payload is held as
///   ``JSONValue`` — and can store, copy or re-encode it unchanged. An unknown kind is
///   never a decoding failure.
///
/// The payload is held as JSON rather than as the typed value so that what is compared,
/// stored and re-encoded is the same thing in memory and on disk. The cost is one
/// encode and decode per result, which is negligible beside computing a metric.
///
/// ```swift
/// let envelope = try MetricEnvelope(NodeScores(["a": 1.0]))
/// print(envelope.kind)   // "scores"
/// let scores = try envelope.value(as: NodeScores<String>.self)
/// print(scores?["a"] ?? 0)   // 1.0
/// ```
public struct MetricEnvelope: Sendable, Codable, Hashable {

	/// The ``MetricValue/kind`` of the payload.
	public let kind: String

	/// The payload, uninterpreted.
	public let payload: JSONValue

	/// Creates an envelope from raw parts.
	public init(kind: String, payload: JSONValue) {
		self.kind = kind
		self.payload = payload
	}

	/// Wraps a typed result.
	///
	/// - Throws: If the value cannot be encoded — for instance a score that is `NaN`,
	///   which JSON cannot represent.
	public init<Value: MetricValue>(_ value: Value) throws {
		let data = try JSONEncoder().encode(value)
		self.kind = Value.kind
		self.payload = try JSONDecoder().decode(JSONValue.self, from: data)
	}

	/// Recovers a typed result.
	///
	/// - Parameter type: The shape to decode as.
	/// - Returns: The value, or `nil` if this envelope holds a different kind.
	/// - Throws: If the kind matches but the payload does not decode.
	public func value<Value: MetricValue>(as type: Value.Type) throws -> Value? {
		guard kind == Value.kind else { return nil }
		let data = try JSONEncoder().encode(payload)
		return try JSONDecoder().decode(Value.self, from: data)
	}
}

extension MetricEnvelope {
	/// How the iteration behind this result ended, if the result records it.
	///
	/// Read from the payload without knowing the node type, so a command-line tool can ask
	/// any stored envelope. `nil` means unknown, not "did not converge": it is what a result
	/// stored before the metric reported convergence (eigenvector version 3 and earlier), a
	/// non-iterative metric, or a different result shape all give.
	public var convergence: ConvergenceReport? {
		guard kind == DiagnosedScores<String>.kind,
			  case .object(let fields) = payload,
			  let found = fields["convergence"],
			  let data = try? JSONEncoder().encode(found)
		else { return nil }
		return try? JSONDecoder().decode(ConvergenceReport.self, from: data)
	}
}
