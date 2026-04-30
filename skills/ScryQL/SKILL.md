---
name: ScryQL
description: Generate ScryQL `rules.pl` + `queries.sql` from existing project SQL so the user can diagnose why a specific record does or doesn't pass through their query. Trigger when the user asks "why isn't <record> in this query result", "trace this row through the joins", "make a diagnostic for this report", or wants to decompose a WHERE/JOIN-heavy SQL into per-step pass/fail attribution against a single subject. Output: a matched pair of files plus a sample CLI invocation; the engine itself lives at /nonreplicated/Git/ScryQL and does not need editing.
---

# ScryQL: generate diagnostics from existing SQL

ScryQL (`/nonreplicated/Git/ScryQL`) is an engine that runs a Prolog rule against facts pulled from DuckDB. The engine is generic; *every diagnostic is a `rules.pl` + `queries.sql` pair*. This skill is for **producing those two files** from existing project SQL so the user can diagnose record-level inclusion or exclusion.

## When to use

Trigger this skill when:
- The user has a SQL query (report, view, ETL filter, API endpoint) and wants to know why a specific row does/doesn't appear in its output.
- They say things like "explain why X is missing", "trace this record through the join", "I want to debug membership in this view".
- A query involves multiple `WHERE` clauses or `JOIN`s and the user is repeatedly probing "is the row in source A? in B? did the filter exclude it?"

Do **not** use for:
- Pure performance optimisation of the original query.
- Bulk reporting (one-record-at-a-time is the whole point).
- Anything that needs to mutate data — ScryQL is read-only.

## The decomposition

A typical query the user wants to diagnose looks like:

```sql
SELECT c.customer_code
FROM customer c
JOIN credit_status cs ON c.customer_code = cs.code
JOIN customer_currency cur ON c.customer_code = cur.code
WHERE cs.status = 'good'
  AND cur.currency IN ('GBP','EUR','USD')
  AND c.customer_code = ?
```

To diagnose "why isn't customer 400007 in this output", decompose it into:

1. **One Prolog fact predicate per source table** — `customer/1`, `credit_status/2`, `currency/2`, `supported_currency/1`.
2. **One `-- @row` block per fact predicate** — each fetches that table's data for the subject. The SELECT emits a single column of pre-formatted Prolog clauses.
3. **One Prolog rule per WHERE condition or JOIN existence check** — `is_customer/1`, `not_on_credit_hold/1`, `currency_supported/1`.
4. **An entry predicate** that calls them in order and either prints diagnostics (`format/2`, arity 1) or returns a `fail(reason, Subject)` term (arity 2).

## File templates

### `queries.sql`

```sql
-- @setup runs once at startup. Use for INSTALL / LOAD / ATTACH / CREATE VIEW.
-- @row   runs per invocation with the single ? bound to the CLI subject.
--        Each @row returns ONE column of fully-formatted Prolog clauses.

-- @setup
INSTALL postgres;
LOAD postgres;
ATTACH 'host=/var/run/postgresql port=5432 dbname=DBNAME user=USERNAME' AS pg (TYPE postgres, READ_ONLY);
-- (or: CREATE VIEW ... AS SELECT * FROM read_parquet('/path/to/file.parquet');)

-- @row
SELECT 'fact_predicate(''' || pk_col || ''').' AS fact
FROM source_table
WHERE pk_col = ?;

-- @row  (multi-arg fact)
SELECT 'other_pred(''' || pk_col || ''', ''' || other_col || ''').' AS fact
FROM other_table
WHERE pk_col = ?;
```

Key SQL idioms:
- **Date columns**: render to text — `strftime(date_col, '%Y-%m-%d')`.
- **Nullable columns**: choose between `COALESCE(col, 'NULL')` (emit a fact with sentinel atom — caller treats `'NULL'` explicitly) or `WHERE col IS NOT NULL` (no fact emitted — predicate has no clause for that subject and rules fail closed). The semantic difference matters; surface it to the user.
- **Reference tables** (small lookups like `supported_currency`): no `WHERE` clause — emit all rows so rules can join against them.
- **Joins inside SQL** (e.g. `ORDERH ⋈ ORDERI` for a derived predicate): keep the join in DuckDB; the resulting predicate can be 1-arity ("ref X has at least one nonzero line").

### `rules.pl`

Two flavours of entry predicate, depending on the user's preferred output:

**Side-effect (arity 1) — diagnostic prints lines:**
```prolog
:- use_module(library(format)).

:- dynamic(customer/1).
:- dynamic(credit_status/2).
:- dynamic(currency/2).
:- dynamic(supported_currency/1).

is_customer(X)         :- customer(X).
not_on_credit_hold(X)  :- credit_status(X, good).
currency_supported(X)  :- currency(X, C), supported_currency(C).

diag(X) :-
    format("~w:~n", [X]),
    ( is_customer(X)         -> format("  customer       OK~n", [])
    ;                           format("  customer       MISSING~n", []) ),
    ( not_on_credit_hold(X)  -> format("  credit_hold    no~n", [])
    ;                           format("  credit_hold    YES~n", []) ),
    ( currency_supported(X)  -> format("  currency       supported~n", [])
    ;                           format("  currency       UNSUPPORTED~n", []) ).
```

