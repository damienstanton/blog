# Multi-Modal Cognitive Orchestrator

## Overview

The cognitive orchestrator enriches the RL workflow with visual reasoning using 4 Ollama models in a thought → visualize → interpret → reason → accrete → orient pipeline. This provides the RL policy with richer state representations that include visual architecture context.

## Model Stack

| Model | Purpose | Capabilities |
|-------|---------|--------------|
| `qwen3-vl:8b` | Vision-Language Model | Interprets architecture diagrams, code screenshots, UI mockups |
| `gemma3n:e4b` | General Cognition | Synthesizes understanding, performs logical reasoning |
| `x/z-image-turbo:fp8` | Photorealistic Visualization | Generates architecture diagrams, workflow visualizations |
| `embeddinggemma:latest` | Vector Embedding | Converts knowledge into 768-dim vectors for accreted memory |

## Cognitive Pipeline

```
┌────────────┐
│  1. Thought│  RL policy's current decision context
└─────┬──────┘
      │
      ↓
┌────────────────┐
│  2. Visualize  │  x/z-image-turbo:fp8 generates diagram
└────────┬───────┘
         │
         ↓
┌────────────────┐
│  3. Interpret  │  qwen3-vl:8b analyzes visual
└────────┬───────┘
         │
         ↓
┌────────────────┐
│  4. Reason     │  gemma3n:e4b synthesizes understanding
└────────┬───────┘
         │
         ↓
┌────────────────┐
│  5. Accrete    │  embeddinggemma collapses to 768-dim vector
└────────┬───────┘
         │
         ↓
┌────────────────┐
│  6. Orient     │  Feed vector back to RL policy
└────────────────┘
```

## Stage Details

### Stage 1: Thought

**Input**: Current workflow state + next action

Example:
```json
{
  "workflow_stage": "DO_TASK",
  "ticket_id": "TASK-042",
  "current_decision": "Select skill sequence for implementation",
  "context": {
    "ticket_description": "Add rate limiting with token bucket algorithm",
    "codebase_files": ["src/api.rs", "src/rate_limit.rs"],
    "test_coverage": 0.85
  }
}
```

**Output**: Textual representation of thought

### Stage 2: Visualize (x/z-image-turbo:fp8)

**Input**: Thought text + codebase structure

**Prompt Template**:
```
Generate a photorealistic architecture diagram showing:
- Current system components: [list]
- Proposed changes: [description]
- Data flow between components
- Integration points with existing code

Style: Clean, minimalist, white background, UML-inspired
```

**Output**: Base64-encoded PNG image (2048x2048)

**Example Visualization**:
```
┌─────────────┐       ┌──────────────┐
│  API Layer  │──────▶│ Rate Limiter │
└─────────────┘       └──────────────┘
       │                      │
       │                      ↓
       │              ┌──────────────┐
       │              │ Token Bucket │
       │              └──────────────┘
       ↓
┌─────────────┐
│   Database  │
└─────────────┘
```

### Stage 3: Interpret (qwen3-vl:8b)

**Input**: Generated diagram (image) + original thought (text)

**Prompt Template**:
```
<image>diagram.png</image>

Analyze this architecture diagram in the context of:
{thought_context}

Identify:
1. Key components and their relationships
2. Potential architectural issues or bottlenecks
3. Missing components or connections
4. Integration complexity estimation
```

**Output**: Textual analysis of visual

Example:
```
The diagram shows a three-layer architecture:
1. API Layer receives requests
2. Rate Limiter intercepts before reaching core logic
3. Token Bucket algorithm manages rate limits

Observations:
- Rate Limiter is synchronous, may block under load
- No distributed coordination for multi-instance deployments
- Token Bucket state needs persistence (database shown)

Recommendation: Consider async rate limiting with Redis for distributed state.
```

### Stage 4: Reason (gemma3n:e4b)

**Input**: Visual interpretation + original thought

**Prompt Template**:
```
Given the visual analysis:
{interpretation}

And the original task context:
{thought}

Synthesize a comprehensive understanding:
1. Does the proposed architecture satisfy requirements?
2. What are the implementation risks?
3. What skill sequence would best implement this?
4. Are there alternative approaches worth considering?
```

**Output**: Synthesized reasoning

