---
name: Vram-GPU-OOM
description: Use when GPU services (Ollama, Whisper, ComfyUI/Flux, Invoice OCR) contend for VRAM on the RTX 3090 and hit CUDA OOM — covers the retry-and-wait convention, quick-unload config, and the request-unload signaling protocol.
---

# GPU OOM / VRAM sharing

Multiple services share one **RTX 3090 (24GB)**. They coordinate without a central scheduler: everyone tries to load normally, catches OOM, waits for others to auto-unload, and retries.

## Retry convention

On CUDA OOM: `torch.cuda.empty_cache()`, `time.sleep(30)`, retry — **up to 3 attempts, 30s apart**. Re-raise non-OOM errors immediately and re-raise after the final attempt. Same idea in shell: loop a GPU command 3 times with a 30s sleep between failures. Alongside retry, configure every service to unload quickly when idle.

## Known services and settings

- **Ollama** already handles unload — just set quick keep-alive in `/etc/systemd/system/ollama.service.d/override.conf`:
  ```
  Environment="OLLAMA_KEEP_ALIVE=30s"
  ```
- **Invoice OCR (Qwen2-VL)** at `http://10.99.0.3:8765` — auto-unloads after idle (`--auto-unload-minutes`, default 5), does 3×/30s OOM retry, and exposes `POST /request-unload` and `GET /status`.
- **Whisper** large-v3 ≈ **6GB** VRAM (see the Whisper-Transcription skill).

## Signaling protocol

For faster, more predictable starts, a service can call `POST /request-unload` on the others before loading a big model instead of relying on OOM-retry delays. The endpoint contracts (`/request-unload`, `/status`, the auto-unload background task), the coordinator usage pattern, and worked timelines are in `reference-gpu-coordination.md`. Helper script: `request_gpu_unload.py` in the OneCuriousRabbit repo.
