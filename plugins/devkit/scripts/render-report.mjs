#!/usr/bin/env node
// Render a devkit PR report page from report.json (schema: references/report.md).
// Usage: node render-report.mjs <report.json> > report.html   — Node built-ins only.
import { readFileSync } from 'node:fs';

// The conventions' "PR report artifact" contents are always present: acs, verified, ui (screenshots or
// "None (no UI change)"), steps, risks. Charts (changes, verification, review, metrics) and the diagram
// appear when their data exists; their order follows the kind of change.
const KINDS = {
  feat: ['summary', 'acs', 'changes', 'diagram', 'verification', 'verified', 'ui', 'steps', 'review', 'metrics', 'risks'],
  fix: ['summary', 'acs', 'verification', 'verified', 'ui', 'steps', 'changes', 'review', 'risks'],
  perf: ['summary', 'metrics', 'acs', 'verification', 'verified', 'ui', 'steps', 'changes', 'review', 'risks'],
  refactor: ['summary', 'acs', 'changes', 'verification', 'verified', 'diagram', 'ui', 'steps', 'review', 'risks'],
};
for (const k of ['docs', 'chore', 'ci', 'build', 'test']) KINDS[k] = ['summary', 'acs', 'changes', 'verified', 'ui', 'steps', 'review', 'risks'];
const AC_MARK = { pass: '✅ met', assumption: '⚠️ assumption', fail: '❌ failed' };
const DETAILS_AFTER_LINES = 8;

const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);
const pct = (part, whole) => (whole > 0 ? Math.max(0, Math.min(100, (part / whole) * 100)) : 0);
const fmt = (n) => (Number.isInteger(n) ? String(n) : n.toFixed(2).replace(/\.?0+$/, ''));
const has = (a) => Array.isArray(a) && a.length > 0;

function fail(msg) {
  process.stderr.write(`render-report: ${msg}\n`);
  process.exit(1);
}

function load(path) {
  if (!path) fail('usage: node render-report.mjs <report.json>');
  let text;
  try { text = readFileSync(path, 'utf8'); } catch (e) { fail(`cannot read ${path}: ${e.message}`); }
  let data;
  try { data = JSON.parse(text); } catch (e) { fail(`invalid JSON in ${path}: ${e.message}`); }
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('report.json must be an object');
  for (const key of ['id', 'title', 'commit']) if (!data[key]) fail(`missing required field "${key}"`);
  if (data.kind && !KINDS[data.kind]) fail(`unknown kind "${data.kind}" (use ${Object.keys(KINDS).join(', ')})`);
  return data;
}

function overall(r) {
  const gateFail = (r.gates || []).some((g) => g.status === 'fail');
  const testFail = num(r.tests?.after?.fail) > 0;
  const critical = num(r.review?.critical?.remaining) > 0;
  if (gateFail || testFail || critical) return ['bad', 'Needs attention'];
  const warn = num(r.review?.warning?.remaining) > 0;
  const acOpen = (r.acs || []).some((a) => a.status && a.status !== 'pass');
  if (warn || acOpen) return ['warn', 'Check'];
  return ['ok', 'Ready'];
}

const pill = (state, text) => `<span class="pill ${state}">${esc(text)}</span>`;
const stateOf = (s) => ({ pass: 'ok', fixed: 'ok', fail: 'bad', remaining: 'warn', skip: 'muted', assumption: 'warn' })[s] || 'muted';
const section = (id, title, body) => `<section id="${id}" aria-labelledby="${id}-h"><h2 id="${id}-h">${esc(title)}</h2>${body}</section>`;

