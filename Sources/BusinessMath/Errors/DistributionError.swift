//
//  DistributionError.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/23/25.
//

import Foundation

public enum DistributionError: Error, LocalizedError {
	case invalidDegreesOfFreedom(Int)
	case invalidParameter(String)

	public var errorDescription: String? {
		switch self {
		case .invalidDegreesOfFreedom(let df):
			return "Degrees of freedom must be positive, got \(df)"
		case .invalidParameter(let message):
			return "Invalid parameter: \(message)"
		}
	}
}
