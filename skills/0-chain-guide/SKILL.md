---
name: 0-chain-guide
description: "Detect where a project sits in the 0-to-8 chain and route to the next step. Use when the user asks what to do next, is unsure which skill applies, starts a new feature or project, or types /chain-guide."
license: MIT
---

# 0-to-8 Chain Guide

Detect where the user is in the 0-to-8 skill chain and tell them what to do next.

## The Chain

```
Step  Skill                  Output
----  ---------------------  ---------------------------------------------------------
 0a   product-vision         docs/PRODUCT.md + specs/product-roadmap.md      ┐ new
 0c   bootstrap              docs/ARCHITECTURE.md §Stack + scaffold + AGENTS.md ┘ build
 0b   intake                 the same curated docs/ baseline, extracted from code
  1   brainstorming          specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md
 1b   visual-companion (opt) specs/PROJ-<X>-<theme>/1b_visual-companion/layout-*.*
 1c   frontend-design (opt)  specs/PROJ-<X>-<theme>/1c_design/design-language.md          ┐ run
 1c   design-intake (opt)    the same 1c_design/ artifacts, extracted from a designer's   ┘ one
                             delivery + design-conformance.md + design-source.md
 1d   ui-mockup (UI req.)    specs/PROJ-<X>-<theme>/1d_mockups/sitemap.html + mockups + implementation-handoff.md + iteration-log.md
 1e   concept-sync (opt)     reconciled 1_brainstorm/PROJ-<X>-concept.md (Concept Sync Log + Handoff Readiness)
  2   requirements-engineer  specs/PROJ-<X>-<theme>/2_PRDs/PRD-<Y>-<desc>.md
 2a   legacy-prd-migration   the same v2 PRD artifact, transformed from an existing PRD
 2b   handoff-package (opt)  specs/PROJ-<X>-<theme>/2b_handoff/YYYY-MM-DD-handoff*/ standalone package (+ zip) — discovery track only
 2c   review-reconcile (opt) specs/PROJ-<X>-<theme>/2_PRDs/<prd>-review-decisions.md + review-changelog.md — resolve PRD review gaps
 2d   release-scope (opt)    specs/_releases/R<N>-<theme>/R<N>-scope.md + R<N>-gaps.md + R<N>-forward-compat.md — cross-PROJ, phased roadmaps only
 2e   release-package (opt)  releases/R<N>-v<X.Y.Z>/ standalone verified package (+ build-log.md in the slice folder) — needs a 2d slice
  3   architecture           specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md
  4   writing-plans          specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md (per wave)
 4a   checkpoint (CP1)       specs/PROJ-<X>-<theme>/decisions.md + state.json sealed CP1:approved
 4b   setup (P0)             proj/PROJ-<X> branch, preflight block in state.json, framework scripts in scripts/
  5   executing              implements code + tests + specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md
  6   qa                     writes 5_progress/<PRD-ID>-qa-results.md (+ ledger records in findings.json)
  7   documentation          creates/updates docs/PROJECT.md
  8   delivery (P8)          PR via gh with rendered body, CI green, CP2 comment reconcile
```

**Reading the numbers.** A bare number is a main-line step. A letter suffix
is a variant at the same stage — `1b`–`1e` run in sequence inside the UI
branch, `2a` is the existing-PRD alternative to authoring Step 2,
`2b`/`2c`/`2d`/`2e` are optional forks, `0a`/`0b`/`0c` are alternative entry
paths (0a+0c for a new build, 0b for an existing codebase), and `4a`/`4b`
are mandatory despite the letter. A skill with no number is not a step at
all: `cross-review` is a mechanism invoked inside P7, never routed to
directly, and `refactor-dreamer`/`sonar-cli` run outside the chain.

**Two skills share the number `1c`**, and that is deliberate: they are
alternative paths to the same artifacts, the way `0a` and `0b` are.
`frontend-design` **decides** a design system by proposing directions to the
user; `design-intake` **extracts** one an external designer already made and
verifies it against the contract it was commissioned under. **Run one, never
both** — two writers for one artifact means two design systems.

