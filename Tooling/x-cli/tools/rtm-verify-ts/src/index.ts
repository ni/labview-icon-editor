/*
  RTM Verify (TypeScript)
  - Reads docs/traceability.yaml
  - Detects changed files (PR base/head if available; else HEAD~1..HEAD)
  - For in-scope requirements (mapping or docs/srs changed, or touched src/** matches code globs),
    validates:
      * id matches ^FGC-REQ-[A-Z]+-\d{3,}$
      * source path exists
      * code/tests glob arrays expand to at least one existing path
  - Prints a colorized, grouped report
  - Optionally posts a PR comment when --comment is passed (uses GITHUB_TOKEN)
*/

import { execSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import fg from 'fast-glob';
import { Minimatch } from 'minimatch';
import YAML from 'yaml';

type ReqEntry = {
  id?: string;
  desc?: string;
  source?: string;
  code?: string[];
  tests?: string[];
  commits?: string[];
};

type Traceability = { requirements?: ReqEntry[] };

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m'
};

function c(color: keyof typeof colors, s: string): string {
  return colors[color] + s + colors.reset;
}

function repoRootFromHere(): string {
  // dist/index.js -> dist -> tools/rtm-verify-ts -> x-cli -> repo root
  // src layout mirrors dist, so this resolves correctly at runtime
  const here = path.dirname(fileURLToPath(import.meta.url));
  const root = path.resolve(here, '..', '..', '..');
  return root;
}

function sh(args: string[], silent = true): string {
  try {
    const out = execSync(args.join(' '), { encoding: 'utf-8', stdio: silent ? ['ignore', 'pipe', 'ignore'] : 'pipe' });
    return out.trim();
  } catch {
    return '';
  }
}

function getChangedFiles(): string[] {
  const base = process.env.GITHUB_BASE_REF;
  if (base) {
    // Ensure base is fetched (safe if already present)
    sh(['git', 'fetch', 'origin', base]);
    const out = sh(['git', 'diff', '--name-only', `origin/${base}...HEAD`]);
    return out ? out.split('\n').map(s => s.trim()).filter(Boolean) : [];
  }
  const out = sh(['git', 'diff', '--name-only', 'HEAD~1', 'HEAD']);
  return out ? out.split('\n').map(s => s.trim()).filter(Boolean) : [];
}

function parseArgs(argv: string[]) {
  const args = new Set<string>();
  const kv: Record<string, string> = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const [k, v] = a.includes('=') ? a.split('=', 2) : [a, ''];
      args.add(k);
      if (v) kv[k] = v;
      if (!v && i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        kv[k] = argv[++i];
      }
    }
  }
  return { args, kv };
}

function loadTraceability(root: string): Traceability {
  const p = path.join(root, 'docs', 'traceability.yaml');
  if (!existsSync(p)) throw new Error('docs/traceability.yaml not found');
  const txt = readFileSync(p, 'utf-8');
  const data = YAML.parse(txt) as Traceability;
  return data ?? { requirements: [] };
}

function globExpand(root: string, patterns: string[] | undefined): string[] {
  if (!patterns || patterns.length === 0) return [];
  const results = fg.sync(patterns, { cwd: root, dot: true, onlyFiles: false, absolute: false, unique: true });
  return Array.from(new Set(results)).sort();
}

function matchAny(patterns: string[], file: string): boolean {
  return patterns.some(p => new Minimatch(p, { dot: true, nocase: false }).match(file));
}

function detectScope(changed: string[], entry: ReqEntry): boolean {
  const reqChanged = changed.some(p => p === 'docs/traceability.yaml' || p.startsWith('docs/srs/'));
  if (reqChanged && entry.source) return true;
  const touchedSrc = changed.filter(p => p.startsWith('src/'));
  if (touchedSrc.length && entry.code && entry.code.length) {
    // If any changed src file matches any code glob, this entry is in-scope
    return touchedSrc.some(f => matchAny(entry.code!, f));
  }
  return false;
}

