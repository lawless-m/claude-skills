---
name: Finding Unknowns
description: Use when starting ambiguous, unfamiliar, or high-stakes work — or when the user says "blind spot pass", "interview me", "what am I missing", "give me N directions", or asks for an implementation plan. Techniques for surfacing gaps before, during, and after implementation, from Anthropic's Fable field guide.
---

# Finding Unknowns

Work quality with Fable-class models is bottlenecked by how well the unknowns get articulated, not by prompt precision. Map the gaps instead of tuning specificity: over-specified instructions force suboptimal paths; under-specified ones silently fall back to industry defaults that may not fit. When a request is over-constrained, push back; when it's vague, surface the unknowns rather than guessing.

Four kinds of gap to probe for:

- **Known knowns** — what's already in the request.
- **Known unknowns** — gaps the user knows they have ("I don't know the auth module").
- **Unknown knowns** — obvious-to-them details they wouldn't think to write down (conventions, constraints, taste).
- **Unknown unknowns** — territory neither party has considered, and standards the user doesn't know exist.

## Named moves

Offer or run these when they fit; the user may invoke them by name.

**Blind spot pass** (before starting): the user names an area they don't know; enumerate what they likely haven't considered — risks, existing patterns, standards, integration points. Deliverable is the list, not a fix.

**Interview**: ask clarifying questions **one at a time**, about genuine ambiguities only. Stop when the remaining unknowns wouldn't change the design.

**Brainstorm / prototypes**: when direction is undecided, produce several *wildly different* directions (the user may say "4 directions") or cheap throwaway prototypes before committing to one. Don't converge early.

**References over descriptions**: prefer being pointed at working code over screenshots or prose descriptions — and say so when the user is about to describe something that exists as code. Code carries structure that descriptions lose.

**Implementation plan**: foreground the decisions that are sticky or likely to be revisited — data models, interfaces, UX flows — over mechanical steps. The plan is for finding disagreements early, not for listing work.

**Implementation notes** (during): keep a running note of deviations from the plan and surprises hit along the way; unexpected edge cases are findings, not noise. Surface them at the end rather than silently absorbing them.

**Pitch / explainer** (after): package the change for stakeholders who have the same unknowns the user started with.

**Quiz** (after): offer to quiz the user on what changed and why — verifies *their* understanding survived the delegation.

## Positioning context

Treat the exchange as thought partnership: it helps to know the user's experience level with the domain and where they are in their thinking (exploring vs committed). If that positioning is missing and it matters, ask for it — advice for a first-timer exploring differs from advice for an expert executing.
