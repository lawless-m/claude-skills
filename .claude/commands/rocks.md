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
   and stop. Then run `claude mcp list` once and print it, so the run log shows which MCPs were
   Connected when the carrying started.
2. **Pick** the lowest-numbered open rock whose every dependency is **closed**. If none:
   - no open rocks → the stone is crushed. Every rock is closed, so none halted and the gate rock
     passed. Confirm that the gate (the highest-numbered rock) is closed with a passing comment.
     Then:
     1. **Close adopted issues.** For each open non-rock issue in the milestone, find a comment
        from `claude` whose first line begins `adopted:`. If there is one, comment with the gate's
        number and result, set the `fixed` label (replacing the workflow label, e.g. `triage`), and
        close it. If any non-rock issue has **no** `adopted:` comment, leave it open and stop:
        `rocks: milestone <title> held open — #<n> was never adopted by /crush`. Someone raised it
        separately, so it needs a person's decision. Re-read the milestone from the API and
        confirm `open_issues` is 0 before going on.
     2. **Close the milestone**: `PATCH /repos/<repo>/milestones/<id>` with `{"state": "closed"}`.
        Print `rocks: milestone <title> cleared and closed — <n> carried`, with the gate's result.
     3. **Crush the next stone**: invoke the `crush` skill, which picks the next earliest open
        milestone. Report what it created, then stop. Starting the next milestone's rocks is a fresh
        `/rocks`, so each phase begins from a clean read of its own queue.
     4. If no open milestones remain, `/crush` says so. Print `rocks: all stones crushed — project
        plan complete` and stop.

     If anything is still open (a halted rock, or the gate not closed), the milestone stays open
     and `/crush` does not run. That is the stalled or halted case below, never a clear.
   - rocks remain but all blocked → `rocks: stalled — #<n> blocked by #<ids>` and stop.
   - a rock whose **last comment begins `halted:`** is skipped, not retried (see below).
3. **Read only that issue.** Announce: `rocks: starting #<n> — <title>`.
   **Check the tools it names before touching anything.** If the body depends on a house service
   or an MCP — Piggy, Squirrel, any MCP server — confirm it works *now*: Piggy's `/health` must say
   `browserAlive: true` (the server can be up with its browser dead); an MCP must be Connected and
   answer one cheap call. If it doesn't, comment `halted: <service> unavailable — <what you saw;
   how to bring it back>` and go to 2. A broken tool is a halt, not a verify failure to debug and
   not a reason to build around it.
4. **Do the work.** Don't expand scope or refactor adjacent code — every changed line should trace
   to the body. If the work needs something a house tool or MCP already does, use the tool; if that
   tool is unavailable, halt — never substitute a home-made equivalent (a self-spawned browser for
   Piggy, a raw parquet read for Squirrel). Run its `**Verify:**` command and any others the body
   names, and confirm they pass.
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

Never close a rock to keep a run going, and never report a partial drain as a full one. Above all,
never close a milestone that still has an open rock: closing it is what lets the next phase start.
