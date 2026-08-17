---
name: 5-executing
description: "Execute wave-based implementation plans user story by user story with TDD, Ralph acceptance-criteria loops, wave gates, code review and QA handoff. Use when a plan is ready to build. Not for planning or architecture."
license: MIT
compatibility: Requires git, jq, node, and coderabbit. Browser automation needed only when the wave config lists frontend_routes.
---

# Executing

Orchestrate implementation by creating an agent team and spawning teammates per user story. The lead (main agent) stays in the loop: after each US is implemented, it runs an outer Ralph loop — checking every acceptance criterion deterministically until all pass.

**Agent Teams vs Subagents:** where the host offers agent teams, use them so teammates can communicate during parallel waves — when one discovers a gotcha it broadcasts to the others immediately, instead of everyone waiting for the wave to end. For sequential single-US waves, a regular subagent is fine.

## Host adaptation

The gates, the wave order, the Ralph loop, and every artifact this skill writes are the same on every host. Only the orchestration primitives differ — follow the capability you actually have, and never fake one you don't:

- **Delegation.** Claude Code: agent teams and the `Agent` tool with `subagent_type` (`implementer` / `backend-implementer` / `frontend-implementer`). Codex: `spawn_agent` roles (`worker`, `explorer`, or default), and only where the active session policy allows delegation; give workers disjoint file ownership. **No delegation available:** implement locally, one user story at a time, and keep context lean by reading only what the story needs. The wave gate is unchanged either way.
- **Background spawns.** Only where the host supports them (Claude Code: `run_in_background: true`). Where it does not, run the same spawns in the foreground in dependency order — the fan-out is an optimization, never a correctness requirement.
- **Parallel local reads.** Use the host's batching primitive if it has one (Codex: `multi_tool_use.parallel`).
- **Context compaction.** Hosts that compact automatically need no action; where there is an explicit command (Claude Code: `/compact`) run it at the points this skill marks.
- **Permissions.** Claude Code: the run needs `--dangerously-skip-permissions` or the merged `defaultMode: bypassPermissions` allowlist, or an overnight run dies on the first prompt. Hosts governed by a sandbox/approval policy instead (Codex): use that policy, there is no permission-merge step.
- **Hook-based gate enforcement.** Available only on hosts with pre-tool hooks (see *Wave Completion Gate*). Everywhere else the orchestrator itself must verify the previous wave's `PASSED` block before spawning wave N+1. The script is the gate; the hook is only a fail-safe.

