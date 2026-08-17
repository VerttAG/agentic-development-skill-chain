---
name: cross-review
description: "Route a concept, PRD set, architecture, wave plans or curated docs to the provider opposite its author for an adversarial read-only review. Works before P0 without state.json. Not for code-bug testing (use 6-qa)."
license: MIT
compatibility: Requires both provider CLIs (claude and codex) to be installed and authenticated; a review is never satisfied by the artifact author.
---

# Cross-Review — Opposite-Provider Gate

Same-model review is an echo chamber. This skill asks the other provider to
try to break an artifact, with identical severity rules and JSON Lines output
for every mode. It never starts by itself: the producing skill asks the human
at handoff, defaulting to yes.

## Modes

| Mode | Artifact | Review focus |
|---|---|---|
| `concept` | `1_brainstorm/PROJ-<X>-concept.md` | product coherence, buildability, boundaries, grounding |
| `requirements` | `2_PRDs/*.md` (legacy `3_PRDs/`) | story completeness, AC strength, edge-case clarity, scope drift, internal consistency |
| `architecture` | `3-4_plan/PROJ-<X>-architecture.md` | decisions, feasibility, traceability, risk |
| `plan` | wave plans and gate config | executability, coverage, sequencing, scope |
| `docs` | curated documentation | factual truth, staleness, cap-gaming, durable-rule quality |

Supply source artifacts that establish truth through `--ground-truth`; the
script embeds both artifacts and ground truth with `cat -n` line numbers. A
`--diff-base` embeds that git diff. The reviewer has no need or permission to
run commands, making read-only behaviour independent of sandbox support.

## Run it

Before P0, state.json does not exist. Pass the author explicitly; findings are
written to stdout for the human, never to a ledger:

```bash
bash scripts/cross-review.sh concept <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md \
  --ground-truth specs/PROJ-<X>-<theme>/0_context/existing-state.md \
  --author-provider claude --author-model <writer-model> --round 1
```

Use `architecture` with the concept, every PRD in `2_PRDs/`, and the curated
`docs/ARCHITECTURE.md` and `docs/GUIDELINES.md` as ground truth; `plan` takes
the architecture and the same PRDs. Feasibility and traceability are only
checked against what is supplied, so a PRD left out is a requirement nobody
reviews. If a referenced input does not exist, omit it; do not invent a
replacement.

Use `requirements` for a PRD set, with the concept as ground truth — and add any
sibling PRD whose contract the set claims to honour, since a misread contract is
the most expensive defect this mode finds. It carries the criteria
`2-requirements-engineer` names for a second-model review, and explicitly forbids
the reviewer from demanding protocols, schemas, cadences or component design:
on the discovery/handoff track a requirement that states an observable property
and leaves the mechanism open is correct, not a gap.

**Do not substitute `architecture` for a PRD set.** It judges requirements on
feasibility and technical risk, which pushes implementation mechanism *into* the
PRDs and walks straight past story-versus-AC contradictions. Two rounds were lost
that way on PROJ-8 before the mode existed, and the resulting over-specification
had to be reverted.

After any multi-file fix pass, re-run the same mode over the edited files. The
recurring failure is structural rather than careless — one side of a statement
edited and the other left standing — and every fix pass on PROJ-8 introduced at
least one such contradiction, including a criterion made unfalsifiable while
fixing an unfalsifiable criterion.

After P0, omit `--author-provider` and use `--author-key` to resolve authorship
from state.json. That is the persistent gate path: findings are added only via
`ledger.mjs`, and the round is appended only via `state.sh`.

```bash
bash scripts/cross-review.sh docs <X> <theme> \
  --artifacts docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md \
  --author-key docs-delta \
  --diff-base "$(bash scripts/state.sh get <X> <theme> .base_sha)" --round 1
```

Exit codes: `0` clean or non-blocking only; `3` Critical/High findings;
`1` infrastructure failure; `64` invalid use. Critical/High findings block the
current handoff: fix and perform one re-review (`--round 2`); a remaining red
round goes to the human. Medium/Low findings are reported or deferred as debt.

## Routing and output integrity

- Claude-authored artifacts go to Codex; Codex-authored artifacts go to Claude.
  `--joint` runs both independently. If Codex is unavailable, a different
  Claude model may be used only when it is not the author model; that is marked
  as a degraded persistent review.
- Adapters reject zero findings, `review-blocked`, recognizable Bubblewrap or
  user-namespace failures, and any output that mixes `review-clean` with a
  finding.
- Findings are deduplicated by `category + file + line + summary` before they
  reach stdout or the ledger. `review-clean` is a liveness marker, never a
  finding.
- The default 128 KiB embedded-context limit fails explicitly if exceeded.
  Narrow the review inputs, or deliberately set
  `CROSS_REVIEW_MAX_CONTEXT_BYTES` for a reviewed larger prompt.
