---
description: Carry the rocks — do the open rock issues of the current milestone, one after another, until done or something stops you
argument-hint: [max rocks — omit to carry the lot]
---

# rocks

Work the open **rock** issues of the earliest open milestone until none remain or something stops
you. `$ARGUMENTS`, if a number, caps how many rocks to carry — an override for when the user wants
one, never a default and never something to ask them for. Otherwise carry the lot.

Finish a rock, pick the next, carry on in the same turn.

**Progress lives on the tracker, not in the conversation.** A finished rock is a closed issue. If
context is summarised mid-drain, re-read the open rocks from the API and continue with nothing
lost — which is also what lets a fresh `claude -p` take over mid-queue.

Read the `Gitea` skill for auth (`$GITEA_TOKEN` is the `claude` account; no `Sudo`).

## The queue is the tracker, and the label is the state

    open issue, labelled `rock`      outstanding
    closed                            done

A rock's body is authoritative: what to do, its `**Verify:**` command, its done-when. Its
dependencies (`GET /repos/<repo>/issues/<index>/dependencies`) are what `blocked-by` was.

## Flow

1. **Read the queue.** Repo from `git remote get-url origin`. Earliest open milestone; its issues
   `state=open` labelled `rock`, lowest number first. None → `rocks: nothing to carry — run /crush`
   and stop.
2. **Pick** the lowest-numbered open rock whose every dependency is **closed**. If none:
   - no open rocks → `rocks: milestone <title> cleared — <n> carried`; report the gate's result and
     stop. **Do not close the milestone** — that is the user's, and it is what advances the phase.
   - rocks remain but all blocked → `rocks: stalled — #<n> blocked by #<ids>` and stop.
   - a rock whose **last comment begins `halted:`** is skipped, not retried (see below).
3. **Read only that issue.** Announce: `rocks: starting #<n> — <title>`.
4. **Do the work.** Don't expand scope or refactor adjacent code — every changed line should trace
   to the body. Run its `**Verify:**` command and any others the body names, and confirm they pass.
5. **Close or halt** — never close on a failed verification; partial completion is not completion:
   - Verified → commit on the current branch, staging files explicitly, message referencing the
     issue (`#<n>`). Comment the sha and what was done, then **close the issue**. Push only if the
     user has said to.
   - Failed or blocked by something real → comment, first line exactly `halted: <reason>`, and
     **leave the issue open**. Go to 2 for the next unblocked rock.
6. Repeat until a stop condition in step 2, or the cap is reached:
   `rocks: <n> carried, <m> halted, <k> blocked`

## A halt skips, it does not stop the run

A halt is not a failure of the run and not a rock to retry. The reason goes in a comment, the issue
stays open, and the next unblocked rock starts. Anything genuinely downstream has a dependency on
it and becomes unrunnable by itself; everything else is independent, and one stumble shouldn't cost
the rest. The person who crushed a stone and left is precisely the person a full stop fails.

Do not unblock a halted rock by editing its body, relaxing its verification, or inventing a
workaround its author didn't sanction. Halt, comment, carry on. At the end, list every halted rock
with its reason together, so the first thing read on return is what needs a decision.

## Keep going until something objective stops you

The stop conditions are exactly those in step 2, plus a cap the user asked for. Nothing else. Do
**not** stop because the run feels long, because a lot has been done, because the next rock looks
big, or because the context window is filling. Compaction is automatic and the queue is on the
tracker precisely so it survives one: after a summary, re-read the open rocks and continue. If you
think a run should end for a reason not listed, say so and ask — don't decide it silently and
describe it afterwards as though it were a rule.

Announce each rock as it starts, so a long run is followable as it happens.

Never close a rock to keep a run going, and never report a partial drain as a full one.
