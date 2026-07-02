---
name: DCG-Grammar-Companion
description: Pattern for building parsers with provable correctness via a Prolog DCG companion. Write the language grammar as a Definite Clause Grammar in Prolog alongside the production parser, then use the DCG as both an executable second reading of the spec and a fuzz-input generator for differential testing. Trigger when planning a new parser or lexer for a published language spec, deciding how to validate parser correctness, discussing fuzz-testing parsers, or evaluating whether to build a grammar companion alongside a hand-written parser.
---

# DCG Grammar Companion

A planning pattern for parser projects where **correctness matters more than time-to-first-AST**. Pair the production parser (in whatever language ships — Rust, Go, C++, etc.) with a parallel implementation of the same grammar as a Prolog Definite Clause Grammar. The DCG serves three roles:

1. **Executable second reading of the spec** — forces re-reading the language reference in a different paradigm; ambiguities surface as DCG ambiguities you have to resolve.
2. **Generator of valid source** — `phrase(Grammar, Source, [])` runs in both directions; randomised search produces arbitrary valid programs to fuzz the production parser.
3. **Independent oracle** — every divergence between DCG and production parser (or between either of them and a published reference parser, if one exists) is a bug somewhere; investigate.

The pattern earns its keep on **any non-trivial grammar with a published spec** — not just textual languages:

- **Programming/query languages**: Power Query M, SQL dialects, custom DSLs with nested literals.
- **Binary network protocols**: iSCSI (RFC 7143), DNS, BGP, anything with PDU formats and state machines defined in an RFC. DCGs work on byte lists exactly like character lists — `phrase(pdu(P), Bytes, [])` is the same pattern.
- **File formats**: Parquet/Arrow encoding edges, custom binary serialisation formats, anything with versioned headers and length-prefixed sections.
- **Wire formats with state machines**: protocols where legal message sequences matter (login phases, capability negotiation, handshakes). The DCG encodes the *sequence grammar* over message types, not just individual messages.

It is overkill for tiny config languages or one-off parsers.

Particularly valuable for **binary protocols and fuzzing**: random byte mutation overwhelmingly produces inputs the target rejects at the first length check or checksum. A DCG generates *valid* PDUs the target will actually parse, exercising real code paths instead of the early-reject path.

## When to use

