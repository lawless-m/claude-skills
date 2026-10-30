---
name: Creating Skills
description: Use when writing a new skill or revising an existing one — format, trigger descriptions, and what content belongs in a skill.
---

# Creating Skills

Skills are on-demand knowledge files. Claude 5-generation models have strong judgment and broad tool knowledge, so a skill earns its tokens only by recording what Claude *cannot* infer: your environment's hosts, paths, credentials locations, version quirks, conventions, and hard-won gotchas. Everything else is padding that slows discovery and constrains exploration.

## Format

A skill is a directory under `.claude/skills/` containing `SKILL.md` (required) plus optional supporting files:

```
skills/
    My Skill Name/
        SKILL.md            # short guide, always loaded when triggered
        reference-*.md      # detail read only when needed
        Working-Code.cs     # real implementations to copy, not describe
```

`SKILL.md` starts with YAML frontmatter — `name` and `description` are required.

## The description is the trigger

The `description` is what Claude sees when deciding whether to load the skill. Write it as *when to use*, not just *what it covers*. Include the trigger phrases a user would actually say.

- Weak: `C# static analysis tool for call graphs and unused code detection`
- Strong: `Use when you need to find unused methods, trace who calls a function, or assess removal impact before refactoring a C# solution`

## What belongs in a skill

**Keep** (Claude cannot infer these):
- Hosts, IPs, ports, URLs, DSNs, file paths, credential locations
- Version pins and version-specific quirks ("ES 5.2, will not change")
- Team conventions and decisions ("we're migrating from timestamped indices to in-place overwrites")
- Gotchas that cost real debugging time ("Turnstile is domain-locked — must be real suno.com", "always clear the scroll in a finally block")
- Hard constraints, sparingly, only where deviation genuinely breaks things

**Cut** (Claude already knows these):
- Standard tool/API documentation (ImageMagick flags, curl syntax, Apache directives, stdlib usage)
- Tutorial walkthroughs of common patterns (retry loops, HTTP clients, CMake boilerplate)
- Example dialogues showing "how Claude should respond" — these constrain more than they help
- Generic best-practice lists and troubleshooting steps any competent engineer would try

The test: if you deleted a line and Claude could reconstruct it from the tool's `--help` or general knowledge, delete it.

## Progressive disclosure

Keep `SKILL.md` short — a screenful or two. When there's genuinely more detail (full templates, long worked examples, protocol references), move it to a reference file in the same directory and point to it:

```markdown
For the full CMake template and PIC troubleshooting, see `reference-cmake.md`.
```

Claude reads reference files only when the task needs them, so their length is free. Never make SKILL.md long to avoid a second file.

## Prefer working code over described code

A real, production-proven file in the skill directory (`Utf8LoggingExtensions.cs`, `json_io.py`) beats prose describing the same pattern. Say what it is and where to copy it; don't restate its contents in markdown.

## Common mistakes

1. Missing or malformed frontmatter — the skill won't be discovered.
2. A description that says *what* instead of *when*.
3. Encyclopedia content — restating public documentation.
4. Over-constraining — "ALWAYS use this exact command" for things with obvious alternatives; reserve imperatives for real footguns.
5. Stale paths, hosts, and version pins — recheck them when touching the skill.

## Testing

Verify the skill appears in the skills list, trigger it with a realistic request, and confirm the environment-specific facts (paths, hosts, versions) are still correct.
