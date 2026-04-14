---
name: Flowstone Docs
description: Writing Flowstone-compatible project notes and hub notes in a dedicated docs directory. Each project in a multi-repo corpus gets its own small Markdown note with [[wiki-links]] to sibling projects and shared themes, so Flowstone's knowledge graph stays connected. Existing repo READMEs are NOT touched.
---

# Flowstone Docs

Flowstone parses a folder of Markdown files into a CozoDB knowledge graph. The only edges it understands are `[[wiki-links]]`. Shared themes, adjacency, and common vocabulary are invisible to the tool — if you want the connection in the graph, you must write the bracket.

The Flowstone corpus is a **dedicated docs folder**, separate from the projects it describes. Each project, theme, or concept worth tracking gets its own small note in that folder. Original repo READMEs stay as they are, written for whatever audience they already serve.

## When this skill applies

Use this skill when:

- Creating or editing a note inside a Flowstone corpus (a dedicated docs folder such as `Flowstone-docs/`)
- Adding a new project to the corpus — one new note per project
- Creating or updating theme hub notes
- Being asked to "Flowstone-ify", "index", or "cross-reference" a set of projects or repos

This skill does **not** apply to editing the READMEs of the projects themselves. Those READMEs belong to their repos and are out of scope.

## Detecting a Flowstone corpus

A folder is a Flowstone corpus if **any** of these hold:

1. Its name contains `flowstone` or `flowstone-docs`, or it holds a `.flowstone` / `flowstone.toml` marker
2. It contains a `hubs/` subfolder with theme notes
3. Its contents are small project summary notes (one per repo), not the projects themselves
4. The user says so

If unsure, ask once: "Is this the Flowstone corpus directory? Should new notes go here?" Remember the answer for the session.

The corpus is usually a **sibling** of the project repos (e.g. `~/Git/Flowstone-docs/` alongside `~/Git/Caturiel/`, `~/Git/Crabbit/`, etc.), not a subfolder of any one project.

## Core rules

1. **One note per project.** Filename matches the project directory name, case preserved: `Caturiel.md`, `Crabbit.md`, `Flowstone.md`. Flowstone normalises for matching.

2. **Link sibling projects by bare name.** If `Caturiel` interacts with `Robocyril`, write `[[Robocyril]]` in `Caturiel.md`. No paths, no extensions, no display-text syntax.

3. **Link themes to hub notes.** Shared themes (`[[rust]]`, `[[fuzzing]]`, `[[9p]]`, `[[cli-tools]]`, `[[ollama]]`, `[[bots]]`) live as hub notes in the same corpus folder (or a `hubs/` subfolder if the user prefers).

4. **Link on first meaningful mention only.** One `[[Crabbit]]` per note is enough. Flowstone deduplicates `(source, target)` pairs, but repeated brackets clutter prose for humans.

5. **Don't link generic words.** `[[file]]`, `[[tool]]`, `[[database]]`, `[[server]]` are noise. Link only proper nouns (project names, people, products) and named themes worth tracking as graph edges.

6. **Don't link external tools unless they have a hub.** CozoDB, Rust-the-language, GitHub are not corpus notes. Leave them as plain text unless the user has explicitly created a hub for them.

7. **Notes are small.** A project note is roughly: a one-line summary, a pointer to the source repo, a short paragraph, and a list of related links. Not a duplicate of the README. The README lives in the repo; the note lives in the graph.

12. **Include deployment URLs and domains.** If a project is deployed as a web app or service, include the live URL in a `**URL:**` field as a plain link. The domain itself (e.g. `dw.ramsden-international.com`) is a meaningful graph node — link it separately with `[[...]]` in the body or Related section so the corpus tracks which projects are deployed where. Don't wrap the domain inside the URL field itself — keep the URL clean and readable.

8. **Don't touch the source repo's README.** This skill creates new files in the corpus folder only. The repo's own README is out of scope.

9. **Surface dangling links; don't silently create files.** After writing a note, list any `[[target]]` wiki-links whose note does not yet exist. Each dangling target is either (a) a hub or project note that should be created next, or (b) a typo. Report the list to the user; let them decide.

