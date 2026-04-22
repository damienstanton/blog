# RL Workflow Specification

## Overview

The harness-kit RL workflow extends harness-kit with an autonomous reinforcement learning loop based on Microsoft Research's AgentLightning framework. This system learns optimal strategies for feature implementation through trial, reward, and skill augmentation.

## Architecture

### Components

1. **Policy Network** — Learns skill selection and parameter tuning
2. **Reward Calculator** — Aggregates signals from tests, reviews, and user feedback
3. **Experience Buffer** — Stores episodes for sample-efficient learning
4. **Hierarchical Decomposition** — Epic → Features → Skills → Steps → Edits
5. **Container Execution** — Isolated Python/TypeScript/Rust environments
6. **Skill Registry** — Self-augmentation through new skill proposals

### Integration Points

- **Issue #3 (Auto-release)**: New skills trigger version bumps and releases
- **Issue #4 (Autonomous operations)**: RL loop proceeds without approval gates
- **Issue #6 (harness-kit orchestrator)**: RL guidance feeds workflow decisions
- **Issue #7 (TypeScript constraints)**: Type errors provide negative reward signals
- **Issue #8 (Multi-modal cognition)**: Visual reasoning enhances RL state representation

## RL Loop Flow

```
1. Load ticket (from GitHub Issues or local mode)
2. RL Planner: Select high-level strategy (hierarchical policy)
3. RL Executor: Decompose into skill sequence (low-level policy)
4. Execute skills in containers (Python/TS/Rust sandboxes)
5. Collect reward signals:
   - Test pass rate (+10 per passing test)
   - Code review score (0-10 scaled)
   - DoD compliance (+20 if all criteria met)
   - User feedback (±50 on PR accept/reject)
   - Type errors (-1 per error from Issue #7)
6. Store experience tuple: (state, action, reward, next_state, done)
7. Update policy network via PPO (Proximal Policy Optimization)
8. Checkpoint model every N episodes
9. If episode successful: auto-create PR (Issue #4)
10. If PR merged: positive reward; if closed: negative reward with reason
11. If repeated pattern detected: propose new skill (Phase 3)
```

## Policy Network

### Input (State)

