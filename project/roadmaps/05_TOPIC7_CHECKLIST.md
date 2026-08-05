# Topic 7: Data Structures & Architecture - Implementation Checklist

**Purpose:** Track implementation progress for architectural components
**Status:** Not Started
**Created:** October 29, 2025
**Last Updated:** October 29, 2025

---

## Quick Reference

| Phase | Status | Files | Tests | Docs |
|-------|--------|-------|-------|------|
| Phase 1: Formula Engine Core | ⬜ Not Started | 0/6 | 0/1 | 0/6 |
| Phase 2: Calculation Graph | ⬜ Not Started | 0/3 | 0/1 | 0/3 |
| Phase 3: Multi-Entity Consolidation | ⬜ Not Started | 0/4 | 0/1 | 0/4 |
| Phase 4: Caching & Performance | ⬜ Not Started | 0/2 | 0/1 | 0/2 |
| Phase 5: Model Versioning | ⬜ Not Started | 0/3 | 0/1 | 0/3 |
| Phase 6: Integration & Documentation | ⬜ Not Started | 0/2 | 0/1 | 0/2 |

**Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Complete
- ⚠️ Blocked
- 🔴 Issues Found

**Overall Progress:** 0% (0 of 20 files, 0 of 6 test suites, 0 of 20 docs)

---

## Vision & Guiding Principles

### Core Vision
Make BusinessMath as intuitive as Excel for financial modeling, while providing the power, type safety, and performance of Swift.

### Key Design Principles

1. **Excel Familiarity**: Use Excel-like syntax where it makes sense (=SUM(A1:A10), cell references)
2. **Type Safety**: Leverage Swift's type system to catch errors at compile time
3. **Performance**: Smart caching and dependency tracking for large models
4. **Composability**: Each component works standalone and together
5. **Testability**: TDD approach with comprehensive test coverage

### User Stories

**As an Excel user**, I want to:
- Write formulas using familiar syntax (=NPV(0.1, B2:B10))
- Reference cells and ranges like I do in Excel
- Have the system automatically recalculate dependent cells
- Build multi-entity consolidated statements
- Track changes to my model over time

**As a Swift developer**, I want to:
- Type-safe formula evaluation
- Dependency tracking that prevents circular references
- Performance optimization through intelligent caching
- Clean API for building financial models programmatically

---

## Phase 1: Formula Engine Core

**Objective**: Build Excel-like formula parser and evaluator with cell references and basic functions.

**Estimated Effort:** 25-35 hours

### 1.1 Token Types and Lexer ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaLexer.swift`

**Requirements:**
- [ ] Define `Token` enum with all formula token types
  - [ ] Operators: `+`, `-`, `*`, `/`, `^`
  - [ ] Parentheses: `(`, `)`
  - [ ] Cell references: `A1`, `$A$1`, `Sheet1!A1`
  - [ ] Range operators: `:`, `,`
  - [ ] Functions: `FUNCTION_NAME()`
  - [ ] Literals: numbers, strings, booleans
  - [ ] Comparison: `=`, `<`, `>`, `<=`, `>=`, `<>`
- [ ] Implement `Lexer` struct
  - [ ] Method: `tokenize(_ expression: String) throws -> [Token]`
  - [ ] Handle whitespace gracefully
  - [ ] Support absolute references ($A$1) vs relative (A1)
  - [ ] Parse function names case-insensitively
  - [ ] Parse string literals with quotes
- [ ] Error: `LexerError` enum
  - [ ] `invalidCharacter(Character, position: Int)`
  - [ ] `unterminatedString(position: Int)`
  - [ ] `invalidNumber(String)`
- [ ] Conform to Sendable for concurrency
- [ ] Complete DocC documentation with examples

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaLexerTests.swift`
- [ ] Test tokenizing simple arithmetic: `1+2*3`
- [ ] Test operator precedence recognition
- [ ] Test cell references: `A1`, `$A$1`, `A$1`, `$A1`
- [ ] Test sheet references: `Sheet1!A1`
- [ ] Test range notation: `A1:A10`, `A1:C5`
- [ ] Test function calls: `SUM(A1:A10)`
- [ ] Test nested functions: `IF(A1>0, SUM(B:B), 0)`
- [ ] Test string literals: `"Hello World"`
- [ ] Test comparison operators
- [ ] Test whitespace handling
- [ ] Test error cases: invalid characters, unterminated strings
- [ ] Test edge cases: empty formula, very long formulas

**Example Usage:**
```swift
let lexer = Lexer()
let tokens = try lexer.tokenize("=SUM(A1:A10) * 2")
// Returns: [equals, function("SUM"), lparen, cellRef("A1"), colon,
//           cellRef("A10"), rparen, multiply, number(2)]
```

**Estimated Effort:** 4-6 hours

---

### 1.2 Cell Reference Types ⬜

**File:** `Sources/BusinessMath/Architecture/CellReference.swift`

**Requirements:**
- [ ] Define `CellReference` struct
  - [ ] Property: `sheet: String?` (nil for same sheet)
  - [ ] Property: `column: String` (A-ZZ notation)
  - [ ] Property: `row: Int` (1-based)
  - [ ] Property: `isColumnAbsolute: Bool` ($A vs A)
  - [ ] Property: `isRowAbsolute: Bool` ($1 vs 1)
- [ ] Initializer: `init(sheet:column:row:columnAbsolute:rowAbsolute:)`
- [ ] Static method: `parse(_ reference: String) throws -> CellReference`
  - [ ] Parse: `A1`, `$A$1`, `Sheet1!A1`, `Sheet1!$A$1`
  - [ ] Validate column (A-ZZ), row (1-1048576)
- [ ] Method: `offset(by rows: Int, columns: Int) -> CellReference`
  - [ ] Respect absolute vs relative references
  - [ ] Handle column overflow (Z -> AA)
- [ ] Method: `description` → formatted string (A1, $A$1, etc.)
- [ ] Conform to: `Hashable`, `Codable`, `Sendable`, `CustomStringConvertible`
- [ ] Complete DocC documentation

**Requirements - Range Support:**
- [ ] Define `CellRange` struct
  - [ ] Property: `start: CellReference`
  - [ ] Property: `end: CellReference`
- [ ] Method: `cells() -> [CellReference]` (expand range to individual cells)
- [ ] Method: `contains(_ cell: CellReference) -> Bool`
- [ ] Static method: `parse(_ rangeString: String) throws -> CellRange`
  - [ ] Parse: `A1:A10`, `Sheet1!A1:C5`
- [ ] Conform to: `Hashable`, `Codable`, `Sendable`

**Tests:** `Tests/BusinessMathTests/Architecture Tests/CellReferenceTests.swift`
- [ ] Test parsing simple references: `A1`, `Z99`
- [ ] Test parsing absolute references: `$A$1`, `$A1`, `A$1`
- [ ] Test parsing sheet references: `Sheet1!A1`, `'My Sheet'!A1`
- [ ] Test column conversion: A=1, Z=26, AA=27, ZZ=702
- [ ] Test offset with relative references
- [ ] Test offset with absolute references (should not change)
- [ ] Test column overflow: Z offset by 1 = AA
- [ ] Test range parsing: `A1:A10`, `A1:C5`
- [ ] Test range expansion: `A1:B2` → [A1, A2, B1, B2]
- [ ] Test range validation: start must be <= end
- [ ] Test Hashable (use in dictionary keys)
- [ ] Test Codable (serialize/deserialize)
- [ ] Test error cases: invalid column, invalid row, malformed reference

**Example Usage:**
```swift
let ref = try CellReference.parse("Sheet1!$A$1")
print(ref.sheet)           // "Sheet1"
print(ref.column)          // "A"
print(ref.row)             // 1
print(ref.isColumnAbsolute) // true
print(ref.isRowAbsolute)   // true

