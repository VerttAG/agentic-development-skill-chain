# Security Audit — 2026-08-09

- **Repository:** `silviobeer/agentic-development-skill-chain`
- **Audited commit:** `0a9c302a5ce231765b02878f698234d7adc720df` (`main`)
- **Verdict:** Not safe for unattended execution on a credentialed host as-is
- **Findings:** 1 Critical, 1 High, 2 Medium

## Executive Summary

No malicious payload, backdoor, or committed credential was identified in the
tracked source or its 44-commit history. The audited commit matched the remote
`main` branch and passed Git object integrity checks.

The project is nevertheless not safe for its intended unattended host workflow.
The default Claude writer bypasses interactive permission checks without an
enforced container boundary. A target-controlled role name can also escape the
context output directory and overwrite writable Markdown files. Two additional
input-validation defects can corrupt workflow state or execute shell command
substitution from a timeout value.

A passive clone or source review is low risk. Do not run the autonomous phase
runner on a host containing credentials or valuable data until the Critical and
High findings are fixed. A disposable container or VM with a repo-only mount,
minimal credentials, and restricted outbound network access reduces exposure
but does not replace the required fixes.

## Severity Summary

| ID | Severity | Finding |
|---|---|---|
| SEC-01 | Critical | Default unattended Claude writer bypasses permission prompts without enforced host isolation |
| SEC-02 | High | Unvalidated role manifest names permit output-path traversal |
| SEC-03 | Medium | `state.sh set` permits jq-expression injection and phase-transition bypass |
| SEC-04 | Medium | Unvalidated timeout values permit command substitution through Bash arithmetic |

## Findings

### SEC-01 — Permission bypass without enforced isolation

**Evidence**

