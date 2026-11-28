# GPU coordination — service signaling protocol

Optional enhancement on top of passive OOM retry. Services expose three endpoints so a service about to load a large model can politely ask others to free VRAM first, rather than relying on OOM-retry delays.

## Endpoints

### Auto-unload on idle (background task)

```python
# FastAPI
import asyncio, time

last_request_time = None
auto_unload_minutes = 5  # configurable

async def auto_unload_task():
    while True:
        await asyncio.sleep(60)  # check every minute
        if current_handler is None:
            continue
        idle = time.time() - last_request_time
        if idle > (auto_unload_minutes * 60):
            logger.info(f"Auto-unloading model after {idle/60:.1f} minutes")
            current_handler.unload()
            current_handler = None

@app.on_event("startup")
async def startup():
    asyncio.create_task(auto_unload_task())
```

### POST /request-unload

Unload only if idle for at least 30s; otherwise report busy.

```python
@app.post("/request-unload")
async def request_unload():
    if current_handler is None:
        return {"status": "ok", "unloaded": False, "message": "No model loaded"}
    idle = time.time() - last_request_time
    if idle < 30:
        return {"status": "busy", "unloaded": False,
                "message": f"Model in use (idle {idle:.0f}s)", "idle_seconds": idle}
    logger.info("Unloading on request from another service")
    current_handler.unload()
    current_handler = None
    return {"status": "ok", "unloaded": True, "message": "Model unloaded", "idle_seconds": idle}
```

### GET /status

```python
@app.get("/status")
async def get_status():
    idle = time.time() - last_request_time if last_request_time else None
    return {"status": "ok", "model_loaded": current_handler is not None,
            "idle_seconds": idle, "auto_unload_enabled": auto_unload_minutes is not None,
            "auto_unload_minutes": auto_unload_minutes}
```

### Using the protocol

Before loading a large model, ask other services to unload, then load (OOM retry remains the fallback):

```python
import requests

SERVICES = ["http://10.99.0.3:8765"]  # Invoice OCR; add others

for service in SERVICES:
    try:
        result = requests.post(f"{service}/request-unload", timeout=5).json()
        if result.get("unloaded"):
            print(f"{service} unloaded")
        elif result.get("status") == "busy":
            print(f"{service} busy, will retry OOM")
    except Exception:
        pass  # service not available
```

Helper: `request_gpu_unload.py` in the OneCuriousRabbit repo.

## Timelines

### Passive (OOM retry only)

- 12:00 scheduled Qwen task loads 4GB.
- 12:01 user uploads invoice, tries to load 18GB → OOM; Invoice OCR waits 30s.
- 12:01:30 Qwen task finishes and auto-unloads.
- 12:02 Invoice OCR retry succeeds, loads 18GB; unloads at 12:03.

### Active (with signaling)

- 12:00 user starts Flux; Flux calls `POST /request-unload` on Invoice OCR.
- 12:00 Invoice OCR idle 4 min → unloads immediately; Flux loads 22GB.
- 12:05 Flux completes, auto-unloads after 5 min.

Signaling gives faster, more predictable starts (no waiting on OOM-retry delays) and can be triggered proactively; OOM retry still covers the case where a service is busy.