let range = try CellRange.parse("A1:B3")
print(range.cells().count) // 6 cells
```

**Estimated Effort:** 5-7 hours

---

### 1.3 Formula Parser (AST) ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaParser.swift`

**Requirements:**
- [ ] Define `FormulaAST` enum (Abstract Syntax Tree)
  - [ ] `case number(Double)`
  - [ ] `case string(String)`
  - [ ] `case boolean(Bool)`
  - [ ] `case cellReference(CellReference)`
  - [ ] `case range(CellRange)`
  - [ ] `case binaryOp(op: BinaryOperator, left: FormulaAST, right: FormulaAST)`
  - [ ] `case unaryOp(op: UnaryOperator, operand: FormulaAST)`
  - [ ] `case functionCall(name: String, args: [FormulaAST])`
- [ ] Define `BinaryOperator` enum
  - [ ] Arithmetic: `add`, `subtract`, `multiply`, `divide`, `power`
  - [ ] Comparison: `equal`, `notEqual`, `lessThan`, `greaterThan`, `lessOrEqual`, `greaterOrEqual`
  - [ ] String: `concatenate` (&)
- [ ] Define `UnaryOperator` enum
  - [ ] `negate` (-)
  - [ ] `percent` (%)
- [ ] Implement `Parser` struct
  - [ ] Method: `parse(_ tokens: [Token]) throws -> FormulaAST`
  - [ ] Recursive descent parser with operator precedence
  - [ ] Precedence: parentheses > power > multiply/divide > add/subtract > comparison
- [ ] Error: `ParseError` enum
  - [ ] `unexpectedToken(Token, expected: String)`
  - [ ] `unexpectedEndOfFormula`
  - [ ] `unmatchedParenthesis`
  - [ ] `invalidFunctionArguments(String)`
- [ ] Conform to Sendable
- [ ] Complete DocC documentation with grammar definition

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaParserTests.swift`
- [ ] Test parsing literals: numbers, strings, booleans
- [ ] Test parsing cell references: `A1`
- [ ] Test parsing ranges: `A1:A10`
- [ ] Test parsing arithmetic: `1+2*3` (precedence)
- [ ] Test parsing with parentheses: `(1+2)*3`
- [ ] Test parsing power operator: `2^3`
- [ ] Test parsing comparison: `A1>10`
- [ ] Test parsing function calls: `SUM(A1:A10)`
- [ ] Test parsing nested functions: `IF(A1>0, SUM(B:B), 0)`
- [ ] Test parsing complex formulas: `=NPV(0.1, A1:A10) + SUM(B1:B10)`
- [ ] Test operator associativity (left-to-right)
- [ ] Test error cases: mismatched parentheses, invalid syntax
- [ ] Test edge cases: empty formula, very deeply nested

**Example Usage:**
```swift
let lexer = Lexer()
let parser = Parser()

let tokens = try lexer.tokenize("=SUM(A1:A10) * 2")
let ast = try parser.parse(tokens)
// Returns: binaryOp(.multiply,
//            functionCall("SUM", [range(A1:A10)]),
//            number(2))
```

**Estimated Effort:** 8-10 hours

---

### 1.4 Formula Evaluation Context ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaContext.swift`

**Requirements:**
- [ ] Define `FormulaContext` protocol
  - [ ] Method: `getValue(for reference: CellReference) throws -> FormulaValue`
  - [ ] Method: `getRange(for range: CellRange) throws -> [FormulaValue]`
  - [ ] Method: `getNamedRange(_ name: String) throws -> CellRange`
- [ ] Define `FormulaValue` enum
  - [ ] `case number(Double)`
  - [ ] `case string(String)`
  - [ ] `case boolean(Bool)`
  - [ ] `case error(FormulaError)`
  - [ ] `case empty`
- [ ] Define `FormulaError` enum
  - [ ] `divisionByZero`
  - [ ] `invalidReference`
  - [ ] `circularReference`
  - [ ] `invalidValue`
  - [ ] `nameNotFound`
  - [ ] Custom error messages
- [ ] Implement `SimpleFormulaContext` (in-memory dictionary)
  - [ ] Property: `cells: [CellReference: FormulaValue]`
  - [ ] Property: `namedRanges: [String: CellRange]`
  - [ ] Method: `setValue(_ value: FormulaValue, for: CellReference)`
  - [ ] Method: `defineNamedRange(_ name: String, range: CellRange)`
- [ ] Type conversion helpers
  - [ ] `asNumber() throws -> Double`
  - [ ] `asString() -> String`
  - [ ] `asBoolean() -> Bool`
- [ ] Conform to Sendable
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaContextTests.swift`
- [ ] Test SimpleFormulaContext creation
- [ ] Test setting and getting cell values
- [ ] Test getting ranges
- [ ] Test named ranges
- [ ] Test type conversions
- [ ] Test error handling: invalid reference, name not found
- [ ] Test FormulaValue equality
- [ ] Test error propagation

**Example Usage:**
```swift
var context = SimpleFormulaContext()
context.setValue(.number(100), for: try CellReference.parse("A1"))
context.setValue(.number(200), for: try CellReference.parse("A2"))

let value = try context.getValue(for: try CellReference.parse("A1"))
// Returns: .number(100)

context.defineNamedRange("Revenue", range: try CellRange.parse("A1:A12"))
let range = try context.getNamedRange("Revenue")
```

**Estimated Effort:** 4-6 hours

---

### 1.5 Formula Evaluator ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaEvaluator.swift`