Example:
```
Analysis:
- Proposed architecture satisfies functional requirements (rate limiting)
- Risk: Synchronous design may impact latency under load
- Risk: Distributed state management adds complexity

Recommended skill sequence:
1. planner: Decompose into local + distributed implementations
2. implementer: Start with local token bucket (simpler)
3. test-runner: Validate correctness
4. refactor-medium: Extend to distributed if needed

Alternative: Use existing rate-limiting library (less custom code, faster)
```

### Stage 5: Accrete (embeddinggemma:latest)

**Input**: Synthesized reasoning text

**Process**:
```python
import ollama

response = ollama.embeddings(
    model='embeddinggemma:latest',
    prompt=reasoning_text
)

embedding = response['embedding']  # 768-dimensional vector
```

**Output**: 768-dimensional dense vector

**Storage**: Append to `.claude/rl/cognitive_memory.json`:

```json
{
  "schema_version": "cognitive_memory.v1",
  "embeddings": [
    {
      "timestamp": "2026-03-02T10:30:00Z",
      "context": "Rate limiting implementation",
      "embedding": [0.123, -0.456, ...]  // 768 floats
    }
  ]
}
```

### Stage 6: Orient

**Input**: Accreted embedding vector

**Process**: Feed vector into RL policy as additional state context

```python
# In .claude/rl/policy.py

def forward(self, state):
    ticket_embedding = state['ticket_embedding']  # 768-dim
    codebase_embedding = state['codebase_embedding']  # 768-dim
    cognitive_embedding = state['cognitive_embedding']  # 768-dim

    # Concatenate embeddings
    combined = torch.cat([
        ticket_embedding,
        codebase_embedding,
        cognitive_embedding
    ], dim=-1)  # 2304-dim

    # Transformer policy
    output = self.transformer(combined)
    skill_probs = self.softmax(output)
    return skill_probs
```

**Effect**: RL policy now has visual reasoning context when selecting skills

## Implementation

### File: `.claude/rl/cognitive_pipeline.py`

```python
"""
Multi-Modal Cognitive Pipeline

Orchestrates 4 Ollama models for visual reasoning integrated with RL loop.
"""

import ollama
import base64
from pathlib import Path
from typing import Dict, List
import json


class CognitivePipeline:
    """
    Multi-modal cognitive orchestrator.

    Models:
    - x/z-image-turbo:fp8 for visualization
    - qwen3-vl:8b for visual interpretation
    - gemma3n:e4b for reasoning
    - embeddinggemma:latest for accretion
    """

    def __init__(self, memory_path: str = ".claude/rl/cognitive_memory.json"):
        self.memory_path = Path(memory_path)
        self.memory_path.parent.mkdir(parents=True, exist_ok=True)

        # Load existing memory
        if self.memory_path.exists():
            with open(self.memory_path) as f:
                self.memory = json.load(f)
        else:
            self.memory = {"schema_version": "cognitive_memory.v1", "embeddings": []}

    def execute(self, thought: Dict) -> Dict:
        """
        Execute full cognitive pipeline.

        Args:
            thought: Current workflow context

        Returns:
            {
                "visual": "base64-encoded-image",
                "interpretation": "text analysis",
                "reasoning": "synthesized understanding",
                "embedding": [768-dim vector],
                "context": {...}
            }
        """
        # Stage 2: Visualize
        visual = self._visualize(thought)

        # Stage 3: Interpret
        interpretation = self._interpret(visual, thought)

        # Stage 4: Reason
        reasoning = self._reason(interpretation, thought)

        # Stage 5: Accrete
        embedding = self._accrete(reasoning)

        # Store in memory
        self._store_memory(thought, embedding)

        return {
            "visual": visual,
            "interpretation": interpretation,
            "reasoning": reasoning,
            "embedding": embedding,
            "context": thought
        }

    def _visualize(self, thought: Dict) -> str:
        """
        Stage 2: Generate architecture diagram.

        Args:
            thought: Workflow context

        Returns:
            Base64-encoded PNG image
        """
        prompt = self._build_visualization_prompt(thought)
        response = ollama.generate(
            model='x/z-image-turbo:fp8',
            prompt=prompt
        )
        # Placeholder: actual image generation logic
        return "base64-encoded-image-data"

    def _interpret(self, visual: str, thought: Dict) -> str:
        """
        Stage 3: Interpret visual with VLM.

        Args:
            visual: Base64-encoded image
            thought: Original context

        Returns:
            Textual analysis
        """
        prompt = self._build_interpretation_prompt(thought)
        response = ollama.generate(
            model='qwen3-vl:8b',
            prompt=prompt,
            images=[visual]  # VLM processes image
        )
        return response['response']

    def _reason(self, interpretation: str, thought: Dict) -> str:
        """
        Stage 4: Synthesize understanding.

        Args:
            interpretation: Visual analysis
            thought: Original context

        Returns:
            Synthesized reasoning
        """
        prompt = self._build_reasoning_prompt(interpretation, thought)
        response = ollama.generate(
            model='gemma3n:e4b',
            prompt=prompt
        )
        return response['response']

    def _accrete(self, reasoning: str) -> List[float]:
        """
        Stage 5: Embed reasoning into 768-dim vector.

        Args:
            reasoning: Synthesized text

        Returns:
            768-dimensional embedding
        """
        response = ollama.embeddings(
            model='embeddinggemma:latest',
            prompt=reasoning
        )
        return response['embedding']

    def _store_memory(self, thought: Dict, embedding: List[float]):
        """
        Append to cognitive memory.

        Args:
            thought: Context that produced this embedding
            embedding: 768-dim vector
        """
        self.memory['embeddings'].append({
            "timestamp": thought.get("timestamp"),
            "context": thought.get("ticket_description", ""),
            "embedding": embedding
        })

        with open(self.memory_path, 'w') as f:
            json.dump(self.memory, f, indent=2)

    def _build_visualization_prompt(self, thought: Dict) -> str:
        """Build prompt for visualization model."""
        return f"""
Generate a photorealistic architecture diagram showing:
- Current system components: {thought.get('codebase_files', [])}
- Proposed changes: {thought.get('ticket_description', '')}
- Data flow between components
- Integration points with existing code

Style: Clean, minimalist, white background, UML-inspired
"""

    def _build_interpretation_prompt(self, thought: Dict) -> str:
        """Build prompt for visual interpretation."""
        return f"""
Analyze this architecture diagram in the context of:
{json.dumps(thought, indent=2)}

Identify:
1. Key components and their relationships
2. Potential architectural issues or bottlenecks
3. Missing components or connections
4. Integration complexity estimation
"""

    def _build_reasoning_prompt(self, interpretation: str, thought: Dict) -> str:
        """Build prompt for reasoning synthesis."""
        return f"""
Given the visual analysis:
{interpretation}

And the original task context:
{json.dumps(thought, indent=2)}

Synthesize a comprehensive understanding:
1. Does the proposed architecture satisfy requirements?
2. What are the implementation risks?
3. What skill sequence would best implement this?
4. Are there alternative approaches worth considering?
"""
```

