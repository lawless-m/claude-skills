# Claude Code Template

![Spellbook](spellbook.png)

A GitHub template repository containing reusable Claude Code skills and commands.

## Usage

### Creating a New Project

1. Click **"Use this template"** on GitHub
2. Create your new repository
3. Your project automatically includes:
   - Skills in `.claude/skills/`
   - Commands in `.claude/commands/`

### Available Commands

| Command | Description |
|---------|-------------|
| `/blog` | Write a blog post in Cyril's voice and publish it to steponnopets.net. |
| `/build-loop` | Plan the current goal into a finite, verifiable task list that /tasks can drain |
| `/commit` | Create a well-crafted git commit for the current changes. |
| `/detemplate` | Remove files from the initial Git template commit, typically used when starting a new project from the claude-skills template. |
| `/devblog` | Write and publish a devblog post focused on accomplishments and how colleagues can use what we've built. |
| `/publish` | Run dotnet publish in release configuration: |
| `/pull` | Pull the latest changes from the remote repository and help resolve any merge conflicts that arise. |
| `/push` | Commit any pending changes and push to the remote repository. |
| `/tasks` | Drain the tasks/ queue — one slice after another, no timer, until done or something stops it |
| `/yazi` | Launch yazi in a new alacritty window at the current session directory |

### Available Skills

