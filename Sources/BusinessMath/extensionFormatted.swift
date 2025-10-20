//
//  File.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/19/25.
//

import Foundation

extension BinaryFloatingPoint {
	@available(macOS 12.0, *)
	public func currency(_ currency: String = "usd") -> String {
		return self.formatted(.currency(code: currency).presentation(.narrow))
	}
}
