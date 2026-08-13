#!/usr/bin/env swift

import Foundation

// MARK: - Documentation Gap Analyzer
// Finds public APIs without documentation comments
// Identifies specific file:line locations for missing docs

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let sourcesDir = "\(packageRoot)/Sources/BusinessMath"

// MARK: - Helper Functions

func runCommand(_ command: String) -> String {
	let task = Process()
	task.launchPath = "/bin/bash"
	task.arguments = ["-c", command]

	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = Pipe()

	task.launch()
	task.waitUntilExit()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

// MARK: - Data Structures

struct UndocumentedAPI {
	let file: String
	let lineNumber: Int
	let apiType: String
	let name: String
	let declaration: String
}

// MARK: - Main Logic

print("📖 Documentation Gap Analyzer")
print("Finding public APIs without documentation comments...\n")

// Get all source files
let sourceFilesOutput = runCommand("find '\(sourcesDir)' -name '*.swift' -type f")
let sourceFiles = sourceFilesOutput.components(separatedBy: "\n")
	.filter { !$0.isEmpty && !$0.contains(".build") }
	.sorted()

var undocumentedAPIs: [UndocumentedAPI] = []
var fileCount = 0
var totalPublicAPIs = 0

print("Scanning \(sourceFiles.count) files...")

for sourceFile in sourceFiles {
	guard let content = try? String(contentsOfFile: sourceFile, encoding: .utf8) else { continue }

	fileCount += 1
	if fileCount % 50 == 0 {
		print("  Scanned \(fileCount)/\(sourceFiles.count) files...")
	}

	let lines = content.components(separatedBy: "\n")
	let relativePath = sourceFile.replacingOccurrences(of: packageRoot + "/", with: "")

	for (index, line) in lines.enumerated() {
		let lineNumber = index + 1
		let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

		// Skip non-public declarations
		guard trimmed.hasPrefix("public ") else { continue }
		
		totalPublicAPIs += 1

		// Check if previous line has documentation
		let hasDocs = index > 0 && (lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("///") || lines[index - 2].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("///") || lines[index - 2].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("///") || lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("public") || lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("private") || lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("@available"))

		if !hasDocs {
			// Extract API information
			var apiType = "other"
			var name = "unknown"

			if trimmed.contains("func ") {
				apiType = "func"
				name = extractFunctionName(from: trimmed)
			} else if trimmed.contains("class ") {
				apiType = "class"
				name = extractTypeName(from: trimmed, keyword: "class ")
			} else if trimmed.contains("struct ") {
				apiType = "struct"
				name = extractTypeName(from: trimmed, keyword: "struct ")
			} else if trimmed.contains("enum ") {
				apiType = "enum"
				name = extractTypeName(from: trimmed, keyword: "enum ")
			} else if trimmed.contains("protocol ") {
				apiType = "protocol"
				name = extractTypeName(from: trimmed, keyword: "protocol ")
			} else if trimmed.contains("var ") || trimmed.contains("let ") {
				apiType = trimmed.contains("var ") ? "var" : "let"
				name = extractPropertyName(from: trimmed, keyword: apiType == "var" ? "var " : "let ")
			} else if trimmed.contains("init") {
				apiType = "init"
				name = "init"
			} else if trimmed.contains("typealias ") {
				apiType = "typealias"
				name = extractTypeName(from: trimmed, keyword: "typealias ")
			}

			undocumentedAPIs.append(UndocumentedAPI(
				file: relativePath,
				lineNumber: lineNumber,
				apiType: apiType,
				name: name,
				declaration: trimmed
			))
		}
	}
}

print()

// MARK: - Extraction Helpers

func extractFunctionName(from line: String) -> String {
	guard let funcRange = line.range(of: "func ") else { return "unknown" }
	let afterFunc = line[funcRange.upperBound...]

	// Find end of function name (before < or ()
	let endChars = CharacterSet(charactersIn: "(<")
	if let endRange = afterFunc.rangeOfCharacter(from: endChars) {
		return String(afterFunc[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
	}

	// No delimiter found, take everything
	return String(afterFunc).trimmingCharacters(in: .whitespaces)
}

func extractTypeName(from line: String, keyword: String) -> String {
	guard let keywordRange = line.range(of: keyword) else { return "unknown" }
	let afterKeyword = line[keywordRange.upperBound...]

	// Find end of type name (before :, {, or <)
	let endChars = CharacterSet(charactersIn: ":{<")
	if let endRange = afterKeyword.rangeOfCharacter(from: endChars) {
		return String(afterKeyword[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
	}

	// No delimiter found, take everything
	return String(afterKeyword).trimmingCharacters(in: .whitespaces)
}

func extractPropertyName(from line: String, keyword: String) -> String {
	guard let keywordRange = line.range(of: keyword) else { return "unknown" }
	let afterKeyword = line[keywordRange.upperBound...]

	// Find end of property name (before :, =, or {)
	let endChars = CharacterSet(charactersIn: ":={")
	if let endRange = afterKeyword.rangeOfCharacter(from: endChars) {
		return String(afterKeyword[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
	}

	// No delimiter found, take everything
	return String(afterKeyword).trimmingCharacters(in: .whitespaces)
}

// MARK: - Analysis

let byType = Dictionary(grouping: undocumentedAPIs) { $0.apiType }
let byFile = Dictionary(grouping: undocumentedAPIs) { $0.file }

print("📊 Results:")
print("- Total public APIs: \(totalPublicAPIs)")
print("- Documented: \(totalPublicAPIs - undocumentedAPIs.count) (\(String(format: "%.1f", Double(totalPublicAPIs - undocumentedAPIs.count) / Double(totalPublicAPIs) * 100))%)")
print("- Undocumented: \(undocumentedAPIs.count) (\(String(format: "%.1f", Double(undocumentedAPIs.count) / Double(totalPublicAPIs) * 100))%)")
print()

print("By type:")
for (type, apis) in byType.sorted(by: { $0.value.count > $1.value.count }) {
	print("\n\n  - \(type): \(apis.count)")
	print(apis.enumerated().sorted(by: {$0.1.file < $1.1.file}).map({ "\($0.0) \($0.1.file) : \($0.1.lineNumber) \($0.1.name)"}).joined(separator: "\n"))
}
print()

if !undocumentedAPIs.isEmpty {
	print("📋 Top files with undocumented APIs:")
	for (index, (file, apis)) in byFile.sorted(by: { $0.value.count > $1.value.count }).enumerated() {
		print("  \(index + 1). \(file) (\(apis.count) undocumented)")
	}
	print()
}

// MARK: - JSON Export

let summary: [String: Any] = [
	"total_public_apis": totalPublicAPIs,
	"documented": totalPublicAPIs - undocumentedAPIs.count,
	"undocumented": undocumentedAPIs.count,
	"documentation_coverage_percent": Double(totalPublicAPIs - undocumentedAPIs.count) / Double(totalPublicAPIs) * 100,
	"by_type": byType.mapValues { $0.count }
]

let undocumentedJSON = undocumentedAPIs.map { api -> [String: Any] in
	return [
		"file": api.file,
		"line": api.lineNumber,
		"type": api.apiType,
		"name": api.name,
		"declaration": api.declaration
	]
}

let jsonOutput: [String: Any] = [
	"timestamp": ISO8601DateFormatter().string(from: Date()),
	"summary": summary,
	"undocumented_apis": undocumentedJSON
]

let outputDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/data"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let outputPath = "\(outputDir)/doc_gaps.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("✅ Documentation gaps saved to: \(outputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
} else {
	print("❌ Failed to save JSON output")
}

print()
