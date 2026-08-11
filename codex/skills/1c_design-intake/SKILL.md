---
name: design-intake
description: "Turn a delivered external design system into the chain's design artifacts by extraction and verification — never by authoring. Use when: (1) an external UI/UX expert has delivered a design file and screens against an agreed design-system contract, (2) a design system exists but only in a design tool and the chain has no tokens, catalog or showcase for it, (3) a new design version arrives and the extracted artifacts must be re-reconciled. Not for: deciding a visual direction (use frontend-design), authoring mockups (use ui-mockup), extracting a baseline from code (use intake)."
---

# Design Intake — External Design System Into The Chain

The counterpart to `1c_frontend-design`. That skill **decides** a design system by
proposing directions to the user; this one **extracts** one a designer already
made, and verifies it against the contract it was commissioned under.

Same stage, same folder, same output artifacts, one writer each. **Run one of
the two, never both** — the rule the chain already applies to
`0a_product-vision` and `0b_intake`, for the same reason: two writers for one
artifact means two design systems.

| Artifact | Answers | Written by |
|---|---|---|
| `1c_design/design-conformance.md` | Is the delivery machine-readable at all? | this skill — the gate |
| `1c_design/design-source.md` | Which file, which version, which node? | this skill — the traceability anchor |
| `1c_design/design-language.md` | Why does it look like this? | this skill, from the designer's decisions |
| `docs/DESIGN-SYSTEM.md` | What are the rules? (≤80 lines) | this skill, curated by P7 |
| `docs/components.md` | What exists? | **generated** from code; never hand-edited |
| showcase | Is it really true? | this skill (pre-scaffold), extended in P5 |

## The rule behind every step

**The design file is not the authority — the contract is.** A design tool holds
geometry and names; the agents that implement from it receive names, numbers and
structure, never the picture. A file that looks finished and violates the
contract produces a design system that is *confidently wrong*: tokens that
resolve to raw hex, states that were sketched and never drawn as variants,
components whose props cannot be derived. Extraction from such a file is worse
than no extraction, because the output looks authoritative.

So this skill verifies before it extracts, and **refuses to compensate**. Where
the delivery falls short it reports and stops — it never fills the gap with its
own judgement. Filling the gap is exactly how the designer's authority quietly
becomes the agent's.

## When to Use

- An external UI/UX expert delivered a component library plus screens against a
  design-system contract stated in the PROJ's UI brief
- A design system exists in a design tool and the chain has no tokens, catalog
  or showcase derived from it
- A new design version arrived and the extracted artifacts must be reconciled

## When to Skip

- No external designer — the agent proposes the system → `1c_frontend-design`
- A design system already exists **in code** → `0b_intake` extracts it
- The design brief carries **no design-system contract** → stop and amend the
  brief first. Output written against an uncontracted file cannot be defended,
  and re-extraction after the contract lands is a full re-run, not a patch.

## Input

Read these in order. The first two are the authority; the design file is the
subject being judged, not the judge.

1. **The contract** — the UI brief the designer was commissioned under. On the
   discovery track this is the brief carried by the `2b_handoff-package` run;
   on a seeded brownfield PROJ it is the brief under `0_context/references/`.
   Its design-system-contract section is the checklist this skill runs. Read it
   in full; do not reconstruct it from this file.
2. **The prior design language** — `1c_design/design-language.md`, where the
   chain produced one before commissioning the designer. Its **semantic token
   names are the binding vocabulary** and its values are not. That split is what
   makes a visual redesign non-breaking for engineering.
3. **The delivery** — the component library file, the screen file, and the
   designer's own notes on open questions.
4. **Interpretation layer** — the PROJ's UI handoff: screen families, red lines,
   what the designer was free to move.
5. **Concept and PRDs**, for what the screens are supposed to do.

If the brief and the design language disagree about what is binding, **the brief
wins and the disagreement is a finding** — record it in the conformance report
rather than choosing silently.

## Process

### 1. Route check

