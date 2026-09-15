---
name: Qwen-Ollama
description: Use when a task needs local LLM inference via the on-box Ollama server (Qwen 2.5) instead of a cloud API.
---

# Qwen via Ollama

- Chosen model: **qwen2.5:7b** (4.7 GB). Other sizes exist if needed: `0.5b` / `14b` / `32b`.
- Endpoint: `http://localhost:11434` (standard Ollama API).
- Timeouts: 120 s default for analysis calls; longer (e.g. 300 s) for heavy generation.
- Prefer local over cloud when: offline, data can't leave the machine, or bulk work where API cost matters.
- VRAM contention with other GPU services: see the **Vram-GPU-OOM-memory-management** skill.

## Reference implementation (Marvinous)

- `OllamaClient.rs` in this folder — copy of the production async client (reqwest, timeout, error handling) from `/home/matt/Marvinous/src/llm/client.rs`.
- Prompt building: `/home/matt/Marvinous/src/llm/prompt.rs`
- System prompt (Marvin's personality): `/etc/marvinous/system-prompt.txt`
- Config (model/endpoint settings): `/etc/marvinous/marvinous.toml`
