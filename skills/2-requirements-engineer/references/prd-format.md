# PRD format

Use this format for every newly authored or migrated PRD.

## File and identifiers

- Save the file as `PRD-<number>-<slug>.md`, for example `PRD-1-auth.md`.
- The declared PRD ID equals the filename stem.
- The chain stores PRDs inside `2_PRDs/`, so `Product domain` is the actual
  domain: the `<theme>` in `PROJ-<X>-<theme>` unless the concept names a more
  precise domain. It is never the literal folder name `2_PRDs`.
- Derive the identifier slug from the PRD ID after `PRD-`:
  `PRD-1-auth` uses `UC-1-auth-01`, `AC-1-auth-01-01`, and `Q-1-auth-01`.
- UC and question numbers run from `01` across the PRD. AC numbering restarts
  at `01` inside each UC. IDs are unique and zero-padded.

## Exact document grammar

A PRD is UTF-8 without front matter. It has one H1, the three header items,
and exactly these six H2 sections in order:

1. `Outcome and success signals`
2. `Scope`
3. `Domain vocabulary`
4. `Use cases`
5. `Assumptions`
6. `Open questions`

Do not add `Status`, `Edge Cases`, `Dependencies`, `Technical Requirements`,
`UI Implementation Notes`, or `QA Test Results` sections. Put binding
behaviour in the owning UC's acceptance criteria. Keep implementation and QA
artifacts in their chain-owned files.

```markdown
# <Feature name>

- **PRD ID:** `PRD-<number>-<slug>`
- **Schema version:** `1`
- **Product domain:** `<domain>`

## Outcome and success signals

<One non-empty outcome paragraph.>

- <One or more observable success signals.>

## Scope

### In scope

- <One or more in-scope items.>

### Out of scope

- <One or more out-of-scope items.>

## Domain vocabulary

- **<lowercase_snake_case_term>:** <Definition.>

## Use cases

### UC-<number>-<slug>-01 — As a <actor>, I want <intent> so that <benefit>

- **Given:** <precondition or None>
- **When:** <trigger>
- **Then:** <observable outcome>
- **Depends on:** <sorted AC IDs or None>
- **Blocked by:** <sorted same-PRD Q IDs or None>

#### Acceptance criteria

- **AC-<number>-<slug>-01-01:** <One testable criterion.>

## Assumptions

- <Assumption or None.>

## Open questions

- **Q-<number>-<slug>-01:** <Question referenced by at least one Blocked by field.>
```

Use the exact sentinel `- None.` when vocabulary, assumptions, or questions
are empty. `Given`, `Depends on`, and `Blocked by` use the scalar `None`.

## Authoring rules

- Outcome has one paragraph followed by one or more observable list items.
- Scope has exactly `### In scope` then `### Out of scope`, each with at least
  one item.
- Vocabulary keys are unique, sorted, lowercase snake case, and resolve to a
  term used outside the vocabulary section. Do not invent definitions.
- A UC heading uses exactly `As a` or `As an`, followed by `, I want ` and
  ` so that `. The actor, intent, and benefit are non-empty plain text.
- Each UC has the five fields shown above, once and in order, followed
  immediately by one `#### Acceptance criteria` heading and at least one AC.
- `Depends on` names only existing AC IDs. `Blocked by` names only questions
  from this PRD. Lists are comma-space separated and lexicographically sorted.
- Every question is referenced by at least one `Blocked by` field.
- ACs are plain unordered-list items with one inline paragraph. No task-list
  markers, nested lists, tables, HTML, headings, images, or ordered lists.
- Put cross-cutting rules and edge cases under the one UC that owns them. Do
  not duplicate them and do not hide testable behaviour in Assumptions.
- Keep one coherent user goal per UC. More than 15 ACs is a review trigger:
  split when the criteria cover independently testable actions, while keeping
  shared invariants with their single owning UC.
- PRDs are self-contained. Inline the substance of external decisions. A real
  unresolved cross-PRD dependency becomes a question and blocks the affected
  UC until the target AC ID is known.

## Completion gate

Verify mechanically before review:

- header order, six-H2 order, and required Scope/UC substructure;
- filename/PRD-ID match and sequential unique UC, AC, and Q IDs;
- every dependency and blocker resolves, lists are sorted, and every question
  is used;
- no forbidden AC construct, task marker, external reference, or extra H2;
- vocabulary keys resolve outside the vocabulary section and do not duplicate
  Assumptions;
- every scope rule, edge case, and behavioural requirement is represented by
  an owning AC.
