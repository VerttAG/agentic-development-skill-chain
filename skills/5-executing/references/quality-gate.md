# Quality Gate

Runs once per PROJ-X after all waves complete and all ACs are verified.
Must pass before handing off to QA.

## Prerequisites

- All waves complete, all ACs verified by outer Ralph loop
- Record `BASE_SHA` (commit before first implementation change) at the start of execution

---

## Gate 1: Code Review Expert

Full review of the entire feature diff — catches cross-cutting issues the per-US inner Ralph loop may miss.

### Steps

1. Get the feature diff:
   ```bash
   git diff BASE_SHA..HEAD --stat    # scope overview
   git diff BASE_SHA..HEAD           # full diff
   ```

2. Review using the full checklist from `references/code-reviewer.md`:
   - Architecture & SOLID
   - Security & Reliability
   - Error Handling
   - Performance
   - Boundary Conditions
   - Testing
   - Holistic "What Would I Do Better?"

3. Classify findings by severity:
   - **P0 Critical** — Security vulnerability, data loss risk, correctness bug → must fix
   - **P1 High** — Logic error, significant SOLID violation, performance regression → must fix
   - **P2 Medium** — Code smell, maintainability concern → log for user decision
   - **P3 Low** — Style, naming, minor suggestion → log only

4. Fix all P0/P1:
   - Spawn fix subagent per issue (or batch related issues)
   - Re-run all tests after fixes
   - Re-review the fix diff to ensure no regressions

5. Log P2/P3 to `5_progress/PROJ-<X>-progress.md` under the Quality Gate section.

---

## Gate 2: Optional Sonar Scan

Fetch fresh SonarQube Cloud/Server issues for files touched by this feature when both Sonar CLIs are available.

### Preflight

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both commands exist, run this gate using the `sonar-cli` skill guidance.
- If either command is missing, skip this gate and record `SonarCloud: skipped (sonar CLI unavailable)` in `5_progress/PROJ-<X>-progress.md`.
- If both commands exist but the project has no Sonar config and no explicit user/plan requirement to create one, skip this gate and record `SonarCloud: skipped (project not configured)`.
- A skipped Sonar gate does not block QA handoff.

### Steps

1. Get the list of files changed by this feature:
   ```bash
   git diff BASE_SHA..HEAD --name-only
   ```

2. Run the Sonar scanner to upload the latest code for analysis:
   ```bash
   sonar-scanner
   ```
   If the repo provides a matching script such as `npm run sonar` that runs coverage first and then `sonar-scanner`, use that script instead. Wait for the scan to complete before proceeding.

3. Fetch current Sonar issues, measures, and quality-gate status:
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   sonar list issues --project <project-key> --branch "$BRANCH" --page-size 500
   sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc"
   sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
   ```

4. Filter issues to only files from step 1.

5. Classify by SonarCloud severity:
   - **BLOCKER / CRITICAL** → must fix
   - **MAJOR** → must fix (treat as P1)
   - **MINOR** → log for user decision
   - **INFO** → log only

6. Fix all BLOCKER/CRITICAL/MAJOR:
   - Spawn fix subagent with the sonar issue details (file, line, message, rule)
   - Re-run tests after fixes
   - Update `scripts/sonar-tracker.md` if it exists (mark fixed items `[x]`)

7. Log MINOR/INFO to `5_progress/PROJ-<X>-progress.md`.

---

## Exit Criteria

The quality gate passes when ALL of these are true:

- [ ] Zero P0/P1 code review findings remain
- [ ] Full PROJ build passes (`build_cmd` from `wave-gate-config.json`) — the last wave gate already built the project, so this only needs rerunning after Quality-Gate fixes touch code
- [ ] If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues in feature files
- [ ] If Sonar was skipped: explicit skip reason is logged
- [ ] All tests still passing (`npm run test`)
- [ ] No new lint errors (`npm run lint`)

If the gate cannot pass after 3 fix iterations on the same issue, escalate to user.

---

## Progress Tracking

Update `5_progress/PROJ-<X>-progress.md` with a Quality Gate section after running:

```markdown
## Quality Gate — PROJ-X

### Code Review
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 2 | 2 | 0 |
| P2 Medium | 1 | 0 | 1 |
| P3 Low | 3 | 0 | 3 |

### SonarCloud
Status: ran | skipped (sonar CLI unavailable) | skipped (project not configured)

| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| Critical | 0 | 0 | 0 |
| Major | 1 | 1 | 0 |
| Minor | 4 | 0 | 4 |
| Info | 2 | 0 | 2 |

