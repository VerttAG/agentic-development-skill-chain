---
name: 2e-release-package
description: "Build a standalone, immutable, verified specs release package from a release slice spanning many PROJs. Copies concepts, PRDs and manifests into one folder, pins source commits, then verifies integrity and self-containment."
license: MIT
---

# Release Package — Freeze A Slice, Prove It Stands Alone

`release-scope` (2d) produces an *index*: three markdown files that point at PROJ folders. That
index is a claim about other files, and claims drift. Observed failure modes, all from real slices:
a release index described a PROJ as having no PRDs for five days while sixteen sat in its folder; a
readiness audit corrected four of its own statements on a third pass; a PRD manifest cited a PRD that
never existed and nobody noticed until a human read it by chance; an invariant was hardened into a
forward-compat register in the *opposite* sense to the PRD it came from, and surfaced only because a
reviewer looking at a different project happened to read it.

None of those is carelessness. They are what happens when a document asserts something about files
that move independently of it.

This skill removes the indirection. It **derives** a package from the sources at a known commit,
proves mechanically that the package holds together, and routes every defect it finds back to the
source folder that owns it. A package cannot drift, because it is regenerated rather than maintained.

## Core Principles

- **Derived, never authored.** Everything in the package is a copy of a source file or a report
  computed from those copies. There is no hand-maintained slice declaration: the in-slice PROJ set
  comes from the scope index's own `§1` and `§3`. A second declaration could disagree with the first,
  which is the disease this skill exists to cure.
- **Immutable.** A built package is never edited, patched, or overwritten. A change means a new
  version. `build-package.sh` refuses to write into an existing directory.
- **Gaps are fixed at the source.** Verification never repairs the package. It emits findings keyed
  by *source path*, and the fix lands in `specs/PROJ-<X>-<theme>/…`. The next build picks it up for
  free. Editing the package would make it disagree with the repository it claims to describe.
- **Verify out of the main context.** The checks read across the whole payload — routinely more than
  a hundred files. Delegate them so the main session sees the verdict, not the corpus.
- **Report gaps plainly.** Finding that a release has an unwritten requirement *is* the deliverable.
  Never soften it into "mostly covered".

## Host adaptation

Every gate and artifact here is host-neutral; only the verification pass differs:

- **Delegation available:** run both verification layers in a subagent (Claude Code: the `Agent` tool; Codex: `spawn_agent`, where the session policy allows). It returns the verdict; the evidence stays on disk.
- **No delegation:** run the checks inline, but read only the check outputs and the written reports into context — never the package payload itself. The size of the payload is the reason this step is delegated, not a preference.

## Input

1. A release slice folder — `specs/_releases/R<N>-<theme>/` — containing at minimum `R<N>-scope.md`.
   Produced by `release-scope` (2d). Also frozen into the package when present:
   `release-<N>-definition.md`, `R<N>-forward-compat.md`, `R<N>-gaps.md`, `R<N>-review-*.md`.
2. The PROJ folders the scope index points at.
3. A version string, decided with the user (see Phase 5).

## Output

```
releases/R<N>-v<MAJOR>.<MINOR>.<PATCH>[-rcN]/
  README.md                 entry point, reading order, conflict order   (generated)
  release-manifest.md       resolved slice, artifact map, per-file SHAs  (generated)
  VERIFICATION.md           Layer A + Layer B results                    (generated)
  KNOWN-GAPS.md             open gaps → source path, owner, what blocks  (generated)
  00-what-changed.md        delta against the previous package           (generated)
  01-definition.md          frozen release charter                       (copied)
  02-scope.md               frozen scope index — AUTHORITY on membership (copied)
  03-forward-compat.md      frozen forward-compat register               (copied)
  04-gaps-at-release.md     frozen ranked gap register                   (copied)
  05-review-notes.md        frozen change narrative                      (copied)
  projects/<PROJ-dir>/      concept, PRD manifest, PRDs/, linear-import,
                            open-decisions register, mockups/             (copied)
```

`releases/` sits at the repository root, outside `specs/`. Source specs and generated packages are
different kinds of thing and the separation should be visible from the top level.

Source basenames are preserved throughout `projects/`. The specifications cite each other by
filename constantly, so renaming would break every one of those references — and the resolvability
check would be right to fail it.

**The open-decisions register** (`<PROJ>-open-decisions.md`, beside the PRDs) is copied as its own
artifact type and is **excluded from the PRD sweep**, so it never inflates the PRD count. A project
that keeps its live open decisions only inside a handoff run will not have them packaged — move the
register into the project folder; a handoff is a snapshot and this package is derived.

