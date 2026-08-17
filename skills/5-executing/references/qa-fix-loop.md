# 10. QA + Fix Loop

> Reference for the 5-executing skill. Loaded on demand.

**IMPORTANT:** The lead coordinates browser E2E testing (Playwright or agent browser + `npm run dev`). Code-level analysis runs in parallel as agent team teammates.

**How to run QA:** Create an agent team that splits QA work:

```
Create an agent team for QA of PROJ-X.

Spawn teammates:
- "red-team" using the red-team-tester agent type with prompt:
  "Test feature PROJ-X for security vulnerabilities and edge cases.
   Read PRDs at specs/PROJ-<X>-<theme>/2_PRDs/*.md for acceptance criteria.
   Focus on: injection attacks, auth bypass, boundary values, race conditions."
- "ui-audit" using the ui-auditor agent type with prompt:
  "Audit PROJ-X UI changes for design system compliance.
   BASE_SHA=$BASE_SHA. Check colors, typography, spacing, components, responsive."
```

**In parallel, the lead runs browser E2E testing directly:**
1. Start dev server (`npm run dev`)
2. Use Playwright or agent-browser tools to test every AC in the browser
3. Take snapshots and screenshots as evidence
4. Document findings

**After all QA sources report:**
1. Merge findings from lead (browser E2E), red-team, and ui-audit into `progress.md`
2. Clean up the team

```
while QA reports Critical or High bugs:
  for each Critical/High bug (in severity order):
    spawn fix teammate with: bug description + reproduction steps + verbatim failure output
    after fix: re-run the specific test that caught the bug to confirm it passes
  re-run relevant QA checks for full regression pass

if only Medium/Low bugs remain:
  framework run (state.json exists) — autonomy policy §8, no user question:
    auto-defer every Medium/Low as debt — ledger record
    (node scripts/ledger.mjs add <X> <theme>, status deferred) plus a
    `ponytail:` marker where applicable; the human decides at Checkpoint 2
  interactive run (no state.json):
    present to user and ask: "Which bugs should be fixed before release?"
    fix user-selected bugs, then re-run QA one final time
```

**Rules:**
- Do NOT skip QA — it runs automatically after every Quality Gate, not on request.
- Browser E2E (Playwright or agent browser) MUST be coordinated by the lead; delegate only if the browser automation tool is available to the teammate.
- Red-team and ui-audit teammates work on code-level analysis in parallel with browser testing.
- Fix subagents receive the verbatim bug report from QA (never a summary).
- After each fix, re-run the specific failing test before the next QA pass.
- If the same bug persists after 3 fix attempts: interactive run — escalate to user with full history; framework run — STOP CONDITION (§8): park the run (rescue branch, state → blocked, stop report), never keep retrying past the cap.
- QA is considered clean only when it reports no Critical or High bugs.

Update `progress.md` with QA results. Mark this PROJ-X as complete.

---