Confirm the PROJ is on the designer path before writing anything:

- The brief commissions an external design deliverable, and
- `1c_design/design-language.md` either does not exist, or exists and the brief
  declares its *visual direction* replaceable.

If `1c_frontend-design` already ran to completion for this PROJ family and no
external designer is involved, stop and say so. Two design systems is the
failure this check exists to prevent.

### 2. Conformance pass — the gate

Write `1c_design/design-conformance.md` **before extracting anything**. Walk the
brief's contract clause by clause and record, per clause: what you checked, what
you found, and whether it blocks.

The checks that are load-bearing, and why each one is:

| Check | Blocks | Why it blocks |
|---|---|---|
| Every semantic variable carries a **code syntax field** | yes | Without it the design tool's dev API returns a raw hex. The token layer does not degrade — it disappears, and every consumer sees hardcoded values that lint will later reject |
| Semantic names **match the binding vocabulary exactly** | yes | Engineering code is written against these names; a rename is a change to every consumer. See step 3 |
| **Two tiers** — semantic tokens alias primitives, components bind to semantic only | yes | A component bound to a primitive cannot be re-themed; the point of the split is that a palette change edits one alias |
| **Auto layout on every container**; fill/hug/fixed deliberate | yes | This *is* the responsive specification. Without it the implementer sees rectangles at coordinates and guesses — and guesses wrong at a width nobody tested |
| **All applicable states drawn as variants** | yes | A state sketched in a side frame labelled "hover states" is invisible. It ships with no hover treatment and nobody notices until review |
| **No detached instances** on any dev-ready frame | yes | A detached instance produces bespoke code — the mechanism by which a design system acquires its fourth button |
| **Version stamp** on every dev-ready frame | yes | Without it a later design-vs-implementation discrepancy is unresolvable: nobody can say which version was accepted |
| Required **reference widths** delivered | yes | A single width is not a responsive specification |
| **Work-in-progress separation** honoured | yes | An abandoned component copy is structurally identical to the real one to an automated reader. Page separation is the only thing distinguishing them |
| **Annotations** present for interaction, validation, focus, announcements | advisory | Recoverable — that behaviour belongs in PRD acceptance criteria anyway (step 6) |
| **Component descriptions** on published components | advisory | Improves generation quality; nothing downstream breaks without them |

**Report method, not just verdict.** For each check state *how* you established
it and over what set. A clause you could not check is `NOT CHECKED`, never
`PASS`, and never inferred from a spot sample. Before writing "no detached
instances found", confirm your method can find one: locate a known instance and
verify it appears. An absence claim from a search you defined yourself is a
claim about your search, not about the file.

**On a blocking failure: stop.** Write the report, name what fails and what
would clear it, and hand it back. Do not extract "the parts that are fine" — a
partial token set is indistinguishable from a complete one to everything
downstream.

### 3. Token extraction and name reconciliation

Export the design tool's variables to **W3C DTCG JSON** and commit it as the
generated source. Then reconcile against the binding vocabulary — the step the
whole contract exists to make possible:

| Case | Action |
|---|---|
| Binding name present in the delivery | Adopt the new **value**; keep the name |
| Binding name **missing** | **Blocking.** The designer dropped a token engineering writes against. Ask; never substitute a lookalike |
| Delivery adds a **new** semantic name | Not adopted. Record as a **proposal** with the designer's rationale for the product owner to accept — the one-way route the chain uses for every un-accepted source |
| Delivery **renames** a binding token | **Blocking.** A rename is a breaking change, not a design decision |
| A token reserved for a later pass now carries a real value | Not a deviation — the anticipated event. Record it as an approved product decision with its date, never a silent adoption |

The same reconciliation covers the **non-colour scales** the vocabulary
names — type, spacing, radius, shadow. Values are free, step names are fixed,
and a new step is a proposal like any other.

