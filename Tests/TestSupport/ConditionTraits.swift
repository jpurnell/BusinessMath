//
//  ConditionTraits.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/28/26.
//
import Testing
import Foundation

extension Trait where Self == ConditionTrait {
	public static var localOnly: Self {
		.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true")
	}
	
	public static var requiresParallelHardware: Self {
		.enabled(if: ProcessInfo.processInfo.environment["RUN_PARALLEL_TESTS"] == "1", "Skipped in CI: set RUN_PARALLEL_TESTS=1 to enable")
	}
}
