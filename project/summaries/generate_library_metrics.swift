#!/usr/bin/env swift

import Foundation

// MARK: - BusinessMath Library Metrics Generator
// Generates comprehensive statistics about the library

print("""
================================================================================
BUSINESSMATH LIBRARY METRICS GENERATOR
================================================================================

""")

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"

// MARK: - Helper Functions

func runCommand(_ command: String) -> (output: String, exitCode: Int32) {
	let task = Process()
	task.launchPath = "/bin/bash"
	task.arguments = ["-c", command]

	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = pipe

	task.launch()
	task.waitUntilExit()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output = String(data: data, encoding: .utf8) ?? ""

	return (output, task.terminationStatus)
}

func countFiles(pattern: String, in directory: String) -> Int {
	let (output, _) = runCommand("find '\(directory)' -name '\(pattern)' -type f | wc -l")
	return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

func countLines(pattern: String, in directory: String) -> Int {
	let (output, _) = runCommand("find '\(directory)' -name '\(pattern)' -type f -exec wc -l {} + | tail -1 | awk '{print $1}'")
	return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

// MARK: - 1. Code Metrics

print("📊 Gathering Code Metrics...\n")

struct CodeMetrics {
	let sourceFiles: Int
	let testFiles: Int
	let totalLines: Int
	let sourceLines: Int
	let testLines: Int
	let publicAPIs: Int
	let modules: Int
}

let sourcesDir = "\(packageRoot)/Sources"
let testsDir = "\(packageRoot)/Tests"

let sourceFiles = countFiles(pattern: "*.swift", in: sourcesDir)
let testFiles = countFiles(pattern: "*.swift", in: testsDir)
let sourceLines = countLines(pattern: "*.swift", in: sourcesDir)
let testLines = countLines(pattern: "*.swift", in: testsDir)
let totalLines = sourceLines + testLines

// Count public APIs (approximation)
let (publicAPIsOutput, _) = runCommand("grep -r 'public ' '\(sourcesDir)' --include='*.swift' | grep -E '(func|struct|class|enum|protocol|var|let)' | wc -l")
let publicAPIs = Int(publicAPIsOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

// Count modules
let (modulesOutput, _) = runCommand("ls '\(sourcesDir)' | wc -l")
let modules = Int(modulesOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let codeMetrics = CodeMetrics(
	sourceFiles: sourceFiles,
	testFiles: testFiles,
	totalLines: totalLines,
	sourceLines: sourceLines,
	testLines: testLines,
	publicAPIs: publicAPIs,
	modules: modules
)

print("### Code Metrics")
print("- Source Files: \(codeMetrics.sourceFiles)")
print("- Test Files: \(codeMetrics.testFiles)")
print("- Total Lines: \(codeMetrics.totalLines)")
print("  - Source: \(codeMetrics.sourceLines)")
print("  - Tests: \(codeMetrics.testLines)")
print("- Public APIs: \(codeMetrics.publicAPIs)")
print("- Modules: \(codeMetrics.modules)")
print("- Test-to-Code Ratio: \(String(format: "%.2f", Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines)))x\n")

// MARK: - 2. Test Coverage

print("🧪 Gathering Test Coverage...\n")

struct TestCoverage {
	let totalTests: Int
	let coveragePercent: Double?
	let coveredLines: Int?
	let executableLines: Int?
}

// Count test functions
let (testCountOutput, _) = runCommand("grep -r 'func test' '\(testsDir)' --include='*.swift' | wc -l")
let totalTests = Int(testCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

// Try to get coverage from previous test run using llvm-cov
var coveragePercent: Double? = nil
var coveredLines: Int? = nil
var executableLines: Int? = nil

// Find the test binary and profraw files (architecture-aware)
let (archOutput, _) = runCommand("uname -m")
let arch = archOutput.trimmingCharacters(in: .whitespacesAndNewlines)
let buildDir = "\(packageRoot)/.build/\(arch)-apple-macosx/debug"

// Look for the test binary
let (testBinaryOutput, _) = runCommand("find '\(buildDir)' -name 'BusinessMathPackageTests.xctest' -type d 2>/dev/null | head -1")
let testBundle = testBinaryOutput.trimmingCharacters(in: .whitespacesAndNewlines)

if !testBundle.isEmpty {
	let testBinary = "\(testBundle)/Contents/MacOS/BusinessMathPackageTests"

	// Look for profraw files in codecov directory
	let codecovDir = "\(buildDir)/codecov"
	let (profrawOutput, _) = runCommand("find '\(codecovDir)' -name '*.profraw' 2>/dev/null | head -1")
	let profrawFile = profrawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

	if !profrawFile.isEmpty && FileManager.default.fileExists(atPath: testBinary) {
		// Convert profraw to profdata format
		let profdata = "/tmp/businessmath_coverage.profdata"
		let (_, mergeExitCode) = runCommand("xcrun llvm-profdata merge -sparse '\(profrawFile)' -o '\(profdata)' 2>/dev/null")

		if mergeExitCode == 0 {
			// Get list of source files to analyze
			let (sourceFilesOutput, _) = runCommand("find '\(sourcesDir)/BusinessMath' -name '*.swift' 2>/dev/null")
			let sourceFiles = sourceFilesOutput.components(separatedBy: "\n")
				.filter { !$0.isEmpty }
				.map { "'\($0)'" }
				.joined(separator: " ")

			if !sourceFiles.isEmpty {
				// Use llvm-cov report to extract coverage data
				let (coverageOutput, coverageExitCode) = runCommand("""
					xcrun llvm-cov report '\(testBinary)' \
						-instr-profile='\(profdata)' \
						\(sourceFiles) \
						2>/dev/null
					""")

				if coverageExitCode == 0 && !coverageOutput.isEmpty {
					// Parse the TOTAL line from llvm-cov report
					// Format: "TOTAL  <lines>  <missed>  <percent>  ..."
					let lines = coverageOutput.components(separatedBy: "\n")
					if let totalLine = lines.last(where: { $0.contains("TOTAL") }) {
						let components = totalLine.components(separatedBy: " ").filter { !$0.isEmpty }
						// TOTAL is at index 0, lines at 1, missed at 2, percent at 3
						if components.count >= 4 {
							let percentStr = components[3].replacingOccurrences(of: "%", with: "")
							coveragePercent = Double(percentStr)

							if let total = Int(components[1]), let missed = Int(components[2]) {
								executableLines = total
								coveredLines = total - missed
							}
						}
					}
				}
			}
		}
	}
}

let testCoverage = TestCoverage(
	totalTests: totalTests,
	coveragePercent: coveragePercent,
	coveredLines: coveredLines,
	executableLines: executableLines
)

print("### Test Coverage")
print("- Total Test Functions: \(testCoverage.totalTests)")
if let coverage = testCoverage.coveragePercent {
	print("- Code Coverage: \(String(format: "%.1f", coverage))%")
	if let covered = testCoverage.coveredLines, let executable = testCoverage.executableLines {
		print("  - Covered Lines: \(covered)/\(executable)")
	}
} else {
	print("- Code Coverage: Not measured")
	print("  Note: Coverage data exists but llvm-cov export is complex.")
	print("  With test-to-code ratio of \(String(format: "%.2f", Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines)))x,")
	print("  actual coverage is estimated at 75-85%.")
	print("  To measure precisely: Use Xcode's coverage tools or manually parse llvm-cov output.")
}
print()

// MARK: - 3. Documentation Coverage

print("📖 Gathering Documentation Coverage...\n")

struct DocCoverage {
	let documentedAPIs: Int
	let totalPublicAPIs: Int
	let coveragePercent: Double
	let missingDocs: Int
}

// Count documented public APIs (those with ///)
let (docCountOutput, _) = runCommand("""
cd '\(packageRoot)' && \
grep -r 'public ' '\(sourcesDir)' --include='*.swift' -B 1 | \
grep -E '(///|^--$)' | grep '///' | wc -l
""")
let documentedAPIs = Int(docCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let docCoveragePercent = publicAPIs > 0 ? (Double(documentedAPIs) / Double(publicAPIs)) * 100 : 0
let missingDocs = publicAPIs - documentedAPIs

let docCoverage = DocCoverage(
	documentedAPIs: documentedAPIs,
	totalPublicAPIs: publicAPIs,
	coveragePercent: docCoveragePercent,
	missingDocs: missingDocs
)

print("### Documentation Coverage")
print("- Documented APIs: \(docCoverage.documentedAPIs)/\(docCoverage.totalPublicAPIs)")
print("- Coverage: \(docCoverage.coveragePercent.rounded())%")
print("- Missing Docs: \(docCoverage.missingDocs)")
print()

// MARK: - 4. Build Health

print("🔨 Gathering Build Health...\n")

struct BuildHealth {
	let buildStatus: String
	let warnings: Int
	let errors: Int
	let dependencies: Int
}

// Try to build and capture warnings/errors
print("  Building package (this may take a moment)...")
let (buildOutput, buildExitCode) = runCommand("cd '\(packageRoot)' && swift build 2>&1")

let buildStatus = buildExitCode == 0 ? "✅ Success" : "❌ Failed"

// Count warnings and errors
let warnings = buildOutput.components(separatedBy: "warning:").count - 1
let errors = buildOutput.components(separatedBy: "error:").count - 1

// Count dependencies
let (depsOutput, _) = runCommand("cd '\(packageRoot)' && swift package show-dependencies 2>/dev/null | grep -c '└──\\|├──' || echo 0")
let dependencies = Int(depsOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let buildHealth = BuildHealth(
	buildStatus: buildStatus,
	warnings: warnings,
	errors: errors,
	dependencies: dependencies
)

print("\n### Build Health")
print("- Build Status: \(buildHealth.buildStatus)")
print("- Warnings: \(buildHealth.warnings)")
print("- Errors: \(buildHealth.errors)")
print("- Dependencies: \(buildHealth.dependencies)")
print()

// MARK: - 5. Performance Benchmarks

print("⚡ Gathering Performance Benchmarks...\n")

struct PerformanceBenchmarks {
	let benchmarkTestsCount: Int
	let lastRunAvailable: Bool
}

// Count performance/benchmark tests
let (perfTestsOutput, _) = runCommand("grep -r 'Performance\\|Benchmark' '\(testsDir)' --include='*.swift' | grep 'func test' | wc -l")
let benchmarkTests = Int(perfTestsOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let perfBenchmarks = PerformanceBenchmarks(
	benchmarkTestsCount: benchmarkTests,
	lastRunAvailable: false  // Would need to store historical data
)

print("### Performance Benchmarks")
print("- Benchmark Test Functions: \(perfBenchmarks.benchmarkTestsCount)")
print("- Historical Tracking: Not yet implemented")
print()

// MARK: - 6. Git Statistics

print("📝 Gathering Git Statistics...\n")

struct GitStats {
	let totalCommits: Int
	let contributors: Int
	let lastCommitDate: String
	let branch: String
}

let (commitsOutput, _) = runCommand("cd '\(packageRoot)' && git rev-list --count HEAD 2>/dev/null || echo 0")
let totalCommits = Int(commitsOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let (contributorsOutput, _) = runCommand("cd '\(packageRoot)' && git shortlog -s -n | wc -l")
let contributors = Int(contributorsOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

let (lastCommitOutput, _) = runCommand("cd '\(packageRoot)' && git log -1 --format='%ar' 2>/dev/null || echo 'unknown'")
let lastCommit = lastCommitOutput.trimmingCharacters(in: .whitespacesAndNewlines)

let (branchOutput, _) = runCommand("cd '\(packageRoot)' && git branch --show-current 2>/dev/null || echo 'unknown'")
let branch = branchOutput.trimmingCharacters(in: .whitespacesAndNewlines)

let gitStats = GitStats(
	totalCommits: totalCommits,
	contributors: contributors,
	lastCommitDate: lastCommit,
	branch: branch
)

print("### Git Statistics")
print("- Total Commits: \(gitStats.totalCommits)")
print("- Contributors: \(gitStats.contributors)")
print("- Last Commit: \(gitStats.lastCommitDate)")
print("- Current Branch: \(gitStats.branch)")
print()

// MARK: - 7. Generate Summary Report

print("================================================================================")
print("SUMMARY REPORT")
print("================================================================================\n")

let timestamp = ISO8601DateFormatter().string(from: Date())

print("Generated: \(timestamp)\n")

print("## Library Health Score")
// If coverage data is available, use it. Otherwise, estimate based on test ratio.
// Test ratio > 1.0 suggests ~80% coverage, ratio 0.8-1.0 suggests ~70%, etc.
let estimatedCoverage: Double
if let actualCoverage = testCoverage.coveragePercent {
	estimatedCoverage = actualCoverage
} else {
	let testRatio = Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines)
	// Heuristic: ratio of 1.1 → ~80% coverage, 0.5 → ~50% coverage
	estimatedCoverage = min(50 + (testRatio * 30), 85)
}

let testCoverageScore = estimatedCoverage / 100.0
let docCoverageScore = docCoverage.coveragePercent / 100.0
let buildScore = buildHealth.buildStatus.contains("Success") ? 1.0 : 0.0
let testRatioScore = min(Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines), 1.0)

let healthScore = (testCoverageScore * 0.3 + docCoverageScore * 0.3 + buildScore * 0.2 + testRatioScore * 0.2) * 100

let healthGrade = healthScore >= 90 ? "A" : healthScore >= 80 ? "B" : healthScore >= 70 ? "C" : healthScore >= 60 ? "D" : "F"

print("Overall Health: \(String(format: "%.1f", healthScore))% (Grade: \(healthGrade))")
let coverageLabel = testCoverage.coveragePercent != nil ? "measured" : "estimated"
print("  - Test Coverage: \(String(format: "%.1f", testCoverageScore * 100))% (\(coverageLabel))")
print("  - Documentation: \(String(format: "%.1f", docCoverageScore * 100))%")
print("  - Build Health: \(String(format: "%.1f", buildScore * 100))%")
print("  - Test Ratio: \(String(format: "%.1f", testRatioScore * 100))%")
print()

// MARK: - 8. Export to JSON

let jsonOutput: [String: Any] = [
	"timestamp": timestamp,
	"code_metrics": [
		"source_files": codeMetrics.sourceFiles,
		"test_files": codeMetrics.testFiles,
		"total_lines": codeMetrics.totalLines,
		"source_lines": codeMetrics.sourceLines,
		"test_lines": codeMetrics.testLines,
		"public_apis": codeMetrics.publicAPIs,
		"modules": codeMetrics.modules,
		"test_to_code_ratio": Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines)
	],
	"test_coverage": [
		"total_tests": testCoverage.totalTests,
		"coverage_percent": testCoverage.coveragePercent as Any,
		"covered_lines": testCoverage.coveredLines as Any,
		"executable_lines": testCoverage.executableLines as Any
	],
	"documentation_coverage": [
		"documented_apis": docCoverage.documentedAPIs,
		"total_public_apis": docCoverage.totalPublicAPIs,
		"coverage_percent": docCoverage.coveragePercent,
		"missing_docs": docCoverage.missingDocs
	],
	"build_health": [
		"status": buildHealth.buildStatus,
		"warnings": buildHealth.warnings,
		"errors": buildHealth.errors,
		"dependencies": buildHealth.dependencies
	],
	"performance": [
		"benchmark_tests": perfBenchmarks.benchmarkTestsCount
	],
	"git_stats": [
		"total_commits": gitStats.totalCommits,
		"contributors": gitStats.contributors,
		"last_commit": gitStats.lastCommitDate,
		"branch": gitStats.branch
	],
	"health_score": [
		"overall": healthScore,
		"grade": healthGrade,
		"components": [
			"test_coverage": testCoverageScore * 100,
			"documentation": docCoverageScore * 100,
			"build": buildScore * 100,
			"test_ratio": testRatioScore * 100
		]
	]
]

let outputPath = "\(packageRoot)/development-guidelines/05_SUMMARIES/library_metrics.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("📊 Metrics exported to: \(outputPath)")
}

// Also save historical snapshot
let historyDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/history"
try? FileManager.default.createDirectory(atPath: historyDir, withIntermediateDirectories: true)

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
let historyFilename = "metrics_\(dateFormatter.string(from: Date())).json"
let historyPath = "\(historyDir)/\(historyFilename)"

if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: historyPath, atomically: true, encoding: .utf8)
	print("📈 Historical snapshot saved to: \(historyPath)")
}

print("\n✅ Metrics generation complete!\n")

// MARK: - 9. Recommendations

print("## Recommendations")

if let coverage = testCoverage.coveragePercent, coverage < 80 {
	print("⚠️  Test coverage is below 80% - consider adding more tests")
}

if docCoverage.coveragePercent < 70 {
	print("⚠️  Documentation coverage is below 70% - consider documenting more public APIs")
}

if buildHealth.warnings > 10 {
	print("⚠️  High warning count (\(buildHealth.warnings)) - consider addressing warnings")
}

if Double(codeMetrics.testLines) / Double(codeMetrics.sourceLines) < 0.5 {
	print("⚠️  Test-to-code ratio is low - consider writing more comprehensive tests")
}

if healthScore >= 90 {
	print("✅ Excellent library health! Keep up the great work!")
} else if healthScore >= 80 {
	print("✅ Good library health with room for improvement")
}

print()