**Not copied:** `*-review-*decisions.md`, `review-changelog.md`, `*-analysis-*.md`, `*-agenda.md`.
They are the audit trail of how the specs reached their current state, they are large, and they carry
superseded positions that read as current out of context. The manifest records the exclusion so it
reads as deliberate rather than lossy.

## Phase 0 · Preflight

Stop and report if any of these fail — do not work around them.

- The release folder exists and holds an `R<N>-scope.md`.
- The scope index carries the section headings the resolver needs: `# §1 ·` and `# §3 ·`. If 2d's
  output shape ever changes, this is where it surfaces.
- The working tree is clean, or the user has confirmed that uncommitted work should be packaged. A
  package pins commit SHAs; packaging uncommitted edits produces a snapshot nobody can reproduce.
- `releases/` has no directory for the version about to be built.

## Phase 1 · Resolve the slice, and confirm it

Run `build-package.sh` far enough to see the resolved set, or resolve it by reading `§1` and `§3`
yourself. Present to the user:

- the in-slice PROJs, with a one-line reason each (delivers in-scope features / dependency closure)
- the PROJs deliberately left out, and that they will be treated as *known* rather than dangling when
  the specs reference them

**If the set is wrong, the fix goes into `R<N>-scope.md`.** Never carry a correction in the build.
The scope index states its own freeze rule — it is the source of truth for what is in the release —
and the moment a build can override it there are two authorities again.

## Phase 2 · Assemble

```bash
bash scripts/build-package.sh specs/_releases/R<N>-<theme> v<VERSION>
```

Writes the package, pins a per-file commit SHA for every artifact, and rewrites internal links to
package-relative form. Links that genuinely leave the package — a concept's `reference/` sub-tree,
anything under `../` — are demoted to plain text naming the source repo, so a reader is told where
the target lives instead of following a link that cannot resolve.

Exit 2 means the package was written with warnings; read them before continuing.

## Phase 3 · Verify — in a subagent

Dispatch a subagent with the package path. Its instructions:

1. Run both checkers, writing their machine output into the package:
   ```bash
   bash scripts/chain-check.sh specs/_releases/R<N>-<theme> --json <pkg>/gap-report-A.json
   bash scripts/selfcontain-check.sh <pkg> --md <pkg>/VERIFICATION.md --json <pkg>/gap-report-B.json
   ```
   Both exit 2 when they have findings. That is the expected outcome, not an error.
2. Adjudicate the three checks that need a read rather than a match — **B1** completeness against the
   inventory rollup, **B4** whether an in-scope-and-excluded story is a legitimate PARTIAL split, and
   **B5** whether a gap row really says what exists instead.
3. Merge both layers into `VERIFICATION.md` and a single `gap-report.json`.
4. Return **no more than 40 lines**: per-check pass/fail, the blocking-gap count, and anything that
   needs a human decision.

The subagent returns a verdict; the evidence stays on disk. Do not read the payload into the main
session to "check its work" — that defeats the point of dispatching it.

### Layer A — chain integrity, per in-slice PROJ

Replays `chain-guide`'s discovery-track probes. **Do not check architecture, wave plans, or
`state.json`**: on the discovery track a PROJ is complete at step 2, and flagging their absence
buries the real findings under noise.

| | Check |
|---|---|
| A1 | concept file exists |
| A2 | concept `## Status` reads as approved — test *approved* before *draft*, since an approved concept may still say "requirements may be drafted" |
| A3 | at least one PRD, in either folder layout |
| A4 | PRD manifest exists |
| A5 | no superseded PRD directory inside the live PRD folder — a failure if the manifest does not name it, a warning if it does. Naming it makes it documented, not absent: a glob over the PRD folder still reads a contradictory model |
| A6 | every PRD carries a user-story heading — accept both `US-1` and `P1-US1`, because both conventions occur. Requiring one reports a fully specified set as empty |
| A7 | handoff freshness — PRDs committed after the newest handoff run |

### Layer B — release self-containment

B1–B5 are `release-scope`'s own five checks applied to the packaged copy. B6–B8 are additions
targeting failures that have actually occurred in live slices.