Generate the stylesheet custom properties and typed token definitions from the
DTCG JSON with a build step, commit the output, and **never hand-edit generated
files**. What matters on the first pass is not automation — a one-command
regeneration is fine — but that regenerating is **mechanical, never a judgement
call**.

State the tier split explicitly in the output: primitives hold raw values,
semantic tokens alias them, components bind to semantic only.

### 4. Component catalog

Extract the component set: name, purpose, variants, sizes, states, and the
tokens each consumes. Component *properties* map to implemented props — a
`variant`/`size`/`state` axis becomes a prop, a boolean becomes a conditional
slot, a text layer named `label` becomes the child.

Rules carried over from `1c_frontend-design`, unchanged:

- **Variant before component.** A new size, tone or state is a variant.
- **No speculative components.** If no delivered screen uses it, it is not in
  the catalog — even if the library file publishes it.
- Keep variant axes shallow and orthogonal. Four axes of four options is 256
  combinations and an unusable API on both sides.

**Do not hand-write `docs/components.md`.** It is generated by
`gen-component-registry.mjs` from the doc block above each component export once
components exist in code. Before that the catalog lives in the design language
document as a list, and the generated registry replaces it the moment
implementation starts. A hand-written registry is a paper component waiting to
happen.

### 5. Rewrite the design language

`1c_design/design-language.md` keeps its role — the **why** — with the
designer's reasoning replacing the agent's. Preserve the structure and replace
the content:

- **Values replaced, names preserved.** Every table keeps its Token column.
- **Decision record**: what the designer chose, what they rejected, and why.
  This is what a later reader needs when the design and the running app
  disagree.
- **Constraints that survive the redesign** are restated with their source, not
  dropped: an information-never-by-hue-alone rule outlives the arrival of
  colour; a contrast floor outlives a palette change.
- **Implementation Notes must name the *actual* stack.** Read it from its single
  source of truth (`docs/ARCHITECTURE.md` § Stack, or the implementation repo's
  stack document) — never carry a framework forward from the prior draft, and
  never let this document decide a stack. A stale stack line here propagates
  into every implementer's context bundle.

Then write `docs/DESIGN-SYSTEM.md` — rules only, ≤80 lines, no inventory and no
rationale, because it is injected into every frontend implementer's context
bundle. Tokens written as the thing an implementer types, with a **Never**
column. Run `curation-caps.sh`; if it does not fit, detail moves to the
showcase, never to a second markdown file.

### 6. Route behaviour into requirements, not into the design file

Annotations describing validation timing, focus order and return, empty versus
filtered-to-zero, status announcements or reduced-motion behaviour are
**acceptance criteria that happen to live in a design tool**. They reach no
implementation prompt from there.

List them in `design-language.md` under exactly this heading, which
`2_requirements-engineer` reads by name:

```markdown
## Behaviour Annotations — Candidate Acceptance Criteria
| Behaviour | Applies to | Source node |
|---|---|---|
```

The heading is fixed, not descriptive. A downstream skill cannot look up "a
clearly-marked section", and a behaviour stated only in an annotation is a
behaviour that will not be built and will not be tested. Where the delivery has
no annotations, write the heading with an explicit `None — the contract's
annotation clause was advisory and unmet` row rather than omitting it: an absent
section and an unannotated design are indistinguishable to the next reader.

### 7. Showcase

Build the showcase from the extracted tokens — every component with all
variants, sizes and states, foundations section first. Pre-scaffold this is
`1c_design/component-showcase.html`, plain HTML+CSS, **same structure and same
anchors** `1c_frontend-design` fixes, so P5's port to the `/dev/components`
route stays mechanical.

The showcase is the one artifact carrying full detail, because it costs no
context budget and **cannot lie**: a component whose states are missing from the
design shows up as an empty row.

### 8. Source record

Write `1c_design/design-source.md`. It is both the chain-guide's detection
marker for "1c satisfied via the intake path" and the anchor every later
design-vs-implementation argument depends on:

