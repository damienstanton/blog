# TypeScript Type System as Constraint Proof Engine

## Overview

Use TypeScript's type system to validate RL-generated code at compile-time. Type errors provide negative reward signals, guiding the policy toward type-safe implementations.

## Architecture

### Type-Level Encodings

1. **Discriminated Unions**: Encode state machines
2. **Conditional Types**: Encode logical constraints
3. **Template Literal Types**: Encode string patterns
4. **Branded Types**: Encode runtime invariants

### Integration with RL Reward Function

```
TypeScript Compiler (tsc --noEmit)
    ↓
Type Error Count
    ↓
Reward Signal: -1 per error
    ↓
RL Policy Update
```

## Type-Level Patterns

### Pattern 1: State Machine Validation

```typescript
// Encode workflow state machine at type level
type WorkflowStage =
  | { stage: 'INIT' }
  | { stage: 'NEW_TASK'; issue_number: number }
  | { stage: 'REFINE_TASK'; issue_number: number }
  | { stage: 'DO_TASK'; issue_number: number }
  | { stage: 'OPEN_PR'; issue_number: number; pr_number: number }
  | { stage: 'ITERATE'; issue_number: number; pr_number: number }
  | { stage: 'COMPLETE'; issue_number: number; pr_number: number }
  | { stage: 'BLOCKED'; reason: string }
  | { stage: 'ABORTED' };

// Valid transitions encoded as conditional types
type ValidTransition<From extends WorkflowStage, To extends WorkflowStage> =
  From extends { stage: 'INIT' }
    ? To extends { stage: 'NEW_TASK' } ? true : false
  : From extends { stage: 'NEW_TASK' }
    ? To extends { stage: 'REFINE_TASK' } ? true : false
  : From extends { stage: 'REFINE_TASK' }
    ? To extends { stage: 'REFINE_TASK' | 'DO_TASK' } ? true : false
  : From extends { stage: 'DO_TASK' }
    ? To extends { stage: 'OPEN_PR' } ? true : false
  : From extends { stage: 'OPEN_PR' }
    ? To extends { stage: 'COMPLETE' | 'ITERATE' } ? true : false
  : From extends { stage: 'ITERATE' }
    ? To extends { stage: 'DO_TASK' | 'OPEN_PR' } ? true : false
  : false;

// Type-safe transition function
function transition<From extends WorkflowStage, To extends WorkflowStage>(
  from: From,
  to: To & (ValidTransition<From, To> extends true ? {} : never)
): To {
  return to;
}

// Compile-time error if invalid transition:
// const state: WorkflowStage = { stage: 'INIT' };
// transition(state, { stage: 'COMPLETE' }); // ERROR: invalid transition
```

### Pattern 2: Skill Parameter Validation

```typescript
// Encode skill signatures at type level
type SkillName = 'planner' | 'implementer' | 'test-runner' | 'review-correctness-defensive';

type SkillParams<S extends SkillName> =
  S extends 'planner' ? { ticket_id: string }
  : S extends 'implementer' ? { ticket_id: string; plan: unknown }
  : S extends 'test-runner' ? { ticket_id: string }
  : S extends 'review-correctness-defensive' ? { diff: string }
  : never;

// Type-safe skill invocation
function invokeSkill<S extends SkillName>(
  skill: S,
  params: SkillParams<S>
): Promise<unknown> {
  // Implementation
  return Promise.resolve();
}

// Compile-time error if wrong params:
// invokeSkill('planner', { diff: 'wrong' }); // ERROR: expected ticket_id
```

### Pattern 3: Branded Types for Invariants

```typescript
// Encode runtime invariants at type level
type NonEmptyString = string & { __brand: 'NonEmptyString' };
type PositiveNumber = number & { __brand: 'PositiveNumber' };
type ValidIssueNumber = number & { __brand: 'ValidIssueNumber' };

function createNonEmptyString(s: string): NonEmptyString | null {
  return s.length > 0 ? (s as NonEmptyString) : null;
}

function createPositiveNumber(n: number): PositiveNumber | null {
  return n > 0 ? (n as PositiveNumber) : null;
}

// Type-safe function signature
function calculateReward(
  test_passed: PositiveNumber,
  issue: ValidIssueNumber
): number {
  return test_passed * 10;
}

// Compile-time error if invariant not proven:
// calculateReward(5, 42); // ERROR: not proven to be PositiveNumber, ValidIssueNumber
```

### Pattern 4: Template Literal Types for String Patterns

```typescript
// Encode string patterns at type level
type IssueID = `TASK-${number}`;
type EpisodeID = `ep-${string}`;
type BranchName = `rl/${string}` | `${number}-${string}`;

function loadTicket(id: IssueID): unknown {
  // Implementation
  return {};
}

// Compile-time error if pattern doesn't match:
// loadTicket('invalid'); // ERROR: not assignable to IssueID
// loadTicket('TASK-123'); // OK
```

## Reward Function Integration

### Reward Calculation