const ID_RE = /^(?:FGC|AGENT)-REQ-[A-Z]+-\d{3,}$/;

type EvalResult = {
  entry: ReqEntry;
  idOk: boolean;
  srcOk: boolean;
  codeOk: boolean;
  testsOk: boolean;
  codeExpanded: string[];
  testsExpanded: string[];
  reasons: string[];
};

async function maybePostComment(body: string, prNumber?: number, tokenEnv = 'GITHUB_TOKEN'): Promise<void> {
  const token = process.env[tokenEnv] || process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  const repoFull = process.env.GITHUB_REPOSITORY || '';
  const [owner, repo] = repoFull.split('/');

  // Derive PR number from event payload if not provided
  if (!prNumber) {
    try {
      const eventPath = process.env.GITHUB_EVENT_PATH;
      if (eventPath && existsSync(eventPath)) {
        const payload = JSON.parse(readFileSync(eventPath, 'utf-8'));
        prNumber = payload?.pull_request?.number;
      }
    } catch { /* ignore */ }
  }

  if (!token || !owner || !repo || !prNumber) {
    console.log(c('dim', '[rtm-verify] PR commenting skipped (missing token or PR context).'));
    return;
  }

  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ body })
  });

  if (!res.ok) {
    const t = await res.text().catch(() => '');
    console.log(c('yellow', `[rtm-verify] Failed to post PR comment (${res.status}): ${t}`));
    return;
  }
  console.log(c('dim', '[rtm-verify] PR comment posted.'));
}

