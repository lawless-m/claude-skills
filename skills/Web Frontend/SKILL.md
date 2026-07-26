---
name: web-frontend
description: Use when building an elaborate multi-component claude.ai HTML artifact that needs state, routing, or shadcn/ui components — this repo's init/bundle scripts scaffold a React+TS+Vite+Tailwind+shadcn project and inline it to a single bundle.html. Not for simple single-file HTML/JSX artifacts.
license: Complete terms in LICENSE.txt
---

# Web Frontend

Tooling for React 18 + TypeScript + Vite + Tailwind + shadcn/ui artifacts, bundled to a single self-contained HTML file via Parcel. Use it for complex artifacts (state management, routing, shadcn/ui components); for a simple single-file HTML/JSX artifact, skip this and just write the file.

## Design: avoid "AI slop"

VERY IMPORTANT: avoid excessive centered layouts, purple gradients, uniform rounded corners, and the Inter font.

## Workflow

1. **Init**: `bash scripts/init-artifact.sh <project-name>` then `cd <project-name>`. Creates a fully configured project: React + TypeScript via Vite, Tailwind CSS 3.4.1 with the shadcn/ui theming system, 40+ shadcn/ui components pre-installed, all Radix UI deps, `@/` path aliases, and Parcel bundling via `.parcelrc`. Auto-detects Node 18+ and pins a compatible Vite version.
2. **Develop**: edit the generated files.
3. **Bundle**: `bash scripts/bundle-artifact.sh` — requires an `index.html` in the project root. Builds with Parcel (no source maps) and inlines all JS/CSS/assets into a single `bundle.html`.
4. **Share** the `bundle.html` as the artifact.
5. **Test (optional)**: only if requested or if issues arise — testing upfront adds latency before the user sees the artifact.

## Reference

- shadcn/ui components: https://ui.shadcn.com/docs/components
