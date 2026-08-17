# 3. Create team and spawn teammates for the wave

> Reference for the 5-executing skill. Loaded on demand.

**For waves with 2+ parallel user stories:** Create an agent team. The lead (you) coordinates.

**Honor the plan's `## Execution` block before spawning.** `sequential` means
dispatch exactly one US at a time even when `Can start when` says both are
ready. For any frontend wave, the lead owns the dev server: start and stop it
once for the round; agents reuse it and never start or kill one. For a parallel
wave, the lead also owns every other declared shared resource and the control
plane: `progress.md`, staging, and commits. Include the execution mode, runtime
constraints, and these ownership rules in every spawn prompt.

**Choose the right implementer type per US.** Where the current session can
spawn P0's `skillchain-<role>` agent types, use them. Otherwise use the normal
agent type and attach the path printed by
`node scripts/context-injector.mjs codex <role> --path` to its prompt; a
non-zero exit means that role is blocked and must not be spawned. A generic
`general-purpose` spawn gets no bundle unless that path is explicitly passed:
- US touches only UI (components, pages, styling) → `frontend-implementer` (`skillchain-frontend-implementer`)
- US touches only server-side (API, DB, server actions) → `backend-implementer` (`skillchain-backend-implementer`)
- US is full-stack (both UI and server logic) → `implementer` (generic)

**Choose the right model per US (from the wave plan's `Complexity` column):**
Read the `Complexity` column in the wave plan's "User Stories in this Wave" table. Pass the value as the `model` parameter on the `Agent` spawn so the teammate runs on the right brain for the job.
- `sonnet` → `model: "sonnet"` (default for standard US)
- `opus` → `model: "opus"` (architecture-sensitive: state machines, concurrency, cross-feature contracts, migrations, auth/session, money, crypto)

Haiku is deliberately not in the menu — US-level work loses too much fidelity on it. If the wave plan is missing the `Complexity` column (older plan format), default to `sonnet` and log a one-line note in `5_progress/PROJ-<X>-progress.md` so the planner can retrofit it.

```
Create an agent team for Wave N of PROJ-X.

Spawn teammates:
- "us-2" using the frontend-implementer agent type, model: "sonnet": [US-2 prompt with full context]
- "us-7" using the backend-implementer agent type, model: "opus": [US-7 prompt with full context — this one touches auth/session]

Require plan approval for each implementer before they make changes.
```

**For waves with a single user story:** Use a regular subagent (no team overhead needed). Pick the matching implementer type based on the US scope.

Pass to each teammate (via `references/implementer.md` template):
- Full user story (Given/When/Then)
- Its acceptance criteria
- Its task list with TDD steps
- Codebase context + conventions
- What previous waves implemented
- Relevant sections from `agent.md`
- **If the US touches UI:** include the relevant `UI Implementation Notes` from the wave plan and the matching sections from `1d_mockups/implementation-handoff.md`:
  - Project mode (`greenfield`, `brownfield`, `hybrid`)
  - Mockup file reference and selected UI direction
  - Existing components/tokens to reuse
  - Approved new component candidates
  - Required interaction contract and responsive behavior
  - Implementation tolerance and demo-only exclusions
- **If the US touches UI:** the design system baseline is `docs/DESIGN-SYSTEM.md` (rules) plus `docs/components.md` (inventory). In framework runs the `frontend-implementer` context bundle injects both — do not paste them again, that pays the token budget twice. Outside bundle runs, paste both files. Either way the teammate reuses registered components — never one-off styled elements.
- **If a US needs a component the catalog does not have:** the teammate escalates instead of styling a one-off. The main agent runs the extension procedure from `1c-frontend-design` → *Extending The Design System* (variant before new component, confirm with the user, then catalog + `docs/components.md` + `/dev/components` showcase), then the teammate composes the new entry. A component that reaches QA without a catalog and registry entry is a Critical bug (`6-qa` hard-checks this).
- **If the US touches Tailwind CSS styling and a `tailwind-css` skill is installed alongside this chain** (`../tailwind-css/SKILL.md`): include its contents. Pass the relevant sections (responsive patterns, dark mode, class organisation, component patterns) so the teammate uses consistent utility classes and avoids conflicts.
- **If the US involves Next.js App Router and a `nextjs-app-router-patterns` skill is installed alongside this chain** (`../nextjs-app-router-patterns/SKILL.md`): include its contents. Pass the relevant sections (Server vs. Client Components, data fetching, routing, caching) so the teammate follows App Router conventions and avoids common pitfalls (e.g. accidentally marking a Server Component as `'use client'`).

**UI implementation rule:** Existing React components and design tokens take precedence over exact HTML mockup CSS. Preserve the selected layout direction and interaction contract; do not replace a sidepanel with a modal, a wizard with a single page, or a brownfield component with a one-off styled element unless the user explicitly approved that change.

Wait for all teammates in the wave to complete before running Ralph. Clean up the team after each wave.
