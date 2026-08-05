# AI_DOC_VALIDATION_CHECKLIST.md

This checklist serves as the definitive source for validating all project documentation. Adherence to these rules is mandatory to ensure code quality, successful DocC builds, and optimal efficiency for the AI Code Generator (especially for MCP tool construction).

---

## I. General API Documentation (Inline DocC)

These rules apply to all public types, functions, properties, and protocol requirements using triple-slash (`///`) comments.

| Requirement | Status | Source Reference |
| :--- | :--- | :--- |
| **Complete Core Sections** | Must include **Summary**, **Parameters**, and **Returns** sections. | [1, 2] |
| **Code Examples** | Must include at least one runnable Swift code block usage example. | [2, 3] |
| **Excel Equivalent** | Must be noted for all financial functions (e.g., `/// Equivalent of Excel's NPV(...)`). | [2, 4] |
| **Mathematical Formula** | Must be included for all complex mathematical functions and ratios. | [2, 4] |
| **Concurrency (`Sendable`)** | Must document thread-safe types and parameters. | [5] |
| **Error Documentation** | Must document what specific errors (`- Throws:`) can be generated. | [2, 6] |
| **Complexity Documentation** | Should include time/space complexity (e.g., `- Complexity: O(n)`) if non-trivial. | [1] |

### ⚠️ Critical Rule: Mathematical Correctness

This rule ensures mathematical rigor and prevents the masking of errors.

| Requirement | Status | Source Reference |
| :--- | :--- | :--- |
| **NaN/Error Handling** | Must explicitly document behavior for invalid inputs (i.e., when to return **NaN** vs. when to **throw an error**). | [7-9] |
| **No Silent Defaults** | **CRITICAL**: Never use default values that mask mathematically undefined operations. | [3, 7-9] |
| **Test Invalid Inputs** | Must verify in tests that invalid inputs correctly return `NaN` or throw a documented error. | [3, 9] |

---

## II. DocC Narrative Articles (Tutorials/Guides)

These rules apply to standalone `.md` files in the documentation catalog (e.g., `ForecastingGuide.md`). Failure to comply causes articles to break or be "orphaned" [10, 11].

| Requirement | Status | Source Reference |
| :--- | :--- | :--- |
| **Filename Convention** | Filename must include descriptive suffix like `Guide`, `Tutorial`, or `Walkthrough` (e.g., `FinancialStatementsGuide.md`). | [12, 13] |
| **No "Topics" Header** | **CRITICAL PITFALL**: Must **NOT** contain `## Topics` header in the narrative body. Use `## Overview` or `## Content` instead. | [10, 14] |
| **Landing Page Link** | Must be explicitly added to the main `BusinessMath.md` landing page upon creation. | [13, 15] |
| **Mandatory End Sections** | Must end narrative articles with these **two separate sections**, in this exact order: | [13, 16] |
| **"Next Steps" Syntax** | This section must use **ONLY** article links (`<doc:ArticleName>`) and include descriptive text. | [16] |
| **"See Also" Syntax** | This section must use **ONLY** API Symbol links (``SymbolName``) and must **NOT** include descriptive text. | [16] |
| **No Mixed Links** | **CRITICAL PITFALL**: Must **NOT** use a "Related Documentation" section that mixes article and API symbol links. | [13, 16] |

---

## III. Model Context Protocol (MCP) Tool Documentation

These rules ensure AI assistants can reliably construct valid JSON payloads for the 118 computational tools, minimizing ambiguity [17, 18].

| Requirement | Status | Source Reference |
| :--- | :--- | :--- |
| **REQUIRED STRUCTURE** | **MANDATORY**: Tool documentation must begin with a `REQUIRED STRUCTURE` section showing the minimal working JSON example. | [18-20] |
| **Explicit Schema** | Must include explicit input schema with detailed parameter descriptions. | [18] |
| **Nested Objects** | Every nested object or array must be fully documented with its structure and type information (string, number, array, object). | [21, 22] |
| **Date/Time Formats** | **CRITICAL**: All date/time inputs must have their exact format explicitly specified (e.g., **ISO 8601**). | [19, 22] |
| **Enum Values Listed** | All accepted discrete values (enums, like `PeriodType`) must be explicitly listed. | [22] |
| **Required/Optional** | Fields must be clearly marked as required vs. optional. | [21] |
| **Multiple Examples** | Must provide at least two complete, realistic usage examples demonstrating different use cases. | [22] |