- The target language has a **published grammar** but no permissive open-source reference implementation in your target language.
- **Correctness matters durably** — the parser will be a load-bearing dependency, not a throwaway.
- The grammar has known ambiguities, **lexical edge cases** (multiple literal forms, escapes), or is **large enough** that hand-written tests demonstrably miss things.
- A **reference parser exists in another language** you can use as an additional oracle (TypeScript, Java, C#, etc.) — the DCG generates inputs both can ingest.

## When NOT to use

- Tiny grammars where exhaustive hand-written tests suffice.
- Throwaway parsers (one-shot scripts, prototypes you'll delete).
- Languages where a robust permissive-licensed parser already exists in your target language — vendor it, don't reimplement.
- When ship-date pressure outweighs correctness — the DCG is investment work; it pays back over months, not days.

## The three phases

### Phase 1: DCG as executable spec

Open the language spec and translate the lexical and syntactic grammar productions into a DCG, top-down. Each production becomes one DCG rule. The DCG should accept exactly what the spec defines as valid; ambiguities in the spec become non-determinism in the DCG that you must resolve and document.

This phase has independent value **before any fuzz testing happens** — the act of writing the DCG forces every grammatical question to be answered. Comments in the DCG file capture decisions ("spec §12.3 is ambiguous about trailing comma in record literals; chose to allow it; cross-reference: TS reference parser also allows it").

### Phase 2: DCG as generator

A DCG is reversible. Once `phrase(expression(E), Source, [])` parses, the same predicate generates: bind a randomly-chosen production at each choice point, generate terminals via `random_member/2` over symbol classes, and you produce arbitrary valid source.

Practical tactics:
- **Bound recursion depth** — wrap recursive nonterminals so generation halts (otherwise random expansion can recurse forever).
- **Weight productions** — bias toward common forms; rare forms still appear but don't dominate output.
- **Shrink on failure** — when a generated input causes divergence, automatically produce smaller failing inputs (QuickCheck-style shrinking on the parse tree).

### Phase 3: Differential harness

A small driver script:

1. Generates N random programs via the DCG.
2. Feeds each to the production parser and (optionally) any reference parser in another language.
3. Compares ASTs structurally (or token streams, at the lexer level).
4. Logs divergences with the offending input and both ASTs.

Run it in CI on every parser change. Run it ad-hoc with high N when investigating subtle bugs.

## Tooling

**Prolog implementation:**
- **SWI-Prolog** — batteries included, mature, easy install, `library(dcg/basics)` ships standard. Default choice for development tooling.
- **Scryer Prolog** — ISO-pure, targets WASM. Choose if you want to embed the DCG inside your shipping product (e.g. as a runtime grammar reference). Otherwise stick with SWI.
- **Tau Prolog** — JavaScript-native, useful if your tooling pipeline is already JS. Slower than SWI for batch generation.

**Differential harness:**
- Shell script + `jq`/`diff` for small projects.
- Property-based testing libraries (`proptest` in Rust, `Hypothesis` in Python, `quickcheck` in Haskell) integrate well as drivers — DCG generates the input, library handles iteration and shrinking.

**Suggested file layout:**

```
your-project/
├── (production parser code)
└── tools/
    └── grammar-fuzz/
        ├── lexical.pl       # DCG for lexical layer (tokens)
        ├── syntactic.pl     # DCG for syntactic layer (AST)
        ├── generate.pl      # Random generation driver
        └── differential.sh  # Run all parsers, diff outputs
```

Keep the DCG sidecar in a `tools/` subdirectory with its own dependency story — it is **not** a runtime dependency of the shipping product.

## DCG patterns worth knowing

**Lexical productions translate one-to-one:**

```prolog
% From spec: identifier := letter (letter | digit | '_')*
identifier([C|Cs]) --> letter(C), identifier_rest(Cs).
identifier_rest([C|Cs]) --> ( letter(C) ; digit(C) ; [0'_] ), identifier_rest(Cs).
identifier_rest([]) --> [].
```

**Syntactic productions with AST construction:**

```prolog
% expr -> term ('+' term)*
expr(E) --> term(T), expr_rest(T, E).
expr_rest(Acc, E) --> [+], term(T), expr_rest(plus(Acc, T), E).
expr_rest(E, E) --> [].
```

**Random generation with depth bound:**

```prolog
gen_expr(0, lit(N)) :- !, random_between(0, 100, N).
gen_expr(D, plus(L, R)) :-
    D > 0, D1 is D - 1,
    gen_expr(D1, L),
    gen_expr(D1, R).
```

**Round-trip property** — the strongest single check:

```prolog
roundtrip(Source) :-
    phrase(program(AST), Source, []),    % DCG parses
    phrase(program(AST), Source2, []),   % DCG generates from same AST
    Source = Source2.                     % Should match
```

If the production parser also has a pretty-printer, run the round trip across both: `production-parse(source) → ast → DCG-generate(ast) → production-parse(re-generated) → ast2`, then assert `ast = ast2`.

## Common pitfalls

- **Left recursion.** Standard DCGs cannot handle left recursion directly. Refactor to right-recursive form with an accumulator (the `expr_rest` pattern above), or use a Prolog with tabled DCGs (SWI supports this via `:- table`).
- **Whitespace handling.** Decide once whether the DCG operates over raw characters (whitespace explicit at every junction — verbose) or over a pre-tokenised stream (separate lexical and syntactic DCGs — recommended).
- **Generation runaway.** Without depth bounds, random expansion of recursive productions diverges. Always bound.
- **Spec ambiguity hidden by parser priorities.** Hand-written parsers resolve ambiguities by ordering; the DCG exposes them as choice points. When the DCG accepts a string the production parser rejects, the question is often "which one matches the spec?" — answer by reading the spec carefully and updating whichever is wrong.
- **Treating the DCG as the source of truth.** It isn't — the published spec is. The DCG is one reading of the spec; if it diverges from the spec, the DCG is wrong.

## Quick decision checklist

When considering this pattern for a new parser project:

1. Is the target language's grammar non-trivial (≥30 productions)? → Lean toward yes.
2. Is there a published spec you'd otherwise read once and forget? → Strongly yes.
3. Is there a reference parser in another language? → Strongly yes (free oracle).
4. Will the parser be load-bearing for ≥6 months? → Yes.
5. Is the team comfortable with a Prolog tool living in `tools/`? → Confirm; the cognitive cost is real.

If 4+ are yes, build the DCG companion. If only 1–2, skip it.

## Examples

### Example 1: Planning a new parser project

```
User: I need to write a parser for <some published language spec> in Rust.

Claude: Worth considering a Prolog DCG companion alongside the Rust parser:
- The DCG forces a second, independent reading of the spec — surfaces ambiguities early.
- Once written, it generates fuzz inputs for differential testing against the Rust parser.
- If a reference implementation exists in another language, the DCG-generated source feeds both for free oracle comparison.

[Walks through the decision checklist; if 4+ apply, proposes the tools/grammar-fuzz/ layout
and a phased build order: lexer first on both sides, lexer-level differential harness, then
parser, then parser-level differential.]
```

### Example 2: Validating an existing parser

```
User: I have a parser that mostly works but I keep finding edge cases. How do I get more confidence?

Claude: A DCG companion is well-suited to "mostly works, want to find the corners." Write the
grammar as a DCG, generate randomised valid source, run both through the production parser
and (if available) any reference parser; every divergence is a candidate bug.

[Explains the three phases, with focus on Phase 2 (generation) and Phase 3 (differential)
since the parser already exists. Notes the round-trip property as the strongest single check
if the production parser has a pretty-printer.]
```

### Example 3: Pushing back when the pattern doesn't fit

```
User: Should I write a DCG companion for this small config-file parser I'm building?

Claude: Probably not. The decision checklist:
- Grammar size is small (likely <30 productions).
- No published spec to re-read.
- No reference implementation in another language.
- Likely a one-shot or short-lived parser.

Skip the DCG. Hand-written tests covering the documented forms plus a few edge cases will
give equal confidence at a fraction of the effort. Save the DCG pattern for the next big one.
```
