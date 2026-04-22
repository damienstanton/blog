# /learn Command — RL-Driven Goal Optimization

## Overview

The `/learn` command is the top-level entry point that executes a closed-loop workflow: `new-task → refine-task → do-task → open-pr → iterate`. It integrates RL guidance (Issue #5), TypeScript constraint validation (Issue #7), and multi-modal cognitive pipeline (Issue #8).

## Command Signature

```
/learn <goal>
```

Example:
```
/learn "Add rate limiting with token bucket algorithm"
```

## Workflow State Machine

```
┌─────────┐
│  INIT   │
└────┬────┘
     │
     ↓
┌─────────────┐
│  NEW_TASK   │──→ Create GitHub Issue with <goal>
└──────┬──────┘
       │
       ↓
┌──────────────┐
│ REFINE_TASK  │──→ Iterative refinement with user approval
└──────┬───────┘
       │
       ↓
┌──────────┐
│ DO_TASK  │──→ Implement feature with TDD + 8-agent review
└────┬─────┘
     │
     ↓
┌─────────┐
│ OPEN_PR │──→ Create PR, request Copilot review
└────┬────┘
     │
     ↓
┌──────────┐
│ ITERATE  │──→ Address PR feedback, loop back to DO_TASK if needed
└────┬─────┘
     │
     ↓ (PR merged)
┌───────────┐
│ COMPLETE  │
└───────────┘
```

### State Transitions

| From | To | Trigger |
|------|-----|---------|
| INIT → NEW_TASK | Always | Command invocation |
| NEW_TASK → REFINE_TASK | Automatic | Issue created |
| REFINE_TASK → REFINE_TASK | User provides feedback | Refinement loop |
| REFINE_TASK → DO_TASK | User accepts | Refinement complete |
| DO_TASK → OPEN_PR | Implementation complete | Tests pass, review clean |
| OPEN_PR → COMPLETE | PR merged | No feedback needed |
| OPEN_PR → ITERATE | PR feedback received | Changes requested |
| ITERATE → DO_TASK | Feedback addressed | Re-implement |
| ITERATE → OPEN_PR | Minor fixes | Update PR |
| * → BLOCKED | Error | Unrecoverable failure |
| * → ABORTED | User cancels | User intervention |

## RL Integration (Issue #5)

At each decision point, the RL policy provides guidance:

### NEW_TASK
- **RL Input**: Goal text embedding (from Issue #8)
- **RL Output**: Recommended task decomposition strategy
- **Human steering**: User can override with AskUserQuestion

### REFINE_TASK
- **RL Input**: Draft issue body, codebase context
- **RL Output**: Suggested acceptance criteria, related files
- **Human steering**: User reviews and refines

### DO_TASK
- **RL Input**: Refined issue, current codebase state
- **RL Output**: Skill sequence for implementation
- **Human steering**: Auto-proceed unless blocked

### OPEN_PR
- **RL Input**: Code diff, test results, review findings
- **RL Output**: PR title/body, suggested reviewers
- **Human steering**: Auto-proceed (Issue #4)

### ITERATE
- **RL Input**: PR feedback, code quality metrics
- **RL Output**: Prioritized list of fixes
- **Human steering**: User can adjust priority

## TypeScript Constraint Integration (Issue #7)

At DO_TASK and ITERATE stages, run TypeScript type checker:

```bash
tsc --noEmit --project tsconfig.json
```

- **0 errors**: Positive reward signal to RL (+5)
- **N errors**: Negative reward signal (-1 per error)
- **Blocking**: If >10 type errors, halt and report

Constraint violations feed back into RL policy to learn type-safe patterns.

## Multi-Modal Cognitive Integration (Issue #8)

At each workflow stage, engage cognitive pipeline:

1. **Thought**: Current workflow state + next action
2. **Visualize**: Generate architecture diagram (x/z-image-turbo:fp8)
3. **Interpret**: Analyze visual (qwen3-vl:8b)
4. **Reason**: Synthesize understanding (gemma3n:e4b)
5. **Accrete**: Embed knowledge (embeddinggemma:latest)
6. **Orient**: Feed vector back to RL policy

This enriches RL state representation with visual context.

## Session Persistence

State saved to `.claude/state/harness-session.json`:

```json
{
  "schema_version": "harness_session.v1",
  "session_id": "sess-abc123",
  "created": "<ISO 8601>",
  "updated": "<ISO 8601>",
  "goal": "Add rate limiting with token bucket algorithm",
  "current_stage": "DO_TASK",
  "workflow_history": [
    {"stage": "INIT", "timestamp": "...", "duration_ms": 100},
    {"stage": "NEW_TASK", "timestamp": "...", "issue_number": 42},
    {"stage": "REFINE_TASK", "timestamp": "...", "iterations": 2}
  ],
  "issue_number": 42,
  "pr_number": null,
  "rl_episode_id": "ep-abc123",
  "cognitive_context": {
    "visual_representations": ["base64-image-1", "base64-image-2"],
    "accreted_embeddings": [/* 768-dim vectors */]
  }
}
```

## Steering Mechanisms

### Human Steering Points

Use `AskUserQuestion` at these decision points:

1. **NEW_TASK**: "Should we split this into sub-issues?" (if goal is large)
2. **REFINE_TASK**: Design questions from refinement checklist
3. **ITERATE**: "PR feedback received. How should we prioritize?"

### Agent Steering (from RL policy)

Agent can request human input when:
- Confidence < 0.7 threshold
- Multiple strategies with similar reward estimates
- Novel state outside training distribution

### Hybrid Mode

Default: Agent proceeds autonomously, asks when uncertain.
Override: User can force "ask on every decision" mode via config.

## Error Handling

| Error Type | Action |
|------------|--------|
| Test failure (DO_TASK) | Retry with `test-fixer` agent, max 3 iterations |
| Type error >10 (DO_TASK) | Report to user, suggest manual fix |
| Review critical finding | Block PR creation, report to user |
| PR conflicts (ITERATE) | Auto-resolve if trivial, else ask user |
| GitHub API rate limit | Exponential backoff, switch to local mode if persists |
| Container crash | Checkpoint state, restore, retry with lower exploration |

## Observability

REDACTED telemetry (Issue #8 integration):

- One trace per `/learn` invocation
- Spans: one per workflow stage (NEW_TASK, REFINE_TASK, etc.)
- Metrics:
  - Total workflow duration
  - Time per stage
  - RL policy confidence per decision
  - TypeScript type error count
  - Multi-modal pipeline latency

## Future Extensions

- Parallel execution: multiple `/learn` sessions on different goals
- Portfolio learning: RL policy learns cross-project patterns
- Demonstration mode: record manual workflows for imitation learning
- Skill proposal integration: RL suggests new skills during workflow

---

**Status**: ✅ Implemented in Issue #12

**Dependencies**: None - base implementation complete. RL guidance, TypeScript constraints, and multi-modal cognition are optional bootstrap extensions.