**Requirements:**
- [ ] Implement `FormulaEvaluator` struct
  - [ ] Method: `evaluate(_ ast: FormulaAST, context: FormulaContext) throws -> FormulaValue`
  - [ ] Handle all AST node types
  - [ ] Implement operator evaluation
  - [ ] Implement function dispatch
  - [ ] Type coercion (string "123" → number 123)
  - [ ] Error propagation (error values bubble up)
- [ ] Operator implementations
  - [ ] Arithmetic: +, -, *, /, ^
  - [ ] Comparison: =, <>, <, >, <=, >=
  - [ ] String concatenation: &
  - [ ] Percentage: convert to decimal
- [ ] Type coercion rules
  - [ ] Boolean → Number: TRUE=1, FALSE=0
  - [ ] String → Number: parse or error
  - [ ] Number → String: format
  - [ ] Empty → Number: 0
- [ ] Complete DocC documentation with evaluation rules

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaEvaluatorTests.swift`
- [ ] Test evaluating literals
- [ ] Test evaluating arithmetic: `2+3*4` = 14
- [ ] Test evaluating power: `2^3` = 8
- [ ] Test evaluating comparisons: `10>5` = TRUE
- [ ] Test evaluating cell references
- [ ] Test type coercion: "123" + 1 = 124
- [ ] Test error propagation: `#DIV/0! + 1` = #DIV/0!
- [ ] Test division by zero
- [ ] Test boolean arithmetic: TRUE + 1 = 2
- [ ] Test string concatenation: "Hello" & " " & "World"
- [ ] Test nested expressions
- [ ] Test complex formulas with context

**Example Usage:**
```swift
let formula = "=A1 + A2"
let tokens = try Lexer().tokenize(formula)
let ast = try Parser().parse(tokens)

var context = SimpleFormulaContext()
context.setValue(.number(10), for: try CellReference.parse("A1"))
context.setValue(.number(20), for: try CellReference.parse("A2"))

let result = try FormulaEvaluator().evaluate(ast, context: context)
// Returns: .number(30)
```

**Estimated Effort:** 6-8 hours

---

### 1.6 Built-in Formula Functions ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaFunctions.swift`

**Requirements:**
- [ ] Define `FormulaFunction` protocol
  - [ ] Property: `name: String`
  - [ ] Property: `minArgs: Int`
  - [ ] Property: `maxArgs: Int?` (nil = unlimited)
  - [ ] Method: `evaluate(args: [FormulaValue], context: FormulaContext) throws -> FormulaValue`
- [ ] Implement `FunctionRegistry`
  - [ ] Property: `functions: [String: FormulaFunction]`
  - [ ] Method: `register(_ function: FormulaFunction)`
  - [ ] Method: `lookup(_ name: String) -> FormulaFunction?`
  - [ ] Static property: `standard` (pre-registered common functions)
- [ ] Implement standard functions:

  **Math Functions:**
  - [ ] `SUM(values...)` - Sum of all arguments
  - [ ] `AVERAGE(values...)` - Arithmetic mean
  - [ ] `MIN(values...)` - Minimum value
  - [ ] `MAX(values...)` - Maximum value
  - [ ] `COUNT(values...)` - Count of numeric values
  - [ ] `COUNTA(values...)` - Count of non-empty values
  - [ ] `ROUND(number, digits)` - Round to decimal places
  - [ ] `ABS(number)` - Absolute value
  - [ ] `SQRT(number)` - Square root
  - [ ] `POWER(number, power)` - Raise to power

  **Logical Functions:**
  - [ ] `IF(condition, valueIfTrue, valueIfFalse)`
  - [ ] `AND(conditions...)` - All TRUE
  - [ ] `OR(conditions...)` - Any TRUE
  - [ ] `NOT(value)` - Logical negation

  **Financial Functions:**
  - [ ] `NPV(rate, cashFlows...)` - Net present value
  - [ ] `IRR(cashFlows...)` - Internal rate of return
  - [ ] `PMT(rate, periods, presentValue)` - Payment calculation
  - [ ] `PV(rate, periods, payment)` - Present value
  - [ ] `FV(rate, periods, payment)` - Future value

  **Text Functions:**
  - [ ] `CONCATENATE(values...)` - Join strings
  - [ ] `LEFT(text, count)` - First n characters
  - [ ] `RIGHT(text, count)` - Last n characters
  - [ ] `LEN(text)` - String length
  - [ ] `UPPER(text)` - Uppercase
  - [ ] `LOWER(text)` - Lowercase

  **Lookup Functions:**
  - [ ] `VLOOKUP(lookup, range, column, exactMatch)` - Vertical lookup
  - [ ] `INDEX(range, row, column)` - Get cell by position

- [ ] Range flattening: expand A1:A10 to array of values
- [ ] Error handling for each function
- [ ] Complete DocC documentation for each function

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaFunctionsTests.swift`
- [ ] Test SUM with range: `=SUM(A1:A5)`
- [ ] Test AVERAGE calculation
- [ ] Test MIN/MAX with mixed types
- [ ] Test COUNT vs COUNTA
- [ ] Test IF with conditions
- [ ] Test nested IF: `=IF(A1>100, "High", IF(A1>50, "Med", "Low"))`
- [ ] Test AND/OR/NOT logic
- [ ] Test NPV with rate and cash flows
- [ ] Test IRR convergence
- [ ] Test PMT calculation
- [ ] Test string functions
- [ ] Test VLOOKUP scenarios
- [ ] Test INDEX function
- [ ] Test error cases: wrong arg count, type mismatch
- [ ] Test edge cases: empty ranges, division by zero

**Example Usage:**
```swift
// Register custom function
let registry = FunctionRegistry.standard
registry.register(CustomGrowthFunction())