| | Check |
|---|---|
| B1 | **Completeness** — every feature ID accounted for exactly once |
| B2 | **Resolvability** — every cited PRD file exists inside the package |
| B3 | **Round-trip** — every quoted user-story heading appears verbatim in a packaged PRD. An *abbreviated* quote (`US-1: …I join one shared zone queue…`) cannot round-trip by construction; report it, because the verbatim heading is the redundant join key that makes a renumbering detectable and an ellipsis throws it away |
| B4 | **Leakage** — nothing both in-scope and excluded, unless the in-scope row is marked PARTIAL with its specific ACs named |
| B5 | **Gap honesty** — every GAP row names what exists instead |
| B6 | **Dangling references** — every `PROJ-<X>-PRD-<N>` resolves to a packaged PRD or a known out-of-slice PROJ |
| B7 | **Link locality** — no markdown link resolves outside the package |
| B8 | **Contract closure** — every binding cross-PROJ contract names a PROJ that is packaged or knowingly out of slice |
| B9 | **Pin freshness** — no packaged artifact's source has moved since the build. Fails when it has: the verification is void and the answer is a **new version**, never a re-verify. Skips cleanly when the package is read outside its repository, which is the normal standalone case |
| B10 | **Stale claims** — no packaged artifact says a feature is unwritten while the slice index resolves that feature to a packaged PRD |

