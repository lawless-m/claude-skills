---
name: Character LoRA on RunPod
description: End-to-end pipeline to train a character LoRA (Chroma/Flux, or Pony/SDXL) on a rented RunPod GPU and wire it into the ComfyUI + pony_web render stack — caption, deploy pod, train with ai-toolkit, render with face-fix, add a web-UI model entry, and run an infinite variety loop. Includes the RunPod SSH/volume gotchas.
tags: [lora, training, runpod, comfyui, chroma, flux, ai-toolkit, joycaption]
version: 1.0
---

# Character LoRA on RunPod

Runbook for adding a new character LoRA to this stack. Proven on Holly, Cherry, Stella.
Assumes the ComfyUI fork at `~/ComfyUI` (with `pony_web.py`, `run_chroma.py`, `chroma_workflow.py`),
ai-toolkit at `~/ai-toolkit`, and the RunPod network volume `rox8d5p4jp` (EU-SE-1) that mirrors the
stack at `/workspace`.

## The big decision: Chroma+prose, not Pony+tags

**Train character LoRAs on Chroma (Flux) with JoyCaption prose captions.** A/B'd on Cherry:
Pony (SDXL) + WD14 booru tags came out "weird"; Chroma + natural-language prose came out good —
Chroma understands prose, so descriptive captions teach identity cleanly. Only use Pony+tags if you
specifically need the SDXL/score-tag look. (`wd14_tag.py` exists for the Pony path; `joycaption.py`
for the Chroma path.)

## Stage 1 — Caption the dataset (local, on the 3090)

Dataset = a dir of `<stem>.jpg`; JoyCaption writes `<stem>.txt` (prose) beside each.

```bash
cd ~/ComfyUI && ./.venv/bin/python joycaption.py /path/to/CharName/images
```

- **~17 GB model — won't co-reside with Chroma on the 24 GB 3090.** Stop any ComfyUI render loop
  first; joycaption frees ComfyUI's VRAM only if the render queue is idle. Run to completion before
  starting a Chroma batch.
- Resumable (skips images that already have a `.txt`). Tolerates truncated jpgs
  (`ImageFile.LOAD_TRUNCATED_IMAGES = True`) so one bad file won't kill the batch.
- Verify: `ls images/*.jpg | wc -l` == `ls images/*.txt | wc -l`, no unpaired.

## Stage 2 — Deploy + prep the pod

**Deploy** (A40 first, else A6000 — both 48 GB; A40 EU-SE-1 is often `SUPPLY_CONSTRAINT`). Only the
48 GB card can do full bf16; the 24 GB 3090 would need fp8 quantize (see Stage 3). Key in `~/pod-pod`.

```
podFindAndDeployOnDemand(input:{ cloudType:SECURE, gpuCount:1, gpuTypeId:"NVIDIA A40",
  dataCenterId:"EU-SE-1", networkVolumeId:"rox8d5p4jp", containerDiskInGb:30,
  volumeMountPath:"/workspace", imageName:"runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404",
  ports:"8888/http,22/tcp", name:"charname-train" }){ id machineId machine{gpuDisplayName} }
```

**Fix direct SSH** — the `runpod/pytorch` image ships with **no sshd host keys**, so direct SSH is
"connection refused" while the proxy works. The proxy username is in the API (no need to ask the user):

```
pod(input:{podId}){ machine { podHostId } }   # e.g. "t5mohj3krxbske-64411284" = the proxy user
```

PTY-drive the proxy (`ssh <podHostId>@ssh.runpod.io -i ~/.ssh/maht_ed25519`, like `~/bin/podpub`) and run:
`ssh-keygen -A && mkdir -p /run/sshd && /usr/sbin/sshd`, plus add `maht_ed25519.pub` to
`/root/.ssh/authorized_keys`. Then `ssh -p <port> root@<ip>` works. Update `~/.ssh/config` `pod`/`podabgtty`.

**CUDA-test every fresh pod** (bad-host guard): `uv run python -c "import torch; torch.zeros(1).cuda()"`.
If it errors `cudaErrorDevicesUnavailable` (error 46) with a healthy `nvidia-smi`, terminate + redeploy
(faulty host). If direct SSH + proxy are both dead after boot, the container's broken — terminate + redeploy
(A6000 is a different machine than the constrained A40).

