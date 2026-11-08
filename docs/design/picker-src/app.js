'use strict';
/* docsort destination-picker prototype: candidate A (columns with filter) and B (drill-down list with scoped filter).
   Plain DOM, no libraries. FOLDERS and KNOWN_CONTENTS come from the data script above. */

const TODAY = '2033-10-26';
const FILE_DATE = '2033-10-13';
const FILE_STEM = 'Rechnung_NA-33-08812';
const FILE_EXT = '.pdf';
/* The same Recent list as the main-window mockup, newest first. */
const START_RECENT = ['Mobilität/Jahreskarte Regio Plus', 'Kommunikation/Ilmnet Internet/Rechnungen', 'Chor Liederkranz/Kassa/2033', 'Gesundheit/Konrad/Augenarzt & Brillen', 'Bank & Geld/Girokonto Bürgerbank/2033-Q3', 'Arbeit Margit/Gehaltszettel/2033', 'Kleingarten Am Weidenbach/Pacht & Wasser'];
const MAX_RESULTS_B = 50;
const WINDOW_WIDTH = 1100;
const PANEL_WIDTH = { normal: 340, wide: 520 };
/* Task targets, all folders of the fictional sample archive (or, for TASK_NEW_FOLDER, one created in it). */
const TASK_DEEP_FOLDER = 'Gesundheit/Margit/Physiotherapie';
const TASK_CONTENTS_FOLDER = 'Chor Liederkranz/Noten';
const TASK_BROWSE_FOLDER = 'Hund Fritzi';
const TASK_BROWSE_PICK = 'Hundeschule Pfotenweg';
const TASK_NEW_FOLDER = 'Reisen/2033-11 Besuch Matthias Westerholm';
const TASK_RECENT_FOLDER = 'Kleingarten Am Weidenbach/Pacht & Wasser';

const TASKS = [
  { id: 't1', html: `File into <code>${TASK_DEEP_FOLDER}</code> without typing the full path.` },
  { id: 't2', html: `Find <code>${TASK_CONTENTS_FOLDER}</code> and check the newest file in it (take its name with <kbd>⌥↑</kbd> or a click).` },
  { id: 't3', html: `Browse the subfolders of <code>${TASK_BROWSE_FOLDER}</code> and pick <code>${TASK_BROWSE_PICK}</code> (not from Recent).` },
  { id: 't4', html: `Create a new folder <code>${TASK_NEW_FOLDER.slice(TASK_NEW_FOLDER.lastIndexOf('/') + 1)}</code> inside <code>${TASK_NEW_FOLDER.slice(0, TASK_NEW_FOLDER.lastIndexOf('/'))}</code>.` },
  { id: 't5', html: `From Recent, pick <code>${TASK_RECENT_FOLDER}</code>.` },
];

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const lastSeg = (p) => p.slice(p.lastIndexOf('/') + 1);
const parentOf = (p) => (p.includes('/') ? p.slice(0, p.lastIndexOf('/')) : '');
const chainOf = (p) => { const parts = p.split('/'); return parts.map((_, i) => parts.slice(0, i + 1).join('/')); };
const tokenText = (p) => p.replace(/\//g, ' › ');
const where = (p) => p || 'Archive';
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const collator = new Intl.Collator('de', { numeric: true, sensitivity: 'base' });
const reducedMotion = () => window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/* ---------------------------------------------------------------- icons */
const stroke = (vb, d, w = 1.4) =>
  `<svg viewBox="${vb}" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICON = {
  chev: stroke('0 0 12 12', '<path d="M4.5 2.5 8 6l-3.5 3.5"/>', 1.6),
  plus: stroke('0 0 12 12', '<path d="M6 1.5v9M1.5 6h9"/>', 1.5).replace('<svg ', '<svg class="plus" '),
  revert: stroke('0 0 12 12', '<path d="M2.6 4.2A4 4 0 1 1 2 6.6"/><path d="M2.4 1.6v2.8h2.8"/>', 1.4),
  warn: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1.3 15.3 14.4H.7Z M7.15 5.6h1.7l-.3 4.9h-1.1Z M8 11.4a.95.95 0 1 1 0 1.9.95.95 0 0 1 0-1.9Z"/></svg>',
  clear: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1a7 7 0 1 1 0 14A7 7 0 0 1 8 1Z M5.4 4.3 4.3 5.4 6.9 8l-2.6 2.6 1.1 1.1L8 9.1l2.6 2.6 1.1-1.1L9.1 8l2.6-2.6-1.1-1.1L8 6.9Z"/></svg>',
  folder: '<svg class="fold" viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" style="fill:var(--ficon-folder)"/><path d="M1 4.3h14" style="stroke:var(--ficon-folder-tab)" stroke-width=".8"/></svg>',
  newFolder: '<svg viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" fill="none" stroke="currentColor" stroke-width="1.1"/><path d="M8 5.2v4.6M5.7 7.5h4.6" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>',
};
function fileIcon(name) {
  const ext = (name.match(/\.([^.]+)$/) || ['', ''])[1].toLowerCase();
  const band = ext === 'pdf' ? '--ficon-pdf' : ['jpg', 'jpeg', 'png', 'heic'].includes(ext) ? '--ficon-img' : '--label3';
  const label = ext === 'pdf' ? 'PDF' : ['jpg', 'jpeg', 'png', 'heic'].includes(ext) ? 'JPG' : '';
  return `<span class="ficon"><svg viewBox="0 0 15 19" aria-hidden="true"><path d="M1.5 1.5h8l4 4v12h-12z" style="fill:var(--ficon-page);stroke:var(--ficon-stroke)" stroke-width=".8"/><path d="M9.5 1.5v4h4" fill="none" style="stroke:var(--ficon-stroke)" stroke-width=".8"/><rect x="1.9" y="11" width="11.2" height="4.6" style="fill:var(${band})"/>${label ? `<text x="7.5" y="14.5" text-anchor="middle" font-size="3.7" font-weight="700" font-family="-apple-system,Helvetica,sans-serif" style="fill:var(--ficon-page)">${label}</text>` : ''}</svg></span>`;
}

/* ---------------------------------------------------------------- folder model */
const F = { list: [], set: new Set(), pending: new Set(), index: new Map() };
function resetFolders() { F.list = FOLDERS.slice(); F.pending = new Set(); rebuildIndex(); }
function rebuildIndex() {
  F.set = new Set(F.list);
  const map = new Map();
  for (const p of F.list) {
    const par = parentOf(p);
    if (!map.has(par)) map.set(par, []);
    map.get(par).push(p);
  }
  for (const arr of map.values()) arr.sort((a, b) => collator.compare(lastSeg(a), lastSeg(b)));
  F.index = map;
  resultsCache.key = '';
}
const kids = (p) => F.index.get(p) || [];
const exists = (p) => F.set.has(p);
const isNew = (p) => F.pending.has(p);
function childNamed(parent, name) {
  const want = name.toLowerCase();
  return kids(parent).find((c) => lastSeg(c).toLowerCase() === want) || null;
}
/* Resolves a typed new-folder name (slashes nest) against the tree: which folders it would create, or which existing
   folder it names. */
function resolveNew(parent, raw) {
  const parts = raw.split('/').map((s) => s.trim()).filter(Boolean);
  let cur = parent;
  const create = [];
  for (const part of parts) {
    const hit = create.length ? null : childNamed(cur, part);
    if (hit) cur = hit;
    else { cur = (cur ? cur + '/' : '') + part; create.push(cur); }
  }
  return { path: cur, create, existing: parts.length && !create.length ? cur : null };
}
function addPending(paths) {
  for (const p of paths) if (!exists(p)) { F.list.push(p); F.pending.add(p); }
  rebuildIndex();
}

/* ---------------------------------------------------------------- folder contents */
const generatedCache = new Map();
/* Generated folder contents never go back before the sample archive's first year. */
const GENERATED_FIRST_YEAR = 2031;
const GEN_WORDS = ['Rechnung', 'Bestätigung', 'Schreiben', 'Vertrag', 'Information', 'Mitteilung', 'Beleg', 'Antrag', 'Bescheid', 'Polizze', 'Kontoauszug', 'Lieferschein', 'Angebot', 'Zahlungsbestätigung'];
function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function seeded(seed) {
  let x = seed || 1;
  return () => { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 4294967296; };
}
function baseContents(folder) {
  if (isNew(folder)) return [];
  if (KNOWN_CONTENTS[folder]) return KNOWN_CONTENTS[folder];
  if (generatedCache.has(folder)) return generatedCache.get(folder);
  const rnd = seeded(hashStr(folder));
  const list = [];
  if (rnd() > 0.18) {
    const n = 3 + Math.floor(rnd() * 6);
    // A folder named for a year holds that year's files; anything else ends just before today.
    const year = (folder.match(/\b(203[1-3])\b/) || [])[1];
    let y = year ? +year : +TODAY.slice(0, 4), m = year && year !== TODAY.slice(0, 4) ? 12 : +TODAY.slice(5, 7) - 1, d = 1 + Math.floor(rnd() * 27);
    const firstYear = year ? +year : GENERATED_FIRST_YEAR;
    const seg = lastSeg(folder).replace(/^[\d.\s!-]+/, '').trim();
    for (let i = 0; i < n && y >= firstYear; i++) {
      const word = GEN_WORDS[Math.floor(rnd() * GEN_WORDS.length)];
      const desc = seg && seg.length < 18 && rnd() > 0.5 ? `${seg} ${word}` : word;
      list.push(`${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')} ${desc}.pdf`);
      const step = 1 + Math.floor(rnd() * 5);
      m -= step;
      while (m < 1) { m += 12; y -= 1; }
      d = 1 + Math.floor(rnd() * 27);
    }
  }
  generatedCache.set(folder, list);
  return list;
}
/* Alphabetical, so with the archive's "YYYY-MM-DD …" names the newest file is at the bottom. */
const contentsOf = (folder) => baseContents(folder).slice().sort(collator.compare);
const stemOf = (name) => name.replace(/\.[^.]+$/, '');