- [`runner/run-phase.sh`](../runner/run-phase.sh#L196-L200) launches the default
  Claude writer with `--dangerously-skip-permissions`.
- [`project-settings-template.json`](../claude/skills/5_executing/references/project-settings-template.json#L13-L15)
  sets `defaultMode` to `bypassPermissions`.
- The same template permits broad operations including `Bash(bash -c*)`,
  `Bash(node *)`, `Bash(npx *)`, `Bash(gh api*)`, ordinary Git pushes,
  Supabase SQL and migrations, and Vercel deployment.
- Its deny list starts at
  [`project-settings-template.json:238`](../claude/skills/5_executing/references/project-settings-template.json#L238)
  and blocks selected command spellings rather than providing a host boundary.
- Container isolation is proposed as a future improvement in
  [`CONCEPT.md`](../CONCEPT.md#L1343-L1351); the runner does not enforce it.

The generated code graph found 209 allow-community nodes and 39 deny-community
nodes in the Claude template. A focused comparison identified at least 43 broad
allow-side capabilities without an exact deny-side counterpart, grouped into:

- shell and script trampolines such as `.`, `source`, `bash -c`, `node`,
  `deno`, `env`, `find`, `xargs`, and repository-controlled scripts;
- package execution through `npx`, `npm exec`, `pnpm dlx`, `bunx`, and package
  installation lifecycle hooks;
- external control through `gh api`, Git pushes, and Vercel environment access;
- Supabase SQL, migrations, branch operations, and Supabase/Vercel deployments;
- file and process mutation through `Write`, `Edit`, `cp`, `mv`, `tee`, links,
  `kill`, and `pkill`.

This graph comparison proves configuration coverage gaps, not that every listed
operation bypasses Claude Code's runtime matcher. Runtime matcher behavior must
be tested separately.

**Impact**

An unattended model can execute shell commands and mutate local or remote
systems with the user's filesystem, GitHub, cloud, and database credentials.
The incomplete deny list is not sufficient containment if the model, repository
content, dependency scripts, or tool output is hostile.

**Required remediation**

1. Remove `--dangerously-skip-permissions` from the default runner path.
2. Change the template default away from `bypassPermissions`.
3. Disable bypass mode in managed settings where available.
4. Require an actual container or VM boundary for unattended runs.
5. Mount only the target repository, expose minimal short-lived credentials,
   and restrict outbound network destinations.
6. Replace broad interpreter/API rules with narrow task-specific capabilities.

Anthropic's current guidance likewise treats unrestricted Bash as safe only
inside an isolation boundary or behind a strong command classifier. Claude's
built-in Bash sandbox does not cover Write, Web, MCP, hooks, or other tools; see
the official [permissions](https://code.claude.com/docs/en/permissions) and
[security](https://code.claude.com/docs/en/security) documentation.

### SEC-02 — Role-name path traversal

**Evidence**

- [`rolesDir()`](../codex/skills/4b_setup/scripts/compile-context-bundles.mjs#L69-L73)
  permits a target repository to provide `templates/roles/*.md` manifests.
- [`loadManifests()`](../codex/skills/4b_setup/scripts/compile-context-bundles.mjs#L124-L136)
  validates required fields and injection source IDs but does not validate
  `fm.name`.
- The name is interpolated into output paths at
  [`compile-context-bundles.mjs:245`](../codex/skills/4b_setup/scripts/compile-context-bundles.mjs#L245-L257)
  and Claude agent paths at
  [`compile-context-bundles.mjs:282`](../codex/skills/4b_setup/scripts/compile-context-bundles.mjs#L282).

A disposable fixture with the manifest name
`x/../../../../escaped-audit` caused compilation to write outside both the
context output directory and the target repository, including
`/private/tmp/escaped-audit.md`. The proof files were removed after verification.

**Impact**

A malicious or compromised target repository can overwrite writable Markdown
files reachable from the runner's working directory. The impact is greater in
the unattended writer lane because that lane is not host-isolated.

**Required remediation**

- Validate role names with a strict slug expression such as
  `^[a-z0-9][a-z0-9-]*$`.
- Resolve every destination to an absolute path and reject it unless it remains
  within the intended output directory.
- Apply the containment check in the shared compiler before any write or
  removal operation.
- Add one regression test covering `..`, path separators, absolute paths, and
  encoded separator variants.

### SEC-03 — jq-expression injection in workflow state

**Evidence**

[`state.sh`](../codex/skills/4b_setup/scripts/state.sh#L138-L146) accepts a
caller-provided `PATH_EXPR`, blocks only the exact strings `.phase` and
`.status`, and then interpolates the remaining expression into a jq program.

In a disposable state fixture, the expression
`.audit_marker = true | .phase` changed the state directly from `CP1` to `P5`
and inserted an arbitrary field, bypassing the required `transition` command.

**Impact**

Callers can forge phase, status, or other workflow state and bypass the
framework's transition checks. This is a control-plane integrity issue rather
than direct host command execution.

**Required remediation**

- Accept only explicitly supported state paths.
- Prefer jq `setpath()` with path segments supplied through `--argjson` instead
  of interpolating executable jq syntax.
- Reject expressions containing operators, pipes, brackets outside the allowed
  path grammar, or protected fields at any position.
- Add a regression test using the demonstrated compound expression.

### SEC-04 — Bash arithmetic command injection

**Evidence**

- [`runner/run-phase.sh`](../runner/run-phase.sh#L46-L53) accepts `--timeout`
  without numeric validation.
- The value is later evaluated by Bash arithmetic at
  [`run-phase.sh:227`](../runner/run-phase.sh#L227).
- The cross-review adapters repeat the pattern at
  [`review-with-claude.sh`](../claude/skills/cross-review/scripts/review-with-claude.sh#L14-L47)
  and
  [`review-with-codex.sh`](../claude/skills/cross-review/scripts/review-with-codex.sh#L14-L48).

A harmless marker probe confirmed that an array-subscript expression containing
command substitution executes when Bash recursively evaluates the timeout
value.

**Impact**

A caller that controls the timeout or related environment input can execute a
command with the runner's privileges. The current intended caller is local,
which limits exposure, but wrappers and automation can turn this into a trust
boundary.

**Required remediation**

Validate every arithmetic input before evaluation, for example with
`^[0-9]+$`, then enforce a reasonable non-zero upper bound. Apply the same
validation to `TIMEOUT`, `PEER_GRACE`, review timeouts, and wave numbers.

## Additional Security Exposures

These are important trust assumptions but were not counted as separate
vulnerabilities:

- [`wave-gate.sh`](../codex/skills/5_executing/scripts/wave-gate.sh#L247)
  intentionally executes repository-configured acceptance, build, and Sonar
  commands through `bash -c`. Only trusted configuration should reach this gate.
- [`preflight.sh`](../codex/skills/4b_setup/scripts/preflight.sh#L141-L146)
  invokes unpinned `npx supabase --version` when a local Supabase CLI is absent,
  which can download and execute the current registry package during preflight.
- The workflow sends repository material to configured external model, review,
  browser, Sonar, GitHub, Supabase, and Vercel services. Proprietary repositories
  need an explicit data-handling review before use.

## Positive Checks

- The audited HEAD matched remote `main` at review time.
- `git fsck --full --strict` completed successfully.
- High-confidence credential patterns found no committed secret in the current
  tree or the 44-commit history.
- No tracked binary payloads, symlinks, submodules, bidirectional control
  characters, or dependency manifests were found.
- There are no package dependency manifests, so a conventional dependency CVE
  audit was not applicable to this repository.
- A clean archive of the exact tracked commit passed `scripts/validate.sh`.
- The component registry self-test passed.
- Wave-gate negative controls passed under Bash 5.

## Reliability Findings Affecting Safe Operation

These failures are not independently classified as security vulnerabilities,
but they prevent a clean readiness conclusion:

- The wave-gate test fails under macOS system Bash 3.2 because `mapfile` is not
  available. The repository does not enforce or clearly preflight Bash 4+.
- `setsid` is absent by default on macOS, while phase and review scripts depend
  on it without a preflight check.
- The stage-two spike passed 27 of 39 assertions. Its first independent failure
  was the context compiler returning success and changing output state during a
  budget breach, contrary to
  [`spike-stage2.sh`](../runner/spike-stage2.sh#L92-L96). Missing `setsid`
  produced additional cascading failures.
## Incomplete Runtime Permission Matrix

A runtime matrix was started for direct `rm -rf` denial versus indirect
execution through `bash -c`, Node, local `npx` and `gh` recording shims, and a
local fake Supabase MCP server. No real GitHub, package registry, Supabase,
Vercel, or production endpoint was contacted.

The outer macOS sandbox passed its controls: it permitted a marker inside the
disposable fixture and blocked a marker outside it. Claude Code reported
version `2.1.226` and `permissionMode: bypassPermissions`. The actual command
matrix did not run: baseline Bash initialization required additional Claude
session and shell-snapshot paths, and remained blocked by the outer write
boundary as the harness was tightened. Testing was stopped at the user's
request before any victim-directory deletion or MCP tool call occurred.

Therefore this audit does **not** claim runtime proof that a nested command
bypasses a deny rule. SEC-01 is supported by the source configuration, the
unisolated runner design, official security guidance, and the broad capability
surface; runtime matcher behavior remains an explicit follow-up item.

## Scope and Limitations

This review combined source inspection, Git history checks, high-confidence
secret scanning, graph-assisted flow mapping, clean-archive validation,
targeted disposable proofs, and partial isolated CLI testing.

Semgrep, Gitleaks, TruffleHog, and ShellCheck were not installed and were not
added during the audit. GitHub's public security-advisory query returned no
entries, but the code-scanning alerts endpoint returned HTTP 403 with the
available credentials. Absence of a reported finding is not proof that no
unknown vulnerability exists.

## Minimum Safe-Use Gate

Do not approve unattended host use until all of the following are true:

1. SEC-01 and SEC-02 are fixed and covered by regression tests.
2. SEC-03 and SEC-04 are fixed or their inputs are provably inaccessible to
   untrusted callers.
3. The full validation and stage-two spike pass on every supported platform.
4. Runtime permission tests confirm deny behavior for nested interpreters,
   repository scripts, package runners, generic APIs, and MCP mutations.
5. The runner enforces an isolation boundary rather than merely recommending
   one in documentation.
