#!/usr/bin/env swift

import Foundation

// MARK: - BusinessMath Coverage Gap Analyzer
// Identifies specific files, functions, and lines with missing documentation or test coverage

print("""
================================================================================
BUSINESSMATH COVERAGE GAP ANALYZER
================================================================================

This tool identifies exactly where documentation and test coverage gaps exist.

""")

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let sourcesDir = "\(packageRoot)/Sources/BusinessMath"
let testsDir = "\(packageRoot)/Tests/BusinessMathTests"

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

// MARK: - 1. File-Level Test Coverage Mapping

print("📁 Analyzing file-level test coverage...\n")

struct SourceFileInfo {
	let path: String
	let relativePath: String
	let hasTests: Bool
	let suggestedTestPath: String?
}

// Get all Swift source files
let (sourceFilesOutput, _) = runCommand("find '\(sourcesDir)' -name '*.swift' -type f")
let sourceFiles = sourceFilesOutput.components(separatedBy: "\n")
	.filter { !$0.isEmpty && !$0.contains(".build") }
	.sorted()

// Get all test files
let (testFilesOutput, _) = runCommand("find '\(testsDir)' -name '*.swift' -type f")
let testFiles = Set(testFilesOutput.components(separatedBy: "\n")
	.filter { !$0.isEmpty }
	.map { URL(fileURLWithPath: $0).lastPathComponent.replacingOccurrences(of: "Tests.swift", with: ".swift") })

var filesWithoutTests: [SourceFileInfo] = []
var filesWithTests: [SourceFileInfo] = []

for sourceFile in sourceFiles {
	let url = URL(fileURLWithPath: sourceFile)
	let fileName = url.lastPathComponent
	let relativePath = sourceFile.replacingOccurrences(of: sourcesDir + "/", with: "")

	let hasTests = testFiles.contains(fileName)

	let suggestedTestPath = hasTests ? nil : "\(testsDir)/\(fileName.replacingOccurrences(of: ".swift", with: "Tests.swift"))"

	let info = SourceFileInfo(
		path: sourceFile,
		relativePath: relativePath,
		hasTests: hasTests,
		suggestedTestPath: suggestedTestPath
	)

	if hasTests {
		filesWithTests.append(info)
	} else {
		filesWithoutTests.append(info)
	}
}

print("### File-Level Test Coverage Summary")
print("- Total source files: \(sourceFiles.count)")
print("- Files with tests: \(filesWithTests.count) (\(String(format: "%.1f", Double(filesWithTests.count) / Double(sourceFiles.count) * 100))%)")
print("- Files WITHOUT tests: \(filesWithoutTests.count) (\(String(format: "%.1f", Double(filesWithoutTests.count) / Double(sourceFiles.count) * 100))%)")
print()