/* ---------------------------------------------------------------- fuzzy matching (same scorer as the main mockup) */
function foldChar(c) {
  if (c === 'ß') return 'ss';
  return c.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}
const prepCache = new Map();
function prep(str) {
  let p = prepCache.get(str);
  if (p) return p;
  let f = '';
  const map = [], segStart = [], wordStart = [];
  const lastSlash = str.lastIndexOf('/');
  let lastStart = 0;
  for (let i = 0; i < str.length; i++) {
    const c = str[i];
    const fc = foldChar(c);
    const prev = i > 0 ? str[i - 1] : '/';
    const seg = prev === '/';
    const word = seg || /[\s\-_.()!,&]/.test(prev) || (/[a-zäöü]/.test(prev) && /[A-ZÄÖÜ]/.test(c)) || (/\D/.test(prev) && /\d/.test(c));
    if (i === lastSlash + 1) lastStart = f.length;
    for (let k = 0; k < fc.length; k++) {
      map.push(i); segStart.push(seg && k === 0); wordStart.push(word && k === 0); f += fc[k];
    }
  }
  p = { f, map, segStart, wordStart, lastStart };
  prepCache.set(str, p);
  return p;
}
const CONSEC = 5;
function matchToken(tok, p) {
  const n = p.f.length, m = tok.length;
  if (m > n) return null;
  for (let i = 0, j = 0; ; j++) {
    if (i === m) break;
    if (j === n) return null;
    if (p.f[j] === tok[i]) i++;
  }
  const NEG = -1e9;
  let prev = new Float64Array(n).fill(NEG);
  const back = new Int32Array(m * n).fill(-1);
  const bonus = (j) => 1 + (p.segStart[j] ? 9 : p.wordStart[j] ? 6 : 0) + (j >= p.lastStart ? 2 : 0);
  for (let j = 0; j < n; j++) if (p.f[j] === tok[0]) prev[j] = bonus(j) - j * 0.02;
  for (let i = 1; i < m; i++) {
    const cur = new Float64Array(n).fill(NEG);
    let best = NEG, bestK = -1;
    for (let j = 0; j < n; j++) {
      if (j >= 2 && prev[j - 2] > best) { best = prev[j - 2]; bestK = j - 2; }
      if (p.f[j] !== tok[i]) continue;
      const consec = j >= 1 && prev[j - 1] > NEG / 2 ? prev[j - 1] + CONSEC : NEG;
      const gap = best > NEG / 2 ? best - 0.5 : NEG;
      if (consec >= gap && consec > NEG / 2) { cur[j] = consec + bonus(j); back[i * n + j] = j - 1; }
      else if (gap > NEG / 2) { cur[j] = gap + bonus(j); back[i * n + j] = bestK; }
    }
    prev = cur;
  }
  let bestJ = -1, bestScore = NEG;
  for (let j = 0; j < n; j++) if (prev[j] > bestScore) { bestScore = prev[j]; bestJ = j; }
  if (bestJ < 0 || bestScore < NEG / 2) return null;
  const pos = new Array(m);
  for (let i = m - 1, j = bestJ; i >= 0; i--) { pos[i] = j; j = back[i * n + j]; }
  return { score: bestScore, pos };
}
/* Ranks candidates ({path, display}) for a query; marks are indices into display. */
function fuzzy(query, candidates, recentBoost) {
  const tokens = query.split(/\s+/).filter(Boolean).map((t) => t.split('').map(foldChar).join(''));
  if (!tokens.length) return [];
  const out = [];
  for (const c of candidates) {
    const p = prep(c.display);
    let score = 0;
    const marks = new Set();
    let allInLast = true;
    let ok = true;
    for (const t of tokens) {
      const r = matchToken(t, p);
      if (!r) { ok = false; break; }
      score += r.score;
      for (const j of r.pos) { marks.add(p.map[j]); if (j < p.lastStart) allInLast = false; }
    }
    if (!ok) continue;
    if (allInLast) score += 6;
    const lastF = p.f.slice(p.lastStart);
    if (tokens.some((t) => lastF.startsWith(t))) score += 5;
    score -= c.display.length * 0.12 + (c.display.split('/').length - 1) * 0.8;
    const ri = recentBoost.indexOf(c.path);
    if (ri >= 0) score += 14 - ri * 0.5;
    out.push({ ...c, score, marks });
  }
  out.sort((a, b) => b.score - a.score || a.display.length - b.display.length);
  return out;
}

/* ---------------------------------------------------------------- state */
const S = {
  cand: 'A',
  focus: 'picker',          // picker | newfolder | name | none
  query: '',
  recent: START_RECENT.slice(),
  chosen: null,             // chosen destination (token in the filter field)
  chosenVia: null,          // recent | browse | filter | new
  chosenSnap: null,         // picker state to restore when going back to the picker
  nf: null,                 // new-folder row: { parent, value, snap }
  take: null,               // ⌥↑/⌥↓ position: { folder, idx }
  nameHint: '',
  contentsShown: null,
  status: '',
  done: { A: new Set(), B: new Set() },
  // stepped: the folder the user last stepped to in A with ← / → or a click; the parent for A's no-match row
  a: { sel: [], sec0: 'recent', matches: [], matchMap: new Map(), visible: null, stepped: null },
  b: { scope: '', hl: 0 },
};

function resetState() {
  resetFolders();
  S.focus = 'picker';
  S.query = '';
  S.recent = START_RECENT.slice();
  S.chosen = null; S.chosenVia = null; S.chosenSnap = null;
  S.nf = null; S.take = null; S.nameHint = ''; S.contentsShown = null;
  S.a = { sel: [S.recent[0]], sec0: 'recent', matches: [], matchMap: new Map(), visible: null, stepped: null };
  S.b = { scope: '', hl: 0 };
  $('filterInput').value = '';
  $('nameInput').value = FILE_STEM;
  setStatus(`Start: picker focused, Recent first. Candidate ${S.cand === 'A' ? 'A · Columns with filter' : 'B · Drill-down list'}.`);
}