A B6 failure is not always a defect: a *proposed* PRD cited in a gap entry ("a thin new
`PROJ-7-PRD-0`") correctly does not resolve. Classify it in Phase 4 rather than filing it as a broken
reference. The checker matches PRD-ID tokens without reading mood.

`VERIFICATION.md` and `KNOWN-GAPS.md` are excluded from the B2 and B6 scans. Naming artifacts that do
*not* exist is precisely their purpose, and scanning them re-reports every Layer A finding as a
broken citation.

## Phase 4 · Triage the gaps, then write them back

Go through the merged findings with the user, deciding each: **blocking** (the release cannot ship),
**significant** (needs a decision before architecture), **noted** (recorded, not urgent), or **not a
defect** (a proposal, a deliberate exclusion).

Then, in this order:

1. **`KNOWN-GAPS.md` into the package** — the frozen as-of record. Every entry names the source path,
   the owner, and what it blocks. Rank by what unblocks the most downstream work, not by size.
2. **`R<N>-gaps.md` in the release folder** — append a dated `## Machine findings` section. The human
   gap IDs, the ranking and the blocking tiers stay human-owned; the machine contributes raw findings
   only. Never renumber someone's gap register from a script.
3. **Route each fix to its source.** New specifications go to `requirements-engineer` (2); amendments
   to live PRDs go to `review-reconcile` (2c). Nothing under `releases/` is ever hand-edited.

**Findings from version N are fixed in source and land in version N+1. Version N is never
re-verified.** This is what makes the loop terminate instead of regressing, and it is why an `-rc`
carrying an honest gap list is more useful than no artifact: a package ships with its findings
recorded, and the next build proves them closed. Fixing source and rebuilding the *same* version
destroys that version's `VERIFICATION.md` and `KNOWN-GAPS.md` and voids the verification you just
ran — which has happened.

`B9` enforces this rather than leaving it to memory: it compares every pinned SHA against its current
source and fails when source has moved, so a stale package cannot quietly pass twice. **If B9 fires,
the answer is always a new version.**

> ⚠️ **This phase edits a source file** — step 2 appends to `R<N>-gaps.md`. A package's pins are
> therefore stale the moment Phase 4 runs, by design. That is why Phase 6 commits the package and the
> re-based register together, and why B9 firing on an older package reads as *"this package is now
> history"* rather than *"the build is broken"*.

A Layer A failure can sit *in front of* a known release gap and nobody will have recorded the
dependency. A PROJ whose concept is still a draft cannot receive the PRD that closes the release's
blocking gap, because `requirements-engineer` will not run against a draft concept. Say so explicitly
when it happens.

If a package carries blocking gaps, its version keeps the `-rc` suffix. It is still built and still
committed — a release candidate with an honest gap list is more useful than no artifact at all.

### What the checkers do not see

Say this when reporting, because silence here reads as coverage.

- **Files at the root of `specs/_releases/`.** `chain-check.sh` takes the slice folder and
  `selfcontain-check.sh` takes the built package; neither walks the root. A release-level record
  cited by several PROJ manifests can sit there going stale for days across a re-base that touches
  everything around it. Either fold such a file into the slice folder, or give it a dated superseded
  header the moment it stops being current.
- **Everything outside `1_brainstorm/` and the PRD folder.** `0_context/`, `2_visual-companion/`,
  `4_design/`, `5_mockups/` and `8_handoff/` are never opened. This matters most when a project keeps
  a **live open-decision register only under `8_handoff/`**: a handoff is a dated snapshot, a
  register is live state, and the package will then show a reader the PRDs with no sign that an
  architectural prerequisite is unresolved. **Move the register into the project folder** rather than
  teaching the packager to read handoffs — copying a snapshot would freeze it.
- **Truth.** Both layers check structure and self-consistency. `B10` mechanizes the one slice of
  truth the index already knows — a claim that a feature is unwritten, contradicted by the index
  resolving it — but a PRD can still be internally perfect and wrong about the product.

## Phase 5 · Version

Two things are settled:

- Packages are named `R<N>-v<MAJOR>.<MINOR>.<PATCH>[-rcN]` and are immutable.
- A package with open blocking gaps carries `-rcN`.

**The bump rules are deliberately not fixed by this skill.** SemVer's contract is about consumer
breakage, and who the consumer of a spec release is decides the answer: if it is the implementing
developer, MAJOR means "work you already started is now wrong" — an amended acceptance criterion. If
it is the release planner, MAJOR means the slice membership changed. Those invert each other. Propose
a version, state which reading you are using, and confirm with the user rather than inferring one.

**This skill creates no git tags and publishes no releases.** Tag and release strategy depends on the
same undecided question, and ships no script for it.

## Phase 6 · Commit and log

Append a row to `specs/_releases/R<N>-<theme>/build-log.md`: date, package, commit, trigger,
blocking-gap count, notes. Create the file if it does not exist. This is what makes a build visible to
someone reading the release folder later, and the place a CI-triggered build records itself.

Do not generate an index file inside `releases/`. The directory listing and the build log already
carry that information, and a third copy is a third thing that can drift.

Commit subject:

```
docs(release): Build <RELEASE> specs package <VERSION>
```

Then report: the package path, its counts, the verification verdict, and the ranked gap list with
owners. Offer the standalone spot-check — zip the package, unpack it somewhere outside the
repository, open its `README.md`, and confirm an outside reader could act on it without the repo.
Re-running `selfcontain-check.sh` against the unpacked copy proves link locality with no repository
present, which is the only way to prove it rather than assert it.

## Legacy Folder Layout

PROJ folders created before the layout rename carry the old subfolder names. Mapping, old → current:
`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` · `5_mockups/` →
`1d_mockups/` · `3_PRDs/` → `2_PRDs/` · `8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`.

Like `release-scope`, this skill reads across **many** PROJs at once, so expect the two layouts to be
mixed within a single release — one PROJ on `2_PRDs/`, its neighbour still on `3_PRDs/`. The shipped
scripts probe both, current name first. **Never report a PROJ as having no PRDs because only its
legacy folder exists**; that failure mode turns a fully specified project into a wall of gaps, which
is the most expensive wrong answer this skill can produce.

## Scripts

Shipped in `scripts/`. Written for **bash 3.2** — the macOS default has no `mapfile` and no
associative arrays, and a script that assumes bash 4 fails outright on a Mac.

| Script | Does | Exit |
|---|---|---|
| `build-package.sh <release-dir> <version>` | Resolves the slice, copies the payload, rewrites links, writes `release-manifest.md` with per-file SHAs. Refuses to overwrite an existing package | 0 / 2 warn / 64 usage |
| `chain-check.sh <release-dir>` | Layer A. `--json` writes a findings report | 0 / 2 findings / 64 usage |
| `selfcontain-check.sh <package-dir>` | Layer B. `--md` writes `VERIFICATION.md`, `--json` a findings report | 0 / 2 findings / 64 usage |

## Completion Checklist

- [ ] Slice resolved from `R<N>-scope.md` and confirmed with the user — no hand-authored slice file
- [ ] Package built, immutable, with per-file commit SHAs in `release-manifest.md`
- [ ] Both verification layers run **in a subagent**, reports written into the package
- [ ] B1, B4 and B5 adjudicated by reading, not by matching
- [ ] Every finding carries a source path under `specs/`, and nothing under `releases/` was hand-edited
- [ ] `KNOWN-GAPS.md` written and ranked by downstream unblocking
- [ ] `R<N>-gaps.md` has a dated `## Machine findings` section; no human gap ID renumbered
- [ ] `build-log.md` row appended
- [ ] Standalone spot-check offered: zip, unpack outside the repo, re-run `selfcontain-check.sh`

## Handoff

- **Gaps found** → `requirements-engineer` (2) for new specs, `review-reconcile` (2c) for amendments.
  Give them the feature IDs, what exists instead, and the exclusions that keep new PRDs thin.
- **Package clean** → `architecture` (3), run **once at release level** against the slice rather than
  once per PROJ. A release that spans a dozen projects is one integrated path, and a dozen per-PROJ
  architecture documents will not hold it together.
- **Re-run** after any `review-reconcile` round on a participating PROJ. Staleness, not inaccuracy,
  is the failure mode of a release artifact.