// Evaluate formula with functions
let formula = "=SUM(A1:A10) * (1 + AVERAGE(B1:B10))"
let result = try evaluateFormula(formula, context: context)
```

**Estimated Effort:** 12-16 hours

---

## Phase 2: Calculation Graph

**Objective**: Build dependency tracking system for intelligent recalculation

**Estimated Effort:** 15-20 hours

### 2.1 Dependency Graph ⬜

**File:** `Sources/BusinessMath/Architecture/DependencyGraph.swift`

**Requirements:**
- [ ] Define `DependencyGraph` class
  - [ ] Property: `nodes: [String: GraphNode]`
  - [ ] Property: `edges: [String: Set<String>]` (adjacency list)
  - [ ] Method: `addNode(id: String, value: Any)`
  - [ ] Method: `addEdge(from: String, to: String)` (dependency)
  - [ ] Method: `removeNode(id: String)`
  - [ ] Method: `removeEdge(from: String, to: String)`
  - [ ] Method: `dependents(of: String) -> Set<String>` (downstream)
  - [ ] Method: `dependencies(of: String) -> Set<String>` (upstream)
- [ ] Method: `topologicalSort() throws -> [String]`
  - [ ] Kahn's algorithm or DFS-based
  - [ ] Throw if circular dependency detected
- [ ] Method: `detectCycles() -> [[String]]?`
  - [ ] Return all cycles found
  - [ ] Use DFS with path tracking
- [ ] Method: `transitiveClose(from: String) -> Set<String>`
  - [ ] All downstream nodes (recursive dependents)
- [ ] Conform to Sendable (use locks for thread safety)
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/DependencyGraphTests.swift`
- [ ] Test adding/removing nodes
- [ ] Test adding/removing edges
- [ ] Test topological sort (valid DAG)
- [ ] Test cycle detection (returns error)
- [ ] Test simple cycle: A→B→A
- [ ] Test complex cycle: A→B→C→D→B
- [ ] Test finding dependents
- [ ] Test finding dependencies
- [ ] Test transitive closure
- [ ] Test disconnected components
- [ ] Test large graphs (1000+ nodes)
- [ ] Test thread safety (concurrent access)

**Example Usage:**
```swift
var graph = DependencyGraph()
graph.addNode(id: "A1", value: 100)
graph.addNode(id: "A2", value: 200)
graph.addNode(id: "A3", value: "=A1+A2")

graph.addEdge(from: "A1", to: "A3") // A3 depends on A1
graph.addEdge(from: "A2", to: "A3") // A3 depends on A2

let order = try graph.topologicalSort()
// Returns: ["A1", "A2", "A3"] or ["A2", "A1", "A3"]
```

**Estimated Effort:** 6-8 hours

---

### 2.2 Calculation Graph ⬜

**File:** `Sources/BusinessMath/Architecture/CalculationGraph.swift`

**Requirements:**
- [ ] Define `CalculationNode` struct
  - [ ] Property: `id: String` (cell reference)
  - [ ] Property: `formula: Formula?` (nil = constant)
  - [ ] Property: `cachedValue: FormulaValue?`
  - [ ] Property: `isDirty: Bool`
  - [ ] Property: `lastCalculated: Date?`
- [ ] Define `Formula` struct
  - [ ] Property: `expression: String`
  - [ ] Property: `ast: FormulaAST`
  - [ ] Property: `dependencies: Set<CellReference>`
  - [ ] Static method: `parse(_ expression: String) throws -> Formula`
  - [ ] Method: `evaluate(context: FormulaContext) throws -> FormulaValue`
- [ ] Implement `CalculationGraph` class
  - [ ] Inherit from `DependencyGraph`
  - [ ] Property: `cells: [CellReference: CalculationNode]`
  - [ ] Method: `setFormula(_ formula: String, for: CellReference) throws`
  - [ ] Method: `setValue(_ value: FormulaValue, for: CellReference)`
  - [ ] Method: `getValue(for: CellReference) throws -> FormulaValue`
  - [ ] Method: `invalidate(_ cell: CellReference)`
  - [ ] Method: `recalculate() throws`
  - [ ] Method: `recalculate(_ cell: CellReference) throws`
- [ ] Automatic dependency extraction from formulas
- [ ] Dirty flag propagation (mark dependents)
- [ ] Smart recalculation (only dirty nodes)
- [ ] Thread safety with locks
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/CalculationGraphTests.swift`
- [ ] Test setting constant values
- [ ] Test setting formulas
- [ ] Test automatic dependency extraction
- [ ] Test formula evaluation
- [ ] Test dirty flag propagation
- [ ] Test smart recalculation (only dirty)
- [ ] Test circular reference detection
- [ ] Test complex dependency chain: A1→A2→A3→A4
- [ ] Test diamond dependency: A1→A2,A3→A4
- [ ] Test invalidation propagates to all dependents
- [ ] Test recalculating single cell
- [ ] Test recalculating entire graph
- [ ] Test changing formula updates dependencies
- [ ] Test thread safety (concurrent reads/writes)
- [ ] Test performance (1000+ cells)

**Example Usage:**
```swift
var graph = CalculationGraph()

// Set constants
graph.setValue(.number(100), for: try CellReference.parse("A1"))
graph.setValue(.number(200), for: try CellReference.parse("A2"))

// Set formula (automatically extracts dependencies)
try graph.setFormula("=A1+A2", for: try CellReference.parse("A3"))

// Get value (calculates if dirty)
let value = try graph.getValue(for: try CellReference.parse("A3"))
// Returns: .number(300)

// Change A1, A3 automatically marked dirty
graph.setValue(.number(150), for: try CellReference.parse("A1"))

// Recalculate only dirty cells
try graph.recalculate()
```

**Estimated Effort:** 8-12 hours

---

### 2.3 Formula Workbook ⬜

**File:** `Sources/BusinessMath/Architecture/FormulaWorkbook.swift`

**Requirements:**
- [ ] Define `FormulaSheet` struct
  - [ ] Property: `name: String`
  - [ ] Property: `graph: CalculationGraph`
  - [ ] Method: `cell(_ reference: String) throws -> FormulaValue`
  - [ ] Method: `setCell(_ reference: String, value: FormulaValue)`
  - [ ] Method: `setCell(_ reference: String, formula: String) throws`
  - [ ] Method: `range(_ rangeRef: String) throws -> [FormulaValue]`
  - [ ] Subscript: `sheet["A1"]` → `FormulaValue?`
  - [ ] Conform to Codable, Sendable
- [ ] Implement `FormulaWorkbook` class
  - [ ] Property: `sheets: [String: FormulaSheet]`
  - [ ] Method: `addSheet(name: String) -> FormulaSheet`
  - [ ] Method: `removeSheet(name: String)`
  - [ ] Method: `sheet(named: String) -> FormulaSheet?`
  - [ ] Method: `recalculateAll()`
  - [ ] Cross-sheet reference support
  - [ ] Subscript: `workbook["Sheet1"]` → `FormulaSheet?`
  - [ ] Conform to Codable
- [ ] Excel-like convenience API
  - [ ] Simple cell access: `workbook["Sheet1"]["A1"]`
  - [ ] Batch operations: `setRange("A1:A10", values: ...)`
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/FormulaWorkbookTests.swift`
- [ ] Test creating workbook with sheets
- [ ] Test adding/removing sheets
- [ ] Test setting cell values
- [ ] Test setting cell formulas
- [ ] Test getting cell values
- [ ] Test range operations
- [ ] Test cross-sheet references: `=Sheet2!A1`
- [ ] Test workbook-wide recalculation
- [ ] Test subscript access
- [ ] Test Codable (save/load workbook)
- [ ] Test complex multi-sheet model
- [ ] Test sheet name validation
- [ ] Test thread safety