```markdown
# Design Source — PROJ-<X>

## Accepted version
- Files: <library file> · <screen file>
- Version stamp: <v3 — YYYY-MM-DD>
- Accepted: <date> by <role>
- Conformance: `1c_design/design-conformance.md` (pass | pass-with-advisories)

## Node index
| Screen / component | Node link | Version stamp |
|---|---|---|

## Extraction
- Variables export: <path to DTCG JSON>
- Generated token files: <paths> — generated, never hand-edited
- Regeneration: <the one command>

## Proposals not adopted
| Item | Designer's rationale | Awaiting |
|---|---|---|

## Deviations accepted
| Deviation | Reason | Recorded in |
|---|---|---|
```

### 9. Verify

- Every binding semantic name resolves; none silently dropped
- Generated token files regenerate byte-identically from the committed export
- The showcase renders every catalog entry, and every state in the catalog has a
  row — a missing state is a visual diff, not a search
- Contrast floors hold under the new values, at the sizes actually used
- Text-carrying components were checked against **real product strings**, not
  English placeholders, wherever the product's language produces materially
  longer compounds than the language the design was drafted in
- `docs/DESIGN-SYSTEM.md` passes `curation-caps.sh`
- Every clause of the conformance report carries a verdict **and** a method

## Output

`1c_design/design-conformance.md` (the gate), `design-source.md` (the anchor),
`design-language.md` (the why), `docs/DESIGN-SYSTEM.md` (the rules), the
committed DTCG export plus generated token files, and the showcase (the proof).

## Handoff

Invoke `1d_ui-mockup` in **`design-derived`** fidelity mode. In that mode 1d does
not author screen mockups — the design file is the visual authority and a second
set of HTML screens is a competing one. 1d still produces the two artifacts
everything downstream consumes: the sitemap, and `implementation-handoff.md`
with a `## Design Source` block pointing at the node index above.

Then `2_requirements-engineer`, which consumes the annotation-derived acceptance
criteria from step 6.

## Rules

- **Verify before extracting. Refuse rather than compensate.** A gap this skill
  fills is the designer's authority silently becoming the agent's.
- **Never author a token value.** Values come from the delivery, or the skill
  stops.
- **Never invent or accept a renamed semantic token.** Names are the interface.
- **A new name from the designer is a proposal, not an adoption** — it routes to
  the product owner and enters the binding vocabulary only after acceptance.
- **Never accept an unstamped dev-ready frame.** Without a version stamp there
  is no later argument about what was accepted.
- **Never edit generated files** — the DTCG export, the emitted token files, or
  the component registry.
- **Never edit the mockups or the concept.** Drift reconciliation belongs to
  `1e_concept-sync`, from the iteration log.
- **Report checked versus inferred**, and never prove an absence from a search
  space you narrowed yourself.
- **One writer per artifact.** This skill and `1c_frontend-design` are mutually
  exclusive for a PROJ family.
- **English** — all documentation in English; product vocabulary preserved
  verbatim in its own language.

## Track Boundary

On the **discovery track there is no codebase**, so only `1c_design/*` can be
written there: the conformance report, the source record, the design language,
the DTCG export, and the standalone showcase. `docs/DESIGN-SYSTEM.md`, the
generated token files and the component registry belong to the implementation
repository and are produced when the chain reaches it.

On the **full chain** all outputs land in the one repo, exactly as
`1c_frontend-design` writes them today.

Where discovery and implementation are separate repositories, run the intake in
discovery and carry the DTCG export plus the design language across in the
`2b_handoff-package` run. The implementation repo consumes them; it does not
re-extract, and it never edits them in place.

## Legacy Folder Layout

PROJ folders created before the layout rename carry the old subfolder names.
Mapping, old → current: `2_visual-companion/` → `1b_visual-companion/` ·
`4_design/` → `1c_design/` · `5_mockups/` → `1d_mockups/` · `3_PRDs/` →
`2_PRDs/` · `8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`.

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are.** Never create
a second folder next to it. Say it once, then continue either way.