/* ---------------------------------------------------------------- candidate A: columns */
function aRecompute() {
  const q = S.query.trim();
  if (!q) { S.a.matches = []; S.a.matchMap = new Map(); S.a.visible = null; return; }
  const res = fuzzy(q, F.list.map((p) => ({ path: p, display: p })), S.recent);
  S.a.matches = res;
  S.a.matchMap = new Map(res.map((r, i) => [r.path, { rank: i, marks: r.marks }]));
  const vis = new Set();
  for (const r of res) for (const c of chainOf(r.path)) vis.add(c);
  S.a.visible = vis;
}
const aFiltering = () => !!S.query.trim();
function aVisibleKids(p) {
  const k = kids(p);
  if (!aFiltering() || (S.nf && S.nf.parent === p)) return k;
  return k.filter((c) => S.a.visible.has(c));
}
function aColItems(i) {
  if (i === 0) {
    if (S.nf && S.nf.parent === '') return kids('').map((p) => ({ path: p, sec: 'all' }));
    if (!aFiltering()) return S.recent.filter(exists).map((p) => ({ path: p, sec: 'recent' })).concat(kids('').map((p) => ({ path: p, sec: 'all' })));
    return aVisibleKids('').map((p) => ({ path: p, sec: 'all' }));
  }
  const parent = S.a.sel[i - 1];
  if (parent === undefined) return [];
  return aVisibleKids(parent).map((p) => ({ path: p, sec: 'all' }));
}
const aHighlightPath = () => S.a.sel[S.a.sel.length - 1] || null;
function aColumnCount() {
  const n = S.a.sel.length;
  if (!n) return 1;
  const h = S.a.sel[n - 1];
  return (S.nf && S.nf.parent === h) || aVisibleKids(h).length ? n + 1 : n;
}
function aMove(delta) {
  const n = S.a.sel.length;
  const col = Math.max(0, n - 1);
  const items = aColItems(col);
  if (!items.length) return;
  let idx = n ? items.findIndex((it) => it.path === S.a.sel[col] && (col > 0 || it.sec === S.a.sec0)) : -1;
  idx = idx < 0 ? 0 : clamp(idx + delta, 0, items.length - 1);
  S.a.sel = S.a.sel.slice(0, col).concat(items[idx].path);
  if (col === 0) S.a.sec0 = items[idx].sec;
  afterHighlight();
}
function aInto() {
  const h = aHighlightPath();
  if (!h) return;
  const k = aVisibleKids(h);
  if (!k.length) { setStatus(`“${lastSeg(h)}” has no subfolders.`); return; }
  S.a.sel.push(k[0]);
  S.a.stepped = k[0];
  afterHighlight();
}
function aOut() {
  if (S.a.sel.length > 1) { S.a.sel.pop(); S.a.stepped = aHighlightPath(); afterHighlight(); }
}
function aSelectPath(p) { S.a.sel = chainOf(p); S.a.sec0 = 'all'; }
function aJump(dir) {
  const m = S.a.matches;
  if (!m.length) return;
  const cur = S.a.matchMap.get(aHighlightPath());
  let i = cur ? cur.rank : dir > 0 ? -1 : 0;
  i = (i + dir + m.length) % m.length;
  aSelectPath(m[i].path);
  afterHighlight();
}
function aClickRow(col, path, sec) {
  S.a.sel = S.a.sel.slice(0, col).concat(path);
  if (col === 0) S.a.sec0 = sec;
  S.a.stepped = path;
}

/* ---------------------------------------------------------------- candidate B: drill-down list */
let resultsCache = { key: '', items: [] };
function bItems() {
  const key = [S.query, S.b.scope, F.list.length, S.recent.join('|')].join('\u0001');
  if (resultsCache.key === key) return resultsCache.items;
  const q = S.query.trim(), scope = S.b.scope;
  const items = [];
  if (!q) {
    if (!scope) {
      const rec = S.recent.filter(exists);
      if (rec.length) {
        items.push({ type: 'header', text: 'Recent' });
        for (const p of rec) items.push({ type: 'folder', path: p, display: p, marks: new Set(), recent: true });
      }
      items.push({ type: 'header', text: 'All folders' });
      for (const p of kids('')) items.push({ type: 'folder', path: p, display: p, marks: new Set() });
    } else {
      // The folder you stand in is choosable itself, as the first row.
      items.push({ type: 'folder', path: scope, display: lastSeg(scope), marks: new Set(), self: true });
      for (const p of kids(scope)) items.push({ type: 'folder', path: p, display: lastSeg(p), marks: new Set() });
    }
  } else {
    const prefix = scope ? scope + '/' : '';
    const cands = F.list.filter((p) => p.startsWith(prefix)).map((p) => ({ path: p, display: p.slice(prefix.length) }));
    const res = fuzzy(q, cands, S.recent);
    if (res.length) {
      items.push({ type: 'header', text: `${res.length} ${res.length === 1 ? 'match' : 'matches'}${scope ? ` in ${lastSeg(scope)}` : ''}${res.length > MAX_RESULTS_B ? ` · best ${MAX_RESULTS_B} shown` : ''}` });
      for (const r of res.slice(0, MAX_RESULTS_B)) items.push({ type: 'folder', ...r });
    } else {
      items.push({ type: 'create', name: q, parent: scope });
    }
  }
  resultsCache = { key, items };
  return items;
}
const bSelectable = () => bItems().filter((x) => x.type === 'folder' || x.type === 'create');
function bMove(delta) {
  const sel = bSelectable();
  if (!sel.length) return;
  S.b.hl = clamp(S.b.hl + delta, 0, sel.length - 1);
  afterHighlight();
}
function bInto(path) {
  const p = path || (highlighted() && highlighted().kind === 'folder' ? highlighted().path : null);
  if (!p || p === S.b.scope) return;
  S.b.scope = p; setQuery(''); S.b.hl = 0;
  afterHighlight();
}
function bIndexOf(path, allowRecent) {
  return bSelectable().findIndex((x) => x.type === 'folder' && x.path === path && !x.self && (allowRecent || !x.recent));
}
function bOut() {
  if (!S.b.scope) return;
  const old = S.b.scope;
  S.b.scope = parentOf(old); setQuery('');
  S.b.hl = Math.max(0, bIndexOf(old, false));
  afterHighlight();
}
function bRoot() {
  if (!S.b.scope && !S.query) return;
  const top = S.b.scope ? chainOf(S.b.scope)[0] : null;
  S.b.scope = ''; setQuery('');
  S.b.hl = top ? Math.max(0, bIndexOf(top, false)) : 0;
  afterHighlight();
}
function bJump(path) {
  const old = S.b.scope;
  S.b.scope = path; setQuery('');
  const child = old.startsWith(path ? path + '/' : '') && old !== path ? chainOf(old)[path ? chainOf(path).length : 0] : null;
  S.b.hl = child ? Math.max(0, bIndexOf(child, false)) : 0;
  afterHighlight();
}

/* ---------------------------------------------------------------- shared picker logic */
/* The highlighted row: { kind: 'folder', path, via } or { kind: 'create', name, parent } or null. */
function highlighted() {
  if (S.cand === 'A') {
    if (aFiltering() && !S.a.matches.length) return { kind: 'create', name: S.query.trim(), parent: S.a.stepped && exists(S.a.stepped) ? S.a.stepped : '' };
    const p = aHighlightPath();
    if (!p) return null;
    const via = aFiltering() ? 'filter' : S.a.sec0 === 'recent' && S.a.sel.length === 1 ? 'recent' : 'browse';
    return { kind: 'folder', path: p, via };
  }
  const sel = bSelectable();
  if (!sel.length) return null;
  const it = sel[clamp(S.b.hl, 0, sel.length - 1)];
  if (it.type === 'create') return { kind: 'create', name: it.name, parent: it.parent };
  return { kind: 'folder', path: it.path, via: it.recent ? 'recent' : S.query.trim() ? 'filter' : 'browse', self: !!it.self };
}
function setQuery(q) { S.query = q; $('filterInput').value = q; if (S.cand === 'A') aRecompute(); }
function snapshotPicker() { return { query: S.query, a: { sel: S.a.sel.slice(), sec0: S.a.sec0 }, b: { ...S.b } }; }
function restorePicker(snap) {
  S.query = snap.query; $('filterInput').value = snap.query;
  S.a.sel = snap.a.sel.slice(); S.a.sec0 = snap.a.sec0;
  S.b = { ...snap.b };
  aRecompute();
  resultsCache.key = '';
}
function afterHighlight() {
  renderPicker();
  renderContents();
  renderName();
  renderFilterField();
}
function onFilterInput() {
  if (S.chosen) { S.chosen = null; S.chosenSnap = null; }
  S.query = $('filterInput').value;
  if (S.cand === 'A') {
    aRecompute();
    if (aFiltering()) {
      if (S.a.matches.length) aSelectPath(S.a.matches[0].path);
      else S.a.sel = [];
    } else if (!S.a.sel.length) { S.a.sel = [S.recent[0]]; S.a.sec0 = 'recent'; }
  } else {
    S.b.hl = 0;
  }
  afterHighlight();
}
function clearFilter() {
  if (S.cand === 'A') {
    const keep = aHighlightPath();
    setQuery('');
    if (keep) aSelectPath(keep); else { S.a.sel = [S.recent[0]]; S.a.sec0 = 'recent'; }
  } else {
    const keep = highlighted();
    setQuery('');
    const i = keep && keep.kind === 'folder' ? bIndexOf(keep.path, true) : -1;
    S.b.hl = Math.max(0, i);
  }
  afterHighlight();
}