**Example Usage:**
```swift
var workbook = FormulaWorkbook()
let revenues = workbook.addSheet(name: "Revenues")
let expenses = workbook.addSheet(name: "Expenses")
let summary = workbook.addSheet(name: "Summary")

// Set values in Revenues sheet
revenues["A1"] = .number(10000)
revenues["A2"] = .number(12000)
try revenues.setCell("A3", formula: "=SUM(A1:A2)")

// Cross-sheet reference
try summary.setCell("A1", formula: "=Revenues!A3 - Expenses!A3")

// Get result
let netIncome = summary["A1"]
```

**Estimated Effort:** 6-8 hours

---

## Phase 3: Multi-Entity Consolidation

**Objective**: Build parent-subsidiary consolidation with eliminations

**Estimated Effort:** 15-20 hours

### 3.1 Entity Hierarchy ⬜

**File:** `Sources/BusinessMath/Financial Statements/EntityHierarchy.swift`

**Requirements:**
- [ ] Define `EntityNode` struct
  - [ ] Property: `entity: Entity`
  - [ ] Property: `parent: EntityNode?` (weak reference)
  - [ ] Property: `children: [EntityNode]`
  - [ ] Property: `ownershipPercent: Double` (0-100)
  - [ ] Property: `consolidationMethod: ConsolidationMethod`
  - [ ] Method: `isWhollyOwned() -> Bool` (100% owned)
  - [ ] Method: `effectiveOwnership() -> Double` (recursive up tree)
- [ ] Define `ConsolidationMethod` enum
  - [ ] `full` - Full consolidation (>50% ownership)
  - [ ] `proportional` - Proportional consolidation (20-50%)
  - [ ] `equity` - Equity method (<20%)
  - [ ] `none` - No consolidation
- [ ] Implement `EntityHierarchy` class
  - [ ] Property: `root: EntityNode` (parent company)
  - [ ] Method: `addSubsidiary(_ entity: Entity, parent: Entity, ownership: Double)`
  - [ ] Method: `removeEntity(_ entity: Entity)`
  - [ ] Method: `updateOwnership(_ entity: Entity, newPercent: Double)`
  - [ ] Method: `allEntities() -> [Entity]`
  - [ ] Method: `subsidiariesOf(_ entity: Entity) -> [EntityNode]`
  - [ ] Method: `consolidationPath() -> [EntityNode]` (topological order)
- [ ] Validation
  - [ ] Ownership must be 0-100%
  - [ ] No circular ownership
  - [ ] Parent must exist before adding children
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Financial Statements Tests/EntityHierarchyTests.swift`
- [ ] Test creating hierarchy
- [ ] Test adding subsidiaries
- [ ] Test ownership percentages
- [ ] Test consolidation method determination
- [ ] Test effective ownership (indirect ownership)
- [ ] Test wholly-owned check
- [ ] Test finding all entities
- [ ] Test finding subsidiaries
- [ ] Test consolidation path order
- [ ] Test validation: invalid ownership, circular reference
- [ ] Test updating ownership
- [ ] Test removing entities
- [ ] Test complex hierarchy (3+ levels)

**Example Usage:**
```swift
let parent = Entity(name: "Parent Corp")
let subsidiary1 = Entity(name: "Subsidiary 1")
let subsidiary2 = Entity(name: "Subsidiary 2")

var hierarchy = EntityHierarchy(root: parent)
hierarchy.addSubsidiary(subsidiary1, parent: parent, ownership: 100.0)
hierarchy.addSubsidiary(subsidiary2, parent: parent, ownership: 75.0)

let path = hierarchy.consolidationPath()
// Returns: [parent, subsidiary1, subsidiary2]
```

**Estimated Effort:** 5-7 hours

---

### 3.2 Consolidation Eliminations ⬜

**File:** `Sources/BusinessMath/Financial Statements/ConsolidationEliminations.swift`

**Requirements:**
- [ ] Define `EliminationEntry<T: Real>` struct
  - [ ] Property: `debitAccount: String`
  - [ ] Property: `creditAccount: String`
  - [ ] Property: `amount: TimeSeries<T>`
  - [ ] Property: `reason: EliminationReason`
  - [ ] Property: `entities: (from: Entity, to: Entity)?` (intercompany)
- [ ] Define `EliminationReason` enum
  - [ ] `intercompanySales` - Revenue/COGS elimination
  - [ ] `intercompanyReceivables` - AR/AP elimination
  - [ ] `intercompanyDividends` - Dividend elimination
  - [ ] `equityInvestment` - Investment elimination
  - [ ] `intercompanyProfit` - Unrealized profit
  - [ ] `custom(String)` - User-defined
- [ ] Implement common elimination patterns:
  - [ ] `eliminateIntercompanySales(from:to:amount:periods:)` → `[EliminationEntry]`
  - [ ] `eliminateIntercompanyReceivables(from:to:amount:periods:)` → `[EliminationEntry]`
  - [ ] `eliminateEquityInvestment(parent:subsidiary:investment:equity:periods:)` → `[EliminationEntry]`
  - [ ] `eliminateDividends(subsidiary:parent:amount:periods:)` → `[EliminationEntry]`
- [ ] Validation
  - [ ] Debits must equal credits
  - [ ] Amounts must be positive
  - [ ] Entities must be in hierarchy
- [ ] Complete DocC documentation with accounting examples

**Tests:** `Tests/BusinessMathTests/Financial Statements Tests/ConsolidationEliminationsTests.swift`
- [ ] Test creating elimination entries
- [ ] Test intercompany sales elimination
- [ ] Test intercompany receivables/payables elimination
- [ ] Test equity investment elimination
- [ ] Test dividend elimination
- [ ] Test unrealized profit elimination
- [ ] Test debit/credit balance validation
- [ ] Test applying eliminations to financial statements
- [ ] Test multiple eliminations in same period
- [ ] Test time series elimination (quarterly/annual)

**Example Usage:**
```swift
// Eliminate intercompany sales: Parent sold $50K to Sub
let periods = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
let amount = TimeSeries(
    periods: periods,
    values: [50_000, 50_000, 50_000, 50_000]
)

