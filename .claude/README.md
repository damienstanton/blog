# harness-kit for Claude Code

harness-kit is a language-agnostic feature development framework for Claude Code. It provides a cyclic workflow of four intentions — **Orient → Ideate → Implement → Contribute** — backed by specialized subagents, structured specs, and a governed review pipeline.

```
/hello         Orient     — version check, scan open work, suggest next action
/new-task      Ideate     — research codebase, create + refine a GitHub Issue
/refine-task   Ideate     — 14-item refinement checklist on an existing issue
/do-task       Implement  — TDD loop + 8-agent review
/open-pr       Contribute — create PR, walk Copilot review
```

The human or agent is the implicit orchestrator. Start with `/hello`.

`.claude/` is the single source of truth. All rules, specs, profiles, tickets, and artifacts live here. `CLAUDE.md` provides a concise project summary and pointers to specs — agents read spec files on demand rather than loading them all at session start.

---

## Quick Start

### New project from this template

If you cloned this repo or used it as a template:

```bash
cd your-project
claude
```

Then type `/hello` to orient yourself and see what's on the plate, or `/new-task <description>` to begin planning a feature.

### Adding harness-kit to an existing project

Install the framework:

```bash
bash <(gh api repos/<your-org>/harness-kit/contents/.claude/scripts/install.sh -q '.content' | base64 --decode)
```

Then open Claude Code and run `/setup-project`:

```bash
claude
```

### Returning to an existing project

Then type `/hello` to orient yourself and see what's on the plate, or `/new-task <description>` to begin planning a feature.

---

## What You Get

### Skills (slash commands)

All workflow commands are available as `/command` in Claude Code:

| Command | Purpose |
|---------|---------|
| `/hello` | Start a session with version check and orientation |
| `/new-task` | Plan features and create GitHub Issues |
| `/do-task` | Implement a ticket with TDD and code review |
| `/open-pr` | Create PR and walk through Copilot review |
| `/refine-task` | Iteratively refine tickets to implementation-ready |
| `/status` | Project dashboard |
| `/resume-work` | Pick up where you left off |
| `/run-tests-and-fix` | Run tests, fix failures |
| `/review-code` | 8-agent code review on any diff |
| `/review-findings` | Walk through findings one-by-one |
| `/refactor` | 3-tier refactoring analysis |
| `/setup-project` | First-time profile and directory setup |
| `/start-ticket-refinement` | Deep refinement with 14-item checklist |
| `/add-codebase` | Add a git repo or local directory to `.claude/context/` |
| `/check-update` | Check for newer harness-kit versions |
| `/reset-workflow` | Reset to clean template state |
| `/learn` | Long-term RL-driven goal optimization (opt-in) |

### Subagents

All 22 specialized agents are available. Claude Code spawns them via the Task tool using `subagent_type` values that match the `name` field in each `.claude/agents/*.md` file:

| Category | Agent File | `subagent_type` | Model |
|----------|-----------|-----------------|-------|
| Orchestration | `planner.md` | `planner` | sonnet |
| Orchestration | `implementer.md` | `implementer` | sonnet |
| Orchestration | `triager.md` | `triager` | sonnet |
| Testing | `test-runner.md` | `test-runner` | haiku |
| Testing | `test-fixer.md` | `test-fixer` | sonnet |
| Review (correctness) | `review-correctness-defensive.md` | `review-correctness-defensive` | opus |
| Review (correctness) | `review-correctness-specification.md` | `review-correctness-specification` | opus |
| Review (quality) | `review-quality-structural.md` | `review-quality-structural` | opus |
| Review (quality) | `review-quality-evolutionary.md` | `review-quality-evolutionary` | opus |
| Review (extended) | `review-docs-consistency.md` | `review-docs-consistency` | sonnet |
| Review (extended) | `review-error-surface.md` | `review-error-surface` | sonnet |
| Review (extended) | `review-operations-hygiene.md` | `review-operations-hygiene` | sonnet |
| Review (extended) | `review-test-quality.md` | `review-test-quality` | sonnet |
| Refactoring | `refactor-small.md` | `refactor-small` | sonnet |
| Refactoring | `refactor-medium.md` | `refactor-medium` | sonnet |
| Refactoring | `refactor-large.md` | `refactor-large` | sonnet |
| Polyglot | `rust-core.md` | `rust-core` | sonnet |
| Polyglot | `diplomat-ffi.md` | `diplomat-ffi` | sonnet |
| Polyglot | `typescript-ui.md` | `typescript-ui` | sonnet |
| Polyglot | `python-agentic.md` | `python-agentic` | sonnet |
| Polyglot | `c-embedded.md` | `c-embedded` | sonnet |
| Polyglot | `tauri-desktop.md` | `tauri-desktop` | sonnet |