**One PROJ at a time:** The executing loop runs per PROJ. Each PROJ has multiple wave-plan files (`PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …) that are read in order. A single `5_progress/PROJ-<X>-progress.md` tracks all waves. When the user provides multiple PROJ plans, execute each PROJ fully (all waves → Quality Gate → QA) before starting the next.

**Decomposed PROJs:** If the plan references sibling PROJs, treat them as dependencies or context only. Do not implement sibling scope from the current PROJ's waves. If a wave depends on an incomplete sibling PROJ, stop before that wave and report the blocker. Shared design-language files from sibling PROJs may be consumed, but they do not authorize building sibling workflows.

## Context economy — always delegate to subagents

The orchestrator (main agent) must stay lean so it survives the full PROJ → QA → docs chain without a mid-run compact crash. **Default: delegate everything to subagents; main agent only coordinates.**

- **US implementation:** always spawned (`implementer` / `backend-implementer` / `frontend-implementer`). Never write code inline.
- **Ralph AC loops:** drive from subagents; main agent only collects verdicts.
- **PROJ-end Ken review:** spawned in Skill 6, not read inline. Ken no longer runs per wave — only once against the assembled PROJ.
- **Quality Gate (Step 9):** `code-reviewer-gate` plus optional `sonar-cli` quality input run as delegated streams, not inline review by the orchestrator.
- **Fix-spawns:** every Critical/High finding is fixed by a spawned subagent, clustered by file.
- **Even single-file edits:** if the edit needs to read 5+ files first, spawn — don't pull them into the orchestrator context.

Subagents return a ≤ 300-token summary; raw diffs/logs stay in their context and die with them. The orchestrator keeps only IDs, verdicts, and next-step pointers. If the main agent has to read more than ~3 source files directly for a decision, it's the wrong tool — spawn an `Explore` or domain agent instead.

**Run in background by default, where the host supports it.** Spawn all subagents in the background (Claude Code: `run_in_background: true`) unless the orchestrator genuinely cannot proceed without the result. Background spawns let the orchestrator dispatch the next wave of work immediately and get notified on completion — parallel fan-out without blocking. Foreground is the exception, not the norm. Dependencies like `implementer → Ralph → Build → Gate` still run sequentially (the orchestrator awaits each stage), but within a stage every independent spawn goes to background in a single parallel batch.

---

## FIRST ACTION (before reading any plan)

<HARD-GATE>
Before doing ANYTHING else — before reading plans, before spawning any agent:
0. Flush prior conversation context — on hosts with an explicit command run `/compact`; hosts that compact automatically need no action. Steps 1–4 leave large artifacts in the context window that are no longer needed — the PRDs, architecture and wave plans are on disk. Reclaim that space now before the most context-intensive step begins.
1. **P0 setup gate — setup (4b) owns all preflights.**
   - If `specs/PROJ-<X>-<theme>/state.json` exists:
     `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'` must be
     `P0:done` (fresh PROJ) or `P5:*` (resume). Anything earlier → STOP and
     route: `CP1:*` → run **checkpoint** (4a); `CP1:approved` → run
     **setup** (4b). The former inline preflights — permissions merge,
     `.coderabbit.yaml`, Supabase/browser/CLI + auth checks — now run in
     4b's `preflight.sh`; do NOT re-run them here.
   - Then mark the phase if needed: if state shows `P0:done`, run
     `bash scripts/state.sh transition <X> <theme> P5 running`.
2. **Standalone fallback (no state.json — manual run without the framework):**
   run the legacy preflights inline before wave 1: (a) permission preflight, on
   hosts that have one —
   `claude --dangerously-skip-permissions` or `bash scripts/merge-project-settings.sh`
   (copy from `../5-executing/scripts/` if missing, commit);
   (b) `.coderabbit.yaml` at repo root (copy
   `../5-executing/references/coderabbit-template.yaml`, adjust
   `path_filters`); (c) tool checks — `jq`, `coderabbit`, browser automation
   when `wave-gate-config.json` has `frontend_routes`, Supabase CLI/MCP when
   the project uses Supabase. Any hard tool missing → STOP.
3. Record BASE_SHA: from `state.json` (`.base_sha`, set by 4b) — standalone: `git rev-parse HEAD`
4. Create `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md` using the template below
5. Store BASE_SHA in progress.md

This file is your single source of truth for the whole PROJ. Update it after EVERY action.
If progress.md does not exist, you have skipped this step — STOP and create it now.
</HARD-GATE>

---

## Wave Completion Gate

<HARD-GATE>
Before spawning ANY teammate for a new wave N+1, you MUST run the Wave Gate script — it MUST exit 0.

Doc-input collection is owned by Skill 7. Do **not** fill documentation summaries or the `### Post-Wave Notes` blocks during Skill 5 — Skill 4 reserves those as placeholders and Skill 7 harvests them after QA. Keep `progress.md`, commit messages, and `agent.md` accurate instead; those are the sources Skill 7 reads.

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <theme>
```

Exit code ≠ 0 → STOP. Fix the failing check, re-run the script until green. Only then spawn the next wave's teammates.

For a provider signature only (`over_request_rate_limit`, `Request rate limit reached`, or HTTP/status 429), the gate pauses and retries that AC once. A second occurrence is red infrastructure, not a reason to widen limits. Other failures — including a test name containing “rate limit” — are ordinary red ACs.

The script validates:
1. **Ralph ACs** — every `ac_commands` entry exits 0 **and reports a non-empty selected-test count**. The gate persists each result in `5_progress/ralph-wave-N.json` immediately; reruns skip only recorded-green ACs, and `bash scripts/wave-gate.sh --status <N> <PROJ-X> <theme>` checks its PID/heartbeat without `pgrep`.
2. **Build** — `build_cmd` from config exits 0
3. **CodeRabbit** — 0 Critical/High findings against wave start SHA
4. **Smoke Test** — `agent-browser` passes on every `frontend_routes` entry (skipped if empty)

On success the script appends a `### Wave N Gate — PASSED` block with timestamp to `progress.md`. This is the canonical proof that the wave is done — no manual checkbox editing.

**Framework runs (state.json exists):** after every green gate, update the machine state too — `bash scripts/state.sh set <X> <theme> .waves '{"current": <N>, "total": <M>, "stories": {…per-US status…}}'` (merge with the existing block). The gate also pipes its CodeRabbit/Sonar findings into the ledger when `scripts/ledger.mjs` is present — never re-enter them by hand.

**If the wave-gate.sh script is missing from the project:** copy the template from `../5-executing/scripts/wave-gate.sh` to `scripts/wave-gate.sh`, `chmod +x` it, commit it before running the first wave.

**If jq, coderabbit, or agent-browser are missing:** the script prints a clear error and exits non-zero. Install them, do not work around the gate.

**Belt-and-braces enforcement:** on hosts with pre-tool hooks, a global PreToolUse hook (Claude Code: `~/.claude/hooks/wave-gate-enforcer.js`) inspects every subagent spawn. When the type is `implementer` / `backend-implementer` / `frontend-implementer` and the prompt mentions Wave N with N > 1, it refuses the spawn unless `### Wave N-1 Gate — PASSED` exists in `5_progress/PROJ-<X>-progress.md`. On hosts without pre-tool hooks the orchestrator must perform that same check itself before every wave-N+1 spawn. Either way the script is the primary gate; this is only the fail-safe.
</HARD-GATE>

---

## Memory Files

Two files are maintained throughout execution:

### `progress.md` (short-term memory)
Created at the start of execution, lives in `specs/` alongside the plan.
Tracks granular build state — task completion, test status, AC verification, and blockers.
Updated after every task, after every Ralph loop iteration, and whenever a blocker occurs.

Use the template in [`assets/progress-md-template.md`](assets/progress-md-template.md).

**Update rules:**
- Subagent updates task rows after each TDD cycle (tests written → tests passing → done)
- Main agent updates AC rows after each Ralph loop iteration
- `—` means not yet attempted; `✗` means attempted and failing; `✓` means passing
- Ralph Loop section appended after each iteration with verbatim failure reason

### `agent.md` (long-term memory)
Lives in the feature's **source folder** (e.g., `src/features/deliveries/agent.md`).
Written when any agent hits a wall and finds a workaround — or discovers something a future developer must know.
Written like notes to a developer who has never seen this code.

Use the template in [`assets/agent-md-template.md`](assets/agent-md-template.md).

Write to `agent.md` immediately when a learning occurs — not at the end. Future subagents in the same session read it at the start.

---

## Input

Read the following before starting each PROJ:

**All PRDs** — `specs/PROJ-<X>-<theme>/2_PRDs/*.md`. These are the authoritative requirements source. Used by the outer Ralph loop to verify ACs. If plan and PRD disagree on AC text, the PRD wins.

**Architecture** — `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`. Cross-PRD tech design.

**Wave plans** — `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md` (in numeric order). Each wave plan lists:
- The user stories in that wave (may span multiple PRDs)
- Tasks per US with TDD cycle descriptions and file paths
- For UI tasks, UI Implementation Notes and UI handoff constraints propagated from `1d_mockups/implementation-handoff.md`

**UI implementation handoff** — for UI PROJs, read `specs/PROJ-<X>-<theme>/1d_mockups/implementation-handoff.md` before starting implementation. It is the compact source for project mode, component reuse, new component candidates, design tokens, interaction contract, implementation tolerance, and demo-only mockup exclusions.

The PRDs define WHAT success means. The wave plans define HOW to get there. The UI handoff defines how to preserve the approved interface shape without treating HTML mockups as pixel-perfect production specs.

**When multiple PROJ plans are provided:** Execute one PROJ fully (all waves → Quality Gate → QA) before starting the next. Each PROJ has its own `5_progress/PROJ-<X>-progress.md`.

---

## Per-PROJ-X Execution Loop

For each PROJ-X plan (in order):

```
0. Record BASE_SHA (git rev-parse HEAD)
1. Create specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md
2. Execute waves (Steps 1–5 below)
3. Build check after each wave (Step 5)
4. CodeRabbit wave review after each wave (Step 7)
5. Mark wave complete (Step 8)
6. Quality Gate after all waves (Step 9)
7. QA + Fix Loop (Step 10)
8. Mark PROJ-X complete
→ Next PROJ-X
```

After ALL PROJ-X plans complete: Final Summary Report (Step 9).

---

## Orchestration (per PROJ-X)

### 0. Record BASE_SHA

Before any implementation changes, record the current commit:
```bash
git rev-parse HEAD
```
Store this in `progress.md` as `BASE_SHA`. It is used later by the Quality Gate to diff only this feature's changes.

### 1. Read the dependency map

Extract waves from the plan's dependency table:

```
Wave 1: US-1                    → 1 teammate
Wave 2: US-2, US-7 (parallel)   → 2 teammates simultaneously
Wave 3: US-3                    → 1 teammate
...
```

### 2. Before each wave: read `agent.md`, refresh the context bundles

If `agent.md` exists in the source folder, read it before spawning teammates.
Include relevant sections in the teammate prompt so they don't repeat known dead ends.
(Implementers additionally follow the agent.md read/write protocol in `references/implementer.md`;
entries are rendered with `templates/agent-md-entry.md.tmpl`.)

When `specs/.../api-contracts.md` has entries for this wave, recompile the bundles
wave-scoped so `api-contracts-own-wave` is real, and record the new hashes:

```bash
node scripts/compile-context-bundles.mjs compile <X> <theme> --wave <N>
bash scripts/state.sh set <X> <theme> .context.bundles "$(jq -c . specs/PROJ-<X>-<theme>/context/bundles.lock.json)"
```

### 2a. Mark wave start with a git tag

<HARD-GATE>
Before spawning any teammate for wave N, tag the current HEAD as the wave base. `wave-gate.sh` resolves this tag to scope the CodeRabbit diff. Without `WAVE_BASE_SHA` or this tag, the gate fails hard. This prevents accidentally reviewing broad branch history.
</HARD-GATE>

```bash
git tag "wave-${WAVE}-start-PROJ-${PROJ}"
```

One tag per (wave, PROJ) pair. Tags are local-only; do not push. If neither `WAVE_BASE_SHA` nor `wave-${WAVE}-start-PROJ-${PROJ}` exists, `wave-gate.sh` fails hard. There is no `HEAD~20`, commit-message, or root-commit fallback. If the tag already exists from a re-run, delete and re-create: `git tag -d "wave-${WAVE}-start-PROJ-${PROJ}"`.

### 3. Create team and spawn teammates for the wave

Honor the plan's `## Execution` block before spawning: `sequential` means one US at a time even when both are ready. For any frontend wave the lead owns the dev server — start and stop it once per round, agents never start or kill one. Wait for every teammate in the wave before running Ralph, then clean up the team.

Full spawn procedure, the teammate prompt template, context-pack rules and the UI implementation rule: [`references/wave-spawning.md`](references/wave-spawning.md).

### 4. Outer Ralph loop (AC verification per US)

<HARD-GATE>
After EVERY teammate reports back → IMMEDIATELY run Ralph.
This is not optional. This is not "later". This is not "after I commit".
The NEXT thing you do after a teammate completes is verify ACs with actual commands.
Do NOT commit, do NOT proceed to the next wave, do NOT spawn new teammates until Ralph passes.
</HARD-GATE>

After subagents report back, the main agent runs a Ralph loop for each US:

```
RALPH_CAP = 3
iter = 0
while iter < RALPH_CAP and not all ACs pass:
  iter += 1
  for each AC:
    run the deterministic check (test command or direct behavior verification)
    if fail:
      collect exact failure output (test result, error, stack trace)
      spawn fix teammate with: failing AC + verbatim failure output + previous attempts
      update progress.md with iteration details
  re-check all ACs

if iter == RALPH_CAP and not all ACs pass:
  log a "Ralph cap hit" warning in progress.md with the failing ACs + last error
  CONTINUE to next step — do NOT halt, do NOT escalate to user mid-run
```

**Rules for the Ralph loop:**
- Checks must be **deterministic** — run actual test commands, read actual output. No subjective judgment ("this looks like it works").
- A test that depends on state outside itself — provider rate budget, file order, or clock — must establish that state itself or explicitly assert it. Never accept a green result merely because neighbouring tests primed the bucket or fixture.
- Treat “nothing happened” as weak evidence: add a positive control that proves the valid session/input/path would have worked, and do not let polling matchers pass on their first attempt without proving the observed transition.
- Failure output is passed **verbatim** to the fix subagent — not summarized, not interpreted.
- The loop exits when every AC passes OR when the iteration cap is reached.
- **Iteration cap: 3.** A stubborn AC after 3 fix attempts signals an architectural or understanding problem the loop cannot crack. Log it, move on. The PROJ-end Quality Gate and Skill 6 QA will catch unresolved issues with fresh eyes — burning the orchestrator on a stuck loop is more expensive than letting one AC carry forward as a known gap.
- Cap-hit ACs are recorded under `### Ralph Cap Hit (Wave N, US-X)` in `progress.md` with: AC text, last 3 failure outputs, files touched, recommendation. Skill 6 QA reads these as priority test targets.

Update `progress.md` after each Ralph iteration.

### 5. Build check — handled by `wave-gate.sh`

Do not run an extra build between Ralph and the wave gate. Build is intentionally centralized:
- **Wave-end build:** `wave-gate.sh` runs `build_cmd` once per wave.
- **PROJ-end build:** the Quality Gate verifies the assembled PROJ before QA.

If a build failure is discovered by the wave gate, fix it immediately with the verbatim compiler output, then rerun the gate.

### 6. Write learnings to `agent.md`

After a US completes (or after a hard Ralph iteration), write any learnings to the source folder's `agent.md`. Include:
- Walls hit and how they were bypassed
- Surprising behavior in the framework/DB/tooling
- Patterns that worked well
- Dead ends (so future agents don't repeat them)

### 7. Wave review with CodeRabbit — handled by `wave-gate.sh`

<HARD-GATE>
CodeRabbit is MANDATORY, but it is run by `wave-gate.sh`, not as a separate pre-gate command. Do NOT run a second per-wave review outside the gate.
If CodeRabbit fails to execute (e.g., not installed, auth error), the gate exits non-zero. Fix the tool or auth problem and rerun the gate — do NOT silently skip it.
</HARD-GATE>

The wave gate runs CodeRabbit on the wave's changes against the wave base SHA, so cross-cutting issues surface early rather than only at the end in the full Quality Gate. `critical` and `blocker` findings always block, whatever `advisory_severities` says; anything listed in `waves.<N>.advisory_severities` is logged as advisory and does not fail the gate.

**How to handle findings:**
- **Blocking (Critical / High):** the gate fails. Fix immediately — spawn a fix teammate before the next wave. These would only get worse with more code on top.
- **Advisory (Medium / Low):** the gate records them. They are picked up by the full Quality Gate later.

The gate appends its own result to `progress.md` and, when `scripts/ledger.mjs` is present, pipes findings into the ledger. Do not re-enter either by hand.

### 7b. Browser smoke test (if wave touched frontend)

**Skip this step if the wave only contained backend-implementer teammates.**

After the CodeRabbit review, run a quick browser smoke test using `agent-browser` to verify that what was just built actually renders and works. This is NOT the full QA — it's a 60-second gut check.

```bash
# The lead owns this server for the wave; do not start or stop another one.
agent-browser open http://localhost:3000/[route-affected-by-wave]
agent-browser read
agent-browser errors
```

For multiple pages affected by the wave, run one `agent-browser` call per route.

**Pass criteria:** Page renders, no visible errors, primary happy path works.
**Fail:** Stop and fix before the next wave — broken UI compounds fast.

Log the result in `progress.md` under the wave section:
```markdown
### Browser Smoke Test
- Pages tested: [list of URLs]
- Result: PASS / FAIL
- Details: [agent-browser output summary]
```

**Why agent-browser as an option?** It runs as a standalone CLI — no MCP context required. This means it can also be delegated to a teammate if needed. Full browser testing with Playwright or agent browser is reserved for the comprehensive QA in Step 10.

### 7c. Minimalism Review — moved to PROJ-end QA

Ken Takahashi (Minimalism / retrospective review) **no longer runs per wave**. CodeRabbit covers per-wave diff-review; Ken now runs once in Skill 6 against the assembled PROJ with PROJ-level scope. Rationale: per-wave Ken doubled review time without catching what CodeRabbit missed, and bloat is easier to spot in the full PROJ diff than in a single-wave diff.

Skip this step. Continue to Step 8 (wave-gate.sh).

<details>
<summary>Legacy details (kept for reference; do not run)</summary>

The previous per-wave Ken implementation lived here. It is removed in favor of a single PROJ-end Ken pass in Skill 6. The agent.md retrospective entries and AGENTS.md candidate harvesting still happen — just at PROJ scope, not wave scope.

Legacy invocation (per-wave Codex companion / general-purpose subagent at wave-base SHA) is removed. The same persona prompt now runs once at PROJ scope — see Step 9.

</details>

### 8. Mark wave complete, auto-continue to next wave

Run the Wave Gate script (see Wave Completion Gate above):

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <theme>
```

- Exit 0 → script appended `### Wave N Gate — PASSED` block to `progress.md`. Commit the wave. **Immediately proceed to next wave — do NOT pause, do NOT ask the user, do NOT announce "ready for next wave".** The gate already proved the wave is done; the next wave's Step 1 (read dependency map) is the next action.
- Non-zero → read the script's error, fix the failing check (spawn fix teammate if code problem, install missing tool if env problem), re-run. Only a red gate blocks progression — green means keep rolling.

**No stop between waves.** A PROJ with 5 waves should execute as one continuous run: wave 1 → gate ✓ → wave 2 → gate ✓ → … → wave 5 → gate ✓ → Step 9 Quality Gate. Pausing for user confirmation between waves defeats the wave-gate design — the gate IS the signal.

Manual checklist editing in progress.md is no longer sufficient proof of wave completion — only the script's passed-block counts.

### 9. Quality Gate (after all waves, before QA)

After all waves for this PROJ-X are complete and all ACs verified, run the Quality Gate.

See `references/quality-gate.md` for full instructions.

Run code review, the PROJ-end build, optional Sonar and Ken in parallel where safe. The stream setup, tool-availability preflight and result merge are in [`references/quality-gate.md`](references/quality-gate.md) under *Running the gate: parallel streams*.

### 10. QA + Fix Loop

A first-pass QA before the comprehensive Skill 6 pass: browser E2E coordinated by the lead, code-level analysis delegated in parallel, then a bounded fix loop on Critical/High bugs.

Full procedure, spawn prompts and the fix-loop pseudocode: [`references/qa-fix-loop.md`](references/qa-fix-loop.md).

## 11. Handoff to Skill 6 (QA)

<HARD-GATE>
Skill 5 does a first-pass QA in Step 10 (red-team + ui-audit + browser E2E) to catch Critical/High bugs before the Quality Gate proof. **Skill 6 is the comprehensive QA** with the six-persona panel (Chen/Weber/Sharma/Mueller/Rodriguez/Takahashi) + PROJ Retrospective + AGENTS.md candidate collection.

**Framework runs (state.json exists):** seal the phase first —
`bash scripts/state.sh transition <X> <theme> P5 done`. The phase runner
then starts P6 as fresh lanes (read-only QA finder + P6 controller);
do NOT continue into Skill 6 inside this session.

Before invoking Skill 6 (interactive runs), flush context:

1. Run `/compact`. Wave plans, agent chatter, Ralph iterations, and Quality-Gate review output are all on disk in `progress.md` — reclaim the context budget for Playwright or agent-browser testing + persona reviewers.
2. Verify `progress.md` Quality-Gate section is complete (code review + build + Sonar findings or explicit Sonar skip reason logged).
3. Suggest that the user run QA with a different model than the one that executed the implementation, for example GPT reviewing Claude-built work or Claude reviewing GPT-built work.
4. Invoke Skill 6: `/6-qa`. Skill 6 follows its own release gate and hands passing or Medium/Low-only work directly to Skill 7.

**Do NOT skip Skill 6** even if Step 10 reported zero bugs. The persona panel and PROJ retrospectives produce `AGENTS.md` candidates and `## PROJ Retrospective` notes that Skill 7 consumes — skipping them means docs are incomplete.
</HARD-GATE>

## 12. Final Summary Report

After ALL PROJ-X plans are complete AND Skill 6 has finished, present a combined report:

> "All PROJ-X plans implemented and verified.
>
> ## PROJ-A: [topic]
> Implementation:
> - US-1: ✓ (N ACs, N Ralph iterations)
> - US-2: ✓ (N ACs, 0 Ralph iterations)
>
> Quality Gate:
> - Code Review: X found, X fixed, X deferred
> - SonarCloud: X found, X fixed, X deferred OR skipped (reason)
>
> QA:
> - [N] bugs found, [N] fixed, [N] Medium/Low deferred
> - Production-ready: YES / NO
>
> ## PROJ-B: [topic]
> ...
>
> Learnings documented in `src/features/[feature]/agent.md`.
> Progress logs at `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md`."

---

## Subagent Responsibility (per US)

Each subagent:
1. Reads `agent.md` if provided in the prompt
2. Implements all tasks for its US in order (TDD per task — see below)
3. Reports task status after each TDD cycle; the lead updates `progress.md` and commits for parallel waves
4. Runs an **inner Ralph loop** (2-stage review) after all tasks complete
5. Reports back with full detail

The subagent does NOT verify ACs — that is the main agent's outer Ralph loop.

### TDD cycle (per task)

No production code without a failing test first.

**RED:** Write one failing test. Run it — verify it fails for the expected reason (missing feature, not import error).

**GREEN:** Write the simplest code to pass. Run ALL tests — new + existing must pass.

**REFACTOR:** Remove duplication, improve names. No new behavior. Re-run tests.

Never claim a test passes without running the command and reading actual output.

### Inner Ralph loop (2-stage review, after all tasks in US)

```
while review not clean:
  Stage 1 — Spec compliance (references/spec-reviewer.md):
    read actual code, verify against task requirements
    if issues: fix (critical first), re-run tests, repeat Stage 1
  Stage 2 — Code quality (references/code-reviewer.md):
    only runs after Stage 1 passes
    if issues: fix, re-run tests, repeat Stage 2
```

Escalate to main agent only if a fix requires spec/architecture changes.

---

## When Something Breaks

Do NOT guess. Consult the `systematic-debugging` reference skill:

**Phase 1 — Root Cause Investigation:**
1. Read the full error message and stack trace — not a summary
2. Reproduce the failure consistently
3. Check `git diff` — what changed since it last worked?
4. Trace data flow from input to failure point

**Phase 2 — Hypothesis and Fix:**
1. Form ONE hypothesis, test with the smallest possible change
2. Write a failing test reproducing the bug, then fix
3. Run ALL tests — the fix must not introduce regressions

**The 3-Fix Rule:** If 3+ fix attempts fail on the same bug → STOP. This is an architectural or understanding problem. Escalate to the user with full iteration history.

**Always write the wall + workaround to `agent.md` when you find one.**

**Escalate to user if:**
- Outer Ralph has run 3+ iterations on the same AC
- Root cause is in the spec or architecture
- Missing dependency, broken environment, external service down
- Requirements are ambiguous or contradictory

---

## Commit Format

```
feat(PROJ-<X>-PRD-<Y>): implement [US-N task name]
fix(PROJ-<X>-PRD-<Y>): address review findings for [US-N]
fix(PROJ-<X>): address quality gate findings
```

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/` → `1d_mockups/` · `3_PRDs/` → `2_PRDs/` ·
`8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are**. Never
create a second folder next to it — a split PROJ is worse than an old name.
Say it once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the
> current names, or continue with the existing layout?"

Renaming is a `git mv` per folder plus a search for the old paths in the
PROJ's own documents. It is never a precondition for this skill.