if !filesWithoutTests.isEmpty {
	print("### Files Without Test Coverage (\(filesWithoutTests.count) files)")
	print()
	for (index, file) in filesWithoutTests.enumerated() {
		let path = "\(index + 1). \(file.relativePath)"
//		print(path)
		if let testPath = file.suggestedTestPath {
			print("\(path)   → Suggested test: \(testPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
		}
	}
	if filesWithoutTests.count > 20 {
		print("   ... and \(filesWithoutTests.count - 20) more")
	}
	print()
}

// MARK: - 2. Function-Level Documentation Gap Analysis

print("📖 Analyzing function-level documentation gaps...\n")

struct UndocumentedAPI {
	let file: String
	let lineNumber: Int
	let apiType: String // func, class, struct, enum, protocol
	let name: String
	let signature: String
}

var undocumentedAPIs: [UndocumentedAPI] = []

print("  Scanning source files for undocumented public APIs...")

for sourceFile in sourceFiles {
	guard let content = try? String(contentsOfFile: sourceFile, encoding: .utf8) else { continue }

	let lines = content.components(separatedBy: "\n")
	let relativePath = sourceFile.replacingOccurrences(of: packageRoot + "/", with: "")

	for (index, line) in lines.enumerated() {
		let lineNumber = index + 1
		let trimmed = line.trimmingCharacters(in: .whitespaces)

		// Skip if line doesn't contain public declaration
		guard trimmed.contains("public ") else { continue }

		// Check if previous line has documentation
		let hasDocs = index > 0 && lines[index - 1].trimmingCharacters(in: .whitespaces).contains("///")

		if !hasDocs {
			// Extract API type and name
			var apiType = "unknown"
			var name = ""
			let signature = trimmed

			if trimmed.contains("func ") {
				apiType = "func"
				// Extract function name
				if let funcRange = trimmed.range(of: "func "),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "(<")),
				   endRange.lowerBound > funcRange.upperBound {
					name = String(trimmed[funcRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			} else if trimmed.contains("class ") {
				apiType = "class"
				if let classRange = trimmed.range(of: "class "),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":{<")),
				   endRange.lowerBound > classRange.upperBound {
					name = String(trimmed[classRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			} else if trimmed.contains("struct ") {
				apiType = "struct"
				if let structRange = trimmed.range(of: "struct "),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":{<")),
				   endRange.lowerBound > structRange.upperBound {
					name = String(trimmed[structRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			} else if trimmed.contains("enum ") {
				apiType = "enum"
				if let enumRange = trimmed.range(of: "enum "),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":{<")),
				   endRange.lowerBound > enumRange.upperBound {
					name = String(trimmed[enumRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			} else if trimmed.contains("protocol ") {
				apiType = "protocol"
				if let protocolRange = trimmed.range(of: "protocol "),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":{<")),
				   endRange.lowerBound > protocolRange.upperBound {
					name = String(trimmed[protocolRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			} else if trimmed.contains("var ") || trimmed.contains("let ") {
				apiType = trimmed.contains("var ") ? "var" : "let"
				let keyword = apiType == "var" ? "var " : "let "
				if let keywordRange = trimmed.range(of: keyword),
				   let endRange = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":=({}")),
				   endRange.lowerBound > keywordRange.upperBound {
					name = String(trimmed[keywordRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
				}
			}

			if !name.isEmpty {
				undocumentedAPIs.append(UndocumentedAPI(
					file: relativePath,
					lineNumber: lineNumber,
					apiType: apiType,
					name: name,
					signature: signature
				))
			}
		}
	}
}

print("### Documentation Gap Summary")
print("- Total undocumented public APIs: \(undocumentedAPIs.count)")

// Group by type
let byType = Dictionary(grouping: undocumentedAPIs) { $0.apiType }
print("\nBreakdown by type:")
for (type, apis) in byType.sorted(by: { $0.value.count > $1.value.count }) {
	print("  - \(type): \(apis.count)")
}
print()

if !undocumentedAPIs.isEmpty {
	print("### Top Undocumented APIs (showing first 30)")
	print()

	// Sort by file, then line number
	let sorted = undocumentedAPIs.sorted { ($0.file, $0.lineNumber) < ($1.file, $1.lineNumber) }

	for (index, api) in sorted.prefix(30).enumerated() {
		print("\(index + 1). [\(api.apiType)] \(api.name)")
		print("   → \(api.file):\(api.lineNumber)")
	}

	if undocumentedAPIs.count > 30 {
		print("\n   ... and \(undocumentedAPIs.count - 30) more undocumented APIs")
	}
	print()
}

// MARK: - 3. Line-Level Coverage Analysis (from llvm-cov)

print("🧪 Analyzing line-level test coverage from llvm-cov...\n")

struct FileCoverage {
	let file: String
	let coveragePercent: Double
	let coveredLines: Int
	let executableLines: Int
	let uncoveredRegions: [(line: Int, count: Int)]
}

var fileCoverageData: [FileCoverage] = []

// Find the test binary and profraw files
let (archOutput, _) = runCommand("uname -m")
let arch = archOutput.trimmingCharacters(in: .whitespacesAndNewlines)
let buildDir = "\(packageRoot)/.build/\(arch)-apple-macosx/debug"

let (testBinaryOutput, _) = runCommand("find '\(buildDir)' -name 'BusinessMathPackageTests.xctest' -type d 2>/dev/null | head -1")
let testBundle = testBinaryOutput.trimmingCharacters(in: .whitespacesAndNewlines)

if !testBundle.isEmpty {
	let testBinary = "\(testBundle)/Contents/MacOS/BusinessMathPackageTests"
	let codecovDir = "\(buildDir)/codecov"
	let (profrawOutput, _) = runCommand("find '\(codecovDir)' -name '*.profraw' 2>/dev/null | head -1")
	let profrawFile = profrawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

	if !profrawFile.isEmpty && FileManager.default.fileExists(atPath: testBinary) {
		print("  Found coverage data, generating detailed report...")

		// Convert profraw to profdata
		let profdata = "/tmp/businessmath_coverage.profdata"
		let (_, mergeExitCode) = runCommand("xcrun llvm-profdata merge -sparse '\(profrawFile)' -o '\(profdata)' 2>/dev/null")

		if mergeExitCode == 0 {
			// Export detailed coverage as JSON
			let (coverageJSON, exportExitCode) = runCommand("""
				xcrun llvm-cov export '\(testBinary)' \
					-instr-profile='\(profdata)' \
					-ignore-filename-regex='Tests|.build' \
					2>/dev/null
				""")

			if exportExitCode == 0 && !coverageJSON.isEmpty {
				// Parse JSON coverage data
				if let jsonData = coverageJSON.data(using: .utf8),
				   let coverage = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
				   let data = coverage["data"] as? [[String: Any]] {

					for fileData in data {
						guard let files = fileData["files"] as? [[String: Any]] else { continue }

						for file in files {
							guard let filename = file["filename"] as? String,
								  filename.contains("/Sources/BusinessMath/"),
								  let summary = file["summary"] as? [String: Any],
								  let lines = summary["lines"] as? [String: Any],
								  let covered = lines["covered"] as? Int,
								  let count = lines["count"] as? Int else { continue }

							let percent = count > 0 ? (Double(covered) / Double(count)) * 100 : 0

							// Extract uncovered regions
							var uncoveredRegions: [(line: Int, count: Int)] = []
							if let segments = file["segments"] as? [[Any]] {
								for segment in segments {
									// Segment format: [line, col, count, hasCount, isRegionEntry]
									if segment.count >= 5,
									   let line = segment[0] as? Int,
									   let count = segment[2] as? Int,
									   let hasCount = segment[3] as? Bool,
									   let isRegionEntry = segment[4] as? Bool,
									   hasCount && isRegionEntry && count == 0 {
										uncoveredRegions.append((line: line, count: count))
									}
								}
							}

							let relativePath = filename.replacingOccurrences(of: packageRoot + "/", with: "")

							fileCoverageData.append(FileCoverage(
								file: relativePath,
								coveragePercent: percent,
								coveredLines: covered,
								executableLines: count,
								uncoveredRegions: uncoveredRegions
							))
						}
					}
				}
			}
		}
	}
}

if fileCoverageData.isEmpty {
	print("⚠️  No coverage data available.")
	print("   Run: swift test --enable-code-coverage")
	print("   Then re-run this script.\n")
} else {
	print("### Line-Level Coverage Summary")
	print("- Files analyzed: \(fileCoverageData.count)")
	print("- Average coverage: \(String(format: "%.1f", fileCoverageData.map { $0.coveragePercent }.reduce(0, +) / Double(fileCoverageData.count)))%")
	print()

	// Find files with low coverage
	let lowCoverage = fileCoverageData.filter { $0.coveragePercent < 80 }.sorted { $0.coveragePercent < $1.coveragePercent }

	if !lowCoverage.isEmpty {
		print("### Files with Coverage Below 80% (\(lowCoverage.count) files)")
		print()
		for (index, file) in lowCoverage.prefix(20).enumerated() {
			print("\(index + 1). \(file.file)")
			print("   → Coverage: \(String(format: "%.1f", file.coveragePercent))% (\(file.coveredLines)/\(file.executableLines) lines)")
			if !file.uncoveredRegions.isEmpty {
				let regions = file.uncoveredRegions.prefix(5).map { "L\($0.line)" }.joined(separator: ", ")
				print("   → Uncovered lines: \(regions)")
				if file.uncoveredRegions.count > 5 {
					print("     ... and \(file.uncoveredRegions.count - 5) more")
				}
			}
		}
		if lowCoverage.count > 20 {
			print("\n   ... and \(lowCoverage.count - 20) more files")
		}
		print()
	}
}

// MARK: - 4. Generate JSON Output

print("================================================================================")
print("GENERATING DETAILED REPORTS")
print("================================================================================\n")

let timestamp = ISO8601DateFormatter().string(from: Date())

// Build JSON in parts to avoid compiler timeout
let fileCoverageJSON: [String: Any] = [
	"total_files": sourceFiles.count,
	"files_with_tests": filesWithTests.count,
	"files_without_tests": filesWithoutTests.count,
	"coverage_percent": Double(filesWithTests.count) / Double(sourceFiles.count) * 100,
	"uncovered_files": filesWithoutTests.map { [
		"path": $0.relativePath,
		"suggested_test": $0.suggestedTestPath?.replacingOccurrences(of: packageRoot + "/", with: "") ?? ""
	]}
]

let documentationGapsJSON: [String: Any] = [
	"total_undocumented": undocumentedAPIs.count,
	"by_type": byType.mapValues { $0.count },
	"undocumented_apis": undocumentedAPIs.map { [
		"file": $0.file,
		"line": $0.lineNumber,
		"type": $0.apiType,
		"name": $0.name,
		"signature": $0.signature
	]}
]

let lineCoverageJSON: [String: Any] = [
	"available": !fileCoverageData.isEmpty,
	"files_analyzed": fileCoverageData.count,
	"files_below_80_percent": fileCoverageData.filter { $0.coveragePercent < 80 }.count,
	"detailed_coverage": fileCoverageData.map { [
		"file": $0.file,
		"coverage_percent": $0.coveragePercent,
		"covered_lines": $0.coveredLines,
		"executable_lines": $0.executableLines,
		"uncovered_regions": $0.uncoveredRegions.map { ["line": $0.line, "count": $0.count] }
	]}
]

let jsonOutput: [String: Any] = [
	"timestamp": timestamp,
	"file_coverage": fileCoverageJSON,
	"documentation_gaps": documentationGapsJSON,
	"line_coverage": lineCoverageJSON
]

// Save JSON
let jsonOutputPath = "\(packageRoot)/Instruction Set/05_SUMMARIES/coverage_gaps.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: jsonOutputPath, atomically: true, encoding: .utf8)
	print("📊 Detailed gap analysis exported to:")
	print("   \(jsonOutputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
}

// MARK: - 5. Generate Markdown Report

var markdown = """
# Coverage Gap Analysis Report

**Generated**: \(timestamp)

## Executive Summary

| Metric | Value |
|--------|-------|
| Files without tests | \(filesWithoutTests.count) / \(sourceFiles.count) (\(String(format: "%.1f", Double(filesWithoutTests.count) / Double(sourceFiles.count) * 100))%) |
| Undocumented APIs | \(undocumentedAPIs.count) |
| Files below 80% coverage | \(fileCoverageData.filter { $0.coveragePercent < 80 }.count) / \(fileCoverageData.count) |

---

## 1. Files Without Test Coverage

"""

if filesWithoutTests.isEmpty {
	markdown += "✅ All source files have corresponding test files!\n\n"
} else {
	markdown += "**\(filesWithoutTests.count) files** need test coverage:\n\n"
	for (index, file) in filesWithoutTests.enumerated() {
		markdown += "\(index + 1). `\(file.relativePath)`\n"
		if let testPath = file.suggestedTestPath {
			markdown += "   - Create: `\(testPath.replacingOccurrences(of: packageRoot + "/", with: ""))`\n"
		}
	}
	markdown += "\n"
}

markdown += """
---

## 2. Undocumented Public APIs

"""

if undocumentedAPIs.isEmpty {
	markdown += "✅ All public APIs are documented!\n\n"
} else {
	markdown += "**\(undocumentedAPIs.count) public APIs** need documentation:\n\n"

	// Group by file
	let byFile = Dictionary(grouping: undocumentedAPIs) { $0.file }
	for (file, apis) in byFile.sorted(by: { $0.value.count > $1.value.count }).prefix(15) {
		markdown += "### `\(file)` (\(apis.count) undocumented)\n\n"
		for api in apis.sorted(by: { $0.lineNumber < $1.lineNumber }) {
			markdown += "- Line \(api.lineNumber): `\(api.apiType) \(api.name)`\n"
		}
		markdown += "\n"
	}

	if byFile.count > 15 {
		markdown += "\n*... and \(byFile.count - 15) more files with undocumented APIs*\n\n"
	}
}

markdown += """
---

## 3. Files with Low Test Coverage (<80%)

"""

if fileCoverageData.isEmpty {
	markdown += "⚠️ Coverage data not available. Run `swift test --enable-code-coverage` first.\n\n"
} else {
	let lowCoverage = fileCoverageData.filter { $0.coveragePercent < 80 }.sorted { $0.coveragePercent < $1.coveragePercent }

	if lowCoverage.isEmpty {
		markdown += "✅ All files have ≥80% test coverage!\n\n"
	} else {
		markdown += "**\(lowCoverage.count) files** have coverage below 80%:\n\n"
		markdown += "| File | Coverage | Lines |\n"
		markdown += "|------|----------|-------|\n"
		for file in lowCoverage.prefix(30) {
			markdown += "| `\(file.file)` | \(String(format: "%.1f", file.coveragePercent))% | \(file.coveredLines)/\(file.executableLines) |\n"
		}
		markdown += "\n"
		if lowCoverage.count > 30 {
			markdown += "*... and \(lowCoverage.count - 30) more files*\n\n"
		}
	}
}

markdown += """
---

## How to Use This Report

### Improving Test Coverage

1. **File-level**: Create test files for uncovered source files
2. **Line-level**: Add tests for uncovered lines/regions

### Improving Documentation

1. Add `///` documentation comments above undocumented public APIs
2. Include parameters, return values, and usage examples
3. Consider adding code examples in documentation

### Tracking Progress

Run this script regularly to track improvements:
```bash
swift "Instruction Set/05_SUMMARIES/analyze_coverage_gaps.swift"
```

---

*Generated by BusinessMath Coverage Gap Analyzer*
"""

// Save Markdown
let markdownOutputPath = "\(packageRoot)/Instruction Set/05_SUMMARIES/COVERAGE_GAPS.md"
try? markdown.write(toFile: markdownOutputPath, atomically: true, encoding: .utf8)
print("📄 Markdown report exported to:")
print("   \(markdownOutputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")

print("\n✅ Coverage gap analysis complete!\n")

// MARK: - 6. Generate LLM-Friendly TODO List

print("📝 Generating LLM-actionable TODO list...\n")

var todoMarkdown = """
# Coverage Gap TODO List

**Generated**: \(timestamp)

This file contains actionable tasks for improving test coverage and documentation.
Each task is self-contained and can be completed independently.

---

## Priority 1: Files Without Any Test Coverage (\(filesWithoutTests.count) files)

These source files have no corresponding test files. Create comprehensive test suites.

"""

for (index, file) in filesWithoutTests.enumerated() {
	todoMarkdown += """
	### Task \(index + 1): Create tests for `\(file.relativePath)`

	- [ ] Create test file at: `\(file.suggestedTestPath?.replacingOccurrences(of: packageRoot + "/", with: "") ?? "Tests directory")`
	- [ ] Review the source file to identify all public APIs
	- [ ] Write unit tests covering:
	  - Happy path scenarios
	  - Edge cases
	  - Error handling
	- [ ] Aim for >80% code coverage
	- [ ] Run tests and verify they pass

	**Source file**: `Sources/BusinessMath/\(file.relativePath)`

	---

	"""
}

todoMarkdown += """

## Priority 2: Undocumented Public APIs (\(undocumentedAPIs.count) APIs)

These public APIs lack documentation comments. Add comprehensive documentation.

"""

// Group by file for easier organization
let apisByFile = Dictionary(grouping: undocumentedAPIs) { $0.file }
var taskNumber = filesWithoutTests.count + 1

for (file, apis) in apisByFile.sorted(by: { $0.value.count > $1.value.count }).prefix(50) {
	todoMarkdown += """
	### Task \(taskNumber): Document APIs in `\(file)` (\(apis.count) undocumented)

	Add `///` documentation comments for the following public APIs:

	"""

	for api in apis.sorted(by: { $0.lineNumber < $1.lineNumber }) {
		todoMarkdown += """
		- [ ] Line \(api.lineNumber): `\(api.apiType) \(api.name)`
		  - Add description of purpose and behavior
		"""

		if api.apiType == "func" {
			todoMarkdown += """
			  - Document parameters (if any)
			  - Document return value (if any)
			  - Add usage example if complex
			"""
		} else if api.apiType == "class" || api.apiType == "struct" {
			todoMarkdown += """
			  - Describe the type's purpose
			  - Document key properties and methods
			  - Add usage example
			"""
		}

		todoMarkdown += "\n"
	}

	todoMarkdown += """

	**File location**: `\(file)`

	---

	"""
	taskNumber += 1
}

if apisByFile.count > 50 {
	todoMarkdown += "\n*Note: Showing top 50 files with undocumented APIs. \(apisByFile.count - 50) more files need attention.*\n\n"
}

todoMarkdown += """

## Priority 3: Files with Low Test Coverage (<80%)

These files have tests but coverage is below 80%. Add tests for uncovered code paths.

"""

let lowCoverageFiles = fileCoverageData.filter { $0.coveragePercent < 80 }.sorted { $0.coveragePercent < $1.coveragePercent }

if lowCoverageFiles.isEmpty && !fileCoverageData.isEmpty {
	todoMarkdown += "✅ All files have ≥80% test coverage!\n\n"
} else if !lowCoverageFiles.isEmpty {
	for (index, file) in lowCoverageFiles.prefix(30).enumerated() {
		todoMarkdown += """
		### Task \(taskNumber): Improve coverage for `\(file.file)`

		**Current coverage**: \(String(format: "%.1f", file.coveragePercent))% (\(file.coveredLines)/\(file.executableLines) lines)

		- [ ] Review uncovered lines in the source file
		"""

		if !file.uncoveredRegions.isEmpty {
			let regionList = file.uncoveredRegions.prefix(10).map { "Line \($0.line)" }.joined(separator: ", ")
			todoMarkdown += """
			- [ ] Add tests to cover: \(regionList)
			"""
			if file.uncoveredRegions.count > 10 {
				todoMarkdown += "\n  - And \(file.uncoveredRegions.count - 10) more uncovered lines\n"
			}
		}

		todoMarkdown += """
		- [ ] Focus on edge cases and error paths
		- [ ] Target: ≥80% coverage
		- [ ] Verify tests pass

		**File location**: `\(file.file)`

		---

		"""
		taskNumber += 1
	}

	if lowCoverageFiles.count > 30 {
		todoMarkdown += "\n*Note: Showing top 30 files with low coverage. \(lowCoverageFiles.count - 30) more files need improvement.*\n\n"
	}
}

todoMarkdown += """

---

## How to Use This TODO List

### For Human Developers
1. Pick a task from Priority 1, 2, or 3
2. Complete the checklist items
3. Run tests and verify coverage improved
4. Re-run this script to update the TODO list

### For LLM Agents
Each task is self-contained with:
- Clear success criteria (checkboxes)
- File locations for easy navigation
- Specific line numbers where applicable
- Coverage targets to aim for

To work on a task:
1. Read the source file mentioned
2. Complete the checklist items
3. Verify your changes compile and tests pass
4. Move to the next task

---

## Tracking Progress

After completing tasks, re-generate this TODO list:
```bash
swift "Instruction Set/05_SUMMARIES/analyze_coverage_gaps.swift"
```

The script will show updated statistics and remaining tasks.

---

*Generated by BusinessMath Coverage Gap Analyzer*
"""

// Save TODO list
let todoOutputPath = "\(packageRoot)/Instruction Set/05_SUMMARIES/COVERAGE_TODO.md"
try? todoMarkdown.write(toFile: todoOutputPath, atomically: true, encoding: .utf8)
print("📋 LLM-actionable TODO list exported to:")
print("   \(todoOutputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
print()

// MARK: - 7. Action Items Summary

print("## 🎯 Recommended Actions")
print()

if !filesWithoutTests.isEmpty {
	print("1. 📁 Create tests for \(filesWithoutTests.count) files without coverage")
	print("   Priority: \(filesWithoutTests.prefix(3).map { $0.relativePath }.joined(separator: ", "))")
	print()
}

if !undocumentedAPIs.isEmpty {
	let topFiles = Dictionary(grouping: undocumentedAPIs) { $0.file }
		.sorted { $0.value.count > $1.value.count }
		.prefix(3)
		.map { "\($0.key) (\($0.value.count) APIs)" }

	print("2. 📖 Document \(undocumentedAPIs.count) public APIs")
	print("   Priority files:")
	for file in topFiles {
		print("   - \(file)")
	}
	print()
}

if !fileCoverageData.isEmpty {
	let lowCoverage = fileCoverageData.filter { $0.coveragePercent < 50 }.sorted { $0.coveragePercent < $1.coveragePercent }
	if !lowCoverage.isEmpty {
		print("3. 🧪 Improve coverage for \(lowCoverage.count) files below 50%")
		print("   Lowest coverage:")
		for file in lowCoverage.prefix(3) {
			print("   - \(file.file) (\(String(format: "%.1f", file.coveragePercent))%)")
		}
		print()
	}
}

print()