let eliminations = eliminateIntercompanySales(
    from: parent,
    to: subsidiary,
    amount: amount,
    periods: periods
)
// Returns: [debit Revenue, credit COGS]
```

**Estimated Effort:** 6-8 hours

---

### 3.3 Consolidation Engine ⬜

**File:** `Sources/BusinessMath/Financial Statements/ConsolidationEngine.swift`

**Requirements:**
- [ ] Implement `ConsolidationEngine` class
  - [ ] Method: `consolidate(hierarchy:period:) throws -> ConsolidatedStatements`
  - [ ] Method: `consolidateIncomeStatement(...) throws -> IncomeStatement<Double>`
  - [ ] Method: `consolidateBalanceSheet(...) throws -> BalanceSheet<Double>`
  - [ ] Method: `consolidateCashFlowStatement(...) throws -> CashFlowStatement<Double>`
- [ ] Define `ConsolidatedStatements<T: Real>` struct
  - [ ] Property: `incomeStatement: IncomeStatement<T>`
  - [ ] Property: `balanceSheet: BalanceSheet<T>`
  - [ ] Property: `cashFlowStatement: CashFlowStatement<T>`
  - [ ] Property: `eliminations: [EliminationEntry<T>]`
  - [ ] Property: `nonControllingInterest: NonControllingInterest<T>`
  - [ ] Method: `summary(for:Period) -> String` (formatted report)
- [ ] Define `NonControllingInterest<T: Real>` struct
  - [ ] Property: `percentOwned: Double` (minority %)
  - [ ] Property: `equityBalance: TimeSeries<T>`
  - [ ] Property: `incomeAllocation: TimeSeries<T>`
  - [ ] Method: `calculate(subsidiaryEquity:subsidiaryIncome:ownership:) -> NonControllingInterest`
- [ ] Consolidation steps:
  1. [ ] Collect all entity statements
  2. [ ] Sum accounts according to consolidation method
  3. [ ] Apply elimination entries
  4. [ ] Calculate non-controlling interest
  5. [ ] Validate balanced statements
- [ ] Support for consolidation methods
  - [ ] Full consolidation: 100% of subsidiary accounts
  - [ ] Proportional: ownership% of subsidiary accounts
  - [ ] Equity method: investment account only
- [ ] Complete DocC documentation with consolidation examples

**Tests:** `Tests/BusinessMathTests/Financial Statements Tests/ConsolidationEngineTests.swift`
- [ ] Test simple consolidation (100% owned subsidiary)
- [ ] Test partial ownership (75% subsidiary)
- [ ] Test non-controlling interest calculation
- [ ] Test intercompany elimination during consolidation
- [ ] Test multi-level consolidation (parent→sub1→sub2)
- [ ] Test proportional consolidation
- [ ] Test equity method consolidation
- [ ] Test balanced statements (assets = liabilities + equity)
- [ ] Test validation errors
- [ ] Test complex scenario with multiple subsidiaries
- [ ] Test consolidation across quarters

**Example Usage:**
```swift
let engine = ConsolidationEngine()

// Consolidate for Q1 2025
let consolidated = try engine.consolidate(
    hierarchy: hierarchy,
    period: Period.quarter(year: 2025, quarter: 1)
)

print(consolidated.incomeStatement.netIncome)
print(consolidated.nonControllingInterest.incomeAllocation)
print("Eliminations: \\(consolidated.eliminations.count)")
```

**Estimated Effort:** 8-10 hours

---

### 3.4 Consolidation Tutorial ⬜

**File:** `Sources/BusinessMath/BusinessMath.docc/ConsolidationGuide.md`

**Requirements:**
- [ ] Overview of consolidation accounting
- [ ] Step-by-step consolidation example
- [ ] Intercompany elimination examples
- [ ] Non-controlling interest calculation
- [ ] Multi-level consolidation example
- [ ] Code examples for each scenario
- [ ] Links to API reference
- [ ] Added to BusinessMath.md landing page
- [ ] Follows DocC guidelines (no ## Topics in narrative)

**Estimated Effort:** 4-6 hours

---

## Phase 4: Caching & Performance

**Objective**: Intelligent memoization for expensive calculations

**Estimated Effort:** 10-15 hours

### 4.1 Calculation Cache ⬜

**File:** `Sources/BusinessMath/Architecture/CalculationCache.swift`

**Requirements:**
- [ ] Define `CacheEntry<Value>` struct
  - [ ] Property: `value: Value`
  - [ ] Property: `timestamp: Date`
  - [ ] Property: `dependencies: Set<AnyHashable>`
  - [ ] Property: `accessCount: Int`
  - [ ] Property: `lastAccess: Date`
- [ ] Implement `CalculationCache<Key: Hashable, Value>` class
  - [ ] Property: `cache: [Key: CacheEntry<Value>]`
  - [ ] Property: `dependencyMap: [AnyHashable: Set<Key>]`
  - [ ] Property: `maxSize: Int` (LRU eviction)
  - [ ] Property: `statistics: CacheStatistics`
  - [ ] Method: `get(_ key: Key) -> Value?`
  - [ ] Method: `set(_ key: Key, value: Value, dependencies: [AnyHashable])`
  - [ ] Method: `invalidate(_ key: Key)`
  - [ ] Method: `invalidate(dependency: AnyHashable)`
  - [ ] Method: `clear()`
  - [ ] Method: `evict(leastRecentlyUsed count: Int)`
- [ ] Define `CacheStatistics` struct
  - [ ] Property: `hits: Int`
  - [ ] Property: `misses: Int`
  - [ ] Property: `evictions: Int`
  - [ ] Computed: `hitRate: Double`
  - [ ] Method: `reset()`
- [ ] Thread safety with locks
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/CalculationCacheTests.swift`
- [ ] Test basic get/set
- [ ] Test cache hits/misses
- [ ] Test dependency invalidation
- [ ] Test cascading invalidation
- [ ] Test LRU eviction
- [ ] Test max size enforcement
- [ ] Test statistics tracking
- [ ] Test thread safety (concurrent access)
- [ ] Test memory pressure handling
- [ ] Test performance (10K+ entries)

**Example Usage:**
```swift
var cache = CalculationCache<CellReference, Double>(maxSize: 1000)

let ref = try CellReference.parse("A1")
cache.set(ref, value: 123.45, dependencies: [])

if let value = cache.get(ref) {
    print("Cache hit: \\(value)")
}

print("Hit rate: \\(cache.statistics.hitRate)")
```

**Estimated Effort:** 6-8 hours

---

### 4.2 TimeSeries Caching Extension ⬜

**File:** `Sources/BusinessMath/Architecture/TimeSeriesCaching.swift`

**Requirements:**
- [ ] Extend `TimeSeries` with caching
  - [ ] Method: `cached() -> CachedTimeSeries<T>`
  - [ ] Cached operations: `movingAverage`, `growthRate`, `exponentialMovingAverage`
  - [ ] Automatic invalidation on modification