Each PROJ has its own folder `specs/PROJ-<X>-<theme>/`, and each subfolder
carries the number of the skill that writes it — `1c_design/` is written by
whichever `1c` skill ran, `2b_handoff/` by `2b-handoff-package`. Architecture
and plans share `3-4_plan/` because steps 3 and 4 both write there.
Progress is a single file in `5_progress/` tracking all waves. Framework runs additionally keep machine state in `state.json` (written only via `scripts/state.sh`) and the findings ledger in `findings.json` (written only via `scripts/ledger.mjs`).

**Once per product, before the first PROJ:** on a NEW build with no code
yet, `product-vision` (0a) establishes what the product is —
`docs/PRODUCT.md` (purpose, users, non-goals, success) plus the numbered
PROJ map in `specs/product-roadmap.md`, which is where PROJ numbers and
their `Depends on` ordering are allocated. Route to it when a new product
starts and `docs/PRODUCT.md` does not exist. On an EXISTING codebase the
counterpart is `intake` (0b) — same baseline, extracted instead of decided;
run one of the two, not both.

**Once per project, before the first PROJ:** on a new build, `bootstrap`
(0c) turns the vision into a running empty project — the stack decided into
`docs/ARCHITECTURE.md` § Stack (the single source of truth every skill reads
instead of assuming a framework), the real scaffold executed, `build` and
`test` verified green, root `AGENTS.md` plus the `CLAUDE.md` pointer written.
Route to it after `product-vision` when the workspace has no application
code. Skip it on the discovery track — there is no codebase there.

**Once per repo, before the first PROJ:** `intake` (0b) bootstraps the
curated context baseline — docs/PRODUCT.md, ARCHITECTURE.md, GUIDELINES.md,
DESIGN-SYSTEM.md, components.md, security-baseline.md, test-conventions.md,
root AGENTS.md — from a code scan (provenance-marked drafts) plus a
developer interview, reconciled via the checkpoint (4a) bootstrap variant
and sealed as a baseline commit (no state.json — that is born at CP1).
`cross-review` is the opposite-provider review mechanism; it is
invoked INSIDE P7 by the documentation skill (docs truth-check), never
routed to directly by users.

**Autonomous full-chain runs** go through the phase runner: after
`checkpoint` (4a) seals `CP1:approved`, `runner/run-phase.sh auto <X> <theme>`
drives P0 → P5 → P6 → P7 → P8 unattended with dual provider lanes and
ends with `specs/morning-report-<date>.md`. Skills 4b/5/6/7/8 are the
same skills the runner's lanes load — interactive use stays supported.

## Two Tracks

The same chain serves two delivery tracks. Detect which one applies before recommending a next step.

- **Full chain (in-repo build):** brainstorm → (UI prep) → requirements → architecture → plans → executing → QA → docs. Used when this repo will hold the implementation. A codebase exists or will exist here.
- **Product discovery (Linear handoff):** brainstorm → visual-companion → ui-mockup (iterate) → concept-sync → requirements-engineer → optional handoff-package, then stop. Used when the user only does product management — brainstorming, wireframes/mockups, stakeholder iteration — and hands a PRD to a developer via Linear and/or an external UI/UX expert. **No code is written here and there is no codebase.**

Detect the discovery track when any of these hold:

- The concept's `Handoff Readiness` sets `Delivery track: discovery (Linear handoff)`.
- A `1d_mockups/iteration-log.md` exists with stakeholder iterations but the repo has no application code (no `package.json`/`src/` app, only `specs/` and `docs/`).
- The user states they are doing discovery/PM only and will hand off to developers.

On the discovery track, do not recommend Steps 3–7. The chain ends at `requirements-engineer`, optionally followed by `handoff-package` (2b) when a standalone deliverable for external UI/UX experts or developers is needed. When a developer or stakeholder reviews the PRDs and returns gaps, recommend `review-reconcile` (2c) to resolve them point by point and update the artifacts before the next review cycle.

Discovery-track notes:

- **Folder structure is identical** to the full chain (`specs/PROJ-<X>-<theme>/`); `brainstorming` bootstraps it on first run. No manual scaffolding.
- **Git is optional.** If the workspace is not a git repo, skip commit recommendations; the files are the durable artifacts. Optionally suggest `git init` for iteration history.
- **Brownfield discovery** captures the existing product/design system/vocabulary into `0_context/existing-state.md` during brainstorming, since there is no codebase to scan.
- **Handoff packages are generated snapshots.** Existing `2b_handoff/YYYY-MM-DD-handoff*/` runs are immutable; only `handoff-package` (2b) may create or update files under `2b_handoff/`. If `review-reconcile` or another skill changes source artifacts, recommend a new `handoff-package` run instead of editing a prior package.

## Detect Current State

**Rule 0 (baseline):** `docs/PRODUCT.md` missing → the curated context
baseline is missing, and the next step depends on whether code exists:

- **Code exists** → **intake** (0b): extract the baseline from the codebase.
- **No code** (empty workspace, or specs only) → **product-vision** (0a),
  then **bootstrap** (0c) to decide the stack and stand up the project —
  unless this is the discovery track, where 0c is skipped.

Either way this comes before any further chain step — framework runs need
the baseline for the P0 context bundles. Run one baseline path, not both.

**Legacy layout rule:** PROJ folders created before the layout rename carry
the old subfolder names (`2_visual-companion/`, `4_design/`, `5_mockups/`,
`3_PRDs/`, `8_handoff/`, `6_plan/`, `7_progress/`). Detect them as their
current equivalents — an old `5_mockups/sitemap.html` means step 1d is done,
exactly like `1d_mockups/sitemap.html` would. Never report such a PROJ as
"step missing". Mention the old layout once and offer the rename as an
option, never as a precondition:

> "This PROJ uses the pre-rename folder layout. I can rename the folders to
> the current names (`git mv` per folder + fix the paths inside the PROJ's
> documents), or we continue with the existing layout — both work."

**Roadmap rule:** if `specs/product-roadmap.md` exists, read it before
recommending anything. It carries the PROJ numbers, the `Depends on`
ordering, and each entry's `Status`. A PROJ whose dependency is not
`shipped` waits — recommend the dependency instead. `planned` entries with
no `specs/PROJ-<X>-<theme>/` folder yet are the natural candidates for
**brainstorming** (1).

Scan `specs/PROJ-*/` folders to find the latest PROJ. For each PROJ, check:

