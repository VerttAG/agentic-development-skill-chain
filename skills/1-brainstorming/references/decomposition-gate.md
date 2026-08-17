# Project Decomposition Gate

> Reference for the 1-brainstorming skill. Loaded on demand.

Run this gate immediately after project-context discovery and before detailed feature-concept intake.

### Why This Exists

PRDs, user stories, and waves are too late for deciding whether one broad seed is actually multiple PROJs:

- **PRDs/user stories** split behavior inside an already-approved PROJ. They are good for testable feature slices, not for deciding project identity.
- **Waves** split implementation order. They are good for dependency management during execution, not for product scoping.
- **Brainstorming** owns product boundaries. It must decide whether the seed should become one PROJ or multiple PROJs before downstream artifacts inherit the wrong scope.

Skipping this gate is acceptable only when the seed has one coherent user outcome, one main audience, and one downstream path.

### When To Decompose

Split one seed idea into multiple PROJs when two or more of these are true:

- It contains independent user goals that can ship, test, or be adopted separately.
- It touches different subsystems with different owners, risk profiles, data models, or rollout paths.
- It mixes foundation/enabling work with user-facing workflows.
- It includes multiple audiences whose success criteria differ materially.
- It would naturally produce several PRDs with weak dependency between them.
- It needs separate UI exploration paths, such as admin tooling plus end-user workflow.
- It contains a risky or unknown piece that should be isolated before broader product work.
- One part is clearly MVP-critical while another is expansion, automation, analytics, migration, support tooling, or polish.

Do not decompose only because a feature is complex. Keep it as one PROJ when the pieces must be designed, shipped, and validated together to create user value.

### Decomposition Output

If the seed appears too broad, stop detailed questioning and present a proposed project map:

```markdown
This seed looks larger than one PROJ. I recommend splitting it into:

1. PROJ-A candidate: <theme>
   - User value:
   - Scope:
   - Explicitly not included:
   - Depends on:
   - Suggested downstream path: visual-companion | requirements-engineer

2. PROJ-B candidate: <theme>
   - User value:
   - Scope:
   - Explicitly not included:
   - Depends on:
   - Suggested downstream path: visual-companion | requirements-engineer

Recommended first PROJ: <theme>, because <reason>.
```

Use temporary labels such as "PROJ-A candidate" until the user approves the split. Do not allocate real PROJ numbers before approval.

### User Approval Rules

Ask the user to approve or correct the split before continuing:

> "Does this project split match your intent, or should any of these be merged, removed, renamed, or reordered?"

This is a concrete decision, so a vague "yes" is not enough if the split has unresolved boundaries. Re-ask with specific merge/remove/reorder options when needed.

After approval:

- Decide whether to create concepts for all approved PROJs now or only the recommended first PROJ.
- If the user wants all concepts now, process them one at a time in dependency order.
- Allocate real PROJ numbers only after the split and ordering are approved.
- Each PROJ gets its own folder and concept doc.
- Each concept doc must record its sibling PROJs, dependencies, and excluded sibling scope.
- If one PROJ blocks another, mark the blocked PROJ's next step as "wait for PROJ-<X>" rather than handing it directly to the next skill.

### Decomposition In Concept Documents

For every concept created from a decomposed seed, include:

- Original seed idea.
- Approved decomposition map.
- This PROJ's role in the map.
- Sibling PROJs and boundaries.
- Dependencies and recommended order.
- What intentionally belongs to another PROJ.

If the user rejects decomposition, document the conscious decision in the concept under `Risks And Trade-Offs`, including why the broader scope is still acceptable as one PROJ.
