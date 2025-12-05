# Claude Code Template

![Spellbook](spellbook.png)

A GitHub template repository containing reusable Claude Code skills and commands.

## Usage

### Creating a New Project

1. Click **"Use this template"** on GitHub
2. Create your new repository
3. Your project automatically includes:
   - Skills in `skills/`
   - Commands in `commands/`

### Available Commands

| Command | Description |
|---------|-------------|
| `/commit` | Create a well-crafted git commit with conventional format |
| `/publish` | Run `dotnet publish -c release` |
| `/push` | Commit pending changes and push to remote |

### Available Skills

| Skill | Description |
|-------|-------------|
| **BrowserBridge** | Real-time browser debugging via WebSocket bridge |
| **Creating Skills** | Guide for creating new skill documents |
| **CSharpener** | C# static analysis for call graphs and unused code |
| **Databases** | RDBMS patterns for DuckDB, MySQL, PostgreSQL, SQL Server |
| **Dotnet 8 to 9** | .NET migration guide |
| **Elasticsearch** | ES 5.2 operations - search, bulk, scroll, aliases |
| **Email** | Email handling patterns |
| **Image Files** | ImageMagick command-line operations |
| **JSharpener** | JavaScript/TypeScript static analysis |
| **Logging** | UTF-8 file logging with date-based filenames |
| **Parquet Files** | Creating Parquet files in C# |
| **PythonJson** | Python JSON I/O patterns |
| **Rust** | Rust development patterns and project setup |
| **SharePoint** | SharePoint integration |
| **Web Frontend** | React + Tailwind + shadcn/ui artifacts |

## Structure

```
.claude/
├── commands/           # Slash commands
│   ├── commit.md
│   ├── publish.md
│   └── push.md
├── skills/             # Domain-specific skills
│   ├── Databases/
│   │   ├── SKILL.md
│   │   └── *.cs
│   ├── Elasticsearch/
│   └── ...
├── README.md
└── spellbook.png
```

## How Skills Work

Skills are markdown files that teach Claude domain-specific patterns. They're loaded automatically when relevant or can be explicitly invoked.

Each skill has:
- **YAML frontmatter** with name and description
- **Instructions** - numbered guidelines for Claude
- **Examples** - user/Claude dialogue patterns
- **Reference code** - production-tested implementations

## Updating This Template

Skills and commands are maintained at:
- Internal: `gogs@dw.ramsden-international.com:matthew.heath/Claude-Skills.git`
- Public: https://github.com/lawless-m/claude-skills

Push to Gogs → automatically syncs to GitHub via post-receive hook.
