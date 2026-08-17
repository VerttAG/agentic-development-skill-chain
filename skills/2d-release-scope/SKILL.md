---
name: 2d-release-scope
description: "Classify a phase-tagged feature inventory into an executable release slice spanning many PROJs: resolve each in-phase feature to the PRD stories delivering it, list later-phase stories to exclude, and find features with no PRD."
license: MIT
---

# Release Scope — Turn A Phased Roadmap Into An Executable Slice

The 0-to-7 chain is **per-PROJ**: concept → PRDs → architecture → plans, all inside `specs/PROJ-<X>-<theme>/`. A **release** is the other axis — a horizontal slice across many PROJs, defined by a phase column in a feature inventory rather than by a project boundary.

Nothing else in the chain models that axis. So when a roadmap says "Phase 1 is the pilot," there is typically no artifact anywhere that links a feature ID to a user story — the inventory phases *features*, the PRDs specify *user stories*, and the join between them lives only in someone's head. "Build only Phase N" is then not an executable instruction, and no architecture or planning pass can act on it.

This skill builds that join, and three things fall out of it that are worth more than the index itself: the features with **no PRD behind them**, the later-phase stories hiding **inside otherwise in-scope PRDs**, and the **forward-compatibility seams** that decide whether deferring Phase N+1 is safe or expensive.

## When To Use

- A feature inventory assigns phases/waves, and one phase spans several PROJs.
- The user asks to "focus only on Phase N", "what's in the MVP/pilot", or "what blocks the release".
- PRDs exist across the participating PROJs, and architecture is the next step.
- A previously built release slice needs re-checking after PRD revisions.

## When To Skip

- Only one PROJ is involved — its `PRD-manifest.md` phase column already does this job.
- No phase-tagged inventory exists. The phase assignment is a product decision; this skill consumes it, it does not invent it.
- PRDs don't exist yet across the participating PROJs — run `requirements-engineer` (2) first. With no PRDs there is nothing to index and the output would be an all-GAP list.
- The task is resolving review feedback on PRDs — that's `review-reconcile` (2c).

## Core Principle

**Index, don't migrate.** The output is a new artifact that points at existing PRDs. Do not move stories between PROJs, do not restructure PRD sets, and do not edit PRDs to add phase tags in this run. The mapping must be reviewed before it becomes an enforcement mechanism, and an index is cheap to correct while a mass re-tagging is not.

**The exclusions matter as much as the inclusions.** An in-scope PRD drags its later-phase stories into planning unless they are named. In practice a single user story often mixes phases — half of it is in the release, half is not — and those splits are the highest-value output of the whole run.

**A gap is not a failure of the index.** Finding that 40% of a release has no PRD behind it *is* the deliverable. Report it plainly and rank it; never soften it into "mostly covered".

## Input

1. The phase-tagged inventory (e.g. `specs/_drafts/*inventory*.md`, `*triage*.md`, or a roadmap doc). The phase column is the authority for **what** is in the release.
2. Every participating `specs/PROJ-*/2_PRDs/` set (legacy layout: `3_PRDs/`). The PRDs are the authority for **how**.
3. Each PROJ's `PRD-manifest.md` where one exists — these often already carry per-PRD phase markers and cross-PROJ contracts.
4. Concepts (`1_brainstorm/PROJ-<X>-concept.md`) for any PROJ with no PRDs — needed to report what exists *instead* of a PRD.

## Workflow

### 1. Parse The Inventory And Fix Its Own Drift First

Extract for each feature: **ID**, **phase**, and any owning-PROJ hint (these inventories usually carry one in an internal column).

Before going further, check the inventory against itself. Phased inventories commonly carry both a per-row phase column **and** a rollup section grouped by phase — two representations of the same fact, maintained by hand. Diff them and report any row whose phase disagrees with its rollup. Resolve with the user before indexing; everything downstream inherits the error.

Take the rollup's ID list as the completeness target: the finished index must account for every one of them, exactly once.

### 2. Detect The Local Phase Vocabulary — And Flag Collisions Loudly

**Do this before resolving a single feature.** A PROJ may use the word "phase" for something that is not the roadmap phase — most often its own **delivery** phases (`P0-US*`, `P1-US*`, `P2-US*`), which slice that project's build order and do not align with the roadmap at all.

When this happens, a file named like `4_delivery-phase-1-product-prd.md` reads exactly like "the Phase-1 PRD" and is not one: roadmap Phase 1 may reach back into delivery-phase 0 *and* exclude parts of delivery-phase 1.

Detection: for each PROJ, look at US ID prefixes, PRD filenames, and manifest columns. Any use of "phase" that is not the roadmap phase gets a prominent warning **at the top of the output index**, with concrete proof — two or three specific stories whose delivery phase and roadmap phase disagree. Silent conflation here corrupts the whole slice, and it is not self-evident to the next reader.

