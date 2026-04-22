# Observability Standard: REDACTED Telemetry for the harness-kit

This specification defines **REDACTED** as the recommended observability standard for systems built with harness-kit. It establishes instrumentation contracts for workflow phases, subagents, and user-authored code.

---

## I. Overview

Every AI system built with the harness-kit must emit standardized telemetry via the REDACTED framework. This ensures:

- **Distributed tracing** across agents, tools, and model calls using W3C Trace Context
- **Sensitivity classification** on every span to control data replication
- **Data governance compliance metadata** for data access auditing
- **Cross-system correlation** via `app_id`, `agent_id`, and `correlation_id`
- **Framework-agnostic observability** supporting LangChain, LangGraph, LangFlow, FastAPI, MCP, A2A, and custom solutions

**Authoritative Reference:** The full REDACTED protocol is defined in the REDACTED AI Telemetry Spec (an external, separately maintained specification). This document maps that protocol to harness-kit concepts and does not redefine the specification itself.

**Primary Telemetry Backend:** [Langfuse](https://langfuse.com) serves as the telemetry database. REDACTED extends Langfuse with standardized metadata, propagation, and classification.

---

## II. Conceptual Mapping

### harness-kit to REDACTED

| harness-kit Concept | REDACTED Concept | Span Type | Notes |
|------------------------|---------------------|-----------|-------|
| Workflow execution (Phases 0-7) | **Trace** (root) | `trace` | One trace per ticket lifecycle |
| Phase execution (e.g., Planning) | **Observation** | `agent` | Each phase is an agent span under the root trace |
| Subagent invocation (e.g., planner, implementer) | **Observation** | `agent` | Nested under the phase span with its own `agent_id` |
| Test execution | **Observation** | `tool` | Test suite runs as tool invocations |
| LLM call (test fixing, code generation) | **Observation** | `generation` | Model calls with prompt/completion/token tracking |
| Review agent execution | **Observation** | `agent` | Each review lens is an agent span |
| Review finding | **Span metadata** | N/A | Findings attached as metadata to the review agent span |
| Code review batch | **Observation** | `chain` | Orchestration of parallel review agents |
| Template bootstrap | **Observation** | `chain` | Discovery, composition, instantiation steps |
| Data retrieval (RAG, DB access) | **Observation** | `retriever` | Must include CDO metadata per spec section 2.7 |
| Embedding generation | **Observation** | `embedding` | Embedding model calls |
| Quality evaluation | **Observation** | `evaluator` | Automated quality scoring |
| Ticket ID | `correlation_id` | N/A | Links all traces for a single ticket |
| Project name | `app_id` | N/A | Service-level identity from profile |
| Subagent name | `agent_id` | N/A | Agent-level identity (e.g., `"planner"`, `"review-correctness-defensive"`) |

### Trace Hierarchy

A typical workflow execution produces the following trace structure:

```
TRACE: workflow/TASK-001 (correlation_id=TASK-001, app_id=my-project)
├── AGENT: phase/bootstrap (agent_id=bootstrap)
│   ├── CHAIN: discover_templates
│   ├── CHAIN: analyze_templates
│   └── CHAIN: instantiate
├── AGENT: phase/preflight (agent_id=preflight)
│   └── TOOL: precheck_cmd
├── AGENT: phase/planning (agent_id=planner)
│   └── GENERATION: decompose_ticket (model=claude-sonnet-4)
├── AGENT: phase/iteration (agent_id=implementer)
│   ├── GENERATION: generate_code (model=claude-sonnet-4)
│   ├── TOOL: format_cmd
│   ├── TOOL: lint_cmd
│   └── TOOL: test_cmd_targeted
├── AGENT: phase/testing (agent_id=test-runner)
│   ├── TOOL: test_cmd_focused
│   └── TOOL: test_cmd_regression
├── CHAIN: phase/review
│   ├── AGENT: review-correctness-defensive (agent_id=review-correctness-defensive)
│   │   └── GENERATION: analyze_diff (model=claude-sonnet-4)
│   ├── AGENT: review-correctness-specification (agent_id=review-correctness-specification)
│   │   └── GENERATION: check_spec_adherence (model=claude-sonnet-4)
│   ├── AGENT: review-quality-structural (agent_id=review-quality-structural)
│   ├── AGENT: review-quality-evolutionary (agent_id=review-quality-evolutionary)
│   └── AGENT: review-docs-consistency (agent_id=review-docs-consistency)
├── AGENT: phase/triage (agent_id=triager)
│   └── TOOL: apply_autofix
└── AGENT: phase/closure (agent_id=closure)
```

---

## III. Required Metadata

Every trace and span emitted by a harness-kit system must carry the metadata fields defined by the REDACTED specification. These are organized into layers.

### Root Trace Metadata

Set once when the workflow trace is created:

| Field | Source | Required | Example |
|-------|--------|----------|---------|
| `user_id` | Invoking user or `"harness-kit"` | Yes | `"dstanton006"` |
| `correlation_id` | Ticket ID | Yes | `"TASK-001"` |
| `session_id` | Workflow session (optional) | No | `"sess_abc123"` |
| `app_id` | `profile.extensions.observability.identity.app_id` | Yes | `"my-project"` |
| `sensitive_data_type` | `profile.extensions.observability.sensitivity.default_type` | Yes | `"INTERNAL"` |

### Span Metadata (per spec section 2.4)

Every observation includes the `agentaware` metadata namespace:

```json
{
  "agentaware": {
    "language": "python",
    "sdk_version": "1.1.2",
    "spec_version": "v1.1.0",
    "component": {
      "version": "1.0.0",
      "id": "550e8400-e29b-41d4-a716-446655440000"
    }
  }
}
```

### Span-Local Identity

| Field | Source | Required | Notes |
|-------|--------|----------|-------|
| `app_id` | Profile config | Yes | Immutable per service |
| `agent_id` | Subagent name or function name | Yes | Overridable per span |
| `sensitive_data_type` | Inherited from root or overridden per span | Yes | Highest sensitivity wins |
| `sensitive_data_labels` | Per span as appropriate | No | Merged (union) across levels |

---

## IV. Sensitivity Classification

All harness-kit telemetry follows the REDACTED sensitivity model (spec section 2.6).

### Classification Tiers

| Tier | Meaning | REDACTED Replication |
|------|---------|------------------------|
| `PUBLIC` | Approved for unrestricted disclosure | Full data retained |
| `INTERNAL` | Internal use only | Full data retained |
| `CONFIDENTIAL` | Business/client impact if misused | Structure and metrics only; content dropped |
| `HIGHLY_CONFIDENTIAL` | Strictly limited access | Full trace dropped; not replicated |

### Default Classification

| Context | Default `sensitive_data_type` | Rationale |
|---------|------------------------------|-----------|
| harness-kit workflow phases | `INTERNAL` | Workflow metadata is internal operational data |
| Review findings | `INTERNAL` | Code review findings contain source snippets |
| User code in project root | Configured per profile | User sets their project's sensitivity level |
| Test results | `INTERNAL` | Test outputs may reference internal logic |

### Label Vocabulary

The controlled vocabulary from spec section 2.6.2 applies:

`PII`, `FINANCIAL`, `REGULATORY`, `CLIENT`, `STAFF`, `SOURCE_CODE`, `CREDENTIAL`, `HEALTH`, `MODEL_PROMPT`, `MODEL_OUTPUT`, `GEOLOCATION`, `OTHER`

### Precedence Rules

When sensitivity is defined at multiple levels, the **most restrictive wins**:

1. `HIGHLY_CONFIDENTIAL` > `CONFIDENTIAL` > `INTERNAL` > `PUBLIC`
2. Labels from all sources are **merged** (union), never replaced

---

## V. CDO Compliance Metadata

When agents access datasets or data systems, they must capture CDO (Chief Data Officer) consent metadata per spec section 2.7. This applies exclusively to `retriever` span types.

### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `operation` | string | Yes | `"read"` or `"write"` |
| `client_id` | string | Conditional | Client or project identifier |
| `engagement_id` | string | Conditional | Engagement identifier |
| `record_ids` | string[] | Conditional | Record identifier(s) accessed |
| `system_id` | string | Conditional | Source system identifier |

### When CDO Applies

CDO metadata capture is required when:
- An agent queries a vector database, document store, or knowledge base
- An agent reads from or writes to a system of record
- An agent accesses client-specific data

CDO metadata is configured via `profile.extensions.observability.cdo.enabled`. When enabled, the REDACTED SDK enforces capture via compliance mode.

---

## VI. W3C Trace Context Propagation

All inter-service communication must propagate W3C Trace Context per spec section 4.

### HTTP (Agent-to-Agent, API calls)

Required headers:
- `traceparent` (W3C standard, always required)
- `tracestate` (W3C standard, optional)
- `x-langfuse-trace-user-id`
- `x-langfuse-trace-correlation-id`
- `x-langfuse-trace-session-id` (optional)
- `x-langfuse-trace-metadata` (optional, JSON string)

### MCP (STDIO)

Trace context is passed in a top-level `trace` object within the tool call arguments:

```json
{
  "tool_call": {
    "name": "web.search",
    "args": {
      "query": "...",
      "trace": {
        "traceparent": "00-<trace_id>-<span_id>-01",
        "user_id": "...",
        "correlation_id": "..."
      }
    }
  }
}
```

### Agent-to-Agent (A2A)

Always forward `traceparent` unchanged. Callee starts a new `agent` span with its own `app_id` and `agent_id`. See spec section 4.4.

---

## VII. Framework Integration Patterns

### Python SDK Initialization

Every Python service built with the harness-kit must initialize the REDACTED SDK at startup:

```python
import agentaware as aa

aa.init(
    app_id="my-project",                        # From profile.extensions.observability.identity.app_id
    agent_id="my-agent",                         # From profile or function-specific
    default_sensitive_data_type="INTERNAL",       # From profile.extensions.observability.sensitivity.default_type
    environment="production",                     # From AGENTAWARE_ENVIRONMENT or profile
)
```

### Decorator Patterns

```python
from agentaware import observe

# Agent logic
@observe(as_type="agent")
def my_agent(user_query: str) -> str:
    data = extract_info(user_query)
    return call_llm(data)

# Tool invocation
@observe(as_type="tool")
def fetch_data(url: str) -> dict:
    return requests.get(url).json()

# LLM generation
@observe(as_type="generation", name="gpt4-summarize")
def summarize(text: str) -> str:
    return llm.complete(text)
```

### Context Manager Patterns

```python
from agentaware import agent_call, tool_call, generation_call

# For finer-grained control
with agent_call("planning", input_data={"ticket": ticket_id}) as span:
    plan = decompose_ticket(ticket)
    span.set_output(plan)
```

### FastAPI Services

```python
from agentaware import instrument_app
from fastapi import FastAPI

app = FastAPI()
instrument_app(app)  # Adds ASGI middleware for automatic trace extraction
```

### LangGraph Nodes

```python
from agentaware.langgraph import langgraph_node

@langgraph_node
def agent_node(state: AgentState) -> AgentState:
    # Automatically wrapped with trace context propagation
    ...
```

### HTTP Client Instrumentation

```python
# Use instrumented requests for automatic trace header injection
from agentaware.requests import requests

response = requests.post("http://downstream-agent/api", json=payload)
# traceparent + x-langfuse-trace-* headers injected automatically
```

### CDO Metadata Capture

```python
from agentaware import retriever_call, set_cdo_ids

with retriever_call("query_knowledge_base") as span:
    set_cdo_ids(
        client_id="PR-2024-001234",
        engagement_id="ENG-2024-5678",
        system_id="SAP-PROD-01",
    )
    results = vector_db.query(query_embedding)
    span.set_output(results)
```

---

## VIII. Compliance Enforcement

The REDACTED SDK provides a compliance mode that enforces instrumentation standards at runtime.

### Modes

| Mode | Behavior |
|------|----------|
| `error` | Raises `AgentAwareComplianceError` when instrumentation is missing |
| `warn` | Logs a warning but continues execution |
| `off` | No enforcement; SDK silently degrades |

### Configuration

Set via environment variable:
```bash
export AA_COMPLIANCE_MODE=warn  # Default for development
export AA_COMPLIANCE_MODE=error # Recommended for production
```

Or via profile:
```yaml
extensions:
  observability:
    compliance:
      mode: "warn"
```

### What Is Enforced

- `aa.init()` must be called before any `@observe()` decorated function executes
- `default_sensitive_data_type` must be provided at initialization
- Retriever spans should include CDO metadata when `cdo.enabled` is true
- HTTP outbound calls should use instrumented clients for trace propagation

---

## IX. Profile Configuration

The observability configuration lives in `profile.extensions.observability`. See [project-profile-schema.md](./project-profile-schema.md) for the full schema.

### Minimal Configuration

```yaml
extensions:
  observability:
    enabled: true
    provider: "agentaware"
    identity:
      app_id: "my-project"
    sensitivity:
      default_type: "INTERNAL"
```

### Full Configuration

```yaml
extensions:
  observability:
    enabled: true
    provider: "agentaware"
    spec_version: "1.1.0"

    langfuse:
      host: ""                        # Prefer LANGFUSE_HOST env var
      public_key: ""                  # Prefer LANGFUSE_PUBLIC_KEY env var
      secret_key: ""                  # Prefer LANGFUSE_SECRET_KEY env var

    identity:
      app_id: "my-project"
      agent_id: "default-agent"

    sensitivity:
      default_type: "INTERNAL"
      default_labels: ["SOURCE_CODE"]

    cdo:
      enabled: true
      default_operation: "read"

    compliance:
      mode: "warn"
```

### Environment Variables

These take precedence over profile values:

| Variable | Purpose |
|----------|---------|
| `LANGFUSE_HOST` | Langfuse server URL |
| `LANGFUSE_PUBLIC_KEY` | Langfuse public API key |
| `LANGFUSE_SECRET_KEY` | Langfuse secret API key |
| `AGENTAWARE_ENVIRONMENT` | Deployment environment (dev/staging/prod) |
| `AGENTAWARE_APP_ID` | Override `app_id` from profile |
| `AGENTAWARE_AGENT_ID` | Override `agent_id` from profile |
| `AA_COMPLIANCE_MODE` | Compliance enforcement mode |

---

## X. Workflow Phase Instrumentation

When `profile.extensions.observability.enabled` is true, the phase orchestrator emits REDACTED telemetry for each workflow execution.

### Root Trace

Created at workflow start, closed at workflow end:

```python
root_ctx = TraceContext(
    user_id=invoking_user,
    correlation_id=ticket_id,        # Ticket ID as correlation
    session_id=workflow_session_id,   # Optional
    metadata={"root_name": f"workflow/{ticket_id}"},
)
root = aa.start_trace(root_ctx, name=f"workflow/{ticket_id}")
```

### Phase Spans

Each phase creates an `agent` span under the root trace:

```python
with agent_call(
    f"phase/{phase_name}",
    trace_context=root_ctx,
    input_data={"ticket_id": ticket_id, "phase": phase_name},
) as phase_span:
    result = execute_phase(phase_name, ...)
    phase_span.set_output(result)
```

### Subagent Delegation Spans

When the supervisor delegates to a subagent:

```python
with agent_call(
    f"subagent/{agent_id}",
    trace_context=root_ctx,
    input_data={"step": step_description},
) as agent_span:
    # Subagent executes with its own agent_id
    result = await delegate(request)
    agent_span.set_output(result.artifacts)
```

### Tool Command Spans

Toolchain commands (test, lint, format) are tool spans:

```python
with tool_call(
    f"cmd/{command_name}",
    trace_context=root_ctx,
    input_data={"command": cmd, "cwd": working_dir},
) as cmd_span:
    result = execute_command(cmd, cwd=working_dir)
    cmd_span.set_output({"exit_code": result.exit_code, "stdout": result.stdout})
```

---

## XI. Span Type Taxonomy

The canonical span types from REDACTED spec section 3, mapped to harness-kit usage:

| Span Type | REDACTED Definition | harness-kit Usage |
|-----------|----------------------|---------------------|
| `generation` | LLM calls with prompts, tokens, cost | Code generation, test fixing, review analysis, planning decomposition |
| `agent` | Control logic deciding next steps/tool use | Phase execution, subagent delegation, review agents |
| `tool` | External capability invoked by an agent | Toolchain commands (test, lint, format), MCP tool calls, A2A tool invocations |
| `chain` | Glue steps, orchestration hops | Review batching, template composition, multi-step orchestration |
| `retriever` | Vector/DB/document retrieval | RAG queries, knowledge base access, document search |
| `evaluator` | Quality assessment functions | Automated evaluation, quality scoring |
| `embedding` | Embedding model calls | Embedding generation for RAG, similarity search |

---

## XII. Validation

### Pre-Deployment Checklist

Before deploying any system built with the harness-kit:

1. `agentaware` is in dependencies (Python projects)
2. `aa.init()` is called at application startup
3. `default_sensitive_data_type` is explicitly set (not defaulting)
4. All agent functions use `@observe(as_type="agent")`
5. All tool functions use `@observe(as_type="tool")`
6. All LLM calls use `@observe(as_type="generation")`
7. HTTP outbound uses `agentaware.requests` or `instrument_httpx()`
8. FastAPI services use `AgentAwareASGIMiddleware` or `instrument_app()`
9. Retriever functions include CDO metadata when `cdo.enabled`
10. Langfuse connection environment variables are set

### Health Check

The REDACTED SDK provides a health check endpoint:

```python
from agentaware import health_status

result = health_status()
# Returns HealthCheckResult with connectivity and auth status
```

---

## XIII. Relationship to Other Specs

| Spec | Relationship |
|------|-------------|
| REDACTED Spec (external) | Authoritative REDACTED protocol; this doc maps it to the harness-kit system |
| [phase-orchestrator.md](./phase-orchestrator.md) | Phases emit REDACTED telemetry when observability enabled |
| [project-profile-schema.md](./project-profile-schema.md) | Profile `extensions.observability` configures REDACTED |
| [template-bootstrap.md](./template-bootstrap.md) | Bootstrap verifies REDACTED dependencies in Python templates |
| [workflow-contract.md](./workflow-contract.md) | Observability events complement the error-as-data pattern |
| [finding-schema.md](./finding-schema.md) | Review findings are attached as span metadata |
| [polyglot-architecture.md](./polyglot-architecture.md) | Each polyglot layer instruments its own spans |