- [ ] Implement `CachedTimeSeries<T: Real>` wrapper
  - [ ] Wraps original TimeSeries
  - [ ] Internal cache for expensive operations
  - [ ] Transparent caching (same API as TimeSeries)
  - [ ] Method: `clearCache()`
  - [ ] Property: `cacheStatistics: CacheStatistics`
- [ ] Benchmark cached vs uncached operations
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/TimeSeriesCachingTests.swift`
- [ ] Test cached moving average
- [ ] Test cached growth rate
- [ ] Test cached EMA
- [ ] Test cache invalidation on modification
- [ ] Test cache hit rate
- [ ] Test performance improvement (benchmark)
- [ ] Test memory usage
- [ ] Test thread safety

**Example Usage:**
```swift
let series = TimeSeries(periods: periods, values: largeDataset)
let cached = series.cached()

// First call: computed and cached
let ma1 = cached.movingAverage(window: 20)

// Second call: retrieved from cache (fast!)
let ma2 = cached.movingAverage(window: 20)

print("Hit rate: \\(cached.cacheStatistics.hitRate)")
```

**Estimated Effort:** 4-6 hours

---

## Phase 5: Model Versioning

**Objective**: Track model changes over time (like git for models)

**Estimated Effort:** 12-18 hours

### 5.1 Model Snapshot ⬜

**File:** `Sources/BusinessMath/Architecture/ModelSnapshot.swift`

**Requirements:**
- [ ] Define `ModelSnapshot` struct
  - [ ] Property: `drivers: [String: SerializableDriver]`
  - [ ] Property: `formulas: [CellReference: String]`
  - [ ] Property: `assumptions: [String: AssumptionValue]`
  - [ ] Property: `sheets: [String: SheetSnapshot]`
  - [ ] Property: `timestamp: Date`
  - [ ] Method: `capture(from workbook: FormulaWorkbook) -> ModelSnapshot`
  - [ ] Conform to Codable, Hashable
- [ ] Define `AssumptionValue` enum (Codable)
  - [ ] `double(Double)`
  - [ ] `string(String)`
  - [ ] `timeSeries(TimeSeries<Double>)`
  - [ ] `array([Double])`
- [ ] Define `SheetSnapshot` struct (Codable)
  - [ ] Property: `name: String`
  - [ ] Property: `cells: [CellReference: FormulaValue]`
  - [ ] Property: `formulas: [CellReference: String]`
- [ ] Snapshot compression (omit default values)
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/ModelSnapshotTests.swift`
- [ ] Test capturing snapshot from workbook
- [ ] Test Codable (serialize/deserialize)
- [ ] Test snapshot equality/hashing
- [ ] Test snapshot size (reasonable compression)
- [ ] Test capturing large models (1000+ cells)
- [ ] Test capturing with drivers
- [ ] Test capturing with assumptions
- [ ] Test restoring from snapshot

**Example Usage:**
```swift
let workbook = createFinancialModel()
let snapshot = ModelSnapshot.capture(from: workbook)

// Serialize to JSON
let json = try JSONEncoder().encode(snapshot)
try json.write(to: URL(fileURLWithPath: "model_v1.json"))

// Load from JSON
let loadedSnapshot = try JSONDecoder().decode(
    ModelSnapshot.self,
    from: json
)
```

**Estimated Effort:** 5-7 hours

---

### 5.2 Model History ⬜

**File:** `Sources/BusinessMath/Architecture/ModelHistory.swift`

**Requirements:**
- [ ] Define `ModelVersion` struct
  - [ ] Property: `versionNumber: Int`
  - [ ] Property: `timestamp: Date`
  - [ ] Property: `author: String`
  - [ ] Property: `message: String` (commit message)
  - [ ] Property: `snapshot: ModelSnapshot`
  - [ ] Property: `parent: Int?` (previous version)
  - [ ] Conform to Codable, Identifiable
- [ ] Implement `ModelHistory` class
  - [ ] Property: `versions: [Int: ModelVersion]`
  - [ ] Property: `currentVersion: Int`
  - [ ] Property: `head: Int` (latest version)
  - [ ] Method: `commit(message: String, author: String, snapshot: ModelSnapshot) -> ModelVersion`
  - [ ] Method: `checkout(version: Int) -> ModelSnapshot`
  - [ ] Method: `rollback(to version: Int)`
  - [ ] Method: `log() -> [ModelVersion]` (ordered by version)
  - [ ] Method: `diff(from: Int, to: Int) -> ModelDiff`
  - [ ] Method: `save(to url: URL) throws`
  - [ ] Method: `load(from url: URL) throws -> ModelHistory`
  - [ ] Conform to Codable
- [ ] Define `ModelDiff` struct
  - [ ] Property: `cellsChanged: [CellReference: (old: FormulaValue?, new: FormulaValue?)]`
  - [ ] Property: `formulasChanged: [CellReference: (old: String?, new: String?)]`
  - [ ] Property: `driversChanged: [String: (old: Any?, new: Any?)]`
  - [ ] Method: `summary() -> String` (human-readable)
- [ ] Complete DocC documentation

**Tests:** `Tests/BusinessMathTests/Architecture Tests/ModelHistoryTests.swift`
- [ ] Test creating initial commit
- [ ] Test committing changes
- [ ] Test checking out previous version
- [ ] Test rolling back
- [ ] Test version log
- [ ] Test diff between versions
- [ ] Test save/load history
- [ ] Test branching (future feature)
- [ ] Test large history (100+ versions)

**Example Usage:**
```swift
var history = ModelHistory()

// Initial commit
let v1 = history.commit(
    message: "Initial model with revenue assumptions",
    author: "Alice",
    snapshot: ModelSnapshot.capture(from: workbook)
)

// Make changes to workbook...

// Second commit
let v2 = history.commit(
    message: "Updated growth rate from 10% to 15%",
    author: "Alice",
    snapshot: ModelSnapshot.capture(from: workbook)
)

// View diff
let diff = history.diff(from: v1.versionNumber, to: v2.versionNumber)
print(diff.summary())

// Rollback
history.rollback(to: v1.versionNumber)
```

**Estimated Effort:** 6-8 hours

---

### 5.3 Model Versioning Tutorial ⬜

**File:** `Sources/BusinessMath/BusinessMath.docc/ModelVersioningGuide.md`

**Requirements:**
- [ ] Overview of model versioning
- [ ] Committing changes
- [ ] Viewing history and diffs
- [ ] Rolling back changes
- [ ] Saving/loading versioned models
- [ ] Best practices
- [ ] Code examples for each scenario
- [ ] Links to API reference
- [ ] Added to BusinessMath.md landing page
- [ ] Follows DocC guidelines

