# Installation

The chain is one canonical `skills/` tree in the [Agent Skills](https://agentskills.io/specification)
format. Every install path below points at that same tree — pick **one**.
Installing through two channels leaves you with every skill twice.

## Where skills actually land

One canonical copy lives in `.agents/skills/` (project) or `~/.agents/skills/`
(user). That is the path Codex, Cursor, Gemini CLI, GitHub Copilot, Amp,
OpenCode, Zed and Cline read natively. Claude Code reads its own
`~/.claude/skills/` and follows per-skill symlinks into the canonical copy, so
there is still only one copy on disk to update.

> Codex reads `~/.agents/skills/`, **not** `~/.codex/skills/`. `~/.codex/` holds
> `config.toml`. Instructions that point at `~/.codex/skills/` are stale.

## Any agent — `npx skills`

```bash
npx skills add VerttAG/agentic-development-skill-chain
```

Resolves the agents installed on the machine, symlinks from one canonical copy,
and writes a `skills-lock.json` you can commit. Restore it elsewhere with
`npx skills experimental_install` — that restores only into `.agents/skills/`,
does not verify the recorded hash, and does not recreate agent-specific symlinks.

Read-only preview before writing anything (there is no `--dry-run`):

```bash
npx skills add VerttAG/agentic-development-skill-chain --list   # must list 23 skills
```

**Telemetry:** `npx skills add` reports the source, the skill names and a map of
their paths to `add-skill.vercel.sh`, and lists public repos on skills.sh with
install counts. `DISABLE_TELEMETRY=1` or `DO_NOT_TRACK=1` opts out, at the cost
of the pre-install security audit it shows.

## Claude Code — native plugin

```bash
/plugin marketplace add VerttAG/agentic-development-skill-chain
/plugin install skill-chain@skill-chain
```

Send those as two separate prompts. Update with `/plugin marketplace update
skill-chain`, then `/plugin update skill-chain@skill-chain`. Commands appear as
`/skill-chain:0-chain-guide`, `/skill-chain:1-brainstorming`, and so on.

Custom marketplaces do not auto-update by default — opt in under `/plugin` →
Marketplaces.

## Codex — native plugin

```bash
codex plugin marketplace add VerttAG/agentic-development-skill-chain
codex plugin add skill-chain@skill-chain
```

Or search for it in `/plugins` inside a Codex session. Skills are invoked as
`$0-chain-guide`, `$1-brainstorming`, …

## Gemini CLI

```bash
gemini extensions install https://github.com/VerttAG/agentic-development-skill-chain
```

## GitHub Copilot

```bash
gh skill install VerttAG/agentic-development-skill-chain 1-brainstorming
```

## No Node, no registry — the bundled installer

```bash
git clone https://github.com/VerttAG/agentic-development-skill-chain
cd agentic-development-skill-chain

./install.sh                          # every supported host, user scope, symlinked
./install.sh --target claude          # one host
./install.sh --target codex --dest .  # project scope, into ./.agents/skills/
./install.sh --copy                   # real directories instead of symlinks
./install.sh --list                   # print the plan, write nothing
./install.sh --uninstall              # remove the chain, including renamed leftovers
```

`--target` accepts `all`, `claude`, `codex`, `agents`, `cursor`. The installer
strips `.DS_Store` and removes skills from earlier versions of this chain
(including the pre-2.0 underscore names), so renamed or dropped skills never
linger — the retired per-provider scripts could not do that, which is why some
machines still carry orphans like `1c_design-intake`.

## Upgrading from 1.x

Skill directories were renamed to the spec form (`0_chain-guide` →
`0-chain-guide`), and the `claude/` + `codex/` trees became one `skills/` tree.
Any install path above cleans the old names up. To check by hand:

```bash
ls ~/.claude/skills ~/.codex/skills ~/.agents/skills
```

## Ponytail (required for framework runs, Stage 2)

The framework's minimalism ladder is the third-party
[Ponytail](https://github.com/DietrichGebert/ponytail) plugin — installed on
BOTH providers, same version, mode `full`. The P0 preflight
(`ponytail-check.sh`) blocks runs on absence or version/mode mismatch.

```bash
# Claude Code
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
# Codex
codex plugin marketplace add DietrichGebert/ponytail
codex plugin add ponytail@ponytail
```

The shared mode lives in `~/.config/ponytail/config.json`
(`{"defaultMode":"full"}` — `ponytail-check.sh` persists it if absent). Leave
`PONYTAIL_SUBAGENT_MATCHER` unset. Ponytail then reaches every normal subagent,
including generic implementation fallbacks; P0 rejects a scoped matcher because
it silently misses those fallbacks.

`PONYTAIL_ENFORCE=0` is the loud escape hatch — the run continues without the
ladder, recorded in state.json and flagged in the reports.

## Notes

- Existing skill folders with the same names are overwritten.
- The 0-to-8 core chain (incl. `0a-product-vision`, `0c-bootstrap`, `0b-intake`,
  `cross-review`) and the optional skills are installed together.
- `CLAUDE.md` is not a skill. It is a repo-level pointer file only.
- The phase runner in `runner/` is **not** part of the skills package: it starts
  live `claude` and `codex` lanes, so it needs both CLIs installed and
  authenticated. Clone the repo to use it.