**Capture-result (arity 2) — returns a structured term:**
```prolog
classify(X, R) :-
    ( \+ is_customer(X)        -> R = fail(no_customer, X)
    ; \+ not_on_credit_hold(X) -> R = fail(credit_hold, X)
    ; \+ currency_supported(X) -> R = fail(unsupported_currency, X)
    ; R = ok ).
```

Both styles are useful; pick based on whether the user wants pretty output or machine-readable attribution. Often you generate both, in the same `rules.pl`.

## Generation workflow

When the user gives you a SQL query (or points at one in their codebase):

1. **Identify the subject column.** Usually the primary key being filtered with `=` or `IN`. That's what the CLI subject argument binds to.
2. **List source tables and their relevant columns.** Each becomes a `-- @row` block.
3. **List the WHERE/JOIN conditions that constrain inclusion.** Each becomes a Prolog rule predicate.
4. **Map ATTACHes:** if the original query referenced `pg.x3.something`, the user already has a Postgres ATTACH set up — copy its connection string into `-- @setup`. If it referenced `read_parquet('...')`, use the same path in the @row.
5. **Emit `:- dynamic(...)` declarations** for every fact predicate. Without them, an absent fact triggers `existence_error`.
6. **Compose the entry predicate** — usually a chain of `-> ... ; ...` (if-then-else) over the rule predicates.
7. **Suggest a CLI invocation** with concrete sample subjects from the data (use `duckdb -c "..."` to find one row that passes and one that fails for richer demo).

### Decomposition checklist

For each `WHERE` clause or `JOIN`, ask: *what's the smallest fact set that lets a Prolog rule reproduce this condition?* Examples:

| SQL fragment | Prolog predicate | Fact shape |
|---|---|---|
| `c.customer_code = ?` | `is_customer/1` | `customer('CODE').` |
| `cs.status = 'good'` | `not_on_credit_hold/1` | `credit_status('CODE', good).` |
| `cur.currency IN ('GBP','EUR','USD')` | `currency_supported/1` | `currency('CODE', 'GBP').` + `supported_currency('GBP').` |
| `EXISTS (SELECT 1 FROM lines l WHERE l.ref = oh.ref AND l.qty > 0)` | `has_nonzero_lines/1` | `nonzerolines('REF').` (computed in SQL via `bool_or(qty > 0)`) |
| `t.deleted_at IS NULL` | `not_deleted/1` | emit fact only when actually-not-deleted, or emit `deleted_at(X, none)` and check explicitly |

## What the engine guarantees

- `--entry NAME/ARITY` is required — every invocation states the predicate explicitly. No silent default.
- Arity 1 = the rule prints to stdout via `format/2` (Scryer is configured with `StreamConfig::stdio()`).
- Arity 2 = the harness binds `R` and prints it in canonical Prolog notation.
- REPL mode (no subject, or `--repl` after a one-shot run) intercepts `entry('subject').` lines: fetches facts for `subject`, consults them, runs the query. Other Prolog queries pass through.

## Constraints to keep in mind when generating

- **scryer-prolog 0.10 has no foreign-predicate API.** Don't suggest registering Rust callbacks; everything goes through facts injection. (See user's project memory `project_scryer_embed_quirks.md`.)
- **Subjects must be alphanumeric in practice.** Embedded single quotes break the format-string injection (this is a known limitation, not yet fixed).
- **Every dynamic fact predicate needs `:- dynamic(name/arity).`** in rules.pl. Forgetting this is the most common error.
- **Setup runs once, against a fresh in-memory DuckDB.** Don't put per-row work in `-- @setup`.
- **The user's data is at:** `/mnt/prod02_ri_services/Outputs/Parquets/em/` for Exportmaster, Postgres `x3rocs` (read-only as `user=jordan`) for Sage X3, custom `odbcbridge` extension for live Exportmaster. See `reference_cross_db_layout.md` and `reference_odbcbridge.md` in user memory.

## Quick recipe

User says: *"Generate a ScryQL diagnostic for `<their SQL>`."*

1. Read the SQL. Identify subject column, sources, conditions.
2. Write `queries.sql` with `@setup` (preserving any ATTACH from the original) + one `@row` per fact predicate.
3. Write `rules.pl` with `:- dynamic(...)` decls, one rule per condition, an entry predicate (default to a `diag/1` arity-1 unless they ask for `classify/2`).
4. Run `cargo build` once if needed.
5. Demo: `cd /nonreplicated/Git/ScryQL && cargo run --quiet -- --rules <new>.pl --sql <new>.sql --entry diag/1 <a known-passing subject>` and `<a known-failing subject>` to show both branches.
6. Save the new files alongside the user's project (or wherever they prefer); keep `/nonreplicated/Git/ScryQL/` itself as the engine, not the per-project artifacts.
