---
name: JSharpener
description: Use when finding dead JS/TS code, tracing callers (call graphs), or analyzing module and circular dependencies in a JS/TS project.
---

# JSharpener — JS/TS static analysis

TypeScript Compiler API-based analyzer (sibling of CSharpener). Runs on any JS/TS project without it needing to compile.

## Running it

```bash
node "C:\Users\matthew.heath\Git\JSharpener\dist\cli\index.js" <command> [path]
```

If `dist\cli\index.js` is missing, rebuild: `cd C:\Users\matthew.heath\Git\JSharpener && npm install && npm run build`

## Commands

- `analyze [path]` — project overview (files/functions/classes/imports/exports)
- `treeshake [path] --entry src/index.ts` — unused exports, functions, variables, imports. **Always pass `--entry`** (repeatable) or reachability is guessed and results are noisy.
- `callgraph [path] -o out.dot --function processData` — Graphviz DOT call graph focused on a function; add `--reverse` for "who calls this"; `--depth <n>` to limit; `--module-level` for an architecture-level module dependency view
- `deps [path] --circular` — circular dependency chains; `--external` for external package usage

Common flags: `--include "src/**/*.ts"`, `--exclude "**/*.test.ts"`, `-o <file>`, `--format json` (treeshake), `--config jsharpener.json` (include/exclude/entryPoints in one place).

## Known limitations (first version)

Method calls through object instances aren't fully tracked in call graphs; dynamic `import()` and JSX/TSX support is limited — treat treeshake results on React code as suggestions, not proof.