## Integration with RL Loop

In `.claude/rl/rl_loop.py`, before skill selection:

```python
# Initialize cognitive pipeline
cognitive = CognitivePipeline()

# Current thought context
thought = {
    "workflow_stage": current_stage,
    "ticket_id": ticket_id,
    "ticket_description": ticket['description'],
    "codebase_files": affected_files,
    "timestamp": datetime.now().isoformat()
}

# Execute cognitive pipeline
cognitive_result = cognitive.execute(thought)

# Feed embedding into RL policy state
state['cognitive_embedding'] = torch.tensor(cognitive_result['embedding'])

# Now select skill with enriched state
skill, params = policy.sample_action(state)
```

## Observability

REDACTED telemetry for cognitive pipeline:

```python
from agent_aware import trace, span

@trace(name="cognitive_pipeline")
def execute(self, thought):
    with span("visualize", as_type="tool"):
        visual = self._visualize(thought)

    with span("interpret", as_type="agent"):
        interpretation = self._interpret(visual, thought)

    with span("reason", as_type="agent"):
        reasoning = self._reason(interpretation, thought)

    with span("accrete", as_type="tool"):
        embedding = self._accrete(reasoning)

    return {...}
```

## Future Extensions

- Multi-turn visual reasoning (iterate on diagram refinements)
- Cross-modal retrieval (search memory by visual similarity)
- Concept drift detection (embeddings diverging from historical distribution)
- Hierarchical memory (short-term vs long-term cognitive context)

---

**Status**: 🎯 Bootstrap Blueprint - Multi-modal cognitive pipeline using 4 Ollama models. Skeleton exists in `.claude/rl/cognitive_pipeline.py`. Part of the bootstrap sequence when RL infrastructure is requested.

**Dependencies**: Ollama runtime with models: `qwen3-vl:8b`, `gemma3n:e4b`, `x/z-image-turbo:fp8`, `embeddinggemma:latest`
