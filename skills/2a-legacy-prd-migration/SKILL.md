---
name: 2a-legacy-prd-migration
description: "Migrate narrative or user-story PRDs into the six-section UC/AC schema with a full-fidelity, mechanically verified diff. Use for legacy PRDs; not for creating requirements or changing product scope."
license: MIT
---

# Legacy PRD Migration

Transform existing PRDs into the canonical chain format without changing
their product meaning. This is an alternative Step 2 entry for a PROJ that
already has requirements; it does not follow `requirements-engineer`.

Read `../2-requirements-engineer/references/prd-format.md` completely before
analysing a source.

## Contract

- One source PRD maps to one target PRD. Do not import wording or scope from
  sibling PRDs.
- Preserve source text unchanged wherever the target grammar permits it.
- Ask before every forced text change and every item with two defensible UC
  owners. Do not begin writing while mapping questions remain open.
- Never silently drop content. A product-owner-directed drop is named in the
  fidelity ledger and subtracted from the expected count.
- Write the complete target in one pass, then run every verification gate.
- When the requester names a set, each file is an independent migration unit,
  but the run is complete only after every file and the aggregate gate pass.

## 1. Classify the source

- **Type A — narrative:** story prose is incomplete or irregular; Given,
  When, Then, stable AC IDs, vocabulary, or success signals may be absent.
- **Type B — structured:** stories already use actor/intent/benefit, have
  Given/When/Then and labelled ACs, but carry legacy sections, task markers,
  global AC numbering, or surplus `And` clauses.

Type B uses the same fidelity process. It carries existing Given/When/Then
verbatim; Type A derives only missing mandatory fields from that UC's source
criteria.

## 2. Analyse before editing

Report, in source order:

1. every top-level section, its content types, and item counts;
2. every story and its AC count, plus total paragraphs and list items;
3. existing story, GWT, AC-ID, glossary, and success-signal structure;
4. forbidden target constructs such as task markers, nested lists, tables,
   HTML, or headings inside criteria;
5. every file, decision, project, story, and cross-PRD reference;
6. every source section with no direct target section and its combined count.

For Type B, also produce an `And`-coverage table, list duplicate source AC
IDs, resolve each ambiguous inline AC reference by its local story, and check
whether every referenced file exists.

Create a mapping ledger with one row per source element. Each row records its
source location, target section/UC, and treatment: `verbatim`, `derived`,
`approved edit`, or `approved drop`.

## 3. Resolve mapping questions

Ask only questions the source and these standing rules cannot answer:

- Goal/objective prose opens `Outcome and success signals`; derive observable
  signals from measurable goal and in-scope clauses.
- Scope lists map verbatim to `In scope` and `Out of scope`.
- Vocabulary comes verbatim from the source, an approved canonical vocabulary,
  or a product-owner supplement. Never invent a missing definition.
- Source stories retain their order. Fix a heading only as much as the grammar
  requires; preserve all other words. If no benefit exists, append one derived
  from that UC's own criteria.
- Source criteria come first inside their UC. Then place cross-cutting product
  rules, then edge cases, each under exactly one owning UC and in source order.
- Status, handoff, process, outward dependency, and later-phase guardrail text
  becomes Assumptions. It never goes in `Depends on`.
- Decided items become Assumptions; genuinely unresolved product items become
  questions. A question assigned to another discipline is an Assumption unless
  this PRD is waiting for its answer.
- Inline external rules and decisions so the target is self-contained. Strip
  unresolvable labels, dates, and review markers after their substance is
  present. Remap internal story/section pointers to target UC/AC IDs.
- A genuine unresolved cross-PRD dependency becomes a same-PRD question and
  blocks the affected UC until the target AC can replace it.
- Flatten nested criterion sub-bullets into separate ACs in source order.

Type B additions:

- Carry Given/When/Then; whitespace-normalise hard wraps only.
- Strip task-list markers and replace source AC IDs with per-UC target IDs.
- Drop a surplus `And` only when a source AC already covers it; otherwise
  promote it to a source-group AC. Record either result.
- Treat binding technical requirements as ACs on the owning UC. Only
  later-phase implementation guardrails belong in Assumptions.

## 4. Write deterministically

Derive the PRD, UC, AC, and Q IDs from the target filename as defined in the
format reference. UC order follows source story order. Within a UC, number:

1. source story criteria;
2. assigned cross-cutting rules;
3. assigned edge cases.

Use the actual product domain, not the `2_PRDs` or legacy `3_PRDs` folder
name. Keep the source file recoverable through git or a separate source path;
do not delete it during migration.

## 5. Run the fidelity and grammar gates

Automate these checks; a visual read is not sufficient.

### Fidelity

- Whitespace-normalise and match every source list item and paragraph to the
  target. For each non-exact match, inspect the word-level diff and tie it to
  an approved edit, reference removal/remap, or approved drop.
- Reconcile counts explicitly:
  `target ACs = source ACs + promoted And clauses + rules + technical
  requirements + edge cases - approved drops`.
- Target UC count equals source story count unless an approved split is in the
  ledger. Every story sentence survives modulo approved heading fixes.
- Every source element appears exactly once in the mapping ledger.

### Structure and references

- Run the complete gate in the format reference.
- Grep for residual file paths, decision labels, source story/AC IDs, project
  IDs, dates, review rounds, and cross-PRD IDs. Only an explicit unresolved
  dependency question may remain.
- Diff Assumptions against vocabulary definitions; high-overlap duplicates are
  defects.
- For a requested set, run the reference-resolution gate across the whole set
  after every individual PRD passes.

## 6. Report

Report in this order:

1. concrete verification counts and pass/fail results;
2. where every legacy section landed;
3. content derived rather than carried;
4. every approved edit or drop;
5. residual dependency placeholders or accepted format deviations.

Do not report completion after a partial set or a failed gate.
