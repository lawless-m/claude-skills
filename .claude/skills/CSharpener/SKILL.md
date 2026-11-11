---
name: CSharpener
description: Use when you need to find unused methods in a C# solution, trace who calls a method, assess removal impact before refactoring, or generate call-graph documentation/diagrams for C# code.
---

# CSharpener - C# Code Analysis

Roslyn-based static analysis for C# solutions: call graphs, unused-code detection, impact analysis, HTML docs, Graphviz export.

## Executable

**Primary**: `Y:/CSharpDLLs/CSharpener/CSharpener.exe` — use forward slashes for the exe path in bash; the `--solution` argument takes a normal Windows path. Don't search for the executable, use this path directly.

**Fallback** if Y: is unavailable — build from https://github.com/lawless-m/CSharpener with `dotnet build -c Release`; output is `CSharpCallGraphAnalyzer\bin\Release\net9.0\win-x64\csharp-analyzer.exe`.

## Commands

```bash
"Y:/CSharpDLLs/CSharpener/CSharpener.exe" <command> --solution "<path>" --format console
```

| Command | Purpose | Extra options |
|---------|---------|---------------|
| `analyze` | Full analysis: call graph, unused methods, stats | `--include-call-graph` (default true), `--exclude-namespace` |
| `unused` | Find unused methods with confidence levels | `--exclude-namespace` |
| `callers` | Who calls a method | `--method, -m` (partial name OK, case-insensitive) |
| `dependencies` | What a method calls | `--method, -m` |
| `impact` | What breaks if a method is removed (direct/transitive callers, affected entry points) | `--method, -m` |
| `document` | HTML docs with cross-referenced code and call graphs | `--output, -o` (required), `--include-unused`, `--include-tests` |

Common options: `--solution, -s` (required, .sln or .csproj, absolute path), `--format, -f` (json default; console, dot/graphviz, html), `--output, -o`.

## Confidence levels (`unused`)

| Level | Meaning |
|-------|---------|
| High | Private methods never called — safe to remove |
| Medium | Internal methods not called within assembly — review |
| Low | Public methods — might be external API, caution |

## Environment notes

- Cache lives in `.csharpener-cache/` in the solution directory. First run is slow; subsequent runs fast. Delete the cache to force a refresh; it invalidates on file changes.
- For large solutions, use `--exclude-namespace "*.Tests,*.Test"` or analyze individual projects.
- Reflection usage causes false positives in unused detection (the tool warns). DI registration patterns (AddTransient, AddScoped, etc.) are recognized.
- If "no methods found", run `dotnet build` first — the solution may not compile.