const S = {
  summary(r) {
    const parts = [];
    if (r.summary) parts.push(`<p class="lead">${esc(r.summary)}</p>`);
    if (r.why) parts.push(`<p><span class="label">Why</span> ${esc(r.why)}</p>`);
    if (r.kind === 'fix' && r.fix) {
      const f = r.fix;
      parts.push(`<ol class="fixflow">${[['Symptom', f.symptom], ['Cause', f.cause], ['Fix', f.fix]]
        .filter(([, v]) => v).map(([k, v]) => `<li><span class="label">${k}</span><span>${esc(v)}</span></li>`).join('')}</ol>`);
      if (f.regression_test) parts.push(`<p class="guard"><span class="label">Guarded by</span> <code>${esc(f.regression_test)}</code></p>`);
    }
    return parts.length ? section('summary', 'Summary', parts.join('')) : '';
  },

  changes(r) {
    if (!has(r.areas)) return '';
    const max = Math.max(...r.areas.map((a) => num(a.added) + num(a.removed)), 1);
    const tot = r.areas.reduce((t, a) => ({ files: t.files + num(a.files), added: t.added + num(a.added), removed: t.removed + num(a.removed) }), { files: 0, added: 0, removed: 0 });
    const rows = r.areas.map((a) => {
      const add = num(a.added), rem = num(a.removed);
      return `<div class="bar-row"><span class="bar-name">${esc(a.name)}</span>
        <span class="bar" role="img" aria-label="${esc(a.name)}: ${add} added, ${rem} removed"><span class="seg add" style="width:${pct(add, max)}%"></span><span class="seg rem" style="width:${pct(rem, max)}%"></span></span>
        <span class="bar-val">+${add} −${rem} · ${num(a.files)} ${num(a.files) === 1 ? 'file' : 'files'}</span></div>`;
    }).join('');
    return section('changes', 'Change map', `<p class="note">${tot.files} files · <span class="add-t">+${tot.added}</span> <span class="rem-t">−${tot.removed}</span> lines</p><div class="bars">${rows}</div>`);
  },

  diagram(r) {
    return r.diagram ? section('diagram', 'Diagram', `<div class="scroll"><pre class="mermaid">${esc(r.diagram)}</pre></div>`) : '';
  },

  verification(r) {
    const parts = [];
    if (has(r.gates)) {
      parts.push(`<ul class="gates">${r.gates.map((g) => `<li>${pill(stateOf(g.status), g.status || 'n/a')}<span class="gate-name">${esc(g.name)}</span>${g.detail ? `<span class="note">${esc(g.detail)}</span>` : ''}</li>`).join('')}</ul>`);
    }
    if (r.tests && (r.tests.before || r.tests.after)) {
      const b = r.tests.before || {}, a = r.tests.after || {};
      const max = Math.max(num(b.pass) + num(b.fail), num(a.pass) + num(a.fail), 1);
      const row = (label, t) => `<div class="bar-row"><span class="bar-name">${label}</span>
        <span class="bar" role="img" aria-label="${label}: ${num(t.pass)} passing, ${num(t.fail)} failing"><span class="seg add" style="width:${pct(num(t.pass), max)}%"></span><span class="seg rem" style="width:${pct(num(t.fail), max)}%"></span></span>
        <span class="bar-val">${num(t.pass)} pass · ${num(t.fail)} fail</span></div>`;
      const delta = num(a.pass) + num(a.fail) - (num(b.pass) + num(b.fail));
      const caption = r.kind === 'refactor' ? 'Behavior unchanged: the same tests pass before and after.' : `${delta >= 0 ? '+' : ''}${delta} tests`;
      parts.push(`<div class="bars">${r.tests.before ? row('Before', b) : ''}${r.tests.after ? row('After', a) : ''}</div><p class="note">${esc(caption)}${r.tests.command ? ` · <code>${esc(r.tests.command)}</code>` : ''}</p>`);
    }
    if (r.kind === 'fix' && r.fix?.regression_test) parts.push(`<p class="guard"><span class="label">Regression test</span> <code>${esc(r.fix.regression_test)}</code></p>`);
    return parts.length ? section('verification', 'Verification', parts.join('')) : '';
  },

  acs(r) {
    if (!has(r.acs)) return '';
    const rows = r.acs.map((a) => `<tr><th scope="row">${esc(a.id)}</th><td>${esc(a.text)}</td><td class="mark">${esc(AC_MARK[a.status] || a.status || 'n/a')}</td><td>${esc(a.evidence)}</td></tr>`).join('');
    return section('acs', 'Acceptance criteria', `<div class="scroll"><table><thead><tr><th>AC</th><th>Criterion</th><th>Status</th><th>Evidence</th></tr></thead><tbody>${rows}</tbody></table></div>`);
  },

  verified(r) {
    if (!has(r.verified)) return '';
    const blocks = r.verified.map((v) => {
      const out = String(v.output ?? '');
      const pre = `<pre class="out">${esc(out)}</pre>`;
      const lines = out.split('\n').length;
      return `<div class="cmd"><p><code>$ ${esc(v.command)}</code></p>${lines > DETAILS_AFTER_LINES ? `<details><summary>${lines} lines of output</summary>${pre}</details>` : pre}</div>`;
    }).join('');
    return section('verified', 'How it was verified', blocks);
  },

  steps(r) {
    return has(r.manual_steps) ? section('steps', 'Manual test steps', `<ol>${r.manual_steps.map((x) => `<li>${esc(x)}</li>`).join('')}</ol>`) : '';
  },

  ui(r) {
    const withImages = (r.acs || []).filter((a) => has(a.images));
    if (!withImages.length) return section('ui', 'Screenshots / GIF', '<p class="note">None (no UI change)</p>');
    const figs = withImages.map((a) => `<div class="shot-group"><p><strong>${esc(a.id)}</strong> ${esc(AC_MARK[a.status] || a.status || '')} ${esc(a.text)}</p>${a.images.map((src) => `<figure><img src="${esc(src)}" alt="${esc(`${a.id}: ${a.text}`)}" loading="lazy"><figcaption>${esc(src)}</figcaption></figure>`).join('')}</div>`).join('');
    return section('ui', 'Screenshots / GIF', figs);
  },

  review(r) {
    const rv = r.review;
    if (!rv) return '';
    const sev = ['critical', 'warning', 'optional'].filter((k) => rv[k] && (num(rv[k].fixed) + num(rv[k].remaining)) > 0);
    if (!sev.length && !has(rv.items)) return '';
    const max = Math.max(...sev.map((k) => num(rv[k].fixed) + num(rv[k].remaining)), 1);
    const bars = sev.map((k) => {
      const f = num(rv[k].fixed), m = num(rv[k].remaining);
      return `<div class="bar-row"><span class="bar-name">${k[0].toUpperCase() + k.slice(1)}</span>
        <span class="bar" role="img" aria-label="${k}: ${f} fixed, ${m} remaining"><span class="seg add" style="width:${pct(f, max)}%"></span><span class="seg ${k === 'critical' ? 'rem' : 'warn'}" style="width:${pct(m, max)}%"></span></span>
        <span class="bar-val">${f} fixed · ${m} remaining</span></div>`;
    }).join('');
    const items = has(rv.items) ? `<ul class="items">${rv.items.map((i) => `<li>${pill(i.severity === 'critical' ? 'bad' : i.severity === 'warning' ? 'warn' : 'muted', i.severity || 'note')} ${pill(stateOf(i.status), i.status || '')} ${esc(i.text)}</li>`).join('')}</ul>` : '';
    return section('review', 'Review', `${sev.length ? `<div class="bars">${bars}</div>` : ''}${items}`);
  },

  metrics(r) {
    if (!has(r.metrics)) return '';
    const cards = r.metrics.map((m) => {
      const b = num(m.before), a = num(m.after), max = Math.max(Math.abs(b), Math.abs(a), 1);
      const better = m.better === 'higher' ? a > b : a < b;
      const same = a === b;
      const change = b !== 0 ? `${a >= b ? '+' : '−'}${fmt(Math.abs(((a - b) / b) * 100))}%` : `${a >= b ? '+' : '−'}${fmt(Math.abs(a - b))}`;
      const verdict = same ? ['muted', 'unchanged'] : better ? ['ok', `${change} better`] : ['bad', `${change} worse`];
      const unit = m.unit ? ` ${esc(m.unit)}` : '';
      return `<div class="metric"><p class="metric-name">${esc(m.name)} ${pill(verdict[0], verdict[1])}</p><div class="bars">
        <div class="bar-row"><span class="bar-name">Before</span><span class="bar"><span class="seg base" style="width:${pct(Math.abs(b), max)}%"></span></span><span class="bar-val">${fmt(b)}${unit}</span></div>
        <div class="bar-row"><span class="bar-name">After</span><span class="bar"><span class="seg ${verdict[0] === 'bad' ? 'rem' : 'add'}" style="width:${pct(Math.abs(a), max)}%"></span></span><span class="bar-val">${fmt(a)}${unit}</span></div></div></div>`;
    }).join('');
    return section('metrics', 'Metrics', `<div class="metrics">${cards}</div>`);
  },

  risks(r) {
    return has(r.risks) ? section('risks', 'Risks', `<ul>${r.risks.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>`) : '';
  },
};

