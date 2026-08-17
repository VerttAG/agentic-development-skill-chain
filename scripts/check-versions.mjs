#!/usr/bin/env node
// Version consistency guard across every host manifest.
//
// Two separate failures are possible and both matter:
//   1. The manifests disagree with each other.
//   2. The manifests agree with each other but are ALL stale. Mutual agreement
//      passes a naive equality test, so on a tag push the shared version is
//      also compared against the tag itself.
//
// Add new host manifests to VERSION_FILES so a future ecosystem cannot drift
// unnoticed. No dependencies.

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PINNED_SEMVER = /^\d+\.\d+\.\d+$/;

// path -> how to pull the version out, and who reads the file.
const VERSION_FILES = [
  { file: '.claude-plugin/plugin.json',      pick: (j) => j.version,             reader: 'Claude Code (/plugin install)' },
  { file: '.claude-plugin/marketplace.json', pick: (j) => j.plugins?.[0]?.version, reader: 'Claude Code marketplace listing' },
  { file: '.codex-plugin/plugin.json',       pick: (j) => j.version,             reader: 'Codex CLI and ChatGPT' },
  { file: 'gemini-extension.json',           pick: (j) => j.version,             reader: 'Gemini CLI and Antigravity' },
];

let failed = false;
const fail = (msg) => { console.error(`FAIL  ${msg}`); failed = true; };
const ok = (msg) => console.log(`ok    ${msg}`);

const found = [];
for (const { file, pick, reader } of VERSION_FILES) {
  const p = join(ROOT, file);
  if (!existsSync(p)) { fail(`${file} is missing (read by ${reader})`); continue; }
  let json;
  try { json = JSON.parse(readFileSync(p, 'utf8')); }
  catch (e) { fail(`${file} does not parse: ${e.message}`); continue; }
  const v = pick(json);
  if (!v) { fail(`${file} declares no version (read by ${reader})`); continue; }
  if (!PINNED_SEMVER.test(v)) {
    fail(`${file} version "${v}" is not a pinned X.Y.Z — floating refs like "latest" break update detection`);
    continue;
  }
  found.push({ file, v });
}

if (failed) process.exit(1);

const versions = [...new Set(found.map((f) => f.v))];
if (versions.length !== 1) {
  fail('manifests disagree on the version:');
  for (const { file, v } of found) console.error(`        ${v}  ${file}`);
  process.exit(1);
}

const shared = versions[0];
ok(`${found.length} manifests agree on ${shared}`);

// On a tag push the shared version must equal the tag. This is the check that
// mutual agreement alone cannot make: every manifest can be stale together.
if (process.env.GITHUB_REF_TYPE === 'tag') {
  const tag = (process.env.GITHUB_REF_NAME || '').replace(/^v/, '');
  if (PINNED_SEMVER.test(tag) && tag !== shared) {
    fail(`tag v${tag} does not match the manifest version ${shared} — every manifest is stale together`);
    process.exit(1);
  }
  ok(`tag matches manifest version (${shared})`);
}

// Claude Code and Codex detect updates from the version string, never from git
// tags or releases. Shipping changes without a bump leaves every existing
// install on its cached copy.
console.log('\ncheck-versions: ok');
