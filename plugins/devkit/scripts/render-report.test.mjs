// Tests for render-report.mjs. Run: node --test plugins/devkit/scripts/render-report.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = join(dirname(fileURLToPath(import.meta.url)), 'render-report.mjs');
const dir = mkdtempSync(join(tmpdir(), 'report-test-'));
let n = 0;
const file = (data) => {
  const p = join(dir, `r${n++}.json`);
  writeFileSync(p, typeof data === 'string' ? data : JSON.stringify(data));
  return p;
};
const render = (data) => execFileSync('node', [script, file(data)]).toString();
const run = (data) => spawnSync('node', [script, file(data)], { encoding: 'utf8' });

const minimal = { id: 'T-9', title: 'Tiny change', commit: 'abc1234' };
const full = {
  ...minimal, kind: 'feat', branch: 'feat/x', base: 'main', summary: 'Adds X.', why: 'Users need X.',
  areas: [{ name: 'src', files: 2, added: 40, removed: 5 }, { name: 'test', files: 1, added: 20, removed: 0 }],
  diagram: 'flowchart LR\n  A --> B',
  gates: [{ name: 'Tests', status: 'pass', detail: '12/12' }, { name: 'Build', status: 'skip' }],
  tests: { before: { pass: 10, fail: 0 }, after: { pass: 12, fail: 0 }, command: 'npm test' },
  acs: [{ id: 'AC1', text: 'Shows X', status: 'pass', evidence: 'screenshot', images: ['AC1-x.png'] }],
  review: { critical: { fixed: 1, remaining: 0 }, warning: { fixed: 2, remaining: 0 }, optional: { fixed: 0, remaining: 1 },
    items: [{ severity: 'critical', status: 'fixed', text: 'Null check' }] },
  metrics: [{ name: 'Bundle', unit: 'kB', before: 120, after: 110, better: 'lower' }],
  verified: [{ command: 'npm test', output: 'ok 12' }],
  manual_steps: ['Open /x', 'Click Save'],
  risks: ['Touches the cache'],
};
const sections = (html) => [...html.matchAll(/<section id="([a-z]+)"/g)].map((m) => m[1]);

test('minimal report keeps the always-present Screenshots section and skips the rest', () => {
  const html = render(minimal);
  assert.match(html, /<title>T-9 PR report<\/title>/);
  assert.match(html, /Tiny change/);
  assert.deepEqual(sections(html), ['ui']);
  assert.match(html, /None \(no UI change\)/);
  assert.match(html, /Ready/);
});

test('full feat report has every section in feat order', () => {
  assert.deepEqual(sections(render(full)), ['summary', 'acs', 'changes', 'diagram', 'verification', 'verified', 'ui', 'steps', 'review', 'metrics', 'risks']);
});

test('Screenshots section has the #ui anchor and the image', () => {
  const html = render(full);
  assert.match(html, /<section id="ui" aria-labelledby="ui-h"><h2 id="ui-h">Screenshots \/ GIF/);
  assert.match(html, /<img src="AC1-x.png"/);
  assert.doesNotMatch(html, /None \(no UI change\)/);
});

test('AC rows use ✅/⚠️/❌ and the header counts ACs met', () => {
  const html = render({ ...minimal, acs: [
    { id: 'AC1', text: 'a', status: 'pass' }, { id: 'AC2', text: 'b', status: 'assumption' }, { id: 'AC3', text: 'c', status: 'fail' }] });
  assert.match(html, /✅ met/);
  assert.match(html, /⚠️ assumption/);
  assert.match(html, /❌ failed/);
  assert.match(html, /1\/3 ACs met/);
});

test('long verification output is folded into <details>', () => {
  const long = Array.from({ length: 20 }, (_, i) => `line ${i}`).join('\n');
  const html = render({ ...minimal, verified: [{ command: 'npm test', output: long }, { command: 'tsc', output: 'ok' }] });
  assert.match(html, /<details><summary>20 lines of output<\/summary>/);
  assert.match(html, /\$ tsc<\/code><\/p><pre class="out">ok<\/pre>/);
});

test('fix kind leads with symptom, cause, fix and highlights the regression test', () => {
  const html = render({ ...minimal, kind: 'fix', summary: 'Fixes Y.',
    fix: { symptom: 'Crash on save', cause: 'a.js:3', fix: 'Guard null', regression_test: 'save.test.js' },
    tests: { before: { pass: 3, fail: 1 }, after: { pass: 4, fail: 0 } }, areas: full.areas });
  assert.deepEqual(sections(html), ['summary', 'verification', 'ui', 'changes']);
  assert.match(html, /Symptom<\/span><span>Crash on save/);
  assert.match(html, /Regression test/);
});

test('docs kind drops the diagram, gate/test charts and metrics', () => {
  assert.deepEqual(sections(render({ ...full, kind: 'docs' })), ['summary', 'acs', 'changes', 'verified', 'ui', 'steps', 'review', 'risks']);
});

test('refactor says behavior unchanged', () => {
  assert.match(render({ ...full, kind: 'refactor' }), /Behavior unchanged/);
});

test('every string is escaped', () => {
  const html = render({ ...minimal, title: '<script>alert(1)</script>', summary: '"x" & <b>y</b>',
    acs: [{ id: 'AC1', text: '<img src=x onerror=alert(1)>', status: 'pass', images: ['a" onerror="x.png'] }] });
  assert.doesNotMatch(html, /<script>alert/);
  assert.doesNotMatch(html, /<img src=x onerror/);
  assert.doesNotMatch(html, /src="a" onerror=/);
  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.match(html, /&quot;x&quot; &amp; &lt;b&gt;y&lt;\/b&gt;/);
});

test('metrics mark better and worse by direction', () => {
  const html = render({ ...minimal, metrics: [
    { name: 'Size', unit: 'kB', before: 100, after: 80, better: 'lower' },
    { name: 'Score', before: 90, after: 80, better: 'higher' },
    { name: 'Same', before: 5, after: 5, better: 'lower' }] });
  assert.match(html, /Size <span class="pill ok">−20% better/);
  assert.match(html, /Score <span class="pill bad">−11.11% worse/);
  assert.match(html, /Same <span class="pill muted">unchanged/);
});

test('overall status: failing gate or remaining critical needs attention; open AC is check', () => {
  assert.match(render({ ...minimal, gates: [{ name: 'Tests', status: 'fail' }] }), /Needs attention/);
  assert.match(render({ ...minimal, review: { critical: { fixed: 0, remaining: 1 } } }), /Needs attention/);
  assert.match(render({ ...minimal, acs: [{ id: 'AC1', text: 't', status: 'assumption' }] }), /Check/);
});

test('invalid input exits 1 with a message', () => {
  const bad = run('{ not json');
  assert.equal(bad.status, 1);
  assert.match(bad.stderr, /invalid JSON/);
  const missing = run({ id: 'x', title: 'y' });
  assert.equal(missing.status, 1);
  assert.match(missing.stderr, /missing required field "commit"/);
  const kind = run({ ...minimal, kind: 'wip' });
  assert.equal(kind.status, 1);
  assert.match(kind.stderr, /unknown kind/);
});