10. **Flowstone prototype limits.** The prototype does NOT support `[[target|display text]]` or `[[note#heading]]` section links (see Flowstone's `PROJECT.md` out-of-scope list). Use bare `[[target]]` only.

11. **Casing convention.** Proper names keep their proper case: `[[SQLite]]`, `[[Oxygen-Not-Included]]`, `[[Clacker-News]]`, `[[Caturiel]]`, `[[StinkySpy]]`. Generic theme hubs are lowercase: `[[rust]]`, `[[bots]]`, `[[fuzzing]]`, `[[cli-tools]]`, `[[game-mods]]`, `[[claude-tooling]]`. If in doubt: does the word have an official capitalisation? Use it. Is it a common noun describing a category? Lowercase. Flowstone normalises to lowercase for matching (see `flowstone-spec/SCHEMA.md`), so casing is for human readers — but stay consistent so `[[SQLite]]` and `[[sqlite]]` don't drift apart across notes.

## Note templates

### Project note

```markdown
# ProjectName

One-sentence punch description with a couple of [[theme]] links and any sibling like [[OtherProject]] where relevant.

**Repo:** `~/Git/ProjectName`
**URL:** `https://example.com/path` *(if the project is deployed as a web app or service — include the live URL or domain)*
**Themes:** [[theme-a]], [[theme-b]]

Short paragraph (2–5 sentences) saying what the project does, why it exists, and what it talks to. Wrap sibling mentions and themes in `[[...]]` on first meaningful mention only.

## Related

- [[SiblingProject]] — one-line reason for the relationship
- [[theme-a]]
- [[theme-b]]
```

### Hub note

```markdown
# rust

Projects in this corpus written in Rust.
```

Hub notes are just a title and a short description paragraph. **Do not include members lists or related themes sections** — project notes link *to* the hub, so the graph already knows membership and relationships via inbound edges. Manually maintained lists go stale as projects are added and duplicate what Flowstone computes automatically.

## Procedure when writing a NEW project note

1. Read the source repo's README (and any docs folder) to learn what the project actually is.
2. List the Flowstone corpus folder to see which sibling notes and hub notes already exist — you can only draw real edges to targets that exist or that you intend to create.
3. Draft the note using the template above. Keep it short.
4. Wrap sibling references and themes in `[[...]]` on first meaningful mention.
5. Collect the list of wiki-link targets that don't yet have a corresponding note (the dangling set).
6. Report the dangling set to the user. Do not silently create hub notes or sibling notes — let the user decide which to promote next.

## Procedure when bulk-creating project notes

1. **Write ONE note first as a worked example.** Show the user the content. Get explicit confirmation of style, length, and link density before creating the rest.
2. After confirmation, proceed project by project. Keep each note short and consistent in shape.
3. Build hub notes in parallel as recurring themes emerge. Don't invent a hub for a theme that appears in only one note — wait for it to recur at least twice.
4. At the end of each batch, share the accumulated dangling-link report so the user can see the shape of the graph and decide what to write next.

## Example: a worked project note

Seeded from the real `Caturiel` README. Note how the summary is much shorter than the README and the links are sparing.

```markdown
# Caturiel

A [[rust]] bot that monitors Reddit for anti-AI sentiment and posts
Uriel-voiced commentary to [[Clacker-News]].

**Repo:** `~/Git/Caturiel`
**URL:** `https://[[clacker-news.example.com]]/` *(if deployed — omit if CLI-only or not hosted)*
**Themes:** [[rust]], [[ollama]], [[bots]], [[Clacker-News]]

Caturiel uses [[ollama]] (Qwen models) to pick what to post and to write
the commentary. It persists seen-content state in SQLite and notifies via
ntfy.sh. The personality is deliberately terse and deadpan — it points
out irony without cruelty.

## Related

- [[Clacker-News]] — the forum Caturiel posts to
- [[rust]]
- [[bots]]
- [[ollama]]
```

Notes on the example:

- `Qwen`, `SQLite`, `ntfy.sh`, `Reddit` are left plain. They are external products, not corpus notes. Link them only if the user later creates hubs for them.
- The `## Related` section deliberately repeats some inline links as a scannable edge list. Flowstone dedupes `(source, target)` pairs, so there's no cost.
- `[[Clacker-News]]` is written as a theme hub — the forum itself, which multiple bots may post to. If only Caturiel ever posts there, consider demoting it to plain text.

## What NOT to do

- **Don't edit the source repo's README.** The corpus is a separate folder.
- **Don't link every instance of a word.** One per note.
- **Don't invent hub notes** without asking. Surface dangling targets first.
- **Don't link generic nouns** like `[[file]]` or `[[server]]`.
- **Don't link external tools** unless the corpus has a hub for them.
- **Don't use `[[target|display]]` syntax** — the prototype doesn't support it.
- **Don't use `[[note#heading]]` section links** — not supported.
- **Don't assume the folder is a Flowstone corpus.** Check markers or ask.
- **Don't bulk-create notes before showing a worked example** and getting style confirmation.

## Related references

- Flowstone project spec: `flowstone-spec/PROJECT.md` in the Flowstone repo
- Schema and dangling-link query: `flowstone-spec/SCHEMA.md`
- Dangling-link query: `dangling[target] := *links[_, target], not *notes{path: target}`
