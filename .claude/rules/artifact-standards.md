---
description: "Normalization rules for deterministic artifact output: key ordering, timestamps, paths, IDs, formatting."
alwaysApply: true
---

# Artifact Standards

All workflow artifacts (JSON and Markdown) MUST follow these normalization rules to ensure deterministic, reproducible output.

## JSON Normalization

1. **Keys sorted lexicographically** — Object keys in alphabetical order
2. **2-space indent** — Consistent formatting
3. **LF line endings** — Unix-style, never CRLF
4. **Explicit nulls** — Use `null`, not omission, for optional absent fields
5. **No trailing commas** — Standard JSON

## Timestamps

- **Format:** ISO 8601 with UTC timezone: `2026-02-17T10:30:00Z`
- **Always UTC** — Never local time
- **Precision:** Seconds minimum, milliseconds optional

## Paths

- **Always relative** to project root
- **Forward slashes only** — Even on Windows: `src/lib.rs`, not `src\lib.rs`
- **No trailing slash** on directories
- **No leading `./`** — Use `src/lib.rs`, not `./src/lib.rs`

## IDs

- **Content-hash based** — ID derived from content, not random
- **Deterministic** — Same content always produces same ID
- **Format:** First 8 hex characters of SHA-256 hash

## Artifact Naming

```
.claude/artifacts/<TICKET_ID>_<phase>.json
.claude/artifacts/<TICKET_ID>_<phase>.md
```

Phases: `preflight`, `plan`, `iteration`, `test_run`, `review`, `triage`, `summary`

Step-level artifacts:
```
.claude/artifacts/<TICKET_ID>_iteration_step_<N>.json
.claude/artifacts/<TICKET_ID>_iteration_step_<N>.md
```

## Dual Output

Every phase produces BOTH:
- **JSON** — Machine-readable, schema-validated, for pipeline consumption
- **Markdown** — Human-readable, for review and audit

## Lineage

Each artifact includes a `lineage` field linking to its inputs:

```json
{
  "lineage": {
    "ticket_id": "TASK-001",
    "phase": "review",
    "depends_on": ["TASK-001_test_run.json", "TASK-001_iteration.json"],
    "produced_by": "review-correctness-defensive"
  }
}
```
