//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation


enum GoalSeekError: Error {
	case divisionByZero
	case convergenceFailed
}

extension GoalSeekError: LocalizedError {
	public var errorDescription: String? {
		switch self {
			case .divisionByZero:
				return NSLocalizedString("The derivative was zero, resulting in division by zero.", comment: "Division by Zero")
			case .convergenceFailed:
				return NSLocalizedString("The function failed to converge within the specified number of iterations.", comment: "Convergence Failed")
		}
	}
}