function chooseHighlighted() {
  const h = highlighted();
  if (!h) return;
  if (h.kind === 'create') { createFromQuery(h); return; }
  choose(h.path, h.via);
}
function choose(path, via) {
  S.chosenSnap = snapshotPicker();
  S.chosen = path; S.chosenVia = via;
  $('filterInput').value = '';
  if (via === 'new') {
    const created = chainOf(path).filter(isNew);
    setStatus(`New folder ${esc(created.map(lastSeg).join('/'))} in ${esc(where(parentOf(created[0])))} (created on move)`);
  } else setStatus(`Chose ${esc(path)}`);
  checkTasks(path, via);
  S.focus = 'name';
  $('nameInput').focus({ preventScroll: true });
  $('nameInput').select();
  renderAll();
}
function unchoose() {
  if (!S.chosen) return;
  const snap = S.chosenSnap;
  S.chosen = null; S.chosenVia = null; S.chosenSnap = null;
  if (snap) restorePicker(snap);
}
function backToPicker() {
  unchoose();
  S.focus = 'picker';
  const inp = $('filterInput');
  inp.focus({ preventScroll: true });
  inp.setSelectionRange(inp.value.length, inp.value.length);
  renderAll();
}
/* Puts the picker on a folder that was just created or found, with the filter cleared. */
function adoptPath(path) {
  setQuery('');
  if (S.cand === 'A') aSelectPath(path);
  else { S.b.scope = parentOf(path); resultsCache.key = ''; S.b.hl = Math.max(0, bIndexOf(path, false)); }
}
function createFromQuery(h) {
  const res = resolveNew(h.parent, h.name);
  if (res.existing) { adoptPath(res.existing); choose(res.existing, 'browse'); return; }
  addPending(res.create);
  adoptPath(res.path);
  choose(res.path, 'new');
}

/* ---------------------------------------------------------------- new folder */
function newFolderCmd() {
  if (S.nf) { $('nfInput') && $('nfInput').focus(); return; }
  if (S.chosen) unchoose();
  const h = highlighted();
  if (h && h.kind === 'create') { createFromQuery(h); return; }
  const parent = h ? h.path : S.cand === 'B' ? S.b.scope : '';
  S.nf = { parent, value: '', snap: snapshotPicker() };
  if (S.cand === 'B') { S.b.scope = parent; setQuery(''); S.b.hl = 0; resultsCache.key = ''; }
  S.focus = 'newfolder';
  renderAll();
  const inp = $('nfInput');
  if (inp) { inp.focus({ preventScroll: true }); scrollNfIntoView(); }
  setStatus(`New folder in ${esc(where(parent))}: type a name, Tab or Return confirms, Esc cancels.`);
}
function nfNotice(parent, value) {
  if (/:/.test(value)) return { warn: true, text: 'Folder names can’t contain “:”.' };
  const res = value.trim() ? resolveNew(parent, value) : null;
  if (res && res.existing) return { warn: true, text: `${where(lastSeg(parentOf(res.existing)) || '')} already contains a folder named “${lastSeg(res.existing)}”. Return selects it.` };
  if (res && res.create.length > 1) return { warn: false, text: `Creates ${res.create.length} nested folders. ⌘D inserts today’s date.` };
  return { warn: false, text: 'Tab or Return confirms · Esc cancels · ⌘D inserts the date' };
}
function onNfInput() {
  const inp = $('nfInput');
  S.nf.value = inp.value;
  placeNfRow();
  const n = nfNotice(S.nf.parent, S.nf.value);
  const note = $('nfNote');
  note.textContent = n.text;
  note.classList.toggle('warn', n.warn);
}
/* Moves sibling rows around the (focused, never moved) new-folder row so it sits at its alphabetical position. */
function placeNfRow() {
  const before = $('nfBefore'), after = $('nfAfter');
  if (!before || !after) return;
  const rows = [...before.children, ...after.children];
  const first = (S.nf.value.split('/')[0] || '').trim();
  for (const r of rows) {
    const goesBefore = first && collator.compare(r.dataset.name, first) < 0;
    (goesBefore ? before : after).appendChild(r);
  }
  // keep document order inside each part
  for (const part of [before, after]) {
    [...part.children].sort((x, y) => collator.compare(x.dataset.name, y.dataset.name)).forEach((r) => part.appendChild(r));
  }
  scrollNfIntoView();
}
function scrollNfIntoView() {
  const row = $('nfRowBox');
  if (!row) return;
  const box = row.closest('.col, .list');
  if (!box) return;
  const top = row.offsetTop - box.offsetTop;
  if (top < box.scrollTop + 4 || top + row.offsetHeight > box.scrollTop + box.clientHeight - 4) box.scrollTop = Math.max(0, top - box.clientHeight / 2 + row.offsetHeight / 2);
}
function confirmNf() {
  const nf = S.nf;
  if (!nf) return false;
  const v = nf.value.trim().replace(/\/+/g, '/').replace(/^\/|\/$/g, '');
  if (!v) { cancelNf(); return false; }
  if (/:/.test(v)) { setStatus('Folder names can’t contain “:”.'); return false; }
  const res = resolveNew(nf.parent, v);
  S.nf = null;
  if (res.existing) { adoptPath(res.existing); choose(res.existing, 'browse'); return true; }
  addPending(res.create);
  adoptPath(res.path);
  choose(res.path, 'new');
  return true;
}
function cancelNf() {
  if (!S.nf) return;
  const snap = S.nf.snap;
  S.nf = null;
  restorePicker(snap);
  S.focus = 'picker';
  $('filterInput').focus({ preventScroll: true });
  setStatus('New folder cancelled; nothing was created.');
  renderAll();
}

/* ---------------------------------------------------------------- name field */
function contentsFolder() {
  if (S.chosen) return S.chosen;
  if (S.nf) return null;
  const h = highlighted();
  return h && h.kind === 'folder' ? h.path : null;
}
function effectiveStem() {
  let v = $('nameInput').value.trim();
  if (!v) return FILE_STEM;
  while (v.toLowerCase().endsWith(FILE_EXT) && v.length > FILE_EXT.length) v = v.slice(0, v.length - FILE_EXT.length).trimEnd();
  return v;
}
function setName(stem) {
  const inp = $('nameInput');
  inp.value = stem;
  if (S.focus !== 'name') { S.focus = 'name'; inp.focus({ preventScroll: true }); }
  inp.select();
  S.nameHint = '';
}
function takeName(dir) {
  const folder = contentsFolder();
  if (!folder) return;
  const files = contentsOf(folder);
  if (!files.length) { flashHint(`“${lastSeg(folder)}” has no files to take a name from.`); return; }
  let idx;
  if (!S.take || S.take.folder !== folder) idx = files.length - 1;
  else idx = clamp(S.take.idx + dir, 0, files.length - 1);
  S.take = { folder, idx };
  setName(stemOf(files[idx]));
  if (folder === TASK_CONTENTS_FOLDER) markDone('t2');
  renderContents(); renderName();
}
function takeNameFromClick(i) {
  const folder = contentsFolder();
  if (!folder) return;
  const files = contentsOf(folder);
  if (!files[i]) return;
  if (!S.chosen) { const h = highlighted(); if (h && h.kind === 'folder') { S.chosenSnap = snapshotPicker(); S.chosen = h.path; S.chosenVia = h.via; $('filterInput').value = ''; checkTasks(h.path, h.via); } }
  S.take = { folder, idx: i };
  setName(stemOf(files[i]));
  if (folder === TASK_CONTENTS_FOLDER) markDone('t2');
  setStatus(`Took the name “${esc(stemOf(files[i]))}” from ${esc(folder)}`);
  renderAll();
}
function revertName() {
  setName(FILE_STEM);
  S.take = null;
  renderContents(); renderName();
}
function insertDate(date, inp) {
  const v = inp.value;
  const s = inp.selectionStart ?? v.length, e = inp.selectionEnd ?? v.length;
  const allSel = v.length > 0 && s === 0 && e === v.length;
  const m = v.match(/^\d{4}-\d{2}-\d{2} ?/);
  const oldLen = m ? m[0].length : 0;
  const prefix = date + ' ';
  inp.value = prefix + v.slice(oldLen);
  if (allSel) inp.setSelectionRange(prefix.length, inp.value.length);
  else {
    const shift = prefix.length - oldLen;
    inp.setSelectionRange(Math.max(prefix.length, s + shift), Math.max(prefix.length, e + shift));
  }
}
function flashHint(text) {
  S.nameHint = text;
  renderName();
  clearTimeout(flashHint.t);
  flashHint.t = setTimeout(() => { S.nameHint = ''; renderName(); }, 3000);
}
function findConflict(folder) {
  if (!folder || isNew(folder)) return null;
  const target = (effectiveStem() + FILE_EXT).toLowerCase();
  return contentsOf(folder).find((n) => n.toLowerCase() === target) || null;
}

