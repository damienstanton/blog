---
name: learn
description: Long-term goal optimization via reinforcement learning (APO/GRPO). Strictly opt-in — never invoked automatically.
---
# Learn

Optimize toward a long-term goal using a reinforcement learning loop. This command is **strictly opt-in** — it is never invoked by `/hello`, `/do-task`, or any other harness-kit command.

## When to Use

- You have a persistent, measurable objective that spans many tasks (e.g., "reduce P99 latency by 40%", "raise test coverage above 90%")
- You want the agent to self-improve its task selection and implementation strategy over time
- You are willing to let the RL loop run for multiple sessions

**Not for:**
- Single-task implementation → use `/do-task`
- Exploring the codebase → use `/hello`
- Planning a feature → use `/new-task`

## Opt-In Contract

- Requires explicit user confirmation before writing to `.claude/rl/` or spawning containers
- All RL infrastructure (`.claude/containers/`, `.claude/rl/`) is inert unless this command is active
- `/hello` does not mention or suggest `/learn` unless the user has previously run it

## Invocation

```
/learn "<long-term goal>"

Examples:
  /learn "Improve test coverage across the codebase over time"
  /learn "Reduce P99 latency in the HTTP client by 40%"
  /learn "Eliminate all high-severity review findings within 10 tasks"
```

## What It Does

1. **Parse goal** — extract measurable target and success criterion from the goal string
2. **Confirm opt-in** — ask the user to confirm before writing any RL state or starting containers
3. **Bootstrap RL environment** — initialize policy network, reward calculator, and experience buffer in `.claude/rl/`; start containers if needed (see `.claude/containers/`)
4. **Decompose goal** — break the long-term goal into a sequence of tasks using the existing `/new-task` → `/do-task` workflow as the action space
5. **Run APO/GRPO loop** — collect rewards from test results, review findings, and PR outcomes; update policy after each task
6. **Persist state** — save learned policy and experience buffer to `.claude/rl/` for use in future sessions

## RL Architecture

See `.claude/specs/learn.md` for the full specification:
- Policy network (transformer-based, PPO/GRPO training)
- Reward calculator (test pass rate, review severity, PR acceptance)
- Experience replay buffer
- Multi-modal cognitive pipeline (Ollama integration)
- Container execution environment

## Infrastructure Check

Before bootstrapping, verify:

```bash
# Check containers
docker ps --filter "name=harness-python-rl" --format "{{.Names}}" 2>/dev/null

# Check Ollama models
ollama list 2>/dev/null | grep -E "qwen3-vl:8b|gemma3n:e4b"

# Check RL implementation
ls .claude/rl/rl_loop.py 2>/dev/null && echo "present" || echo "missing"
```

If infrastructure is missing, offer to create tickets to build it using `/new-task` for each missing component. See `.claude/specs/learn.md` for the component list.