Also record the phase-marker vocabulary actually in use across the manifests (`P1→`, `P1/P2/P5`, `P1 seed → P2 full`, `NOT MVP`, `out of MVP`, prose-only, none). It is usually inconsistent. Record it; do not normalize it in this run.

### 3. Resolve Each In-Phase Feature To User Stories

For each feature ID in the target phase:

1. Search the owning PROJ's PRDs for the ID itself.
2. If absent — which is common, since PRDs rarely cite inventory IDs — search the feature's **vocabulary terms**. Domain nouns are the strongest keys available, especially in non-English or German-mixed product vocabularies where a term like `Abholpunkt` or `Selbstzahler` appears nowhere else.
3. Read the candidate stories and confirm they actually deliver the feature rather than merely mentioning it.
4. Classify: **SPEC'D** (a phase-scoped story exists) · **PARTIAL** (a story exists but carries later-phase content, or only one side of the feature is specified) · **GAP** (no story anywhere) · **POLICY** (decided, requires no build).

**Quote the US heading verbatim.** US IDs are not stable under review rounds; the heading text is what lets a reader confirm the row survived a renumbering.

Watch for features split across PROJs — one owning the data, another the surface. Both halves get listed, and the row is PARTIAL if only one is specified.

### 4. Build The Exclusion List

For every PRD that contributes to the release, identify the stories in it that are **not** in the release, and say which phase they belong to and why.

Three shapes, in ascending order of how easily they are missed:

- **Whole file out** — cheap to state, easy to spot.
- **Whole story out** — a later-phase story sitting inside an otherwise in-scope PRD.
- **Part of a story out** — a single US whose acceptance criteria span phases. These are invisible without reading the ACs, they are the ones that leak, and they are the reason this pass cannot be done from manifests alone. Name the specific ACs and flag that the story needs splitting.

### 5. Find The Dependency Closure

List the PRDs that no feature ID points at but which the release cannot ship without — typically foundations (auth, record models, retention, failure handling, price finality) that the inventory never assigned a feature ID because they are not user-visible features.

Manifests often state these directly ("live in the pilot: …"). Without this section the index looks complete while omitting the substrate.

### 6. Harvest The Forward-Compatibility Obligations

This is what makes deferring later phases *safe*, and therefore what lets them stay at roadmap altitude.

For every later-phase feature, ask exactly one question: **does deferring this force a rework of a decision in this release?**

- **No** → one inventory line. No concept work, no PRD, no architecture.
- **Yes** → record the seam and the obligation it puts on the current release.

Well-written PRDs already contain these, scattered across projects, in recognisable idioms. Grep the in-scope PRDs for: `extensible`, `not hardcoded`, `no hardcode`, `additive`, `real .* code path`, `not a bypass`, `without re-architecture`, `config(uration)? change`, `not a redesign`, `so that a later phase`, `stays defined`, `identical`, `first entry`, `owed by`, `release-gating`, `definition of done`.

Per row record: the obligation, the source file and line, **why** it exists, and what the release **must** do. Then index them.

Two kinds deserve separate attention because they are the ones skipped in practice:

- **Unreachable code paths.** A branch specified and tested now but unreachable until a later phase exists (typically a fail-closed default). It looks like dead code and gets dropped; the failure mode after it is dropped is silent.
- **Data captured for a later consumer.** A classification or count that is free to compute now, has no reader yet, and is impossible to reconstruct later.

State the rule explicitly in the output: **anything in a later phase not on this list needs no further specification before the release ships.** That sentence is the deliverable's actual purpose.

### 7. Interview On The Residue

Every GAP, every contradiction, and every unresolved cross-phase dependency becomes a question for the product owner: **build it, cut it from the release, or accept it as a tracked dependency?**

Follow `review-reconcile`'s discipline — one point at a time, explained plainly, with a recommendation and visible trade-offs, recorded before moving on. Items needing engineering input are deferred to a developer meeting, not force-decided.

Two residue classes are not gaps and must not be filed as such:

- **Contradictions** — two PRDs specifying incompatible behaviour. Both cannot be built; this needs a decision, not a PRD.
- **Cut-surface dependencies** — the release consumes something whose owning surface it deliberately excluded (a record whose management UI is deferred; a routing target not yet built). The question is "what is the minimal substitute", and the answer usually enlarges another gap's scope.

Rank the residue by what unblocks the most downstream work, not by size. A one-line access request that gates three items across two projects outranks a large but self-contained PRD.

### 8. Write The Artifacts

```
specs/_releases/R<N>-<theme>/
  R<N>-scope.md          — the index: inclusions, exclusions, dependency closure
  R<N>-gaps.md           — gaps, contradictions, unresolved dependencies, ranked
  R<N>-forward-compat.md — the deferral seams
  decisions.md           — the residue decision log (created in step 7)
```