/* ---------------------------------------------------------------- move */
function doMove() {
  if (S.nf && !confirmNf()) return;
  const h = highlighted();
  if (!S.chosen && h && h.kind === 'create') { createFromQuery(h); }
  const folder = S.chosen || (h && h.kind === 'folder' ? h.path : null);
  if (!folder) { setStatus('Nothing to move to: highlight or choose a folder first.'); return; }
  const via = S.chosen ? S.chosenVia : h.via;
  const name = effectiveStem() + FILE_EXT;
  const created = chainOf(folder).filter(isNew);
  const conflict = findConflict(folder);
  let msg = `Would move to <b>${esc(folder)}</b> as <b>${esc(name)}</b>`;
  if (created.length) msg += ` · creates ${esc(created.map(lastSeg).join('/'))} in ${esc(where(parentOf(created[0])))}`;
  if (conflict) msg += ` · “${esc(conflict)}” exists: the Keep Both / Replace sheet would open`;
  setStatus(msg);
  checkTasks(folder, via);
}

/* ---------------------------------------------------------------- tasks */
function checkTasks(path, via) {
  if (path === TASK_DEEP_FOLDER) markDone('t1');
  if (path === `${TASK_BROWSE_FOLDER}/${TASK_BROWSE_PICK}` && via === 'browse') markDone('t3');
  if (path === TASK_NEW_FOLDER && isNew(path)) markDone('t4');
  if (path === TASK_RECENT_FOLDER && via === 'recent') markDone('t5');
}
function markDone(id) {
  if (S.done[S.cand].has(id)) return;
  S.done[S.cand].add(id);
  renderTasks();
}
function renderTasks() {
  $('taskList').innerHTML = TASKS.map((t) => `<li id="task-${t.id}"><span class="tt">${t.html}</span><span class="ticks">${['A', 'B'].map((c) => `<span class="tick${S.done[c].has(t.id) ? ' done' : ''}" title="${S.done[c].has(t.id) ? `Done in ${c}` : `Not done in ${c} yet`}">${c}</span>`).join('')}</span></li>`).join('');
}

/* ---------------------------------------------------------------- rendering */
function setStatus(html) {
  S.status = html;
  const el = $('statusMsg');
  el.innerHTML = html;
  const st = $('status');
  st.classList.remove('flash'); void st.offsetWidth; st.classList.add('flash');
}
function segHtml(text, localMarks) {
  let html = '', inBold = false;
  for (let i = 0; i < text.length; i++) {
    const b = localMarks.has(i);
    if (b && !inBold) { html += '<b>'; inBold = true; }
    if (!b && inBold) { html += '</b>'; inBold = false; }
    html += esc(text[i]);
  }
  return html + (inBold ? '</b>' : '');
}
function localMarks(marks, from, to) {
  const out = new Set();
  for (const k of marks) if (k >= from && k < to) out.add(k - from);
  return out;
}
/* Relative path with the parent part in secondary colour; marks index into display. */
function pathHtml(display, marks) {
  const cut = display.lastIndexOf('/');
  const last = `<span class="last">${segHtml(display.slice(cut + 1), localMarks(marks, cut + 1, display.length))}</span>`;
  if (cut < 0) return last;
  return `<span class="par">${segHtml(display.slice(0, cut + 1), localMarks(marks, 0, cut + 1))}</span>${last}`;
}
function nfRowHtml(parent) {
  const n = nfNotice(parent, S.nf.value);
  return `<div class="nf-row" id="nfRowBox"><div class="nf-line">${ICON.folder}<input id="nfInput" type="text" autocomplete="off" spellcheck="false" placeholder="Folder name" aria-label="New folder name in ${esc(where(parent))}" value="${esc(S.nf.value)}"></div><div class="nf-note${n.warn ? ' warn' : ''}" id="nfNote">${esc(n.text)}</div></div>`;
}
/* Sibling rows split around the new-folder row by the typed name. */
function nfHostHtml(rowsHtml, parent) {
  const first = (S.nf.value.split('/')[0] || '').trim();
  const before = [], after = [];
  for (const r of rowsHtml) (first && collator.compare(r.name, first) < 0 ? before : after).push(r.html);
  return `<div id="nfBefore">${before.join('')}</div>${nfRowHtml(parent)}<div id="nfAfter">${after.join('')}</div>`;
}

