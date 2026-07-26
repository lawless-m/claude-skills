---
name: DuckDB-Extensions
description: Use when building, debugging, or deploying a DuckDB loadable extension (.duckdb_extension) — version-matching the DuckDB build, "not a DuckDB extension" metadata errors, const bind_data problems, install paths, or .duckdbrc auto-loading.
---

# DuckDB Extensions

Building `.duckdb_extension` files with CMake + FetchContent. The gotchas below all cost real debugging time.

## Critical gotchas

1. **Exact version match**: the extension MUST be built against the exact DuckDB version that will load it. Use FetchContent with a specific git tag (e.g. `v1.2.1`), never `main`. Version strings need the `v` prefix (`v1.2.1`, not `1.2.1`) or loading fails with a version mismatch.

2. **Metadata append is REQUIRED**: DuckDB rejects extensions without appended metadata ("The file is not a DuckDB extension. The metadata at the end of the file is invalid"). Add a POST_BUILD command running `${duckdb_SOURCE_DIR}/scripts/append_metadata.cmake`, and `add_dependencies(${TARGET_NAME} duckdb_platform)` — the `duckdb_platform` target generates the `duckdb_platform_out` file the metadata step reads.

3. **Const bind_data (DuckDB 1.1+)**: `bind_data` is const during execution ("increment of member in read-only object"). Put mutable state in a `GlobalTableFunctionState` subclass, register an `init_global`, and access it via `input.global_state`.

4. **Platform ABI mismatch**: "built for platform 'linux_amd64', but we can only load extensions built for platform 'linux_amd64_gcc4'" means the system DuckDB has a different ABI. Easiest fix: use the DuckDB binary from your own build at `build/release/_deps/duckdb-build/duckdb`.

5. **PIC**: any static library linked into the shared extension needs `POSITION_INDEPENDENT_CODE ON`.

## Deployment

- Auto-discovery install path: `~/.duckdb/extensions/v{version}/{platform}/` (e.g. `~/.duckdb/extensions/v1.2.1/linux_amd64/myextension.duckdb_extension`).
- In `~/.duckdbrc`, `LOAD` must come BEFORE any `SET` of extension-registered settings — the settings don't exist until the extension loads.
- Unsigned (dev) extensions need `duckdb -unsigned`. Use a wrapper script so it's never forgotten:

```bash
#!/bin/bash
# ~/.local/bin/duckdb (ahead of the real duckdb in PATH)
exec /path/to/actual/duckdb -unsigned "$@"
```

## References

- Full CMakeLists template (static linking, metadata POST_BUILD, PIC/relocation troubleshooting): `reference-cmake.md`
- Entry-point and table-function C++ boilerplate, custom settings registration: `reference-cpp-patterns.md`
