//
//  JSONSerializer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - JSONSerializationError

/// Errors that can occur during JSON serialization operations.
public enum JSONSerializationError: Error, Sendable {
	/// The data could not be encoded to JSON.
	case encodingFailed

	/// The data could not be decoded from JSON.
	case decodingFailed

	/// The file could not be read.
	case fileReadError(URL)

	/// The file could not be written.
	case fileWriteError(URL)
}

// MARK: - JSONSerializer

/// Serializes and deserializes BusinessMath types to/from JSON.
///
/// `JSONSerializer` provides convenient methods for JSON encoding and decoding
/// of financial data types, with support for both Data and String representations,
/// as well as file I/O.
///
/// ## Basic Usage
///
/// ```swift
/// let serializer = JSONSerializer()
///
/// // To JSON string
/// let jsonString = try serializer.toJSONString(timeSeries, pretty: true)
///
/// // From JSON string
/// let decoded = try serializer.fromJSONString(
///     TimeSeries<Double>.self,
///     from: jsonString
/// )
///
/// // To file
/// try serializer.exportToJSON(timeSeries, to: fileURL)
///
/// // From file
/// let imported = try serializer.importFromJSON(
///     TimeSeries<Double>.self,
///     from: fileURL
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Serializers
/// - ``init(encoder:decoder:)``
///
/// ### String Conversion
/// - ``toJSONString(_:pretty:)``
/// - ``fromJSONString(_:from:)``
///
/// ### File I/O
/// - ``exportToJSON(_:to:)``
/// - ``importFromJSON(_:from:)``
public struct JSONSerializer: Sendable {

	// MARK: - Properties

	/// The JSON encoder to use for serialization.
	public let encoder: JSONEncoder

	/// The JSON decoder to use for deserialization.
	public let decoder: JSONDecoder

	// MARK: - Initialization

	/// Creates a new JSON serializer.
	///
	/// - Parameters:
	///   - encoder: The JSON encoder to use. Defaults to a new `JSONEncoder`.
	///   - decoder: The JSON decoder to use. Defaults to a new `JSONDecoder`.
	public init(encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
		self.encoder = encoder
		self.decoder = decoder
	}

	// MARK: - String Conversion

	/// Converts a Codable value to a JSON string.
	///
	/// - Parameters:
	///   - value: The value to encode.
	///   - pretty: Whether to format the JSON with indentation. Defaults to false.
	///
	/// - Returns: A JSON string representation of the value.
	///
	/// - Throws: `JSONSerializationError.encodingFailed` if encoding fails.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: periods, values: values)
	/// let json = try JSONSerializer().toJSONString(timeSeries, pretty: true)
	/// print(json)
	/// ```
	public func toJSONString<T: Encodable>(_ value: T, pretty: Bool = false) throws -> String {
		let encoder = self.encoder
		if pretty {
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		}

		do {
			let data = try encoder.encode(value)
			guard let string = String(data: data, encoding: .utf8) else {
				throw JSONSerializationError.encodingFailed
			}
			return string
		} catch {
			throw JSONSerializationError.encodingFailed
		}
	}

	/// Decodes a Codable value from a JSON string.
	///
	/// - Parameters:
	///   - type: The type to decode.
	///   - jsonString: The JSON string to decode from.
	///
	/// - Returns: The decoded value.
	///
	/// - Throws: `JSONSerializationError.decodingFailed` if decoding fails.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = try JSONSerializer().fromJSONString(
	///     TimeSeries<Double>.self,
	///     from: jsonString
	/// )
	/// ```
	public func fromJSONString<T: Decodable>(_ type: T.Type, from jsonString: String) throws -> T {
		guard let data = jsonString.data(using: .utf8) else {
			throw JSONSerializationError.decodingFailed
		}

		do {
			return try decoder.decode(type, from: data)
		} catch {
			throw JSONSerializationError.decodingFailed
		}
	}

	// MARK: - File I/O

	/// Exports a Codable value to a JSON file.
	///
	/// - Parameters:
	///   - value: The value to export.
	///   - url: The destination file URL.
	///
	/// - Throws:
	///   - `JSONSerializationError.encodingFailed`: If encoding fails.
	///   - `JSONSerializationError.fileWriteError`: If the file cannot be written.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: periods, values: values)
	/// try JSONSerializer().exportToJSON(timeSeries, to: fileURL)
	/// ```
	public func exportToJSON<T: Encodable>(_ value: T, to url: URL) throws {
		do {
			let data = try encoder.encode(value)
			try data.write(to: url, options: [.atomic])
		} catch is EncodingError {
			throw JSONSerializationError.encodingFailed
		} catch {
			throw JSONSerializationError.fileWriteError(url)
		}
	}

	/// Imports a Codable value from a JSON file.
	///
	/// - Parameters:
	///   - type: The type to decode.
	///   - url: The source file URL.
	///
	/// - Returns: The decoded value.
	///
	/// - Throws:
	///   - `JSONSerializationError.fileReadError`: If the file cannot be read.
	///   - `JSONSerializationError.decodingFailed`: If decoding fails.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = try JSONSerializer().importFromJSON(
	///     TimeSeries<Double>.self,
	///     from: fileURL
	/// )
	/// ```
	public func importFromJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
		let data: Data
		do {
			data = try Data(contentsOf: url)
		} catch {
			throw JSONSerializationError.fileReadError(url)
		}

		do {
			return try decoder.decode(type, from: data)
		} catch {
			throw JSONSerializationError.decodingFailed
		}
	}
}