**Free volume space if needed.** `du -sh /workspace` (NOT `df` — that shows the 756T MFS cluster; the
API's `networkVolumes` gives only the 120 GB allocation, no used-bytes). Removable after verifying a
local beast copy: render PNG dirs, uploaded datasets, `ai-toolkit/output/*` checkpoint histories, `*.log`.
Keep `models/`, the venvs, `hf_cache`, and `models/loras/*.safetensors`.

## Stage 3 — Train (ai-toolkit)

Clone the proven config and swap 4 things:

```bash
cd ~/ai-toolkit/config && cp chroma_local.yaml charname_chroma.yaml
sed -i 's/name: "holly_chroma_lora_v1"/name: "charname_chroma_lora_v1"/' charname_chroma.yaml
sed -i 's/trigger_word: "h0lly"/trigger_word: "ch4rname"/' charname_chroma.yaml   # rare leetspeak token
sed -i 's#folder_path: "/home/matt/Holly"#folder_path: "/workspace/CharName_chroma_train"#' charname_chroma.yaml
sed -i 's#name_or_path: "/home/matt/ComfyUI/.*#name_or_path: "/workspace/ComfyUI/models/diffusion_models/Chroma1-HD.safetensors"#' charname_chroma.yaml
# Precision: quantize:true/quantize_te:true for a 24GB card; quantize:false (full bf16) on the 48GB pod.
# steps: ~2000 for ~100 imgs; ~3500 for ~470 imgs (aim ~7-8 passes; range 500-4000). save_every 250.
```

Upload dataset (images + prose, co-located) + config, then launch detached and confirm it steps
(full bf16 lands ~31 GB / 48 GB — watch for OOM; ~3-4.5 s/it settling to ~3):

```bash
rsync -a -e "ssh -i ~/.ssh/maht_ed25519 -p <port>" /path/CharName/images/ root@<ip>:/workspace/CharName_chroma_train/
rsync -a -e "ssh -i ~/.ssh/maht_ed25519 -p <port>" ~/ai-toolkit/config/charname_chroma.yaml root@<ip>:/workspace/ai-toolkit/config/
ssh pod 'cd /workspace/ai-toolkit && export HF_HOME=/workspace/hf_cache; nohup setsid bash -c "./venv/bin/python run.py config/charname_chroma.yaml > /workspace/charname_train.log 2>&1" </dev/null >/dev/null 2>&1 & disown'
```

Training samples an 8-prompt `[trigger]` grid every 250 steps — review those to pick a checkpoint
(usually a late-but-not-final save, e.g. the ~1750/2500). **Wait for `run.py` gone on 3 consecutive
polls** before acting (it false-triggers once during the final save — don't race it onto the GPU).
Pull the whole `output/charname_chroma_lora_v1/` to beast.

## Stage 4 — Render with the LoRA (Chroma + face-fix)

Render via the existing Chroma pipeline. Params come from `pony_web.CHROMA_PARAMS` + the LoRA via
`chroma_workflow._maybe_lora`. Copy the chosen checkpoint into `models/loras/` (rename to a clean
`charname_chroma_lora_v1_<step>.safetensors`). Key settings: `detail_face: True` (inline FaceDetailer —
pre-empts teeth artifacts; Holly had it off), fp16 on the pod (`weight_dtype="default"` +
`t5_name="flan-t5-xxl-fp16.safetensors"`), fp8 default locally on the 3090.

**OOM guard (important):** ComfyUI leaks VRAM over a long Chroma + FaceDetailer + upscale run and the OS
kills it (no python traceback) around **~67 renders**. For batches >~50, render in chunks and **restart
ComfyUI between chunks** — `run_cherry_chroma.py --max-renders 30` + a wrapper loop. See `run_cherry_chroma.py`.

**ComfyUI launch on the pod:** inline `nohup setsid bash -c "..." &` silently fails to spawn over ssh.
Reliable: write a launcher script (`cd + export + exec uv run python main.py ...`) to the pod, then
`nohup bash /workspace/pod_start_comfy.sh > log 2>&1 &`. Wait patiently for `http 200` (~1-3 min; the
Holly-mirror custom nodes load slowly).

## Stage 5 — Integrate into pony_web + the loops

Add a web-UI model entry (mirrors the `holly`/`cherry` pattern in `pony_web.py`):

```python
CHARNAME_PARAMS = {**CHROMA_PARAMS, "lora_name": "charname_chroma_lora_v1_<step>.safetensors",
                   "lora_strength": 0.90, "detail_face": True}
MODELS["charname"] = {"params": CHARNAME_PARAMS, "pos_tags": "ch4rname, ", "neg_tags": "",
                      "neg_file": "default_neg_chroma.txt"}
# + <option value="charname">CharName — CHROMA + LoRA</option> in the <select>
```

Copy the LoRA into `~/ComfyUI/models/loras/`, restart `pony_web` (doesn't touch ComfyUI/run_pool).
Because it's Chroma+LoRA it shares the base with chroma/holly/cherry — switching profiles just toggles
the LoRA patch, no model reload.

**Infinite variety loop** (`run_lora_loop.py --profile charname`): renders a random prompt from the
prompt_gen prose pools (`~/Randoms/*/prose.db`) + optional caption files, `[trigger]` prepended, fresh
seed each render, forever → `~/CharName_loop/`. `--no-upscale` ~doubles throughput (use a post-render
upscaler). **Only one Chroma-LoRA loop at a time on the 24 GB 3090** — two different LoRAs thrash
(each swap forces a full Chroma reload; one loop starves). Stop with `pkill -f 'run_lora_loo[p]'`
(bracket form so it doesn't kill its own shell — `pkill -f name.py` self-matches when the command also
launches `name.py`).

## Reusable assets in the repo
- `joycaption.py` — prose captioner (Chroma path). `wd14_tag.py` — booru tagger (Pony path).
- `chroma_local.yaml` — the ai-toolkit training template. Clone per character.
- `run_cherry_chroma.py` — Chroma+LoRA pool renderer (`--max-renders` for chunked OOM-safe runs).
- `run_lora_loop.py --profile <name>` — infinite variety loop for any web-UI profile.
- `pony_web.py` — `MODELS` profiles + `build_workflow`/`_maybe_lora_sdxl` (Pony LoRA support).

## Cost/time (per character, 48 GB pod ~$0.35-0.49/hr)
Caption (local, free) → train full-bf16 (~3 hr for 3500 steps) → render (~2-3 hr for ~100, chunked) →
integrate. Terminate the pod when done; the volume persists. Total pod ~$2-3.
