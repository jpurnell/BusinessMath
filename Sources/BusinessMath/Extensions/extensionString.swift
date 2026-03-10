//
//  extensionString.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/2/25.
//

/// Returns a new string formed from the String by appending as many occurrences as necessary of a given pad string to the beginning of a string.
/// /// - Parameters:
///   - toLength: Number of characters to add
///   - withPad: The character to append to the beginning of the string
extension StringProtocol {
	/// Returns a new string padded on the left to the specified length.
	///
	/// If the string is shorter than the target length, the padding character is
	/// repeated and prepended. If the string is longer, only the suffix is returned.
	///
	/// - Parameters:
	///   - toLength: The target length of the resulting string.
	///   - character: The character used for padding. Defaults to space.
	/// - Returns: A string padded to the specified length, or the suffix if longer.
	public func paddingLeft(toLength: Int, withPad character: Character = " ") -> String {
		let stringLength = self.count
		if stringLength < toLength {
			return String(repeatElement(character, count: toLength - stringLength)) + self
		} else {
			return String(self.suffix(toLength))
		}
	}
}