**Estimated Effort:** 3-5 hours

---

## Phase 6: Integration & Documentation

**Objective**: Tie everything together with comprehensive examples and guides

**Estimated Effort:** 12-18 hours

### 6.1 Integration Tests ⬜

**File:** `Tests/BusinessMathTests/Architecture Tests/IntegrationTests.swift`

**Requirements:**
- [ ] Test: Complete formula workbook workflow
  - [ ] Create workbook with multiple sheets
  - [ ] Set formulas with cross-sheet references
  - [ ] Recalculate and verify results
  - [ ] Test circular reference detection
- [ ] Test: Financial model with formulas
  - [ ] Revenue model with growth formulas
  - [ ] P&L with SUM, IF, NPV formulas
  - [ ] Balance sheet with linking formulas
  - [ ] Cash flow with indirect method formulas
- [ ] Test: Multi-entity consolidation workflow
  - [ ] Create parent and subsidiary statements
  - [ ] Set up entity hierarchy
  - [ ] Define intercompany transactions
  - [ ] Consolidate and verify eliminations
  - [ ] Check non-controlling interest
- [ ] Test: Cached calculations performance
  - [ ] Large formula workbook
  - [ ] Measure cache hit rate
  - [ ] Verify performance improvement
- [ ] Test: Model versioning workflow
  - [ ] Create model
  - [ ] Commit version 1
  - [ ] Make changes
  - [ ] Commit version 2
  - [ ] Diff versions
  - [ ] Rollback and verify
  - [ ] Save/load history
- [ ] Test: Complete 3-statement model with formulas
  - [ ] Income statement formulas
  - [ ] Balance sheet formulas
  - [ ] Cash flow statement formulas
  - [ ] All statements linked and consistent

**Example Scenarios:**
```swift
@Test("Complete SaaS financial model with formulas")
func completeSaaSModel() throws {
    // Create workbook
    let wb = FormulaWorkbook()
    let assumptions = wb.addSheet(name: "Assumptions")
    let pl = wb.addSheet(name: "P&L")
    let bs = wb.addSheet(name: "Balance Sheet")
    let cf = wb.addSheet(name: "Cash Flow")

    // Set assumptions
    assumptions["B1"] = .number(100)  // MRR
    try assumptions.setCell("B2", formula: "=B1 * 1.10")  // Growth
    try assumptions.setCell("B3", formula: "=B2 * 1.10")

    // Build P&L
    try pl.setCell("B2", formula: "=Assumptions!B1 * 12")  // Annual Rev
    try pl.setCell("B3", formula: "=B2 * 0.30")  // COGS
    try pl.setCell("B4", formula: "=B2 - B3")  // Gross Profit

    // Verify
    let revenue = try pl.cell("B2")
    #expect(abs(revenue.asNumber()! - 1200) < 0.01)
}
```

**Estimated Effort:** 8-12 hours

---

### 6.2 Comprehensive Documentation ⬜

**Files:** `Sources/BusinessMath/BusinessMath.docc/`

**Requirements:**

- [ ] **Formula Engine Guide** (`FormulaEngineGuide.md`)
  - [ ] Overview of formula syntax
  - [ ] Cell references and ranges
  - [ ] Built-in functions reference
  - [ ] Creating custom functions
  - [ ] Error handling
  - [ ] Performance tips
  - [ ] Complete examples

- [ ] **Calculation Graph Guide** (`CalculationGraphGuide.md`)
  - [ ] Dependency tracking explained
  - [ ] Smart recalculation
  - [ ] Circular reference detection
  - [ ] Performance considerations
  - [ ] Examples with diagrams

- [ ] **Building Financial Models Guide** (`BuildingFinancialModelsGuide.md`)
  - [ ] Step-by-step model construction
  - [ ] Using formulas in financial statements
  - [ ] Linking P&L, Balance Sheet, Cash Flow
  - [ ] Best practices
  - [ ] Complete 3-statement model example

- [ ] Update **BusinessMath.md** landing page
  - [ ] Add Topic 7 to navigation
  - [ ] Add new tutorials
  - [ ] Update overview

- [ ] All docs follow DocC guidelines
  - [ ] No `## Topics` in narrative articles
  - [ ] Proper "Next Steps" and "See Also" sections
  - [ ] Added to landing page
  - [ ] Cross-references work

**Estimated Effort:** 8-12 hours

---

## Completion Criteria

### Phase Complete When:
- [ ] All files implemented
- [ ] All tests passing
- [ ] Test coverage > 90%
- [ ] All documentation complete
- [ ] DocC builds without errors
- [ ] No compiler warnings
- [ ] Code review completed
- [ ] Examples verified working
- [ ] Performance benchmarks acceptable

### Ready for Release (v1.12.0) When:
- [ ] All phases complete
- [ ] Integration tests passing
- [ ] Documentation published
- [ ] README updated
- [ ] CHANGELOG updated
- [ ] Version tagged
- [ ] Migration guide for breaking changes

---

## Implementation Strategy

### Phase Order
1. **Phase 1** (25-35 hrs): Formula Engine - Foundation for everything else
2. **Phase 2** (15-20 hrs): Calculation Graph - Builds on formulas
3. **Phase 3** (15-20 hrs): Consolidation - Uses existing financial statements
4. **Phase 4** (10-15 hrs): Caching - Performance optimization (can do in parallel with Phase 5)
5. **Phase 5** (12-18 hrs): Versioning - Model management (can do in parallel with Phase 4)
6. **Phase 6** (12-18 hrs): Integration - Tie everything together

### Total Estimated Time
- **Minimum**: 89 hours (~11 full days)
- **Maximum**: 126 hours (~16 full days)
- **Realistic**: ~100 hours (~12-13 full days)

### Milestones
- **Milestone 1**: Formula Engine working (end of Phase 1)
- **Milestone 2**: Smart recalculation working (end of Phase 2)
- **Milestone 3**: Consolidation working (end of Phase 3)
- **Milestone 4**: Performance optimized (end of Phase 4)
- **Milestone 5**: Version control working (end of Phase 5)
- **Milestone 6**: Release v1.12.0 (end of Phase 6)

---

## Development Log

### Session 1: October 29, 2025
- Created Topic 7 implementation checklist
- Reviewed master plan and guidelines
- Defined phases and tasks
- Estimated effort for each component
- Ready to begin Phase 1: Formula Engine

---

## Related Documents

- [Master Plan](master_plan.md)
- [Coding Rules](coding_rules.md)
- [Usage Examples](usage_examples.md)
- [DocC Guidelines](docc_guidelines.md)
- [Time Series Checklist](implementation_checklist.md)