| Skill | Description |
|-------|-------------|
| **Anthropic-Rate-Limits** | Anthropic API rate limit handling - retry logic, backoff, throttling for batch workloads against Claude models |
| **auto-testing** | Use when building an automated test → issue → fix loop with Claude Code and GitHub issues — overnight auto-fixing, regression loops, self-healing CI. |
| **Blog Management** | Use when creating, editing, publishing, or deleting posts on Cyril's Workshop blog or the steponnopets.net devblog. |
| **boofuzz** | Use when writing or contributing a boofuzz network-protocol fuzzer in this repo — layout, formatting rules, and reading results. |
| **BrowserBridge** | Use when a task needs real-time control of a connected browser via the Browser Bridge Broker — submit JS jobs over HTTP that browsers eval and return. |
| **Character LoRA on RunPod** | Use when training a character LoRA (Chroma/Flux or Pony/SDXL) on a RunPod GPU and wiring it into the ComfyUI + pony_web render stack. |
| **Creating Skills** | Use when writing a new skill or revising an existing one — format, trigger descriptions, and what content belongs in a skill. |
| **CSharpener** | Use when you need to find unused methods in a C# solution, trace who calls a method, assess removal impact before refactoring, or generate call-graph documentation/diagrams for C# code. |
| **Databases** | Use when querying or writing any RI database — Exportmaster (DBISAM sem01/sem04), PostgreSQL x3rocs, X3/Sage1000 SQL Server, keycloak MySQL, or Parquet. DuckDB is the primary read path. |
| **DCG-Grammar-Companion** | Use when planning a new parser or lexer for a published language spec, validating parser correctness, or fuzz-testing a parser — build a Prolog DCG grammar companion alongside the hand-written parser. |
| **Dotnet 8 to 9** | Use when migrating a project from .NET 8 to .NET 9, or preparing .NET 8 code for that migration with only the .NET 8 SDK available (e.g. Claude for Web). |
| **DuckDB-Extensions** | Use when building, debugging, or deploying a DuckDB loadable extension — version matching, "not a DuckDB extension" errors, install paths, auto-loading. |
| **Elasticsearch** | Use when searching, indexing, bulk-loading, or rebuilding indices on RI's Elasticsearch cluster (locked at 5.2) via ServiceLib.Elasticsearch. |
| **Email** | Use when sending email from RI C# services — notifications, daily reports, or log files as attachments. |
| **Finding Unknowns** | Use when starting ambiguous or high-stakes work, or when the user says "blind spot pass", "interview me", "what am I missing", or asks for an implementation plan. |
| **Flowstone Docs** | Use when writing Flowstone-compatible project or hub notes — small Markdown notes with [[wiki-links]] so the knowledge graph stays connected; never touches repo READMEs. |
| **Gogs** | Gitea issue tracker on dw.ramsden-international.com - the triage/plan/execute plan/fixed label workflow, plus creating, querying and commenting on issues via the REST API |
| **Image Files** | Use when resizing, converting, optimizing, or batch-processing images with ImageMagick — especially when the magick command isn't found on PATH on Windows. |
| **JSharpener** | Use when finding dead JS/TS code, tracing callers (call graphs), or analyzing module and circular dependencies in a JS/TS project. |
| **Logging** | UTF-8 file logging with automatic date-based filenames and thread-safe operations for RocsMiddleware services |
| **Nawin** | Use when working on the Nawin .NET 9 codebase or connecting to 9front/Plan 9 over 9P2000 — file serving, CPU shell, FUSE/ProjFS mounts, auth. |
| **Parquet Files** | This describes how to create Parquet files in C#, including updating and multi threaded creation |
| **PostgreSQL** | PostgreSQL database operations using PgQuery tool for DDL execution, schema management, and query operations |
| **Python JSON** | Use when reading or writing JSON in Python on Windows to avoid CP-1252 mojibake — the convention here is to copy this skill's json_io.py into the project and always open JSON as UTF-8. |
| **Qwen-Ollama** | Use when a task needs local LLM inference via the on-box Ollama server (Qwen 2.5) instead of a cloud API. |
| **Reverse Proxy Deployment** | Use when deploying behind the Apache reverse proxy on rivsprod01, writing a ProxyPass config in /etc/apache2/proxy-conf.d/, or fixing 404s under a path prefix. |
| **ri-service-toolkit** | Use when building a .NET 9 service from RI's shared components (ExportKing, KdbxCredentials, OhSheet, Anthea) deployed as a TinyWeb CGI, or registering a URL on the dw portal page. |
| **Roo-VMS** | Alpine and Debian QEMU VMs for protocol testing, fuzzing, and network experiments |
| **Rust** | Use when starting or writing Rust projects — and especially this environment's v4l2 video I/O, RGB-to-YUYV conversion, and frame-timing patterns. |
| **ScryQL** | Use when asked "why isn't <record> in this query result", to trace a row through joins, or to decompose WHERE/JOIN-heavy SQL into per-step pass/fail attribution — generates ScryQL rules.pl + queries.sql. |
| **SharePoint** | Use when uploading/downloading files to RI's SharePoint Online sites, updating Excel tracker cells, or normalizing pasted share links. |
| **Suno-Automation** | Use when asked to make or generate a song on Suno, automate Suno, or fill the suno.com create form programmatically — drives a logged-in browser via the Browser Bridge. |
| **task-loop** | Do the next unblocked task from tasks/. Exactly one slice, then stop. Use when the user says "do the next task"; /tasks repeats it to drain the queue. |
| **Vram-GPU-OOM** | Use when GPU services (Ollama, Whisper, ComfyUI/Flux, OCR) contend for VRAM on the RTX 3090 and hit CUDA OOM. |
| **web-frontend** | Use when building an elaborate multi-component claude.ai HTML artifact needing state, routing, or shadcn/ui — not for simple single-file artifacts. |
| **Whisper-Transcription** | Use when transcribing audio to text via the local whisper.cpp server (large-v3, CUDA) — POST an audio file, get JSON back. |
| **X3 SOAP Web Services** | Use when building, deploying, or calling Classic SOAP sub-program web services on Sage X3. |

## Structure

```
your-project/
├── .claude/
│   ├── commands/
│   │   ├── commit.md
│   │   ├── publish.md
│   │   └── push.md
│   └── skills/
│       ├── Databases/
│       ├── Elasticsearch/
│       └── ...
├── README.md
└── spellbook.png
```

## How Skills Work

Skills are markdown files that teach Claude domain-specific patterns. They're loaded automatically when relevant or can be explicitly invoked.

## Source

This template is maintained at:
- https://github.com/lawless-m/claude-skills