### Project Memory

`CLAUDE.md` provides a concise summary of project structure, conventions, and a reference table of specs. Agents read spec files on demand:

- `AGENTS.md` — agent identity, workflow overview, command reference
- `.claude/rules/` — harness-kit orchestration, workflow phases, finding schema, artifact standards
- `.claude/specs/` — project profile schema, workflow contract, phase orchestrator, review rubrics, ticket lifecycle, artifact contracts, normalization rules

---

## Architecture

```
CLAUDE.md                          ← Claude Code reads this at session start (concise summary)
  → .claude/specs/*.md             ← read on demand by agents/skills
  → .claude/rules/*.md             ← read on demand by agents/skills

.claude/
  agents/*.md                      ← subagent definitions (22 agents)
  skills/*/SKILL.md                ← /slash commands (16 skills)
  settings.json                    ← lifecycle hooks
  specs/*.md                       ← formal specifications
  rules/*.md                       ← governance rules
  profiles/*.yaml                  ← project configuration
  features/todo/                   ← active tickets
  features/completed/              ← done tickets
  features/ticket_tracker.md       ← ticket state ledger
  artifacts/                       ← phase output artifacts
```

---

## MCP Servers

Configure MCP servers for Claude Code:

```bash
claude mcp add <server-name> -- <command> [args...]
```

List configured servers:

```bash
claude mcp list
```

Use `/mcp` inside a Claude Code session to manage servers interactively.

---

## Headless / CI Usage

Claude Code can run programmatically for automation:

```bash
claude -p "Run /do-task 42" --allowedTools Read,Write,Edit,Bash,Glob,Grep
```

This is useful for:
- CI pipelines that run code review on every PR
- Docker containers that implement tickets from a queue
- Batch processing of multiple tickets

---

## GitHub Integration

The harness-kit supports two tracking modes, auto-detected at the start of every skill:

| Mode | Condition | Ticket source |
|------|-----------|---------------|
| **GitHub mode** | `gh auth status` succeeds | GitHub Issues via `gh` CLI |
| **Local mode** | `gh` not available or not authenticated | `.claude/features/todo/TASK-NNN.json` files |

All `gh` commands referenced in skills (`gh issue create`, `gh issue develop`, `gh pr create`, etc.) run through Claude Code's Bash tool. The full GitHub workflow from AGENTS.md Section XII-A is supported: issue creation, sub-issues, branch linking, PR creation, and Copilot review.

Override via profile: `extensions.tracking.mode: "github"` or `"local"`.

---

## Version Tracking

The install script writes `.claude/.harness-version` with the installed version. `/hello` reads this file to check for updates at session start. If the file is missing (e.g., on a fresh clone), `/hello` reports "version unknown" and continues normally.

Run `/check-update` to check for newer versions and upgrade on demand.

---

## Updating

`/hello` checks for updates at session start. Run `/check-update` to upgrade on demand.

The install script refreshes `.claude/` framework files. It never overwrites your project profiles, tickets, or artifacts.

From the terminal (outside Claude Code):

```bash
bash .claude/scripts/check-update.sh
```