async function main() {
  const { args, kv } = parseArgs(process.argv);
  const wantAll = args.has('--all');
  const wantComment = args.has('--comment');
  const onlyOnFailure = args.has('--only-on-failure');
  const prOverride = kv['--pr'] ? Number(kv['--pr']) : undefined;
  const tokenEnv = kv['--token-env'] || 'GITHUB_TOKEN';
  const jsonOut = kv['--json-out'];

  const root = repoRootFromHere();
  const mappingPath = path.join(root, 'docs', 'traceability.yaml');
  if (!existsSync(mappingPath)) {
    console.error(c('red', 'docs/traceability.yaml not found'));
    process.exit(2);
  }

  const changed = wantAll ? [] : getChangedFiles();
  const data = loadTraceability(root);
  const entries = data.requirements ?? [];

  const inScope: ReqEntry[] = entries.filter(e => wantAll || detectScope(changed, e));
  const outOfScopeCount = entries.length - inScope.length;

  const results: EvalResult[] = inScope.map(entry => {
    const rid = (entry.id || '').trim();
    const idOk = ID_RE.test(rid);
    const src = (entry.source || '').trim();
    const srcOk = src ? existsSync(path.join(root, src)) : false;
    const codeExpanded = globExpand(root, entry.code);
    const testsExpanded = globExpand(root, entry.tests);
    const codeOk = (entry.code && entry.code.length) ? (codeExpanded.length > 0) : true;
    const testsOk = (entry.tests && entry.tests.length) ? (testsExpanded.length > 0) : true;
    const reasons: string[] = [];
    if (!idOk) reasons.push('invalid id shape');
    if (!srcOk) reasons.push(`missing source: ${src || '(none)'}`);
    if (!codeOk) reasons.push(`no code paths for globs: ${JSON.stringify(entry.code || [])}`);
    if (!testsOk) reasons.push(`no tests for globs: ${JSON.stringify(entry.tests || [])}`);
    return { entry, idOk, srcOk, codeOk, testsOk, codeExpanded, testsExpanded, reasons };
  });

  const failures = results.filter(r => !(r.idOk && r.srcOk && r.codeOk && r.testsOk));
  const passes = results.length - failures.length;

  // Header
  console.log(`${c('bold', 'RTM Verify Report')} ${c('dim', '(changed requirements / touched src/**)')}`);
  if (changed.length) {
    console.log(c('dim', 'Changed files:'));
    for (const f of [...changed].sort()) console.log(c('dim', `- ${f}`));
  } else if (!wantAll) {
    console.log(c('dim', 'No changed files detected (diff against HEAD~1).'));
  }
  console.log('');

  // Summary line
  const summary = `In-scope: ${inScope.length}, Passed: ${passes}, Failed: ${failures.length}, Out-of-scope: ${outOfScopeCount}`;
  console.log(`${c('blue', summary)}\n`);

  if (failures.length) {
    console.log(c('bold', 'Failures'));
    console.log('| ReqID | ID shape | source exists | code linked | tests linked |');
    console.log('|---|:---:|:---:|:---:|:---:|');
    for (const r of failures) {
      const rid = (r.entry.id || '(missing id)');
      const mk = (ok: boolean) => ok ? c('green', '✅') : c('red', '❌');
      console.log(`| ${rid} | ${mk(r.idOk)} | ${mk(r.srcOk)} | ${mk(r.codeOk)} | ${mk(r.testsOk)} |`);
    }
    console.log('\n' + c('bold', 'Details:'));
    for (const r of failures) {
      const rid = (r.entry.id || '(missing id)');
      console.log(`- ${rid}: ${r.reasons.join('; ')}`);
    }
  } else {
    console.log(c('green', 'RTM OK (no gaps for in-scope requirements).'));
  }

  // Emit JSON summary when requested
  if (jsonOut) {
    const outDir = path.dirname(jsonOut);
    try { mkdirSync(outDir, { recursive: true }); } catch {}
    const payload = {
      schema: 'rtm.verify/v1',
      meta: {
        mapping: mappingPath,
        changed_files: changed,
        ts: new Date().toISOString(),
        pr: prOverride ?? null,
        base_ref: process.env.GITHUB_BASE_REF || null,
      },
      summary: {
        in_scope: inScope.length,
        passed: passes,
        failed: failures.length,
        out_of_scope: outOfScopeCount,
      },
      failures: failures.map((r) => ({
        id: (r.entry.id || '').trim(),
        id_ok: r.idOk,
        source_ok: r.srcOk,
        code_ok: r.codeOk,
        tests_ok: r.testsOk,
        reasons: r.reasons,
        code_expanded: r.codeExpanded,
        tests_expanded: r.testsExpanded,
      })),
    } as const;
    writeFileSync(jsonOut, JSON.stringify(payload, null, 2), 'utf-8');
  }

  // Optional PR comment
  if (wantComment && (!onlyOnFailure || failures.length)) {
    const mdLines: string[] = [];
    mdLines.push('### RTM Verify Report');
    mdLines.push('');
    mdLines.push(`- In-scope: ${inScope.length}`);
    mdLines.push(`- Passed: ${passes}`);
    mdLines.push(`- Failed: ${failures.length}`);
    mdLines.push(`- Out-of-scope: ${outOfScopeCount}`);
    mdLines.push('');
    if (failures.length) {
      mdLines.push('| ReqID | ID shape | source exists | code linked | tests linked |');
      mdLines.push('|---|:---:|:---:|:---:|:---:|');
      for (const r of failures) {
        const rid = (r.entry.id || '(missing id)');
        const mk = (ok: boolean) => ok ? '✅' : '❌';
        mdLines.push(`| ${rid} | ${mk(r.idOk)} | ${mk(r.srcOk)} | ${mk(r.codeOk)} | ${mk(r.testsOk)} |`);
      }
      mdLines.push('\n<details><summary>Details</summary>');
      for (const r of failures) {
        const rid = (r.entry.id || '(missing id)');
        mdLines.push(`- ${rid}: ${r.reasons.join('; ')}`);
      }
      mdLines.push('</details>');
    } else {
      mdLines.push('RTM OK (no gaps for in-scope requirements).');
    }
    await maybePostComment(mdLines.join('\n'), prOverride, tokenEnv);
  }

  process.exit(failures.length ? 1 : 0);
}

main().catch(err => {
  console.error(c('red', String(err && err.message || err)));
  process.exit(2);
});