- **Ticket context**: title, description, acceptance criteria (embedded as 768-dim vector via embeddinggemma from Issue #8)
- **Codebase state**: file tree, recent commits, test results
- **Visual representation**: diagram/architecture visualization (from Issue #8 multi-modal pipeline)
- **Historical performance**: success rate on similar tickets

### Output (Action)

- **Skill selection**: probability distribution over available skills
- **Skill parameters**: arguments to pass to selected skill
- **Exploration**: epsilon-greedy or curiosity-driven (intrinsic rewards)

### Architecture

Transformer-based policy with attention over skill history:
- Input: concatenated (ticket_embedding, codebase_embedding, visual_embedding)
- Transformer layers: 4 heads, 512 hidden dim
- Output: softmax over skills + regression for parameters
- Trained via PPO with discount factor γ=0.99

## Reward Function

### Primary Rewards

| Event | Reward | Rationale |
|-------|--------|-----------|
| Test pass | +10 | Core correctness signal |
| Test fail | -5 | Penalty for breaking code |
| Review score (0-10) | 0-10 | Code quality gradient |
| DoD met | +20 | Task completion bonus |
| DoD failed | -3 | Incomplete work penalty |

### Shaping Rewards

| Event | Reward | Rationale |
|-------|--------|-----------|
| Code formatted | +1 | Encourage hygiene |
| No lint errors | +1 | Encourage hygiene |
| Docs updated | +2 | Encourage documentation |
| Type error | -1 | From Issue #7 constraint engine |

### User Feedback Rewards

| Event | Reward | Rationale |
|-------|--------|-----------|
| PR accepted | +50 | Strong positive signal |
| PR rejected | -20 + reason embedding | Learn from failure |

### Curiosity Rewards

Intrinsic reward for exploring novel (state, action) pairs:
- Embedding distance from historical states
- Scales with inverse frequency of action
- Prevents policy collapse to local optima

## Experience Buffer

Schema: `(state, action, reward, next_state, done)` tuples

```json
{
  "schema_version": "experience.v1",
  "episode_id": "ep-<sha8>",
  "timestamp": "<ISO 8601>",
  "state": {
    "ticket_id": "TASK-NNN",
    "ticket_embedding": [/* 768-dim vector */],
    "codebase_state": {/* file tree, commits */},
    "visual_context": "base64-encoded-image"
  },
  "action": {
    "skill": "implementer",
    "parameters": {"target_files": ["src/lib.rs"]}
  },
  "reward": 15.0,
  "next_state": {/* same structure as state */},
  "done": false
}
```

Storage: `.claude/rl/episodes/<episode-id>.json`

## Container Execution

### Python Container (`Dockerfile.python-rl`)

- Python 3.11, PyTorch, LangGraph, REDACTED SDK
- Policy training, reward calculation, orchestration
- Mounts: `/workspace` (read-write), `/claude-ro` (read-only framework)

### TypeScript Container (`Dockerfile.typescript-sandbox`)

- Node 20, TypeScript 5.x, Vitest, React
- UI component generation, type constraint validation
- Mounts: `/workspace` (read-write)

### Rust Container (`Dockerfile.rust-sandbox`)

- Rust stable, Cargo, proptest
- Core logic, FFI bridge generation
- Mounts: `/workspace` (read-write)

### Safety Constraints

- Resource limits: 2 CPU cores, 4GB RAM per container
- Network isolation: no outbound except to localhost
- Read-only mounts: harness-kit framework files
- Circuit breaker: halt if reward < -50.0 threshold

## Skill Augmentation

When the RL loop detects a repeated pattern (same action sequence across 3+ episodes):

1. **Proposal**: `propose-skill` agent drafts `.claude/skills/<name>/SKILL.md`
2. **Validation**: `validate-skill` agent runs acceptance tests
3. **Approval**: AskUserQuestion with skill diff preview
4. **Integration**: Write skill file, update registry
5. **Release**: Trigger Issue #3 auto-release workflow

Skill proposal schema:

```json
{
  "schema_version": "skill_proposal.v1",
  "name": "new-skill-name",
  "description": "What this skill does",
  "trigger_pattern": "Detected action sequence",
  "acceptance_criteria": ["Test 1", "Test 2"],
  "estimated_value": 0.85
}
```

## Hierarchical Decomposition

### RL Planner (High-Level)

Input: Epic-level ticket
Output: Strategy → list of feature-level sub-tasks

### RL Executor (Low-Level)

Input: Feature-level ticket
Output: Skill sequence → ordered list of (skill, parameters)

### Decomposition Levels

1. **Epic**: Multi-week, 6+ files, multiple concerns → decompose to Features
2. **Feature**: Single PR, 1-5 files → decompose to Skills
3. **Skill**: Single command invocation → decompose to Steps
4. **Step**: Single code edit → atomic operation

## Warm-Start Training

Pre-train policy on historical harness-kit artifacts:

- Plans: `.claude/artifacts/*_plan.json` → (ticket, strategy) pairs
- Iterations: `.claude/artifacts/*_iteration.json` → (plan, skill sequence) pairs
- Reviews: `.claude/artifacts/*_review.json` → (code diff, quality score) pairs

Imitation learning: supervised learning on (state, action) pairs before RL fine-tuning.

## Observability

REDACTED telemetry (Issue #8 integration):

- One trace per RL episode
- Spans: policy decision, skill execution, reward calculation
- Metrics: episode reward, policy loss, exploration rate, skill success rate
- Attention weights: visualize which part of ticket influenced skill selection

## Safety and Human-in-the-Loop

- Circuit breakers: halt if reward drops below -50.0
- User approval gates: skill proposals, major architectural decisions
- Explainability: log policy decisions with attention weights
- Rollback: git revert for failed episodes

## Future Extensions

- Multi-agent scenarios (parallel tickets with coordinated policies)
- Transfer learning across projects (shared policy, project-specific fine-tuning)
- Demonstration mode (record manual workflows for imitation learning)
- Curiosity-driven exploration (intrinsic rewards for novel states)

---

**Status**: Phase 1 specification complete. Implementation deferred to follow-up issues.

---

**Status**: 🎯 Bootstrap Blueprint - Implementation stubs exist in `.claude/rl/*.py`. When `/learn` detects missing RL infrastructure, it offers to create implementation tickets. The system then builds itself.

**Dependencies**: None - this spec is self-contained. The `/learn` command works without RL (manual mode) and bootstraps RL when requested.