function renderPanelWidth() {
  const wide = S.cand === 'A' && (S.focus === 'picker' || S.focus === 'newfolder');
  $('panel').classList.toggle('wide', wide);
  $('pvWidth').textContent = `${WINDOW_WIDTH - (wide ? PANEL_WIDTH.wide : PANEL_WIDTH.normal)} pt`;
  $('win').classList.toggle('pk-focus', S.focus === 'picker' || S.focus === 'newfolder');
}
function renderFilterField() {
  const inp = $('filterInput');
  const token = $('tokenChip'), scope = $('scopeChip'), count = $('matchCount');
  if (S.chosen) {
    token.hidden = false;
    token.title = `${S.chosen} · click or ⇧Tab to change`;
    token.innerHTML = `<span class="t">${esc(tokenText(S.chosen))}</span>${isNew(S.chosen) ? '<span class="badge-new">New</span>' : ''}`;
    inp.placeholder = '';
  } else {
    token.hidden = true;
    inp.placeholder = S.cand === 'B' && S.b.scope ? `Search in ${lastSeg(S.b.scope)}` : 'Search all folders';
  }
  const showScope = S.cand === 'B' && !!S.b.scope && !S.chosen;
  scope.hidden = !showScope;
  if (showScope) { scope.innerHTML = `<span class="t">in ${esc(lastSeg(S.b.scope))}</span>`; scope.title = `Searching inside ${S.b.scope}. ⌘↑ searches the whole archive.`; }
  const showCount = S.cand === 'A' && aFiltering() && !S.chosen;
  count.hidden = !showCount;
  if (showCount) {
    const n = S.a.matches.length;
    const cur = S.a.matchMap.get(aHighlightPath());
    count.textContent = !n ? 'No matches' : cur ? `${cur.rank + 1} of ${n}` : `${n} ${n === 1 ? 'match' : 'matches'}`;
  }
  const clr = $('filterClear');
  clr.hidden = !(S.query || S.chosen);
  clr.innerHTML = ICON.clear;
}
function renderPicker() {
  if (S.nf && document.activeElement && document.activeElement.id === 'nfInput') return;
  $('pathBar').hidden = S.cand !== 'B';
  if (S.cand === 'A') renderColumns(); else renderList();
  const h = highlighted();
  const parent = S.nf ? S.nf.parent : h && h.kind === 'folder' ? h.path : S.cand === 'B' ? S.b.scope : '';
  const btn = $('newFolderBtn');
  btn.innerHTML = `${ICON.newFolder}<span>New Folder</span>`;
  btn.title = h && h.kind === 'create' ? `New Folder “${h.name}” in ${where(h.parent)} (⇧⌘N)` : `New Folder in ${where(parent)} (⇧⌘N)`;
  btn.setAttribute('aria-label', btn.title);
  $('pickerHint').textContent = S.cand === 'A' ? '→ open · ← back · ⌘G next match · Tab choose' : '→ into · ← out · ⌘↑ top · Tab choose';
}
function renderColumns() {
  const body = $('pickerBody');
  if (aFiltering() && !S.a.matches.length) {
    const h = highlighted();
    body.innerHTML = `<div class="list"><div class="res create hl" role="option" aria-selected="true" id="createRow" data-act="create">${ICON.plus}<span class="rt">New Folder “${esc(h.name)}” in ${esc(where(h.parent))}</span></div><div class="res-empty">No folder matches “${esc(h.name)}”. Tab, Return or ⇧⌘N creates it in ${esc(where(h.parent))}${h.parent ? ', the folder you last stepped into' : ''}.</div></div>`;
    return;
  }
  const n = aColumnCount();
  const hlPath = aHighlightPath();
  const hm = S.a.matchMap.get(hlPath);
  let html = '';
  for (let i = 0; i < n; i++) {
    const items = aColItems(i);
    const focusedCol = i === S.a.sel.length - 1;
    const host = S.nf && (S.nf.parent === '' ? i === 0 : S.a.sel[i - 1] === S.nf.parent && i === S.a.sel.indexOf(S.nf.parent) + 1);
    const rows = [];
    let lastSec = null;
    let head = '';
    for (const it of items) {
      if (i === 0 && !aFiltering() && !host && it.sec !== lastSec) {
        const h = `<div class="col-h">${it.sec === 'recent' ? 'Recent' : 'Archive'}</div>`;
        if (rows.length) rows.push({ name: '', html: h }); else head += h;
        lastSec = it.sec;
      }
      const p = it.path;
      const selected = S.a.sel[i] === p && (i > 0 || it.sec === S.a.sec0);
      const filtering = aFiltering();
      const dim = filtering && !S.a.matchMap.has(p);
      let marks = new Set();
      if (filtering) {
        const start = p.lastIndexOf('/') + 1;
        if (hm && (hlPath === p || hlPath.startsWith(p + '/'))) marks = localMarks(hm.marks, start, p.length);
        else if (S.a.matchMap.has(p)) marks = localMarks(S.a.matchMap.get(p).marks, start, p.length);
      }
      const hasKids = aVisibleKids(p).length > 0;
      const cls = `crow${selected ? ' sel' : ''}${selected && focusedCol ? ' hl' : ''}${dim ? ' dim' : ''}${it.sec === 'recent' ? ' two' : ''}`;
      const label = it.sec === 'recent'
        ? `<span class="rt"><span>${esc(lastSeg(p))}</span><span class="sub">${esc(parentOf(p))}</span></span>`
        : `<span class="rt">${segHtml(lastSeg(p), marks)}</span>`;
      rows.push({
        name: lastSeg(p),
        html: `<div class="${cls}" role="option" aria-selected="${selected}" data-act="arow" data-col="${i}" data-sec="${it.sec}" data-path="${esc(p)}" data-name="${esc(lastSeg(p))}" title="${esc(p)}">${ICON.folder}${label}${isNew(p) ? '<span class="badge-new">New</span>' : ''}${hasKids ? `<span class="chev">${ICON.chev}</span>` : ''}</div>`,
      });
    }
    const inner = host ? nfHostHtml(rows.filter((r) => r.name), S.nf.parent) : head + rows.map((r) => r.html).join('');
    html += `<div class="col" data-col="${i}">${inner || '<div class="res-empty">Empty</div>'}</div>`;
  }
  body.innerHTML = `<div class="cols" id="cols">${html}</div>`;
  const cols = $('cols');
  cols.querySelectorAll('.col').forEach((col) => {
    const sel = col.querySelector('.crow.sel');
    if (sel) {
      const top = sel.offsetTop - col.offsetTop;
      if (top < col.scrollTop + 18 || top + sel.offsetHeight > col.scrollTop + col.clientHeight) col.scrollTop = Math.max(0, top - col.clientHeight / 2 + sel.offsetHeight / 2);
    }
  });
  scrollColsToEnd(false);
}
function scrollColsToEnd(smooth) {
  const cols = $('cols');
  if (!cols) return;
  const left = cols.scrollWidth - cols.clientWidth;
  if (smooth && !reducedMotion()) cols.scrollTo({ left, behavior: 'smooth' });
  else { cols.style.scrollBehavior = 'auto'; cols.scrollLeft = left; cols.style.scrollBehavior = ''; }
}
function renderList() {
  const crumbs = [{ path: '', name: 'Archive' }].concat(S.b.scope ? chainOf(S.b.scope).map((p) => ({ path: p, name: lastSeg(p) })) : []);
  $('pathBar').innerHTML = crumbs.map((c, i) => `${i ? '<span class="sep" aria-hidden="true">›</span>' : ''}<button type="button" class="crumb${i === crumbs.length - 1 ? ' cur' : ''}" data-act="crumb" data-path="${esc(c.path)}" tabindex="-1" id="crumb-${i}" title="${c.path ? esc(c.path) : 'Archive root (⌘↑)'}">${esc(c.name)}</button>`).join('');
  const pb = $('pathBar'); pb.scrollLeft = pb.scrollWidth;
  const body = $('pickerBody');
  if (S.nf) {
    const rows = kids(S.nf.parent).map((p) => ({
      name: lastSeg(p),
      html: `<div class="res" data-name="${esc(lastSeg(p))}" title="${esc(p)}">${ICON.folder}<span class="rt"><span class="last">${esc(lastSeg(p))}</span></span>${isNew(p) ? '<span class="badge-new">New</span>' : ''}</div>`,
    }));
    body.innerHTML = `<div class="list" id="bList"><div class="res-h">New folder in ${esc(where(S.nf.parent))}</div>${nfHostHtml(rows, S.nf.parent)}</div>`;
    return;
  }
  const items = bItems();
  const sel = bSelectable();
  S.b.hl = clamp(S.b.hl, 0, Math.max(0, sel.length - 1));
  const hlItem = sel[S.b.hl];
  let si = -1, html = '';
  for (const it of items) {
    if (it.type === 'header') { html += `<div class="res-h">${esc(it.text)}</div>`; continue; }
    if (it.type === 'info') { html += `<div class="res-empty">${esc(it.text)}</div>`; continue; }
    si++;
    const isHl = it === hlItem;
    if (it.type === 'create') {
      html += `<div class="res create${isHl ? ' hl' : ''}" role="option" aria-selected="${isHl}" id="createRow" data-act="create">${ICON.plus}<span class="rt">New Folder “${esc(it.name)}” in ${esc(where(it.parent))}</span></div><div class="res-empty">No folder${S.b.scope ? ` in ${esc(lastSeg(S.b.scope))}` : ''} matches. Tab, Return or ⇧⌘N creates it in ${esc(where(S.b.scope))}.</div>`;
      continue;
    }
    const hasKids = !it.self && kids(it.path).length > 0;
    const label = it.self ? `<span class="last">${esc(it.display)}</span><span class="par"> — this folder</span>` : pathHtml(it.display, it.marks);
    html += `<div class="res${isHl ? ' hl' : ''}${it.self ? ' self' : ''}" role="option" aria-selected="${isHl}" id="bres-${si}" data-act="brow" data-si="${si}" title="${esc(it.path)}">${ICON.folder}<span class="rt">${label}</span>${isNew(it.path) ? '<span class="badge-new">New</span>' : ''}${hasKids ? `<button type="button" class="into" data-act="binto" data-path="${esc(it.path)}" tabindex="-1" title="Show subfolders (→)" aria-label="Show subfolders of ${esc(lastSeg(it.path))}">${ICON.chev}</button>` : ''}</div>`;
  }
  body.innerHTML = `<div class="list" id="bList">${html}</div>`;
  const list = $('bList');
  const hlEl = list.querySelector('.res.hl');
  if (hlEl) {
    const top = hlEl.offsetTop - list.offsetTop, bottom = top + hlEl.offsetHeight;
    if (top < list.scrollTop + 22) list.scrollTop = Math.max(0, top - 26);
    else if (bottom > list.scrollTop + list.clientHeight) list.scrollTop = bottom - list.clientHeight + 4;
    $('filterInput').setAttribute('aria-activedescendant', hlEl.id);
  }
}
function renderContents() {
  const box = $('contents');
  const folder = contentsFolder();
  const pathEl = $('contentsPath'), cnt = $('contentsCount'), inEl = $('contentsIn');
  if (!folder) {
    inEl.textContent = 'Folder contents'; pathEl.textContent = ''; cnt.textContent = '';
    box.innerHTML = `<div class="ct-empty">${S.nf ? 'Name the new folder; its contents appear once it is chosen.' : 'Highlight a folder to see its files.'}</div>`;
    S.contentsShown = null;
    return;
  }
  inEl.textContent = 'In';
  pathEl.textContent = folder; pathEl.title = folder;
  if (isNew(folder)) {
    cnt.textContent = '';
    box.innerHTML = '<div class="ct-empty">New folder. docsort creates it when you move the file, so cancelling leaves nothing behind.</div>';
    S.contentsShown = folder;
    return;
  }
  const files = contentsOf(folder);
  cnt.textContent = files.length === 1 ? '1 file' : `${files.length} files`;
  const conflict = findConflict(folder);
  const taken = S.take && S.take.folder === folder ? S.take.idx : -1;
  box.innerHTML = files.length
    ? files.map((n, i) => `<div class="ct${n === conflict ? ' conflict' : ''}${i === taken ? ' taken' : ''}" data-act="ct" data-i="${i}" id="ct-${i}" title="Click to use “${esc(stemOf(n))}” as the name">${fileIcon(n)}<span class="tn">${esc(n)}</span></div>`).join('')
    : '<div class="ct-empty">No files yet.</div>';
  if (S.contentsShown !== folder) { box.scrollTop = box.scrollHeight; S.contentsShown = folder; }
  const focusRow = (conflict && box.querySelector('.ct.conflict')) || (taken >= 0 && $(`ct-${taken}`));
  if (focusRow) {
    const top = focusRow.offsetTop; // .contents is the offset parent
    if (top < box.scrollTop || top + focusRow.offsetHeight > box.scrollTop + box.clientHeight) box.scrollTop = top - box.clientHeight / 2;
  }
}
function renderName() {
  const inp = $('nameInput');
  $('revertBtn').hidden = inp.value === FILE_STEM;
  $('revertBtn').innerHTML = ICON.revert;
  const notice = $('nameNotice');
  const folder = contentsFolder();
  const conflict = findConflict(folder);
  let html = '', cls = 'notice';
  if (S.nameHint) { html = `<span>${esc(S.nameHint)}</span>`; cls += ' info'; }
  else if (conflict) { html = `${ICON.warn}<span>“${esc(conflict)}” already exists in this folder.</span>`; cls += ' warn'; }
  notice.className = cls;
  notice.hidden = !html;
  notice.innerHTML = html;
  const target = S.chosen || (folder || null);
  $('moveBtn').disabled = !target && !(highlighted() && highlighted().kind === 'create');
  $('moveHint').textContent = S.focus === 'name' ? 'Return does not move' : S.focus === 'picker' ? '⌘Return moves with this name' : '';
  $('nameBox').title = 'Name the file. ⌥↑/⌥↓ take names from Folder contents, ⌘D inserts today’s date, ⇧⌘R reverts.';
}
const LEGEND = {
  A: [
    ['type', 'Filter the whole tree; columns keep only matches and their parents'],
    ['↑ ↓', 'Move within the focused column'],
    ['→ ←', 'Into the highlighted folder / out to its parent'],
    ['⌘G ⇧⌘G', 'Next / previous match in rank order (also ⌃G ⌃⇧G)'],
    ['Tab Return', 'Choose the highlighted folder, go to the name'],
    ['⇧⌘N', 'New folder inside the highlighted one (also ⌃⇧N)'],
    ['Esc', 'Clear the filter; again: leave the picker'],
    ['⌘Return', 'Move now (from picker or name)'],
    ['dbl-click', 'Choose a folder'],
  ],
  B: [
    ['type', 'Filter inside the current folder (scope chip shows it)'],
    ['↑ ↓', 'Move the highlight'],
    ['→', 'Step into the highlighted folder; its first row is the folder itself'],
    ['← ⌫', 'Step out, when the filter is empty'],
    ['⌘↑', 'Back to the archive root'],
    ['Tab Return', 'Choose the highlighted folder, go to the name'],
    ['⇧⌘N', 'New folder: steps into the highlighted folder (also ⌃⇧N)'],
    ['Esc', 'Clear the filter; again: leave the picker'],
    ['⌘Return', 'Move now (from picker or name)'],
    ['dbl-click', 'Step in, or choose a folder without subfolders'],
  ],
  name: [
    ['⌥↑ ⌥↓', 'Take the previous / next name from Folder contents'],
    ['⌘D ⌥⌘D', 'Insert today’s / the file’s date'],
    ['⇧⌘R ↺', 'Revert to the original name (also ⌃⇧R)'],
    ['⇧Tab Esc', 'Back to the picker'],
  ],
};
function renderLegend() {
  const row = ([k, w]) => `<div class="kr"><span class="keys">${k.split(' ').map((x) => (x === 'type' || x === 'dbl-click' ? `<em>${x}</em>` : `<kbd>${esc(x)}</kbd>`)).join(' ')}</span><span class="what">${esc(w)}</span></div>`;
  $('legend').innerHTML = `<h2 id="legendTitle">Keys · candidate ${S.cand}<span>${S.cand === 'A' ? 'Columns with filter' : 'Drill-down list with scoped filter'}</span></h2>
    <div class="grid">${LEGEND[S.cand].map(row).join('')}${LEGEND.name.map(([k, w]) => row([k, 'Name field: ' + w])).join('')}</div>`;
}
function renderHeader() {
  document.querySelectorAll('#candSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.cand === S.cand)));
}
function renderAll() {
  renderHeader();
  renderPanelWidth();
  renderFilterField();
  renderPicker();
  renderContents();
  renderName();
  renderLegend();
}

/* ---------------------------------------------------------------- focus */
function focusOf(el) {
  const id = el && el.id;
  if (id === 'filterInput') return 'picker';
  if (id === 'nfInput') return 'newfolder';
  if (id === 'nameInput' || id === 'revertBtn' || id === 'moveBtn') return 'name';
  return 'none';
}
function syncFocus() {
  const f = focusOf(document.activeElement);
  if (f === S.focus) return;
  const prev = S.focus;
  S.focus = f;
  if (prev === 'newfolder' && S.nf && (f === 'picker' || f === 'name')) {
    const snap = S.nf.snap; S.nf = null; restorePicker(snap);
  }
  if (f === 'picker' && S.chosen) unchoose();
  renderAll();
}

/* ---------------------------------------------------------------- keyboard */
function keyOf(e) {
  let key = e.key;
  if (key === ' ') key = 'space';
  else if (key.length === 1) {
    if (e.altKey && /^Key[A-Z]$/.test(e.code)) key = e.code.slice(3).toLowerCase();
    else key = key.toLowerCase();
  }
  if ((e.metaKey || e.ctrlKey) && /^Key[A-Z]$/.test(e.code)) key = e.code.slice(3).toLowerCase();
  return { key, cmd: e.metaKey, ctrl: e.ctrlKey, alt: e.altKey, shift: e.shiftKey };
}
function is(k, spec) {
  const parts = spec.split('+');
  const key = parts.pop();
  return k.key === key && k.cmd === parts.includes('cmd') && k.ctrl === parts.includes('ctrl') && k.alt === parts.includes('alt') && k.shift === parts.includes('shift');
}
const caretAtEnd = (inp) => inp.selectionStart === inp.value.length && inp.selectionEnd === inp.value.length;
function pickerKey(k) {
  const inp = $('filterInput');
  if (is(k, 'cmd+Enter') || is(k, 'ctrl+Enter')) { doMove(); return true; }
  if (is(k, 'Enter') || is(k, 'Tab')) { chooseHighlighted(); return true; }
  if (is(k, 'ArrowDown') || is(k, 'ArrowUp')) {
    const d = k.key === 'ArrowDown' ? 1 : -1;
    if (S.cand === 'A') aMove(d); else bMove(d);
    return true;
  }
  if (is(k, 'ArrowRight')) {
    if (!caretAtEnd(inp)) return false;
    if (S.cand === 'A') aInto(); else bInto();
    return true;
  }
  if (is(k, 'ArrowLeft')) {
    if (S.cand === 'A') { if (!caretAtEnd(inp)) return false; aOut(); return true; }
    if (inp.value) return false;
    bOut(); return true;
  }
  if (is(k, 'Backspace') && inp.value === '' && S.cand === 'B' && S.b.scope) { bOut(); return true; }
  if (is(k, 'cmd+ArrowUp') || is(k, 'ctrl+ArrowUp')) { if (S.cand === 'B') bRoot(); return true; }
  if (is(k, 'cmd+g') || is(k, 'ctrl+g')) { if (S.cand === 'A') aJump(1); return true; }
  if (is(k, 'cmd+shift+g') || is(k, 'ctrl+shift+g')) { if (S.cand === 'A') aJump(-1); return true; }
  if (is(k, 'cmd+shift+n') || is(k, 'ctrl+shift+n')) { newFolderCmd(); return true; }
  if (is(k, 'cmd+d') || is(k, 'cmd+alt+d')) return true;
  if (is(k, 'Escape')) {
    if (S.query) { clearFilter(); setStatus('Filter cleared.'); }
    else { inp.blur(); setStatus('Second Esc: in the app this returns to the sidebar; here it only leaves the picker.'); }
    return true;
  }
  return false;
}
function nfKey(k) {
  const inp = $('nfInput');
  if (is(k, 'Enter') || is(k, 'Tab')) { confirmNf(); return true; }
  if (is(k, 'Escape') || is(k, 'shift+Tab')) { cancelNf(); return true; }
  if (is(k, 'cmd+Enter') || is(k, 'ctrl+Enter')) { doMove(); return true; }
  if (is(k, 'cmd+d')) { insertDate(TODAY, inp); onNfInput(); return true; }
  if (is(k, 'cmd+shift+n') || is(k, 'ctrl+shift+n')) return true;
  return false;
}
function nameKey(k) {
  const inp = $('nameInput');
  if (is(k, 'cmd+Enter') || is(k, 'ctrl+Enter')) { doMove(); return true; }
  if (is(k, 'Enter')) { flashHint('Press ⌘Return to move'); return true; }
  if (is(k, 'alt+ArrowUp')) { takeName(-1); return true; }
  if (is(k, 'alt+ArrowDown')) { takeName(1); return true; }
  if (is(k, 'cmd+shift+r') || is(k, 'ctrl+shift+r')) { revertName(); return true; }
  if (is(k, 'cmd+d')) { insertDate(TODAY, inp); onNameInput(); return true; }
  if (is(k, 'cmd+alt+d')) { insertDate(FILE_DATE, inp); onNameInput(); return true; }
  if (is(k, 'shift+Tab') || is(k, 'Escape')) { backToPicker(); return true; }
  if (is(k, 'cmd+shift+n') || is(k, 'ctrl+shift+n')) { backToPicker(); newFolderCmd(); return true; }
  return false;
}
function onNameInput() {
  S.nameHint = '';
  S.take = null;
  renderContents();
  renderName();
}
document.addEventListener('keydown', (e) => {
  const a = document.activeElement;
  const id = a && a.id;
  const k = keyOf(e);
  let handled = false;
  if (id === 'filterInput') handled = pickerKey(k);
  else if (id === 'nfInput') handled = nfKey(k);
  else if (id === 'nameInput') handled = nameKey(k);
  else if (a && $('win').contains(a) && (is(k, 'cmd+Enter') || is(k, 'ctrl+Enter'))) { doMove(); handled = true; }
  if (handled) { e.preventDefault(); e.stopPropagation(); }
});

/* ---------------------------------------------------------------- mouse */
function focusPicker() {
  if (S.nf) { const snap = S.nf.snap; S.nf = null; restorePicker(snap); }
  if (S.chosen) unchoose();
  S.focus = 'picker';
  const inp = $('filterInput');
  inp.focus({ preventScroll: true });
}
$('win').addEventListener('mousedown', (e) => {
  if (e.target.closest('input')) return;
  e.preventDefault();
});
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) {
    if (e.target.closest('#filterBox')) { $('filterInput').focus(); }
    return;
  }
  const act = el.dataset.act;
  switch (act) {
    case 'cand':
      if (S.cand !== el.dataset.cand) { S.cand = el.dataset.cand; resetState(); renderAll(); }
      $('filterInput').focus({ preventScroll: true });
      break;
    case 'theme': setTheme(el.dataset.themeChoice); break;
    case 'reset': resetState(); renderAll(); $('filterInput').focus({ preventScroll: true }); break;
    case 'clear-ticks': S.done = { A: new Set(), B: new Set() }; renderTasks(); break;
    case 'arow': {
      // The second click of a double-click is ignored: the first one may have scrolled the columns under the pointer.
      if (e.detail >= 2) break;
      focusPicker();
      aClickRow(+el.dataset.col, el.dataset.path, el.dataset.sec);
      renderAll();
      break;
    }
    case 'brow': {
      if (e.detail >= 2) break;
      focusPicker();
      S.b.hl = +el.dataset.si;
      renderAll();
      break;
    }
    case 'binto': if (e.detail >= 2) break; focusPicker(); bInto(el.dataset.path); renderAll(); break;
    case 'crumb': focusPicker(); bJump(el.dataset.path); renderAll(); break;
    case 'create': { const h = highlighted(); if (h && h.kind === 'create') createFromQuery(h); break; }
    case 'newfolder': {
      if (S.chosen) unchoose();
      if (S.focus !== 'picker') { S.focus = 'picker'; $('filterInput').focus({ preventScroll: true }); }
      newFolderCmd();
      break;
    }
    case 'ct': takeNameFromClick(+el.dataset.i); break;
    case 'revert': revertName(); break;
    case 'move': doMove(); break;
    case 'clear': focusPicker(); if (S.query) clearFilter(); renderAll(); break;
    case 'token': backToPicker(); break;
    default: break;
  }
});
/* A double-click acts on the row its first click highlighted. */
document.addEventListener('dblclick', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el || (el.dataset.act !== 'arow' && el.dataset.act !== 'brow')) return;
  const h = highlighted();
  if (!h || h.kind !== 'folder') return;
  if (S.cand === 'A' || h.self) choose(h.path, h.via);
  else if (kids(h.path).length) { bInto(h.path); renderAll(); }
  else choose(h.path, h.via);
});
/* Header buttons keep the picker focused, so the panel does not jump while switching. */
document.querySelector('.intro').addEventListener('mousedown', (e) => {
  if (e.target.closest('[data-act="cand"], [data-act="reset"], [data-act="theme"], [data-act="clear-ticks"]')) e.preventDefault();
});
$('filterInput').addEventListener('input', onFilterInput);
$('nameInput').addEventListener('input', onNameInput);
$('pickerBody').addEventListener('input', (e) => { if (e.target.id === 'nfInput') onNfInput(); });
document.addEventListener('focusin', syncFocus);
document.addEventListener('focusout', () => setTimeout(syncFocus, 0));
$('panel').addEventListener('transitionend', (e) => { if (e.propertyName === 'width') scrollColsToEnd(true); });

/* ---------------------------------------------------------------- theme */
function setTheme(choice) {
  if (choice === 'auto') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', choice);
  document.querySelectorAll('#themeSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.themeChoice === choice)));
  try { localStorage.setItem('docsort-picker-theme', choice); } catch (err) { /* storage unavailable: keep the choice for this visit only */ }
}

/* ---------------------------------------------------------------- start */
(function start() {
  let theme = 'auto';
  try { theme = localStorage.getItem('docsort-picker-theme') || 'auto'; } catch (err) { /* storage unavailable: default to auto */ }
  setTheme(['auto', 'light', 'dark'].includes(theme) ? theme : 'auto');
  renderTasks();
  resetState();
  renderAll();
  $('filterInput').focus({ preventScroll: true });
})();