`R<N>-scope.md` carries, in this order: the purpose and freeze rule · **the phase-vocabulary warning from step 2** · a coverage summary with real counts · the inclusion tables grouped as the inventory groups them · the exclusions · the dependency closure · the observed marker vocabulary · how to keep the file true.

State the freeze rule plainly: **this file is the source of truth for what is in the release; the inventory remains the roadmap view.** When they disagree, reconcile deliberately.

### 9. Verify Before Reporting

The index is a claim about other files. Check it:

- **Completeness** — every ID from the rollup appears exactly once. Diff programmatically; do not eyeball it.
- **Resolvability** — every cited PRD path exists on disk.
- **Round-trip** — every quoted US heading appears verbatim in the file it is attributed to.
- **Leakage** — no story is listed as in-scope and also as excluded, *except* the deliberate splits from step 4, which must be marked PARTIAL with their specific ACs named.
- **Gap honesty** — every GAP row names what exists *instead* (concept file + section), so it is actionable rather than merely an absence.

Report the verification results with the deliverable, including anything that did not fully pass.

## Re-Running On A Later Release Or After PRD Revisions

Idempotent and diff-oriented. On re-run, report what changed since the last one — a PRD revision that moved or renumbered a story, a new feature ID, a gap that closed, an exclusion that became an inclusion — and append a dated line to the release changelog. Staleness, not inaccuracy, is the failure mode of any hand-built index; **US IDs are the join key and they are not stable under review rounds**, so a re-run after any `review-reconcile` round on a participating PROJ is the norm, not an exception.

## Handoff

- **Gaps to fill:** route back to `requirements-engineer` (2) with a phase-scoped brief — the feature IDs, what exists instead, and the exclusions that keep the new PRDs thin. Do not write those PRDs here.
- **Slice to distribute or freeze:** run `release-package` (2e). It derives a standalone, immutable, commit-pinned package from this index — every in-slice concept, PRD and manifest copied into one folder a reader can consume without the repo — and verifies it in two layers: per-PROJ chain integrity, and the five checks in step 9 above applied mechanically to the packaged copy. It also finds what an index cannot: a reference to a PRD that does not exist, a cross-PROJ contract naming a PROJ nobody packaged, and quoted US headings that no longer match their PRD. 2e never edits a PRD or this index; it reports findings against their source paths so the next build picks the fixes up.
- **Ready for architecture:** on a cross-PROJ release, run `architecture` (3) **once at release level** against the slice rather than once per PROJ. A release-phase loop that spans ten projects is one integrated path, and ten per-PROJ architecture docs will not hold it together. Per-PROJ architecture remains correct for single-PROJ work.
- **Phase tagging inside PRDs** (per-US markers, manifest phase columns) is a separate, explicit decision after the mapping is trusted. Never bundle it into the first run.

## Completion Checklist

- [ ] Inventory parsed; internal drift between rows and rollup resolved with the user
- [ ] Phase-vocabulary collisions detected and warned about at the top of the index, with concrete proof
- [ ] Every in-phase feature ID resolved to US IDs or classified GAP, with headings quoted verbatim
- [ ] Exclusions listed, including part-of-a-story splits with their specific ACs named
- [ ] Dependency closure identified (PRDs no feature ID points at)
- [ ] Forward-compat obligations harvested, sourced with file + line, and indexed
- [ ] The "anything not on this list needs no further spec" rule stated explicitly
- [ ] Residue walked point by point; contradictions and cut-surface dependencies filed separately from gaps
- [ ] Residue ranked by what unblocks the most downstream work
- [ ] All five verification checks run, and their results reported — including failures
- [ ] No PRD edited in this run
- [ ] Freeze rule stated in the index

## Git Commit Format

```text
docs(release): Add R<N> <theme> release scope index, gaps, and forward-compat register
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the release folder is the durable artifact.

## Legacy Folder Layout

PROJ folders created before the layout rename carry the old subfolder names.
Mapping, old → current: `2_visual-companion/` → `1b_visual-companion/` ·
`4_design/` → `1c_design/` · `5_mockups/` → `1d_mockups/` · `3_PRDs/` →
`2_PRDs/` · `8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`.

This skill reads across **many** PROJs at once, so expect the two layouts to be
mixed within a single release — one PROJ on `2_PRDs/`, its neighbour still on
`3_PRDs/`. Resolve each PROJ independently and **never report a PROJ as having
no PRDs because only its legacy folder exists**; that failure mode turns a fully
specified project into a wall of GAP rows, which is the most expensive wrong
answer this skill can produce.

Read from whichever folder exists and cite the path you actually read. Renaming
is never a precondition for this skill, and this run never performs one — it
indexes, it does not migrate.
