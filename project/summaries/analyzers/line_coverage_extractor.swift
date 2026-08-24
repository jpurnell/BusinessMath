#!/usr/bin/env swift

import Foundation

// MARK: - Line Coverage Extractor
// Extracts actual test coverage from llvm-cov execution data
// Shows which lines were ACTUALLY executed during test runs

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let sourcesDir = "\(packageRoot)/Sources/BusinessMath"

// MARK: - Helper Functions

func runCommand(_ command: String) throws -> (output: String, exitCode: Int32) {
	let task = Process()
	task.launchPath = "/bin/bash"
	task.arguments = ["-c", command]

	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = Pipe()

	task.launch()
	task.waitUntilExit()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

	return (output, task.terminationStatus)
}

// MARK: - Data Structures

struct FileCoverage {
	let path: String
	let relativePath: String
	let coveragePercent: Double
	let linesExecuted: Int
	let linesExecutable: Int
	let uncoveredLines: [Int]
	let uncoveredRegions: [(startLine: Int, endLine: Int, count: Int)]
}

// MARK: - Main Logic

print("🧪 Line Coverage Extractor")
print("Extracting actual test coverage from llvm-cov data...\n")

// Step 1: Find test binary and coverage data
print("📍 Step 1: Locating test coverage data...")

let (archOutput, _) = runCommand("uname -m")
let arch = archOutput
let buildDir = "\(packageRoot)/.build/\(arch)-apple-macosx/debug"

print("  Architecture: \(arch)")
print("  Build directory: \(buildDir)")

// Find test binary
let (testBinaryOutput, _) = runCommand("find '\(buildDir)' -name 'BusinessMathPackageTests.xctest' -type d 2>/dev/null | head -1")
let testBundle = testBinaryOutput

if testBundle.isEmpty {
	print("\n❌ No test binary found!")
	print("   Run: swift test --enable-code-coverage")
	print("   Then re-run this script.\n")
	exit(1)
}

let testBinary = "\(testBundle)/Contents/MacOS/BusinessMathPackageTests"
print("  Test binary: ✓")

// Find profraw coverage data
let codecovDir = "\(buildDir)/codecov"
let (profrawOutput, _) = runCommand("find '\(codecovDir)' -name '*.profraw' 2>/dev/null | head -1")
let profrawFile = profrawOutput

if profrawFile.isEmpty {
	print("\n❌ No coverage data found!")
	print("   Run: swift test --enable-code-coverage")
	print("   Then re-run this script.\n")
	exit(1)
}

print("  Coverage data: ✓\n")

// Step 2: Convert profraw to profdata
print("📊 Step 2: Converting coverage data...")

let profdata = "/tmp/businessmath_coverage_\(ProcessInfo.processInfo.processIdentifier).profdata"
let (_, mergeExitCode) = runCommand("xcrun llvm-profdata merge -sparse '\(profrawFile)' -o '\(profdata)' 2>/dev/null")

if mergeExitCode != 0 {
	print("\n❌ Failed to convert coverage data!")
	print("   This may be a toolchain issue.\n")
	exit(1)
}

print("  Converted to profdata format: ✓\n")

// Step 3: Export coverage as JSON
print("📤 Step 3: Exporting coverage data...")

let (coverageJSON, exportExitCode) = runCommand("""
	xcrun llvm-cov export '\(testBinary)' \
		-instr-profile='\(profdata)' \
		-ignore-filename-regex='Tests|.build' \
		2>/dev/null
	""")

if exportExitCode != 0 || coverageJSON.isEmpty {
	print("\n❌ Failed to export coverage data!")
	print("   llvm-cov export returned no data.\n")
	exit(1)
}

print("  Exported coverage JSON: ✓\n")

// Step 4: Parse JSON and extract file coverage
print("🔍 Step 4: Analyzing coverage per file...")

guard let jsonData = coverageJSON.data(using: .utf8),
      let coverage = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
      let data = coverage["data"] as? [[String: Any]] else {
	print("\n❌ Failed to parse coverage JSON!")
	exit(1)
}

