# testing-agent-llm

LLM inference microservice for Testing Agent. Runs [llama-swap](https://github.com/mostlygeek/llama-swap) in front of [llama.cpp](https://github.com/ggml-org/llama.cpp) to serve multiple GGUF models on a single OpenAI-compatible endpoint.

Admin uploads models through the backend UI; this container loads them on demand.

## Why llama-swap

A single `llama-server` process can only hold one model in memory at a time. We want admin to manage a model registry (Gemma 4 E4B, Qwen3.5-35B-A3B, etc.) and testers to pick one per run. llama-swap solves this by:

1. Proxying OpenAI-compatible requests
2. Routing to the right `llama-server` instance by `model` field in the request
3. Auto-starting llama-server processes when needed
4. Releasing GPU/RAM when idle

## Seed models

On first startup, the backend's seed script downloads two models into the shared volume:

| Model | Size | Use case |
|---|---|---|
| Gemma 4 E4B (Q4_K_M) | ~2.5 GB | Fast classifier, PUCT priors, MC fallback |
| Qwen3.5-35B-A3B (Q4_K_XL) | ~20 GB | AI-only mode, complex reasoning, vision fallback |

Both are multimodal (text + vision via separate mmproj files).

Admin can add more models through `/admin/models` in the frontend.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Backend                                     │
│  │                                           │
│  ▼                                           │
│  llama-swap  :8080  (OpenAI-compatible)      │
│  │                                           │
│  ├─► llama-server  :8180  gemma-4-e4b        │
│  ├─► llama-server  :8181  qwen3.5-35b-a3b    │
│  └─► llama-server  :818N  <user model>       │
└─────────────────────────────────────────────┘
```

`llama-swap.yaml` is generated dynamically by the backend from the `llm_models` Postgres table whenever admin activates/deactivates a model. The container reloads on change.

## Volume layout

```
/var/lib/llm/
├── models/
│   ├── gemma-4-e4b-Q4_K_M.gguf
│   ├── mmproj-gemma-4-e4b.gguf
│   ├── Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf
│   └── mmproj-Qwen3.5-35B-A3B-F16.gguf
└── llama-swap.yaml
```

Mounted into both this container (read-only, for serving) and backend (read-write, for upload + yaml generation).

## Hardware

Targets macOS with Apple Silicon (Metal). On M2 Max 96GB both seed models fit in RAM simultaneously → instant switching. Linux + NVIDIA GPU also supported through llama.cpp CUDA build.

## Related repos

- `testing-agent-backend` — writes `llama-swap.yaml`
- `testing-agent-explorer` — sends inference requests via OpenAI-compatible API
- `testing-agent-frontend` — admin model management UI
- `testing-agent-infra` — docker-compose stack
