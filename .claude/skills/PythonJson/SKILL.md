---
name: Python JSON
description: Use when reading or writing JSON in Python on Windows to avoid CP-1252 mojibake — the convention here is to copy this skill's json_io.py into the project and always open JSON as UTF-8.
---

# Python JSON

Python's `open()` uses the system encoding, which on **Windows is CP-1252, not UTF-8** — so reading/writing JSON that contains `£`, `€`, or accented letters produces mojibake and violates RFC 8259 (JSON must be UTF-8). Two rules fix it:

- Always pass `encoding='utf-8'` when opening a JSON file.
- Always pass `ensure_ascii=False` when writing, so Unicode stays readable instead of becoming `\uXXXX`.

## Convention

Every Python project here that touches JSON gets a copy of **`json_io.py`** (in this skill directory) dropped into its `utils/`, then imports from it instead of calling `json.load`/`json.dump` directly:

```python
from utils.json_io import load_json, save_json

data = load_json('config.json')
save_json('output.json', {'price': '£99.99'})
```

`json_io.py` is already correct — copy it, don't rewrite it.

## Symptom → fix

- `Â£`, `â‚¬`, `Ã©` appearing in data → a UTF-8 file was read as CP-1252; add `encoding='utf-8'` (or use `load_json`).
- `£` in written output → `json.dump` defaulted to `ensure_ascii=True`; pass `ensure_ascii=False` (or use `save_json`).
