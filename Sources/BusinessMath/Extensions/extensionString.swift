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
	public func paddingLeft(toLength: Int, withPad character: Character = " ") -> String {
		let stringLength = self.count
		if stringLength < toLength {
			return String(repeatElement(character, count: toLength - stringLength)) + self
		} else {
			return String(self.suffix(toLength))
		}
	}
}
