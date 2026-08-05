# FORMULA_GRAMMAR.md

This document defines the formal grammar for the FinancialAnalysis Formula Language, which is used to calculate derived accounts within the JSON templates. Adherence to this grammar is mandatory for formula generation and validation.

## I. Core Grammar Definition

The formula language is a simple arithmetic expression parser supporting standard binary operations and parentheses [1, 2].

### Supported Terminals (Tokens)

| Terminal | Description | Context |
| :--- | :--- | :--- |
| `ACCOUNT_NAME` | Reference to any defined account (source or calculated) [3, 4]. | e.g., `Revenue`, `COGS`, `GrossProfit` |
| `NUMBER` | Numeric literal (integer or floating point). | e.g., `100`, `0.1`, `1.5e6` |
| `+` | Addition operator [1, 2]. | |
| `-` | Subtraction operator [1, 2]. | |
| `*` | Multiplication operator [1, 2]. | |
| `/` | Division operator [1, 2]. | |
| `(` | Left Parenthesis [1, 2]. | |
| `)` | Right Parenthesis [1, 2]. | |

### Formal Expression Syntax (EBNF/ABNF Style)

```ebnf
expression = term, { ( "+" | "-" ), term };
term       = factor, { ( "*" | "/" ), factor };
factor     = ( NUMBER | ACCOUNT_NAME ) | "(" , expression, ")" ;
```
## II. Operator Precendence

The formula parser strictly follows standard mathematical precedence rules during evaluation. [1].

| Precedence Rank | Operators | Rule |
| :--- | :--- | :--- |
| 1 (Highest) | `(`,`)` | Parentheses enforce grouping and must be evaluated first [1,2]. |
| 2 | `*`,`/` | Multiplication and Division are evaluated next, from left to right [1,2]. |
| 3 (Lowest) | `+`,`-` | Addition and Subtraction are evaluated last, from left to right [1,2].|

## III. Account Referencing

All account references must match the identifier defined in the `AccountMapping`[3, 4]. Calculated accounts can reference other calculated accounts, and the system automatically resolves dependencies in the correct order [4].

| Feature | Requirement | Example |
| :--- | :--- | :--- |
| Simple Reference | Direct account name resolution [3]. | `Revenue -  COGS` |
| Nested Dependencies | Calculated accounts can reference other calculated accounts [4]. | `OperatingIncome / Revenue` |
| Period References | The language should eventually support period references for lag calculations [5]. | `Revenue[t] - Revenue[t-1]` (Future Enhancement) |

## IV. Error Handling

The parser implements robust error detection[6]. The formula parser detects and handles several error types[2].

| Error Type | Description | Remediation | Source Support |
| :--- | :--- | :--- | :--- |
| Division by Zero | Attempting to divide by a calculated zero value[2]. | Ensure denominator is non-zero[2]. | |
| Undefined Account | Reference to an account name that does not exist in the defined mapping[2]. | Correct the account name[2]. | |
| Syntax Error | Invalid formula structure or unexpected characters[2]. | Ensure parentheses are balanced and operators are used correctly [2]. | |
| Circular Dependency | Account references itself directly or indirectly[2,7]. | The system includes detection for this[7,2].| |

**Note on Future Enhancements:** The formula language can be extended with functions (e.g., `sum`, `avg`) and conditional logic (e.g., `if`/`then`) in later phases[5,8]. For the initial phase, the language supports only basic arithmetic and parentheses[5,9].