1. `1_brainstorm/PROJ-<X>-concept.md` — concept written? → step 1 done
2. `1b_visual-companion/layout-decision.md` + `layout-exploration.html` — visual companion present? → step 1b done
3. Project-mode detection: prefer `1b_visual-companion/layout-decision.md` → `Project Mode`. Fallback: scan for existing app shell/components/tokens. If no reusable app shell, component set, design tokens, or real screens exist → greenfield. If existing screens/components/tokens/navigation meaningfully constrain the feature → brownfield. If some structure exists but important design/component gaps remain → hybrid.
4. `1c_design/design-language.md` exists → step 1c done. Read `1c_design/design-source.md` to tell **which** 1c path ran: present → `design-intake` (an external designer's delivery, conformance-checked and version-stamped); absent → `frontend-design`. This decides 1d's fidelity mode, so establish it before recommending 1d. Never recommend the other 1c skill for a PROJ that already ran one.
5. `1d_mockups/*.html` + `1d_mockups/implementation-handoff.md` — mockups and UI handoff present? → step 1d done
   - Design-derived PROJs have no screen mockups by design — the sitemap plus `implementation-handoff.md` satisfy this step. Absent HTML here is not an unfinished 1d.
   - `1d_mockups/iteration-log.md` with any entry marked `Affects concept: yes` **and** the concept has no `Concept Sync Log` entry covering that iteration → concept drifted, recommend `concept-sync` (1e) before requirements.
   - **Design-derived drift is invisible in the log when nobody recorded it.** If `1c_design/design-source.md` exists and its accepted version stamp is newer than the version named in the concept's last `Concept Sync Log` entry, recommend `concept-sync` (1e) **regardless of whether the iteration log has entries** — and say the log looks unmaintained. An empty log beside a moved design reads as "no drift" to every other rule here, which is the one case where silence is the finding.
   - Concept contains `Concept Sync Log` / `Handoff Readiness` → step 1e done.
6. `2_PRDs/PRD-*.md` (or legacy `PROJ-<X>-PRD-*.md`) — at least one PRD? → step 2 done. If an existing PRD lacks the schema header and canonical six H2s and the user wants the current format, recommend `legacy-prd-migration` (2a) before architecture. If `Handoff Readiness` is `discovery (Linear handoff)`, this PROJ is on the discovery track and is **complete at step 2** — do not recommend architecture. Optionally suggest `handoff-package` (2b) for an external standalone deliverable.
   - `2b_handoff/*/README.md` exists → step 2b done; the latest dated handoff package is assembled.
6b. **Cross-PROJ release check.** If a phase-tagged feature inventory exists (for example `specs/_drafts/*inventory*.md`, `specs/_platform-baseline/*inventory*.md`, or a `*triage*.md` with a phase or wave column), its current phase spans more than one PROJ, and `specs/_releases/` has no folder for that phase → recommend `release-scope` (2d) before architecture. `specs/_releases/R<N>-*/R<N>-scope.md` exists → step 2d done. Skip this check when only one PROJ is involved; its PRD manifest already covers that case.

6c. **Release package check.** Only where a slice from 6b exists. `releases/R<N>-v*/` has no package → step 2e not run; recommend `release-package` (2e) when the slice is meant to be distributed, frozen, or verified. A package exists → compare its build commit (recorded in `releases/R<N>-v*/release-manifest.md` and in `specs/_releases/R<N>-*/build-log.md`) against the newest commit touching any in-slice `specs/PROJ-*/2_PRDs/` (or legacy `3_PRDs/`) folder. **PRDs newer than the newest package → the package is stale; recommend a rebuild.** Same freshness shape as check 10 for docs, and it is the one that catches a release index quietly going wrong: a document describing a PROJ that moved underneath it reads as correct to every other rule here.
7. `3-4_plan/PROJ-<X>-architecture.md` exists → step 3 done
8. `3-4_plan/PROJ-<X>-wave-*-plan.md` files exist → step 4 done (count waves by file glob)
8b. `state.json` exists → framework run; read `.phase` + `.status` via `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'`: `CP1:approved` → step 4a done; `P0:done` → step 4b done; `P5:*`–`P8:*` → that phase is running/done; `*:blocked` → run parked, point to `5_progress/stop-report.md`
9. `5_progress/PROJ-<X>-progress.md` exists → step 5 running or done. Read the file:
   - Has every wave marked complete? → step 5 done
   - Has "QA Results" section at top level? → step 6 done
10. Check `docs/PROJECT.md` for the current PROJ **and** that the latest `docs(PROJ-<X>): Update project documentation` commit is newer than the latest `feat(PROJ-<X>-PRD-<Y>)`/`test(PROJ-<X>)` commit → step 7 done. Skill 7 may additionally update `README.md`, `docs/TECHNICAL.md`, approved `AGENTS.md` entries, and pointer-only `CLAUDE.md`, but only `docs/PROJECT.md` is guaranteed to exist.
11. For back-compat, also check flat old-style paths (`specs/PROJ-*-spec.md`, `specs/PROJ-*-plan.md`, `specs/concepts/`) — treat as legacy, still recognise but recommend the new structure for new work.

## Respond to the User

Based on detected state, tell the user:

**No PROJ folder found:**
> "No feature work detected. Start with the **brainstorming** skill (`/1-brainstorming`) to explore your idea — it will allocate PROJ-X and set up the folder."

**Concept written, no visual companion output, no PRDs (UI feature):**
> "Concept for `PROJ-<X>-<theme>` found. This feature has a UI component. Recommended next step: use **visual-companion** (1b) to explore interactive layout approaches before design, mockups, and PRDs."

**Concept written, no PRDs (backend/API feature):**
> "Concept for `PROJ-<X>-<theme>` found. Next step: use **requirements-engineer** to write PRDs with user stories and acceptance criteria."

**Visual Companion exists, no design-language, no mockups, no PRDs (greenfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Greenfield project detected. Next step: use **frontend-design** (1c), then **ui-mockup** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no design-language, no mockups, no PRDs (hybrid with design gaps):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Hybrid project detected with design/component gaps. Next step: use **frontend-design** (1c) lightly for the gaps, then **ui-mockup** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no mockups, no PRDs (brownfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Existing UI/design detected. Next step: use **ui-mockup** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, an external designer is commissioned, no design-language:**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. An external design deliverable is commissioned for this PROJ, so 1c runs as **design-intake** rather than frontend-design. Before it can run, the UI brief needs a design-system contract — without one the extraction has nothing to verify against and produces artifacts nobody can defend. Confirm the brief carries it, then run **design-intake** (1c), **ui-mockup** (1d) in design-derived mode, then **requirements-engineer** (2)."

**Design language exists, no mockups, no PRDs:**
> "Design language is ready at `specs/PROJ-<X>-<theme>/1c_design/design-language.md`. Next step: use **ui-mockup** (1d); it consumes the Visual Companion decision and design language."

**Design language exists via design-intake (`1c_design/design-source.md` present), no mockups:**
> "The external design system for `PROJ-<X>-<theme>` is extracted and version-stamped (`1c_design/design-source.md`, conformance in `design-conformance.md`). Next step: **ui-mockup** (1d) in **design-derived** mode — it produces the sitemap and implementation handoff only, and authors no screen mockups, because the designer's file is the visual authority."

**Mockups exist, iterated, concept not yet synced:**
> "Mockups for `PROJ-<X>-<theme>` were iterated (`1d_mockups/iteration-log.md`) and the concept hasn't been reconciled yet. Next step: use **concept-sync** (1e) to flow the agreed mockup changes back into the concept before requirements."

**Mockups exist, concept in sync (or no concept-affecting iterations), no PRDs:**
> "Mockups and UI implementation handoff are ready at `specs/PROJ-<X>-<theme>/1d_mockups/`. Next step: use **requirements-engineer** (2); the mockups and handoff are required input for user stories, acceptance criteria, component reuse, and UI implementation notes. For a discovery/Linear handoff, requirements-engineer runs in Linear handoff mode and the chain ends there."

**Discovery track, PRDs exist, no package:**
> "`PROJ-<X>-<theme>` is a product-discovery PROJ. The PRDs are ready to hand to a developer in Linear. For a single standalone deliverable to share with an external UI/UX expert or dev team, optionally run **handoff-package** (2b). Otherwise the chain is complete — Steps 3–7 don't apply."

**Discovery track, handoff package assembled:**
> "The standalone handoff package for `PROJ-<X>-<theme>` is ready in the latest dated run folder under `specs/PROJ-<X>-<theme>/2b_handoff/`. Zip that run folder and share it with the UI/UX expert and/or developers. This chain is complete — Steps 3–7 don't apply."

**PRDs exist, no architecture:**
> "PRDs in `specs/PROJ-<X>-<theme>/2_PRDs/`. Next step: use **architecture** (3) to write the PROJ-level tech design."

**PRDs exist across several PROJs, phased roadmap, no release slice:**
> "A phase-tagged inventory covers `PROJ-<A>…<N>`, and Phase <N> spans several of them, but `specs/_releases/` has no slice for it. Next step: use **release-scope** (2d) before architecture to map the phase to its user stories, exclusions, gaps, and forward-compatibility obligations."

**Release slice exists, no architecture:**
> "The release slice is at `specs/_releases/R<N>-<theme>/`. Read `R<N>-gaps.md` first and close blocking PRD gaps, then run **architecture** (3) once across the release slice."

**Release slice exists, no package:**
> "The release slice is at `specs/_releases/R<N>-<theme>/` but nothing has been built from it. Next step: use **release-package** (2e) to freeze it into `releases/R<N>-v<X.Y.Z>/` and verify it — the slice index asserts things about PRDs in other folders, and 2e is what proves those assertions still hold."

**Package exists but the PRDs have moved since:**
> "`releases/R<N>-v<X.Y.Z>/` was built from `<sha>`, and `specs/PROJ-<A>/2_PRDs/` has changed since. The package is stale. Next step: re-run **release-package** (2e) — staleness, not inaccuracy, is how a release artifact goes wrong."

**Architecture file exists, no wave plans:**
> "Architecture at `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`. Next step: use **writing-plans** (4) to create per-wave implementation plans."

**Wave plans exist, no state.json (CP1 not yet run):**
> "Wave plans ready in `specs/PROJ-<X>-<theme>/3-4_plan/`. Next step: use **checkpoint** (4a) — Checkpoint 1 reviews architecture + plans point by point, writes the decision log, and seals `CP1:approved` in state.json. For a manual run without the framework, **executing** (5) can still be used directly."

**state.json says CP1:approved, no P0:**
> "Checkpoint 1 is approved for `PROJ-<X>-<theme>`. Next step: use **setup** (4b) — it creates the PROJ branch, runs the tool/auth preflight, and copies the framework scripts. After that, either `runner/run-phase.sh auto <X> <theme>` runs P5–P8 unattended, or continue interactively with **executing** (5)."

**state.json says P0:done, no implementation:**
> "P0 setup is complete. Next step: **executing** (5) — interactively in this session, or unattended via `runner/run-phase.sh auto <X> <theme>` (dual-lane, ends with the morning report)."

**state.json says blocked:**
> "The run for `PROJ-<X>-<theme>` is parked (stop condition). Read `5_progress/stop-report.md` — it lists what happened, the rescue branch, and the cleanup list. After fixing the cause: `bash scripts/state.sh transition <X> <theme> <phase> running`, then re-run the phase."

**Progress.md exists, waves partially complete:**
> "Implementation in progress for `PROJ-<X>-<theme>`. Wave <N> is the next one. Continue with **executing** (5)."

**All waves complete, no QA results:**
> "All waves implemented. Next step: use **qa** (6) for end-to-end testing against the PRDs' acceptance criteria."

**QA passed, no docs:**
> "QA passed for `PROJ-<X>-<theme>`. Next step: use **documentation** (7) — conditionally updates `README.md`, `docs/PROJECT.md`, `docs/TECHNICAL.md`, asks for approval on any `AGENTS.md` candidates collected during QA, and keeps `CLAUDE.md` pointer-only."

**Documentation complete, no PR (framework run):**
> "Docs are committed for `PROJ-<X>-<theme>`. Next step: use **delivery** (8) — conflict probe against main, PR with a rendered body from state.json + findings.json, CI polling, then Checkpoint 2 (human PR review)."

**PR open (state.json P8:done):**
> "The PR for `PROJ-<X>-<theme>` is open and waiting on Checkpoint 2 — review and merge it. When review comments come back, **delivery** (8) reconciles them point by point (fix now / debt / reject with rationale)."

**Documentation complete (interactive run, no framework):**
> "Feature `PROJ-<X>-<theme>` is fully implemented, tested, and documented. Ready for release."

**QA found bugs:**
> "QA found bugs in `PROJ-<X>-<theme>`. Fix the Critical/High bugs, then re-run **qa**."

## Multiple PROJs

If multiple PROJ folders exist in different states, list them with their current step:

```
PROJ-1-auth:        Step 5 (executing) — wave 2 of 3 in progress
PROJ-2-dashboard:   Step 3 (architecture) — ready for tech design
PROJ-3-settings:    Step 6 (qa) — bugs found, needs fixes
```

Recommend working on the most advanced PROJ first (finish what's started).

## Quick Reference

If the user asks "what does each step do?":

| Step | Skill | What it does |
|------|-------|-------------|
| 0a | product-vision (once per product) | New build: `docs/PRODUCT.md` (what/who/non-goals) + numbered PROJ map in `specs/product-roadmap.md` |
| 0c | bootstrap (once per project) | New build: stack into `docs/ARCHITECTURE.md` § Stack, real scaffold, build/test green, root `AGENTS.md` + `CLAUDE.md` |
| 0b | intake (once per repo) | Bootstrap the curated docs baseline: scan + provenance-marked drafts, developer interview, checkpoint reconcile, seal commit |
| 1 | brainstorming | Explore the idea, allocate PROJ-X and thema slug, write concept |
| 1b | visual-companion (optional) | Interactive layout exploration plus project mode: greenfield/brownfield/hybrid |
| 1c | frontend-design (optional) | Visual design language — greenfield, or hybrid gaps only. **Decides** the system |
| 1c | design-intake (optional) | **Extracts** an external designer's delivery into the same artifacts, gated by a conformance pass. Alternative to frontend-design — run one, not both |
| 1d | ui-mockup (UI required) | HTML sitemap + per-screen mockups + `implementation-handoff.md` + `iteration-log.md`; greyscale-wireframe or design-system fidelity |
| 1e | concept-sync (optional) | Reconcile iterated mockup changes back into the concept; set delivery track (full chain vs. Linear handoff) |
| 2 | requirements-engineer | PRDs from concept + approved mockups + UI handoff: user stories, acceptance criteria, edge cases; Linear handoff mode produces developer-ready PRDs |
| 2b | handoff-package (optional) | Standalone, zippable package for external UI/UX experts and developers: README index, single-source-of-truth scope/decisions, role-split handoffs, copied mockups |
| 2d | release-scope (optional) | Cross-PROJ release slice from a phased inventory: feature→US index, exclusions, gaps, and forward-compatibility seams |
| 2e | release-package (optional) | Freeze a 2d slice into a standalone, verified, commit-pinned package under `releases/`; findings go back to the source PROJ, never into the package |
| 3 | architecture | PROJ-level tech design covering all PRDs — data model, cross-cutting decisions |
| 4 | writing-plans | Wave-based implementation plans; propagates UI handoff into frontend/full-stack tasks |
| 4a | checkpoint | Human checkpoints as structured reconcile loops: CP1 (arch + plans → decision log → seal state.json) and CP2 (PR comments, via delivery) |
| 4b | setup | P0 once per PROJ: branch + BASE_SHA, tool/auth preflight, framework scripts into the repo, state.json extended |
| 5 | executing | Implement wave by wave with TDD, using UI handoff constraints where relevant |
| 6 | qa | End-to-end test all PRDs, security audit, separate per-PRD QA evidence; read-only finder in framework runs (P6 controller fixes) |
| 7 | documentation | Conditionally update README.md, docs/PROJECT.md, docs/TECHNICAL.md; merge approved AGENTS.md candidates (≤40 lines) |
| 8 | delivery | Conflict probe, PR with rendered body, CI fix loop (max 3), Checkpoint 2 comment reconcile |

## Reference Skills

These skills are not process steps — they are **reference expertise** consulted during execution:

### Cross-Cutting (all projects)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| `systematic-debugging` | 5, 6 | Root cause investigation, 4-phase debugging, 3-fix rule |
| `verification-before-completion` | 5, 6 | Gate function: run → read → verify → then claim |

### Tech Stack (project-specific)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| `tailwind-css` | 2b, 3, 5 | Responsive utilities, dark mode, component patterns |
| `nextjs-app-router-patterns` | 3, 4, 5 | Server vs. Client Components, routing, data fetching, caching |

When to recommend them:
- **Step 1d (ui-mockup):** If the project uses Tailwind, mention that `tailwind-css` provides class patterns for mockups.
- **Step 3 (architecture):** If the stack includes Next.js → reference `nextjs-app-router-patterns` for RSC/routing decisions. If styling is Tailwind → `tailwind-css` for design token and dark mode decisions.
- **Step 5 (executing):** Subagents automatically receive these skills when their US touches UI (Tailwind) or Next.js App Router.