const CSS = `
:root {
  --bg: #f6f7f5; --surface: #ffffff; --fg: #1c2320; --muted: #5f6b65; --line: #dce1dd;
  --ok: #1d7a44; --ok-bg: #e2f2e8; --warn: #8a5a00; --warn-bg: #fbf0d6; --bad: #b42318; --bad-bg: #fde4e1;
  --add: #2f9a5d; --rem: #d0453a; --amber: #d4a017; --base: #9aa6a0;
  --sans: "IBM Plex Sans", system-ui, -apple-system, sans-serif; --mono: "IBM Plex Mono", ui-monospace, Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #121614; --surface: #1a1f1c; --fg: #e3e9e5; --muted: #98a59e; --line: #2b332f;
  --ok: #6fd197; --ok-bg: #19301f; --warn: #f0c35a; --warn-bg: #3a2f15; --bad: #ff8a7d; --bad-bg: #3d1d1a;
  --add: #4cc27f; --rem: #f0685c; --amber: #e2b93b; --base: #6d7a73; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #121614; --surface: #1a1f1c; --fg: #e3e9e5; --muted: #98a59e; --line: #2b332f;
  --ok: #6fd197; --ok-bg: #19301f; --warn: #f0c35a; --warn-bg: #3a2f15; --bad: #ff8a7d; --bad-bg: #3d1d1a;
  --add: #4cc27f; --rem: #f0685c; --amber: #e2b93b; --base: #6d7a73; color-scheme: dark }
body { background: var(--bg); color: var(--fg); font: 15px/1.55 var(--sans); }
main { max-width: 900px; margin: 0 auto; padding-inline: 16px; padding-block: 32px 56px; display: grid; gap: 28px; }
header { display: grid; gap: 8px; }
h1 { font-size: 1.65rem; line-height: 1.2; margin: 0; text-wrap: balance; }
h2 { font-size: 1.05rem; margin: 0 0 12px; }
section { border-top: 1px solid var(--line); padding-block: 20px 0; min-width: 0; }
p { margin: 0 0 8px; max-width: 70ch; }
.lead { font-size: 1.05rem; }
.meta { display: flex; flex-wrap: wrap; gap: 6px 16px; color: var(--muted); font: 0.82rem var(--mono); }
.label { font: 600 0.72rem var(--sans); letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); margin-right: 6px; }
.note { color: var(--muted); font-size: 0.86rem; }
code { font: 0.86em var(--mono); overflow-wrap: anywhere; }
.pill { display: inline-block; font: 700 0.7rem var(--sans); letter-spacing: 0.05em; text-transform: uppercase; padding: 2px 8px; border-radius: 4px; vertical-align: 0.1em; white-space: nowrap; }
.pill.ok { color: var(--ok); background: var(--ok-bg); } .pill.warn { color: var(--warn); background: var(--warn-bg); }
.pill.bad { color: var(--bad); background: var(--bad-bg); } .pill.muted { color: var(--muted); background: var(--line); }
.status-big { font-size: 0.8rem; padding: 4px 10px; }
.fixflow { list-style: none; margin: 8px 0; padding: 0; display: grid; gap: 8px; }
.fixflow li { display: grid; grid-template-columns: 6.5rem 1fr; gap: 8px; background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 8px 12px; }
.guard { background: var(--ok-bg); border-radius: 6px; padding: 6px 10px; display: inline-block; }
.bars { display: grid; gap: 8px; }
.bar-row { display: grid; grid-template-columns: minmax(4.5rem, 9rem) 1fr 11.5rem; align-items: center; gap: 10px; }
.bar-name { font-size: 0.86rem; overflow-wrap: anywhere; }
.bar { display: flex; height: 12px; background: var(--line); border-radius: 3px; overflow: hidden; min-width: 0; }
.seg { display: block; height: 100%; } .seg.add { background: var(--add); } .seg.rem { background: var(--rem); }
.seg.warn { background: var(--amber); } .seg.base { background: var(--base); }
.bar-val { font: 0.8rem var(--mono); color: var(--muted); font-variant-numeric: tabular-nums; white-space: nowrap; text-align: right; }
.add-t { color: var(--add); } .rem-t { color: var(--rem); }
.gates { list-style: none; margin: 0 0 14px; padding: 0; display: flex; flex-wrap: wrap; gap: 8px; }
.gates li { display: flex; align-items: center; gap: 6px; background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 6px 10px; }
.gate-name { font-weight: 600; font-size: 0.88rem; }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-size: 0.9rem; }
th, td { text-align: left; vertical-align: top; padding: 8px 10px; border-bottom: 1px solid var(--line); }
thead th { font: 600 0.72rem var(--sans); letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); }
.shot-group { display: grid; gap: 8px; margin-bottom: 18px; }
figure { margin: 0; display: grid; gap: 4px; }
figure img { display: block; max-width: 100%; height: auto; border: 1px solid var(--line); border-radius: 6px; background: #fff; }
figcaption { font: 0.76rem var(--mono); color: var(--muted); overflow-wrap: anywhere; }
.items { list-style: none; margin: 12px 0 0; padding: 0; display: grid; gap: 6px; }
.metrics { display: grid; gap: 18px; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); }
.metric-name { font-weight: 600; }
pre.mermaid { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 12px; margin: 0; }
footer { color: var(--muted); font-size: 0.78rem; }
.acline { font-weight: 600; margin: 0; }
td.mark { white-space: nowrap; }
.cmd { display: grid; gap: 4px; margin-bottom: 12px; min-width: 0; }
pre.out { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 10px 12px; margin: 0; overflow-x: auto; font: 0.8rem/1.45 var(--mono); }
details summary { cursor: pointer; color: var(--muted); font-size: 0.86rem; margin-bottom: 6px; }
ol { margin: 0; padding-left: 20px; max-width: 70ch; }
@media (max-width: 480px) { .bar-row { grid-template-columns: 1fr; gap: 4px; } .fixflow li { grid-template-columns: 1fr; } }
`;

