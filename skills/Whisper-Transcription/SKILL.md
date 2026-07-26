---
name: Whisper-Transcription
description: Use when transcribing audio to text via the local whisper.cpp server (large-v3, CUDA) — POST an audio file, get JSON back.
---

# Whisper Transcription Server

Local speech-to-text via whisper.cpp with GPU acceleration on **port 5555**. Accepts WAV/MP3 and other common formats (16kHz mono WAV is optimal) as multipart POST.

## Use it

```bash
curl -X POST http://localhost:5555/inference -F "file=@audio.wav"
```
Returns JSON `{"text": ...}`.

## Server

- Binary: `~/whisper.cpp/build/bin/whisper-server`
- Model: `~/whisper.cpp/models/ggml-large-v3.bin`
- Port: 5555
- Runs as the `whisper-server` systemd service (`systemctl status whisper-server`, logs via `journalctl -u whisper-server -f`).

Systemd unit at `/etc/systemd/system/whisper-server.service`:

```ini
[Unit]
Description=Whisper.cpp Transcription Server
After=network.target

[Service]
Type=simple
User=matt
WorkingDirectory=/home/matt/whisper.cpp/build
ExecStart=/home/matt/whisper.cpp/build/bin/whisper-server \
  -m /home/matt/whisper.cpp/models/ggml-large-v3.bin \
  -l en \
  --port 5555 \
  --host 0.0.0.0 \
  --threads 4
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Performance / VRAM

~2–4x real-time; the first request after startup is slow (model load). large-v3 uses ≈ **6GB VRAM** on the shared RTX 3090 — on OOM, wait for other GPU services to unload (see the Vram-GPU-OOM skill for the retry/signaling pattern).
