# Brownfield Context Intake (Discovery Track)

> Reference for the 1-brainstorming skill. Loaded on demand.

On the product discovery track there is usually **no codebase to scan**, so the "Auto-Discovered Inputs" repo scan finds little. When the work extends or fits into something that already exists — a live product, an established design system, a brand, known domain vocabulary — capture that existing state explicitly so it is not lost. Skip this section for greenfield discovery (nothing exists yet) and for the full in-repo chain (the repo scan already covers it).

Run this during project-context discovery, before the Decomposition Gate. Ask the user what already exists and gather references:

- **Existing surfaces:** live URLs of the current product/screens, or screenshots the user provides.
- **Design system / brand:** Figma/Storybook/styleguide links, brand colors, fonts, component library, or a screenshot of the current UI.
- **Vocabulary:** domain terms already in use that must not be renamed (with spelling conventions).
- **Constraints and invariants:** rules, integrations, or behaviors that already exist and must be preserved.

You may fetch a provided live URL for reference (structure, copy, visible patterns) and read provided screenshots. Do not guess — only record what the user confirms or what a reference clearly shows.

Write the captured state to a dedicated context folder so downstream skills can consume it:

```text
specs/PROJ-<X>-<theme>/0_context/existing-state.md
specs/PROJ-<X>-<theme>/0_context/references/        # screenshots, exported style guides, saved links
```

`existing-state.md` structure:

```markdown
# Existing State — PROJ-<X> <theme>

## Existing Product / Surfaces
- <URL or screenshot ref> — what it is, what it covers

## Design System / Brand
- Source: <Figma/Storybook/styleguide link or screenshot>
- Colors / fonts / spacing / radius conventions:
- Component library / patterns to reuse:

## Domain Vocabulary
| Term | Meaning | Notes (spelling, do-not-rename) |
|------|---------|---------------------------------|

## Existing Constraints And Invariants
- <rule / integration / behavior that must be preserved>

## Open Questions About The Existing State
- <anything unconfirmed>
```

Downstream consumers:

- `visual-companion` uses it to ground layout exploration in the existing shell.
- `ui-mockup` uses it in **design-system mode** to adopt existing tokens, components, and patterns (there is no `tailwind.config` to scan on this track).
- `handoff-package` folds it into the standalone package so external readers see the as-is starting point.

Record in the concept's `Project Context` that `0_context/existing-state.md` exists and is the source of as-is truth.