```python
# In .claude/rl/rewards.py

def calculate_type_constraint_reward(
    type_errors: int,
    type_warnings: int
) -> float:
    """
    Calculate reward from TypeScript type checker.

    Args:
        type_errors: Number of type errors from tsc --noEmit
        type_warnings: Number of type warnings

    Returns:
        Reward value: -1 per error, -0.1 per warning
    """
    return -(type_errors * 1.0 + type_warnings * 0.1)
```

### Execution Flow

```
RL Generates Code
    ↓
Write to TypeScript file
    ↓
Run: tsc --noEmit --project tsconfig.json
    ↓
Parse output: count errors and warnings
    ↓
Calculate reward: -1 per error, -0.1 per warning
    ↓
Store in experience buffer
    ↓
Update RL policy
```

## Proof Engine Architecture

```
┌─────────────────────┐
│  RL-Generated Code  │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Type Checker (tsc) │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Constraint Prover  │ (validates type-level constraints)
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Reward Calculator  │ (converts errors → negative reward)
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  RL Policy Update   │
└─────────────────────┘
```

## Implementation

### File: `.claude/rl/type_constraints.py`

```python
"""
TypeScript Type Constraint Validation

Runs tsc --noEmit on generated code and converts type errors to reward signals.
"""

import subprocess
import json
from pathlib import Path
from typing import Dict, List


class TypeConstraintValidator:
    """
    Validates TypeScript code against type-level constraints.

    Uses tsc --noEmit for compile-time validation without code generation.
    """

    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root)
        self.tsconfig = self.project_root / "tsconfig.json"

    def validate(self, files: List[str]) -> Dict:
        """
        Run type checker on files.

        Args:
            files: List of TypeScript file paths

        Returns:
            {
                "errors": int,
                "warnings": int,
                "messages": [...]
            }
        """
        result = subprocess.run(
            ["tsc", "--noEmit", "--project", str(self.tsconfig)],
            capture_output=True,
            text=True
        )

        # Combine stdout and stderr (tsc diagnostics typically go to stderr)
        combined_output = (result.stdout or "") + "\n" + (result.stderr or "")
        errors = self._parse_tsc_output(combined_output, "error")
        warnings = self._parse_tsc_output(combined_output, "warning")

        return {
            "errors": len(errors),
            "warnings": len(warnings),
            "messages": errors + warnings
        }

    def _parse_tsc_output(self, output: str, level: str) -> List[str]:
        """Parse tsc output for errors or warnings."""
        lines = output.split("\n")
        return [line for line in lines if level in line.lower()]

    def calculate_reward(self, validation_result: Dict) -> float:
        """
        Convert validation result to reward signal.

        Args:
            validation_result: Output from validate()

        Returns:
            Reward value: -1 per error, -0.1 per warning
        """
        errors = validation_result["errors"]
        warnings = validation_result["warnings"]
        return -(errors * 1.0 + warnings * 0.1)
```

### File: `tsconfig.json` (project template)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022"],
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true
  },
  "include": [".claude/**/*.ts"],
  "exclude": ["node_modules"]
}
```

## Testing Strategy

### Unit Tests

Test type-level encodings with negative test cases:

```typescript
// test/type-constraints.test.ts

// @ts-expect-error: invalid transition
const invalidTransition = transition(
  { stage: 'INIT' },
  { stage: 'COMPLETE' }
);

// @ts-expect-error: wrong skill params
invokeSkill('planner', { diff: 'wrong' });

// @ts-expect-error: invariant not proven
calculateReward(5, 42);

// @ts-expect-error: pattern doesn't match
loadTicket('invalid');
```

### Integration Tests

Run RL loop with intentionally buggy code, verify negative reward:

```python
# test_rl_integration.py

def test_type_error_negative_reward():
    # Generate code with type errors
    code = "const x: number = 'string';"

    # Run validator
    result = validator.validate([code_file])
    reward = validator.calculate_reward(result)

    # Assert negative reward
    assert reward < 0
    assert result["errors"] == 1
```

## Integration with RL Loop

In `.claude/rl/rl_loop.py`, after skill execution:

```python
# After generating TypeScript code
if any(f.endswith('.ts') for f in generated_files):
    validator = TypeConstraintValidator()
    validation_result = validator.validate(generated_files)
    type_reward = validator.calculate_reward(validation_result)

    # Add to total reward
    total_reward += type_reward

    # Block if too many errors
    if validation_result["errors"] > 10:
        raise CircuitBreakerError("Too many type errors, halting episode")
```

## Future Extensions

- Dependent types (via TypeScript 5.x advanced features)
- Theorem prover integration (Z3, SMT solvers)
- Property-based testing with type-level properties
- Cross-language constraint propagation (TypeScript ↔ Rust via Diplomat FFI)

---

**Status**: 🎯 Bootstrap Blueprint - TypeScript type-level validation feeds reward signals to RL policy. Part of the bootstrap sequence when RL infrastructure is requested.

**Dependencies**: None - this spec is self-contained and integrates with RL workflow when both are implemented.
