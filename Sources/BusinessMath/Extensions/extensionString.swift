//
//  extensionString.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/2/25.
//

extension String {
	public func paddingLeft(toLength: Int, withPad character: Character = " ") -> String {
		let stringLength = self.count
		if stringLength < toLength {
			return String(repeatElement(character, count: toLength - stringLength)) + self
		} else {
			return String(self.suffix(toLength))
		}
	}
}
