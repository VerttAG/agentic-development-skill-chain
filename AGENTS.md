# Repository Instructions

- Keep `AGENTS.md` as the only curated durable-context file.
- Keep `CLAUDE.md` pointer-only; it must reference `AGENTS.md` and must not contain durable rules.
- `skills/` is the ONE canonical skill tree. Never create a second, per-host copy of a skill, a helper script, or a template — that duplication was removed in 2.0 and `check-skills.sh` fails the build if it returns.
- Follow the Adapter Rule ([docs/agent-portability.md](docs/agent-portability.md)): when a host supports skills, point it at `skills/`. Express real host differences as a capability inside a `## Host adaptation` block in the canonical file, never as a vendor name in a path or a forked file.
- Cross-skill references use `../<skill>/…` relative to the skill directory. A bare `scripts/…` means the project's copy that P0 installs at the repo root.
- Skill directory names are spec-form kebab-case, and the frontmatter `name` must match the directory exactly. Frontmatter carries only the six Agent Skills fields (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`).
- Keep each `description` under 250 characters. Hosts render the startup skill list into a fixed budget (~8,000 characters) and silently drop skills past it.
- Include only the core 0-to-8 chain and explicitly documented optional skills in this repository.
- Treat `specs/PROJ-<X>-<theme>/2b_handoff/` package runs as generated artifacts: only the `2b-handoff-package` skill may create or update them. Other skills must update source artifacts and let it generate a new dated run.
- Write `specs/**/state.json` only via `state.sh` and `specs/**/findings.json` only via `ledger.mjs` — never with ad-hoc edits or raw jq writes. Morning reports, stop reports, and PR bodies are rendered by the template scripts (`runner/render-report.mjs`, `render-pr-body.mjs`), never written or edited by hand.
- Bump the version in every host manifest together (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`). Hosts detect updates from the version string, not from git tags — shipping without a bump leaves every existing install on its cached copy. Add any new manifest to `VERSION_FILES` in `scripts/check-versions.mjs`.
- Run `./scripts/check-skills.sh`, `node scripts/check-versions.mjs`, and `./scripts/validate.sh` before publishing changes.