export function render(r) {
  const kind = r.kind || 'feat';
  const [state, label] = overall(r);
  const body = KINDS[kind].map((name) => S[name]({ ...r, kind })).filter(Boolean).join('\n');
  const meta = [
    `<span>${esc(kind)}</span>`,
    r.branch ? `<span>${esc(r.branch)}${r.base ? ` → ${esc(r.base)}` : ''}</span>` : '',
    `<span>commit ${esc(r.commit)}</span>`,
    r.generated ? `<span>${esc(r.generated)}</span>` : '',
  ].filter(Boolean).join('');
  const met = (r.acs || []).filter((a) => a.status === 'pass').length;
  const acLine = has(r.acs) ? `<p class="acline">${met}/${r.acs.length} ACs met</p>` : '';
  return `<title>${esc(r.id)} PR report</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;600;700&display=swap">
<style>${CSS}</style>
<main>
<header>
<p class="label">${esc(r.id)} · PR report</p>
<h1>${esc(r.title)}</h1>
<div class="meta">${meta}</div>
<div>${pill(state, label).replace('class="pill', 'class="pill status-big')}</div>
${acLine}
</header>
${body}
<footer>Generated by devkit render-report from report.json. Numbers come from commands run on commit ${esc(r.commit)}.</footer>
</main>
`;
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('render-report.mjs')) {
  process.stdout.write(render(load(process.argv[2])));
}