var fileCoverageData: [FileCoverage] = []

for dataEntry in data {
	guard let files = dataEntry["files"] as? [[String: Any]] else { continue }

	for file in files {
		guard let filename = file["filename"] as? String,
		      filename.contains("/Sources/BusinessMath/"),
		      let summary = file["summary"] as? [String: Any],
		      let lines = summary["lines"] as? [String: Any],
		      let coveredLines = lines["covered"] as? Int,
		      let executableLines = lines["count"] as? Int else { continue }

		let percent = executableLines > 0 ? (Double(coveredLines) / Double(executableLines)) * 100 : 0
		let relativePath = filename.replacingOccurrences(of: packageRoot + "/", with: "")

		// Extract uncovered line numbers
		var uncoveredLines: [Int] = []
		var uncoveredRegions: [(startLine: Int, endLine: Int, count: Int)] = []

		if let segments = file["segments"] as? [[Any]] {
			var currentUncoveredStart: Int? = nil

			for segment in segments {
				// Segment format: [line, col, count, hasCount, isRegionEntry]
				guard segment.count >= 5,
				      let line = segment[0] as? Int,
				      let count = segment[2] as? Int,
				      let hasCount = segment[3] as? Bool,
				      let isRegionEntry = segment[4] as? Bool else { continue }

				if hasCount && isRegionEntry {
					if count == 0 {
						// Start of uncovered region
						if currentUncoveredStart == nil {
							currentUncoveredStart = line
						}
						if !uncoveredLines.contains(line) {
							uncoveredLines.append(line)
						}
					} else if count > 0 && currentUncoveredStart != nil {
						// End of uncovered region
						uncoveredRegions.append((startLine: try #require(currentUncoveredStart), endLine: line - 1, count: 0))
						currentUncoveredStart = nil
					}
				}
			}

			// Close any open uncovered region
			if let start = currentUncoveredStart {
				uncoveredRegions.append((startLine: start, endLine: start, count: 0))
			}
		}

		fileCoverageData.append(FileCoverage(
			path: filename,
			relativePath: relativePath,
			coveragePercent: percent,
			linesExecuted: coveredLines,
			linesExecutable: executableLines,
			uncoveredLines: uncoveredLines.sorted(),
			uncoveredRegions: uncoveredRegions
		))
	}
}

print("  Analyzed \(fileCoverageData.count) source files: ✓\n")

// Step 5: Analysis and reporting
print("================================================================================")
print("COVERAGE ANALYSIS RESULTS")
print("================================================================================\n")

let totalExecutable = fileCoverageData.reduce(0) { $0 + $1.linesExecutable }
let totalCovered = fileCoverageData.reduce(0) { $0 + $1.linesExecuted }
let overallPercent = totalExecutable > 0 ? (Double(totalCovered) / Double(totalExecutable)) * 100 : 0

print("📊 Overall Coverage:")
print("  - Files analyzed: \(fileCoverageData.count)")
print("  - Lines covered: \(totalCovered) / \(totalExecutable)")
print("  - Coverage: \(String(format: "%.1f", overallPercent))%\n")

// Files with zero coverage
let zeroCoverage = fileCoverageData.filter { $0.coveragePercent == 0 }.sorted { $0.relativePath < $1.relativePath }
print("❌ Files with 0% coverage (\(zeroCoverage.count) files):")
if zeroCoverage.isEmpty {
	print("  None! All files have some coverage.\n")
} else {
	for (index, file) in zeroCoverage.prefix(15).enumerated() {
		print("  \(index + 1). \(file.relativePath)")
	}
	if zeroCoverage.count > 15 {
		print("  ... and \(zeroCoverage.count - 15) more\n")
	} else {
		print()
	}
}

// Files with low coverage (< 50%)
let lowCoverage = fileCoverageData.filter { $0.coveragePercent > 0 && $0.coveragePercent < 50 }
	.sorted { $0.coveragePercent < $1.coveragePercent }
print("⚠️  Files with < 50% coverage (\(lowCoverage.count) files):")
if lowCoverage.isEmpty {
	print("  None! All tested files have ≥50% coverage.\n")
} else {
	for (index, file) in lowCoverage.prefix(10).enumerated() {
		print("  \(index + 1). \(file.relativePath) - \(String(format: "%.1f", file.coveragePercent))% (\(file.linesExecuted)/\(file.linesExecutable))")
	}
	if lowCoverage.count > 10 {
		print("  ... and \(lowCoverage.count - 10) more\n")
	} else {
		print()
	}
}

// Files with medium coverage (50-80%)
let mediumCoverage = fileCoverageData.filter { $0.coveragePercent >= 50 && $0.coveragePercent < 80 }
	.sorted { $0.coveragePercent < $1.coveragePercent }
print("🟡 Files with 50-80% coverage (\(mediumCoverage.count) files):")
for (index, file) in mediumCoverage.prefix(10).enumerated() {
	print("  \(index + 1). \(file.relativePath) - \(String(format: "%.1f", file.coveragePercent))% (\(file.linesExecuted)/\(file.linesExecutable))")
}
if mediumCoverage.count > 10 {
	print("  ... and \(mediumCoverage.count - 10) more\n")
} else {
	print()
}

// Files with good coverage (≥ 80%)
let goodCoverage = fileCoverageData.filter { $0.coveragePercent >= 80 }
print("✅ Files with ≥ 80% coverage (\(goodCoverage.count) files)")
if goodCoverage.count > 0 {
	print("  Great job! \(String(format: "%.1f", Double(goodCoverage.count) / Double(fileCoverageData.count) * 100))% of files have good coverage.\n")
} else {
	print()
}

// Step 6: Export to JSON
print("💾 Saving results...\n")

let summary: [String: Any] = [
	"files_analyzed": fileCoverageData.count,
	"total_executable_lines": totalExecutable,
	"total_covered_lines": totalCovered,
	"overall_coverage_percent": overallPercent,
	"files_by_coverage": [
		"zero_coverage": zeroCoverage.count,
		"low_coverage_0_50": lowCoverage.count,
		"medium_coverage_50_80": mediumCoverage.count,
		"good_coverage_80_plus": goodCoverage.count
	]
]

let filesJSON = fileCoverageData.map { file -> [String: Any] in
	return [
		"file": file.relativePath,
		"coverage_percent": file.coveragePercent,
		"lines_covered": file.linesExecuted,
		"lines_executable": file.linesExecutable,
		"uncovered_line_count": file.uncoveredLines.count,
		"uncovered_lines": file.uncoveredLines.prefix(50).map { $0 }, // Limit to first 50 for JSON size
		"uncovered_regions": file.uncoveredRegions.map { ["start": $0.startLine, "end": $0.endLine] }
	]
}

let jsonOutput: [String: Any] = [
	"timestamp": ISO8601DateFormatter().string(from: Date()),
	"summary": summary,
	"files": filesJSON
]

let outputDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/data"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let outputPath = "\(outputDir)/line_coverage.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("✅ Line coverage saved to: \(outputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
} else {
	print("❌ Failed to save JSON output")
}

// Cleanup temp profdata
try? FileManager.default.removeItem(atPath: profdata)

print("\n✨ Coverage extraction complete!\n")

// Step 7: Recommendations
print("## 💡 Next Steps\n")

if !zeroCoverage.isEmpty {
	print("1. Focus on \(zeroCoverage.count) files with 0% coverage")
	print("   These files have NO test execution - priority targets!\n")
}

if !lowCoverage.isEmpty {
	print("2. Improve \(lowCoverage.count) files with <50% coverage")
	print("   These files need more comprehensive tests.\n")
}

if !mediumCoverage.isEmpty {
	print("3. Boost \(mediumCoverage.count) files from 50-80% to ≥80%")
	print("   These files are close to the target!\n")
}

if goodCoverage.count >= fileCoverageData.count / 2 {
	print("🎉 Great work! Over half your files have ≥80% coverage!\n")
}

print()