### Fixed Issues
- P1: `src/features/foo/bar.ts:42` — Missing null check → fixed in abc123
- Major: `src/features/foo/baz.ts:10` — Cognitive complexity 19 → refactored in def456

### Deferred (user decision)
- P2: `src/features/foo/qux.ts:88` — Data clump, 3 params passed together
- Minor: `src/features/foo/utils.ts:15` — Prefer replaceAll over replace with regex
```

---

## Running the gate: parallel streams

> Moved out of SKILL.md; this is the operational detail for Step 9.

**Run code review, PROJ-end build, optional Sonar, and Ken in parallel where safe:**

Before launching the Sonar stream, check tool availability:

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both CLIs are available, run the Sonar quality-gate stream using the `sonar-cli` skill guidance.
- If either CLI is missing, skip Sonar and record `SonarCloud: skipped (sonar CLI unavailable)` in `progress.md`. Missing Sonar tooling does not block execution or QA handoff.

```
Create an agent team for Quality Gate of PROJ-X.

Spawn teammates:
- "reviewer" using the code-reviewer-gate agent type with prompt:
  "Review the feature diff from BASE_SHA=$BASE_SHA. Check references/code-reviewer.md for the full checklist."
- "sonar" only if `sonar` and `sonar-scanner` are installed, using the sonar-cli skill with prompt:
  "Run the Sonar quality-gate stream for files changed since BASE_SHA=$BASE_SHA. Use sonar-scanner for project analysis and sonar CLI/API for quality gate, issue, coverage, and duplication data. If project Sonar config is absent, log SonarCloud as skipped rather than blocking."
- "ken" using the general-purpose agent type (or codex companion if installed) with prompt:
  "You are Ken Takahashi, Minimalism Engineer with 20 years of experience (ex-kernel contributor, library author who ships small). SCOPE: only files touched between $BASE_SHA and HEAD — do NOT comment on unchanged code. Two questions: (1) Is every piece of NEW code earning its keep? Call out YAGNI, premature abstraction, layers with one caller, boilerplate duplicating framework features, dead pathways, speculative options. (2) What should we have done differently given what we know now? Propose concrete simplifications. Report Critical/High/Medium/Low findings with file:line. Separately emit 'agent.md retrospective' one-liners and 'AGENTS.md candidates' (≤ 120 chars each, project-wide rules). Pre-compute the diff: git diff --stat $BASE_SHA..HEAD > /tmp/ken-stat.txt and git diff $BASE_SHA..HEAD > /tmp/ken-diff.patch — review only that patch."
```

The lead also runs `build_cmd` from `wave-gate-config.json` once for the assembled PROJ. The lead consolidates reviewer, build, optional Sonar, and Ken results.

**Ken's outputs flow into:**
- Critical/High findings → fix-spawn cluster (same parallel-by-file pattern as code-reviewer findings).
- agent.md retrospective entries → append to relevant `src/features/<feature>/agent.md` under `## Retrospective (from Ken)`.
- AGENTS.md candidates → append to `## AGENTS.md Candidates` in `progress.md` with `— source: Ken Takahashi (Minimalism)`.

**After teammates report — Handling Findings with Technical Rigor:**

Do NOT blindly implement every finding. Apply the `receiving-code-review` discipline:

1. **READ** each finding carefully — understand what the reviewer is flagging
2. **VERIFY** — Does this finding apply? Check the actual code. Reviewers (human or automated) can be wrong.
3. **EVALUATE** — Is this a real problem or a false positive?
   - **Push back when:** The finding breaks existing functionality, violates YAGNI (suggests "proper" patterns for unused scenarios), is technically incorrect, or conflicts with the user's explicit decisions
   - **YAGNI check:** If a reviewer suggests adding error handling for a scenario that can't happen, or abstracting code that's used once — grep the codebase for actual usage before implementing
4. **FIX** what's real — spawn fix teammates for confirmed P0/P1 and Sonar BLOCKER/CRITICAL/MAJOR issues
5. **LOG** P2/P3 and Sonar MINOR/INFO to `progress.md` — these are addressed if time permits
6. Clean up the team

**Exit criteria:**
- Zero P0/P1 code review findings
- `build_cmd` from `wave-gate-config.json` passes once for the assembled PROJ
- If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues in feature files
- If Sonar was skipped because CLIs or project config were unavailable: the skip reason is logged in `progress.md`
- All tests passing, no new lint errors

Update `progress.md` with Quality Gate results.
