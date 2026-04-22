# harness-kit — Claude Code Project Instructions

This project is a framework for rigorous, language-agnostic feature development.
It provides slash commands and specialized subagents for planning, implementing,
testing, and reviewing code changes against any project profile.

## Quick Reference

The workflow is cyclic: **Orient → Ideate → Implement → Contribute**. Start with `/hello`, then move through `/new-task` → `/refine-task` → `/do-task` → `/open-pr`. For long-term RL-driven optimization, use `/learn` (strictly opt-in).

## Architecture

`.claude/` is the shared infrastructure (single source of truth).
`.claude/skills/*/SKILL.md` are slash commands, and `.claude/agents/*.md` are subagent definitions.

```
.claude/skills/*/SKILL.md    ← slash commands (16 skills)
.claude/agents/*.md          ← subagent definitions (22 agents)
.claude/settings.json        ← lifecycle hooks

.claude/profiles/*.yaml      ← project configuration
.claude/features/             ← tickets (todo/, completed/, ticket_tracker.md)
.claude/artifacts/            ← phase output artifacts
.claude/specs/                ← formal specifications (read on demand)
.claude/rules/                ← governance rules (read on demand)
.claude/context/              ← reference material and submodules
```

## Ticket Tracking

Auto-detected at session start:
- GitHub mode: when `gh auth status` succeeds — uses GitHub Issues via `gh` CLI
- Local mode: uses `.claude/features/todo/TASK-NNN.json` files

Override via profile: `extensions.tracking.mode: "github"` or `"local"`.

## Specifications (Read On Demand)

Do NOT load these at session start. Read them only when a skill or agent needs them:

| Spec | When to Read |
|------|-------------|
| `.claude/specs/project-profile-schema.md` | Creating or modifying a project profile |
| `.claude/specs/workflow-contract.md` | Understanding phase invariants or error handling |
| `.claude/specs/phase-orchestrator.md` | Implementing `/do-task` phases |
| `.claude/specs/review-rubrics.md` | Running code review agents |
| `.claude/specs/ticket-lifecycle.md` | Creating or transitioning tickets |
| `.claude/specs/finding-schema.md` | Parsing or emitting review findings |
| `.claude/specs/artifact-contracts.md` | Writing phase output artifacts |
| `.claude/specs/normalization-rules.md` | Normalizing artifact JSON |
| `.claude/specs/polyglot-architecture.md` | Polyglot / Diplomat FFI workflows |
| `.claude/specs/observability-standard.md` | REDACTED telemetry instrumentation |

| `.claude/specs/moldable-canvas.md` | Building moldable workbench features or inspectable components |
| `.claude/specs/component-model.md` | Defining full-stack component bundles with evidence artifacts |
| `.claude/specs/hot-reload.md` | Implementing hot-reload with state migration |

## Governance Rules (Read On Demand)

| Rule | When to Read |
|------|-------------|
| `.claude/rules/orchestration.md` | Agent spawning, review batching, profile init |
| `.claude/rules/workflow-phases.md` | Phase sequencing reference |
| `.claude/rules/finding-schema.md` | Finding output format |
| `.claude/rules/artifact-standards.md` | Normalization and dual-output rules |

## Key Conventions

- A task corresponds 1:1 to a GitHub Issue. Sub-tasks map to GitHub sub-issues.
- Every phase emits dual artifacts (JSON + Markdown) in local mode; GitHub mode uses issue comments.
- Errors are data (structured `PhaseResult`), never exceptions. Always return status, never crash.
- Bounded iteration: `max_fix_iterations` from the project profile (default 3).
- Review runs in 3 batches: correctness (blocking), quality + docs (advisory), extended (advisory).
- Findings conform to `finding.v1` schema with severity, category, location, confidence, and suggested fix.
- **Autonomous git/GitHub operations:** Proceed directly with `gh issue create`, `gh issue edit`, `gh pr create`, and `git commit` without intermediate approval. User confirmation is implicit via command invocation (`/new-task`, `/open-pr`, etc.). Use **AskUserQuestion** only for genuine design clarifications, not execution approvals.

## Agent Registry

22 agents spawnable via Task tool. See `.claude/README.md` for the full table with `subagent_type` values and model assignments.

## Project Profile

Each target project has a `.claude/profiles/<name>.yaml` with identity, layout, toolchain, governance, review graph, and lifecycle config. See `.claude/profiles/_template.yaml` for the schema.
