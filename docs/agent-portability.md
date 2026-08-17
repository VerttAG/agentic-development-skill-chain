# Agent portability

This repo ships **one** copy of the chain. Everything else is a thin adapter.

## The Adapter Rule

> When a host supports skills, point it at the existing `skills/` tree.
> Never copy skill content into a host-specific directory.
> When hosts genuinely differ, express the difference as a **capability** inside
> the canonical file — never as a second file, and never as a vendor name in a
> path.

Before 2.0 this repo kept `claude/skills/` and `codex/skills/` side by side. 48
of 66 file pairs were byte-identical, 33 of the last 43 commits touched both
trees, and the two halves had already drifted apart on real behaviour. A
distribution tool that de-duplicates by frontmatter `name` would have picked
whichever copy the filesystem returned first — so a Codex user could silently
receive the Claude-flavoured variant. One tree removes that whole class of bug.

## What each host reads

| File / directory | Host | Tier |
|---|---|---|
| `skills/<name>/SKILL.md` | every host — the canonical source | skills |
| `.agents/skills/`, `~/.agents/skills/` | Codex, Cursor, Gemini CLI, Copilot, Amp, OpenCode, Zed, Cline | skills (native path) |
| `~/.claude/skills/<name>` → symlink | Claude Code | skills (via symlink) |
| `.claude-plugin/plugin.json` + `marketplace.json` | Claude Code | plugin |
| `.codex-plugin/plugin.json` (`"skills": "./skills/"`) | Codex CLI, ChatGPT | plugin |
| `gemini-extension.json` (`contextFileName: AGENTS.md`) | Gemini CLI, Antigravity | plugin |
| `AGENTS.md` | Codex, Cursor, Amp, Copilot, Gemini CLI, OpenCode, Zed, Aider, Jules … | instructions |
| `CLAUDE.md` | Claude Code | instructions (pointer only) |
| `runner/` | needs the real `claude` **and** `codex` CLIs | not portable |

Claude Code auto-discovers `skills/` inside a plugin, so `.claude-plugin/plugin.json`
deliberately declares no `skills` key. Codex requires the key, so it has one.
That is the entire difference between the two manifests.

## Conventions inside a skill

**Cross-skill references use `../<skill>/…`,** relative to the skill directory —
never `~/.claude/skills/…` or `~/.codex/skills/…`:

```markdown
copy from `../5-executing/scripts/wave-gate.sh`
run `bash ../4b-setup/scripts/state.sh init <X> <theme>`
```

This works because every host installs the collection into one parent directory.
It is also what unrelated large collections do — googleworkspace/cli uses the
same idiom across 95 skills. A bare `scripts/state.sh` means the **project's**
copy, which P0 installs at the repo root; the `../` prefix is what distinguishes
the two.

Scripts that must run before P0 has copied them into a project resolve their
siblings at runtime — `$SCRIPT_DIR` first, then `$SKILL_CHAIN_HOME`, then the
known host skill homes. See `skills/4b-setup/scripts/preflight.sh`.

**Host differences go in a `## Host adaptation` block** near the top of the
skill, phrased by capability rather than by vendor, so a new host needs no new
fork:

```markdown
## Host adaptation

- **Structured-choice question tool** (Claude Code `AskUserQuestion`): use it for
  the interview. Otherwise ask one topic per turn and wait for the answers.
- **Delegation to subagents:** … Otherwise implement locally and keep context lean.
```

Name a vendor only as an *example* of a capability, never as the condition itself.

**Host-specific metadata belongs in namespaced frontmatter** — `metadata.<host>.*`
inside the canonical `SKILL.md` — not in a parallel directory.

## Adding a new host

1. If it reads `.agents/skills/` or `SKILL.md`, it already works. Do nothing.
2. If it needs its own manifest, add a small file at the repo root or in a
   `.<host>-plugin/` directory that points at `./skills/`. Add it to
   `VERSION_FILES` in `scripts/check-versions.mjs` so its version cannot drift
   unnoticed.
3. If it needs a different *directory*, add a symlink target in `install.sh`
   (`link_dir_for`). Do not copy the tree.
4. If it lacks a capability a skill assumes, add a bullet to that skill's
   `## Host adaptation` block. Do not fork the file.

`scripts/check-skills.sh` fails the build if a second skill tree appears, if a
helper script exists in more than one place, or if a skill hardcodes a host
skill home.
