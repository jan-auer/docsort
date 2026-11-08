'use strict';
/* Destination search concepts (docs/design/destination-search-study.md): A path field, B choice in list, C soft scope.
   Plain DOM, no libraries. FOLDERS and KNOWN_CONTENTS come from the data script above. The logic keeps all state in S
   and never reads the DOM, so it also runs headless (node) for checks; render() maps S onto the page. */

const HAS_DOM = typeof document !== 'undefined';
const TODAY = '2033-10-26';
const FILE_STEM = 'Rechnung_NA-33-08812';
const FILE_EXT = '.pdf';
/* The same Recent list as the earlier picker prototype, newest first. */
const START_RECENT = ['Mobilität/Jahreskarte Regio Plus', 'Kommunikation/Ilmnet Internet/Rechnungen', 'Chor Liederkranz/Kassa/2033', 'Gesundheit/Konrad/Augenarzt & Brillen', 'Bank & Geld/Girokonto Bürgerbank/2033-Q3', 'Arbeit Margit/Gehaltszettel/2033', 'Kleingarten Am Weidenbach/Pacht & Wasser'];
const MAX_RESULTS = 50;
/* Task targets, all folders of the fictional sample archive (or, for the new folder, one created in it). */
const T = {
  deep: 'Gesundheit/Margit/Physiotherapie',
  browseParent: 'Hund Fritzi',
  browse: 'Hund Fritzi/Hundeschule Pfotenweg',
  scopeFolder: 'Gesundheit',
  scoped: 'Gesundheit/Konrad/Augenarzt & Brillen',
  newParent: 'Reisen',
  newName: '2033-11 Besuch Matthias Westerholm',
  elsewhere: 'Chor Liederkranz/Noten',
};
T.newPath = `${T.newParent}/${T.newName}`;

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const lastSeg = (p) => p.slice(p.lastIndexOf('/') + 1);
const parentOf = (p) => (p.includes('/') ? p.slice(0, p.lastIndexOf('/')) : '');
const chainOf = (p) => { if (!p) return []; const parts = p.split('/'); return parts.map((_, i) => parts.slice(0, i + 1).join('/')); };
const crumbText = (p) => p.replace(/\//g, ' › ');
const where = (p) => p || 'Archive';
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const within = (p, base) => !base || p === base || p.startsWith(base + '/');
const collator = new Intl.Collator('de', { numeric: true, sensitivity: 'base' });

/* ---------------------------------------------------------------- icons */
const stroke = (vb, d, w = 1.4) =>
  `<svg viewBox="${vb}" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICON = {
  chev: stroke('0 0 12 12', '<path d="M4.5 2.5 8 6l-3.5 3.5"/>', 1.6),
  check: stroke('0 0 12 12', '<path d="M2.5 6.4 5 8.8l4.6-5.6"/>', 1.8),
  plus: stroke('0 0 12 12', '<path d="M6 1.5v9M1.5 6h9"/>', 1.5).replace('<svg ', '<svg class="plus" '),
  clear: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1a7 7 0 1 1 0 14A7 7 0 0 1 8 1Z M5.4 4.3 4.3 5.4 6.9 8l-2.6 2.6 1.1 1.1L8 9.1l2.6 2.6 1.1-1.1L9.1 8l2.6-2.6-1.1-1.1L8 6.9Z"/></svg>',
  folder: '<svg class="fold" viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" style="fill:var(--ficon-folder)"/><path d="M1 4.3h14" style="stroke:var(--ficon-folder-tab)" stroke-width=".8"/></svg>',
  /* "this folder": the folder with a downward "file here" arrow */
  here: '<svg class="fold" viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" style="fill:var(--ficon-folder)"/><path d="M8 4.6v5M5.8 7.6 8 9.8l2.2-2.2" fill="none" style="stroke:var(--ficon-page)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  newFolder: '<svg viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" fill="none" stroke="currentColor" stroke-width="1.1"/><path d="M8 5.2v4.6M5.7 7.5h4.6" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>',
};
function fileIcon(name) {
  const ext = (name.match(/\.([^.]+)$/) || ['', ''])[1].toLowerCase();
  const img = ['jpg', 'jpeg', 'png', 'heic'].includes(ext);
  const band = ext === 'pdf' ? '--ficon-pdf' : img ? '--ficon-img' : '--label3';
  const label = ext === 'pdf' ? 'PDF' : img ? 'JPG' : '';
  return `<span class="ficon"><svg viewBox="0 0 15 19" aria-hidden="true"><path d="M1.5 1.5h8l4 4v12h-12z" style="fill:var(--ficon-page);stroke:var(--ficon-stroke)" stroke-width=".8"/><path d="M9.5 1.5v4h4" fill="none" style="stroke:var(--ficon-stroke)" stroke-width=".8"/><rect x="1.9" y="11" width="11.2" height="4.6" style="fill:var(${band})"/>${label ? `<text x="7.5" y="14.5" text-anchor="middle" font-size="3.7" font-weight="700" font-family="-apple-system,Helvetica,sans-serif" style="fill:var(--ficon-page)">${label}</text>` : ''}</svg></span>`;
}

/* ---------------------------------------------------------------- folder model (from picker-src) */
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
  itemsCache.key = '';
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

/* ---------------------------------------------------------------- folder contents (from picker-src) */
const generatedCache = new Map();
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
const contentsOf = (folder) => baseContents(folder).slice().sort(collator.compare);
const stemOf = (name) => name.replace(/\.[^.]+$/, '');

/* ---------------------------------------------------------------- fuzzy matching (from picker-src) */
function foldChar(c) {
  if (c === 'ß') return 'ss';
  return c.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}
const foldStr = (s) => s.split('').map(foldChar).join('');
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
const queryTokens = (q) => q.split(/\s+/).filter(Boolean).map(foldStr);
/* Ranks candidates ({path, display}) for a query; marks are indices into display. */
function fuzzy(query, candidates, recentBoost) {
  const tokens = queryTokens(query);
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
/* Concept A's "/" query: each segment is matched fuzzily against one level below base, level by level. An empty last
   segment ("ges/mar/") lists every folder at that level. Marks index into the relative display path. */
function segmentMatches(base, query, recentBoost) {
  const segs = query.replace(/^\/+/, '').split('/').map((s) => s.trim());
  const n = segs.length;
  const prefix = base ? base + '/' : '';
  const out = [];
  for (const path of F.list) {
    if (!path.startsWith(prefix)) continue;
    const rel = path.slice(prefix.length);
    const parts = rel.split('/');
    if (parts.length !== n) continue;
    let score = 0, off = 0, ok = true;
    const marks = new Set();
    for (let i = 0; i < n && ok; i++) {
      const tokens = queryTokens(segs[i]);
      const p = prep(parts[i]);
      for (const t of tokens) {
        const r = matchToken(t, p);
        if (!r) { ok = false; break; }
        score += r.score;
        for (const j of r.pos) marks.add(off + p.map[j]);
      }
      if (ok && tokens.length && tokens.some((t) => p.f.startsWith(t))) score += 5;
      off += parts[i].length + 1;
    }
    if (!ok) continue;
    // With an empty last segment ("ges/mar/") the listed level ranks alike and sorts by name.
    score -= (segs[n - 1] ? rel.length : rel.length - parts[n - 1].length) * 0.05;
    const ri = recentBoost.indexOf(path);
    if (ri >= 0) score += 14 - ri * 0.5;
    out.push({ path, display: rel, score, marks });
  }
  out.sort((a, b) => b.score - a.score || collator.compare(a.display, b.display));
  return out;
}

/* ---------------------------------------------------------------- state */
const CONCEPTS = ['A', 'B', 'C'];
const S = {
  concept: 'A',
  focus: 'picker',          // sidebar | picker | newfolder (B/C inline row) | name | none
  pendingFocus: true,       // render() moves DOM focus to S.focus once
  selectName: false,        // render() selects the name field's text once
  recent: START_RECENT.slice(),
  query: '',
  scope: '',                // B/C: the location; A: the committed path in the field
  hl: 0,                    // index into the selectable rows
  chosen: null,             // chosen destination (A: equals scope while chosen)
  chosenVia: null,          // recent | browse | filter | new
  chosenScope: null,        // scope at the moment of choosing (for the task checks)
  nf: null,                 // new folder: B/C { parent, value, snap }; A { parent, snap } (the name is S.query)
  name: FILE_STEM,
  take: null,               // ⌥↑/⌥↓ position in Folder contents
  toast: '',
  hint: '',                 // short-lived note in the picker's bottom bar
  moved: '',                // last move, shown in the status line until the next action
  done: { A: new Set(), B: new Set(), C: new Set() },
};

function resetPanel() {
  resetFolders();
  S.query = ''; S.scope = ''; S.hl = 0;
  S.chosen = null; S.chosenVia = null; S.chosenScope = null;
  S.nf = null; S.name = FILE_STEM; S.take = null; S.toast = ''; S.hint = '';
  S.hl = defaultHl();
}

/* ---------------------------------------------------------------- listing */
let itemsCache = { key: '', items: [] };
const folderRow = (path, display, extra = {}) => ({ type: 'folder', path, display, marks: new Set(), ...extra });
function browseItems(scope) {
  const items = [];
  if (!scope) {
    const rec = S.recent.filter(exists);
    if (rec.length) {
      items.push({ type: 'header', text: 'Recent' });
      for (const p of rec) items.push(folderRow(p, p, { section: 'recent' }));
    }
    items.push({ type: 'header', text: 'All folders' });
    for (const p of kids('')) items.push(folderRow(p, p));
  } else {
    // The folder you stand in is choosable itself, as the first row.
    items.push(folderRow(scope, lastSeg(scope), { self: true }));
    items.push({ type: 'sep' });
    for (const p of kids(scope)) items.push(folderRow(p, lastSeg(p)));
  }
  return items;
}
const subtreeCands = (scope) => {
  const prefix = scope ? scope + '/' : '';
  return F.list.filter((p) => p.startsWith(prefix)).map((p) => ({ path: p, display: p.slice(prefix.length) }));
};
const countText = (n, scope) => `${n} ${n === 1 ? 'match' : 'matches'}${scope ? ` in ${lastSeg(scope)}` : ''}${n > MAX_RESULTS ? ` · best ${MAX_RESULTS} shown` : ''}`;
/* The create row for a typed name, or null when the name is an existing folder. A resolves leading "/" segments
   fuzzily (rei/Neu → Neu in Reisen); B and C resolve names literally, as today. */
function createRow(base, query, fuzzyParents) {
  const raw = query.trim().replace(/\s*\/\s*/g, '/').replace(/\/+/g, '/').replace(/^\/|\/$/g, '');
  if (!raw || /:/.test(raw)) return null;
  const segs = raw.split('/');
  let parent = base, rest = segs;
  if (fuzzyParents && !resolveNew(base, raw).existing) {
    for (let k = segs.length - 1; k >= 1; k--) {
      const lead = segs.slice(0, k).join('/');
      const lit = resolveNew(base, lead);
      const top = lit.existing ? { path: lit.existing } : segmentMatches(base, lead, S.recent)[0];
      if (top) { parent = top.path; rest = segs.slice(k); break; }
    }
  }
  const res = resolveNew(parent, rest.join('/'));
  if (!res.create.length) return null;
  const at = parentOf(res.create[0]);
  return { type: 'create', parent: at, name: res.path.slice(at ? at.length + 1 : 0), path: res.path, create: res.create };
}

function itemsA() {
  const scope = S.scope;
  if (S.nf) {
    const items = [folderRow(scope, lastSeg(scope) || 'Archive', { self: true, inert: true }), { type: 'sep' }];
    const v = S.query.trim();
    const res = v ? resolveNew(scope, v) : null;
    items.push({ type: 'nfpreview', parent: scope, value: v, existing: res && res.existing });
    items.push({ type: 'info', text: res && res.existing ? `${where(lastSeg(scope))} already contains “${lastSeg(res.existing)}”. Return selects it.` : 'Type the name; a slash nests. Tab or Return confirms, Esc cancels.' });
    return items;
  }
  const q = S.query.replace(/^\/+/, '');
  if (!q.trim()) return browseItems(scope);
  const slash = q.includes('/');
  const results = slash ? segmentMatches(scope, q, S.recent) : fuzzy(q, subtreeCands(scope), S.recent);
  const create = q.trimEnd().endsWith('/') ? null : createRow(scope, q, true);
  const items = [];
  if (results.length) {
    items.push({ type: 'header', text: countText(results.length, scope) });
    for (const r of results.slice(0, MAX_RESULTS)) items.push({ type: 'folder', ...r, section: 'results' });
    // As today, a plain query offers to create only when nothing matches; a path query ("reis/Neu") names folders,
    // so its create row is offered next to partial matches.
    if (create && slash) items.push(create);
    return items;
  }
  if (create) items.push(create);
  else items.push({ type: 'info', text: `No folder${scope ? ` in ${lastSeg(scope)}` : ''} matches.` });
  if (scope) {
    // Borrowed from C: a scoped search that finds nothing shows the whole archive below a hairline.
    const outside = (r) => !within(r.path, scope);
    const all = (slash ? segmentMatches('', q, S.recent) : fuzzy(q, F.list.map((p) => ({ path: p, display: p })), S.recent)).filter(outside);
    if (all.length) {
      items.push({ type: 'header', text: `Not in ${lastSeg(scope)} – elsewhere`, hairline: true });
      for (const r of all.slice(0, MAX_RESULTS)) items.push({ type: 'folder', ...r, section: 'elsewhere' });
    }
  }
  return items;
}
function itemsBC() {
  const scope = S.scope;
  if (S.nf) return [{ type: 'header', text: `New folder in ${where(S.nf.parent)}` }, { type: 'nfslot', parent: S.nf.parent }];
  const q = S.query;
  if (!q.trim()) return browseItems(scope);
  const items = [];
  if (S.concept === 'C' && scope) {
    const inRes = fuzzy(q, subtreeCands(scope), S.recent);
    const prefix = scope + '/';
    const elseRes = fuzzy(q, F.list.filter((p) => p !== scope && !p.startsWith(prefix)).map((p) => ({ path: p, display: p })), S.recent);
    if (!inRes.length && !elseRes.length) return [createRow(scope, q, false) || { type: 'info', text: 'No folder matches.' }];
    items.push({ type: 'header', text: `In ${lastSeg(scope)}`, count: inRes.length });
    if (inRes.length) for (const r of inRes.slice(0, MAX_RESULTS)) items.push({ type: 'folder', ...r, section: 'in' });
    else items.push({ type: 'info', text: `Nothing in ${lastSeg(scope)} matches.` });
    if (elseRes.length) {
      items.push({ type: 'header', text: 'Elsewhere', count: elseRes.length, hairline: true });
      for (const r of elseRes.slice(0, MAX_RESULTS)) items.push({ type: 'folder', ...r, section: 'elsewhere' });
    }
    return items;
  }
  const res = fuzzy(q, subtreeCands(scope), S.recent);
  if (!res.length) return [createRow(scope, q, false) || { type: 'info', text: 'No folder matches.' }];
  items.push({ type: 'header', text: countText(res.length, scope) });
  for (const r of res.slice(0, MAX_RESULTS)) items.push({ type: 'folder', ...r, section: 'results' });
  return items;
}
function items() {
  const key = [S.concept, S.query, S.scope, S.nf ? S.nf.parent : '\u0002', F.list.length, S.recent.join('|')].join('\u0001');
  if (itemsCache.key === key) return itemsCache.items;
  itemsCache = { key, items: S.concept === 'A' ? itemsA() : itemsBC() };
  return itemsCache.items;
}
const isSelectable = (it) => (it.type === 'folder' && !it.inert) || it.type === 'create' || it.type === 'nfpreview';
const selectable = () => items().filter(isSelectable);
function defaultHl() {
  const sel = selectable();
  const i = sel.findIndex((x) => x.type === 'nfpreview');
  if (i >= 0) return i;
  const f = sel.findIndex((x) => x.type === 'folder');
  return f >= 0 ? f : 0;
}
function highlighted() {
  const sel = selectable();
  if (!sel.length) return null;
  return sel[clamp(S.hl, 0, sel.length - 1)];
}
/* Index of a folder's row, skipping "this folder" and (unless asked) Recent. */
function indexOfPath(path, allowRecent) {
  return selectable().findIndex((x) => x.type === 'folder' && x.path === path && !x.self && (allowRecent || x.section !== 'recent'));
}
function viaOf(h) {
  if (h.section === 'recent') return 'recent';
  return S.query.trim() ? 'filter' : 'browse';
}

/* ---------------------------------------------------------------- picker actions */
function wantFocus(stop) { S.focus = stop; S.pendingFocus = true; }
function flashHint(text) {
  S.hint = text;
  clearTimeout(flashHint.t);
  if (HAS_DOM) flashHint.t = setTimeout(() => { S.hint = ''; render(); }, 3200);
}
function showToast(text) {
  S.toast = text;
  clearTimeout(showToast.t);
  if (HAS_DOM) showToast.t = setTimeout(() => { S.toast = ''; render(); }, 2000);
}
function unchoose() { S.chosen = null; S.chosenVia = null; S.chosenScope = null; }

/* Typing (or any change of the field's text). */
function setQueryFromUser(v) {
  S.moved = '';
  S.query = v;
  if (S.concept === 'A' && S.nf) { S.hl = defaultHl(); return; }
  unchoose();
  S.hl = defaultHl();
}
function moveHl(delta) {
  if (S.concept === 'A' && S.nf) return;
  const sel = selectable();
  if (!sel.length) return;
  unchoose();
  S.hl = clamp(S.hl + delta, 0, sel.length - 1);
}
/* A: write the highlighted folder into the path. B/C: step into it. */
function stepInto(path) {
  const h = highlighted();
  const p = path || (h && h.type === 'folder' && !h.self ? h.path : null);
  if (!p) return false;
  unchoose();
  S.scope = p; S.query = ''; S.hl = defaultHl();
  return true;
}
/* A: remove the last path segment. B/C: step out. The folder you came from is highlighted. */
function stepOut() {
  if (!S.scope) return false;
  const old = S.scope;
  unchoose();
  S.scope = parentOf(old);
  if (S.concept !== 'A') S.query = '';
  S.hl = S.query.trim() ? defaultHl() : Math.max(0, indexOfPath(old, false));
  return true;
}
/* Path-bar segment (B/C) or field segment (A): jump there, highlighting the child you came from. */
function jumpTo(path) {
  const old = S.scope;
  unchoose();
  S.scope = path; S.query = '';
  const child = old !== path && within(old, path) ? chainOf(old)[chainOf(path).length] : null;
  S.hl = child ? Math.max(0, indexOfPath(child, false)) : defaultHl();
}
function toRoot(keepQuery) {
  const top = S.scope ? chainOf(S.scope)[0] : null;
  unchoose();
  S.scope = '';
  if (!keepQuery) S.query = '';
  S.hl = !S.query.trim() && top ? Math.max(0, indexOfPath(top, false)) : defaultHl();
}
function clearAll() { unchoose(); S.scope = ''; S.query = ''; S.hl = defaultHl(); }

function choose() {
  const h = highlighted();
  if (!h) return;
  if (h.type === 'create') {
    if (S.concept === 'A') { flashHint('Tab doesn’t create folders: ⇧⌘N or a click on the row does.'); return; }
    createFrom(h);
    return;
  }
  if (h.type === 'nfpreview') { confirmNf(); return; }
  const via = viaOf(h), scopeBefore = S.scope;
  if (S.concept === 'A') { S.scope = h.path; S.query = ''; S.hl = 0; }
  setChosen(h.path, via, scopeBefore);
}
function setChosen(path, via, scopeBefore) {
  S.chosen = path; S.chosenVia = via; S.chosenScope = scopeBefore;
  checkTasks(path, via, scopeBefore);
  S.take = null;
  wantFocus('name'); S.selectName = true;
}
/* Shows a just-created or found folder: A writes it as the path, B/C stand in its parent with its row highlighted. */
function adoptPath(path) {
  S.query = '';
  if (S.concept === 'A') { S.scope = path; S.hl = 0; return; }
  S.scope = parentOf(path); itemsCache.key = '';
  S.hl = Math.max(0, indexOfPath(path, false));
}
function createFrom(row) {
  const scopeBefore = S.scope;
  addPending(row.create);
  adoptPath(row.path);
  setChosen(row.path, 'new', scopeBefore);
}

/* ⇧⌘N */
function newFolderCmd() {
  const h = highlighted();
  if (h && h.type === 'create') { createFrom(h); return; }
  if (S.concept === 'A') {
    if (S.nf) return;
    const parent = h && h.type === 'folder' ? h.path : S.scope;
    unchoose();
    S.nf = { parent, snap: { scope: S.scope, query: S.query, hl: S.hl } };
    S.scope = parent; S.query = ''; itemsCache.key = '';
    S.hl = defaultHl();
    wantFocus('picker');
    return;
  }
  if (S.nf) { wantFocus('newfolder'); return; }
  const parent = h && h.type === 'folder' ? h.path : S.scope;
  unchoose();
  S.nf = { parent, value: '', snap: { scope: S.scope, query: S.query, hl: S.hl } };
  S.scope = parent; S.query = ''; itemsCache.key = '';
  wantFocus('newfolder');
}
function cancelNf(focusPicker) {
  if (!S.nf) return;
  const snap = S.nf.snap;
  S.nf = null;
  S.scope = snap.scope; S.query = snap.query; itemsCache.key = '';
  S.hl = snap.hl;
  if (focusPicker) wantFocus('picker');
  flashHint('New folder cancelled; nothing was created.');
}
/* Confirms the new-folder name (A: the field's text, B/C: the inline row). */
function confirmNf() {
  const raw = S.concept === 'A' ? S.query : S.nf.value;
  const v = raw.trim().replace(/\s*\/\s*/g, '/').replace(/\/+/g, '/').replace(/^\/|\/$/g, '');
  if (!v) { cancelNf(true); return false; }
  if (/:/.test(v)) { flashHint('Folder names can’t contain “:”.'); return false; }
  const parent = S.nf.parent, scopeBefore = S.nf.snap.scope;
  const res = resolveNew(parent, v);
  S.nf = null;
  if (res.existing) { adoptPath(res.existing); setChosen(res.existing, 'browse', scopeBefore); return true; }
  addPending(res.create);
  adoptPath(res.path);
  setChosen(res.path, 'new', scopeBefore);
  return true;
}
function nfNotice(parent, value) {
  if (/:/.test(value)) return { warn: true, text: 'Folder names can’t contain “:”.' };
  const res = value.trim() ? resolveNew(parent, value) : null;
  if (res && res.existing) return { warn: true, text: `${where(lastSeg(parentOf(res.existing)))} already contains a folder named “${lastSeg(res.existing)}”. Return selects it.` };
  if (res && res.create.length > 1) return { warn: false, text: `Creates ${res.create.length} nested folders.` };
  return { warn: false, text: 'Tab or Return confirms · Esc cancels' };
}

/* ---------------------------------------------------------------- move */
/* What Move would file into right now: { path, via, scopeBefore } or { blocked: reason }. */
function moveTarget() {
  const inPicker = S.focus === 'picker' || S.focus === 'newfolder';
  if (S.chosen && !inPicker) return { path: S.chosen, via: S.chosenVia, scopeBefore: S.chosenScope };
  if (S.nf) return { blocked: 'Name the new folder first.' };
  const h = highlighted();
  if (h && h.type === 'folder') {
    if (S.chosen === h.path) return { path: S.chosen, via: S.chosenVia, scopeBefore: S.chosenScope };
    return { path: h.path, via: viaOf(h), scopeBefore: S.scope };
  }
  if (h && h.type === 'create') return { blocked: S.concept === 'A' ? 'Create the folder first (⇧⌘N or a click).' : null, create: h };
  return { blocked: 'Nothing highlighted.' };
}
function effectiveStem() {
  let v = S.name.trim();
  if (!v) return FILE_STEM;
  while (v.toLowerCase().endsWith(FILE_EXT) && v.length > FILE_EXT.length) v = v.slice(0, v.length - FILE_EXT.length).trimEnd();
  return v;
}
function moveNow() {
  if (S.nf) {
    if (!confirmNf()) return;
  }
  let t = moveTarget();
  if (t.create && !t.blocked) { createFrom(t.create); t = moveTarget(); }
  if (t.blocked || !t.path) { if (t.blocked) flashHint(t.blocked); return; }
  checkTasks(t.path, t.via, t.scopeBefore);
  const name = effectiveStem() + FILE_EXT;
  const created = chainOf(t.path).filter(isNew);
  let msg = `Moved to <b>${esc(t.path)}</b> as <b>${esc(name)}</b>`;
  if (created.length) msg += ` · created ${esc(created.map(lastSeg).join('/'))}`;
  msg += '. Panel reset for the next try; focus is back in the sidebar.';
  resetPanel();
  S.moved = msg;
  wantFocus('sidebar');
}

/* ---------------------------------------------------------------- tasks */
const TASKS = {
  t1: { text: `File into <code>${esc(T.deep)}</code> by typing.` },
  t2: { text: `Browse <code>${esc(T.browseParent)}</code> and pick <code>${esc(lastSeg(T.browse))}</code>.` },
  t3: { text: `Inside <code>${esc(T.scopeFolder)}</code>, search <code>augen</code> and file into <code>${esc(T.scoped)}</code>.` },
  t4: { text: `Create <code>${esc(T.newName)}</code> in <code>${esc(T.newParent)}</code>.` },
  t5: { text: `From inside <code>${esc(T.scopeFolder)}</code>, find <code>${esc(T.elsewhere)}</code>.` },
};
const TASK_KEYS = {
  A: {
    t1: '<kbd>margit physio</kbd> Tab, or <kbd>ges/mar/phy</kbd> Tab',
    t2: '<kbd>hund</kbd> → ↓×5 Tab',
    t3: '<kbd>gesund</kbd> → <kbd>augen</kbd> Tab',
    t4: `<kbd>reisen</kbd> → <kbd>${esc(T.newName)}</kbd> ⇧⌘N`,
  },
  B: {
    t1: '<kbd>margit physio</kbd> Tab',
    t2: '<kbd>hund</kbd> → ↓×5 Tab',
    t3: '<kbd>gesund</kbd> → <kbd>augen</kbd> Tab',
    t4: `<kbd>reisen</kbd> ⇧⌘N <kbd>${esc(T.newName)}</kbd> Tab`,
  },
  C: {
    t1: '<kbd>margit physio</kbd> Tab',
    t2: '<kbd>hund</kbd> → ↓×5 Tab',
    t3: '<kbd>gesund</kbd> → <kbd>augen</kbd> Tab',
    t4: `<kbd>reisen</kbd> ⇧⌘N <kbd>${esc(T.newName)}</kbd> Tab`,
    t5: '<kbd>gesund</kbd> → <kbd>noten</kbd> Tab (nothing in Gesundheit matches, so the first Elsewhere row is highlighted)',
  },
};
function checkTasks(path, via, scopeBefore) {
  const sb = scopeBefore || '';
  if (path === T.deep) markDone('t1');
  if (path === T.browse && via === 'browse') markDone('t2');
  if (path === T.scoped && via === 'filter' && sb && within(sb, T.scopeFolder)) markDone('t3');
  if (path === T.newPath && isNew(path)) markDone('t4');
  if (S.concept === 'C' && path === T.elsewhere && via === 'filter' && sb && within(sb, T.scopeFolder)) markDone('t5');
}
function markDone(id) { S.done[S.concept].add(id); }

/* ---------------------------------------------------------------- keyboard (state only) */
/* k: { key, cmd, ctrl, alt, shift }; caret: { start, end, len } of the focused text field. */
function is(k, spec) {
  const parts = spec.split('+');
  const key = parts.pop();
  return k.key === key && k.cmd === parts.includes('cmd') && k.ctrl === parts.includes('ctrl') && k.alt === parts.includes('alt') && k.shift === parts.includes('shift');
}
const cmdOr = (k, rest) => is(k, 'cmd+' + rest) || is(k, 'ctrl+' + rest);
const isMoveKey = (k) => cmdOr(k, 'Enter');
const printable = (k) => k.key.length === 1 && !k.cmd && !k.ctrl;

function switchConcept(c) {
  if (!CONCEPTS.includes(c)) return;
  S.concept = c;
  S.moved = '';
  resetPanel();
  wantFocus('picker');
}
function handleKey(k, caret) {
  if (k.ctrl && !k.cmd && !k.alt && !k.shift && /^[123]$/.test(k.key)) { switchConcept(CONCEPTS[+k.key - 1]); return true; }
  switch (S.focus) {
    case 'sidebar': return sidebarKey(k);
    case 'picker': return S.concept === 'A' ? pickerKeyA(k, caret) : pickerKeyBC(k, caret);
    case 'newfolder': return nfKeyBC(k);
    case 'name': return nameKey(k);
    default: return false;
  }
}
function sidebarKey(k) {
  if (isMoveKey(k)) {
    if (S.chosen) { moveNow(); return true; }
    wantFocus('picker'); showToast('Choose a destination first');
    return true;
  }
  if (is(k, 'Tab') || is(k, 'Enter')) { wantFocus('picker'); return true; }
  if (is(k, 'shift+Tab')) { wantFocus('name'); return true; }
  if (printable(k) && !k.alt) {
    wantFocus('picker');
    setQueryFromUser(S.query + k.key);
    return true;
  }
  return false;
}
function pickerCommon(k) {
  if (isMoveKey(k)) { moveNow(); return true; }
  if (is(k, 'ArrowDown')) { moveHl(1); return true; }
  if (is(k, 'ArrowUp')) { moveHl(-1); return true; }
  if (cmdOr(k, 'shift+n')) { newFolderCmd(); return true; }
  return false;
}
function pickerKeyA(k, caret) {
  const atEnd = caret.start === caret.len && caret.end === caret.len;
  const empty = !S.query;
  if (S.nf) {
    if (isMoveKey(k)) { moveNow(); return true; }
    if (is(k, 'Enter') || is(k, 'Tab')) { confirmNf(); return true; }
    if (is(k, 'Escape') || is(k, 'shift+Tab')) { cancelNf(true); return true; }
    if (is(k, 'Backspace') && empty) { cancelNf(true); return true; }
    if (is(k, 'ArrowDown') || is(k, 'ArrowUp') || cmdOr(k, 'shift+n')) return true;
    return false;
  }
  if (pickerCommon(k)) return true;
  if (is(k, 'Enter') || is(k, 'Tab')) { choose(); return true; }
  if (is(k, 'shift+Tab')) { wantFocus('sidebar'); return true; }
  if (is(k, 'ArrowRight')) {
    if (!atEnd) return false;
    stepInto();
    return true;
  }
  if (is(k, 'ArrowLeft')) {
    if (!empty) return false;
    stepOut();
    return true;
  }
  if (is(k, 'Backspace')) {
    if (empty || (caret.start === 0 && caret.end === 0)) { stepOut(); return true; }
    return false;
  }
  if (cmdOr(k, 'ArrowUp')) { clearAll(); return true; }
  if (is(k, 'Escape')) {
    if (S.query || S.scope) { clearAll(); flashHint('Path cleared. Esc again goes back to the sidebar.'); }
    else wantFocus('sidebar');
    return true;
  }
  return false;
}
function pickerKeyBC(k, caret) {
  const atEnd = caret.start === caret.len && caret.end === caret.len;
  const empty = !S.query;
  if (pickerCommon(k)) return true;
  if (is(k, 'Enter') || is(k, 'Tab')) { choose(); return true; }
  if (is(k, 'shift+Tab')) { wantFocus('sidebar'); return true; }
  if (is(k, 'ArrowRight')) {
    if (!atEnd) return false;
    stepInto();
    return true;
  }
  if (is(k, 'ArrowLeft') || is(k, 'Backspace')) {
    if (!empty) return false;
    stepOut();
    return true;
  }
  if (cmdOr(k, 'ArrowUp')) { toRoot(true); return true; }
  if (is(k, 'Escape')) {
    if (S.query || S.scope) { clearAll(); flashHint('Search and location cleared. Esc again goes back to the sidebar.'); }
    else wantFocus('sidebar');
    return true;
  }
  return false;
}
function nfKeyBC(k) {
  if (isMoveKey(k)) { moveNow(); return true; }
  if (is(k, 'Enter') || is(k, 'Tab')) { confirmNf(); return true; }
  if (is(k, 'Escape') || is(k, 'shift+Tab')) { cancelNf(true); return true; }
  if (cmdOr(k, 'shift+n')) return true;
  return false;
}
function nameKey(k) {
  if (isMoveKey(k)) { moveNow(); return true; }
  if (is(k, 'Enter')) { showToast('Press ⌘Return to move'); return true; }
  if (is(k, 'shift+Tab') || is(k, 'Escape')) { wantFocus('picker'); return true; }
  if (is(k, 'Tab')) { wantFocus('sidebar'); return true; }
  if (is(k, 'alt+ArrowUp')) { takeName(-1); return true; }
  if (is(k, 'alt+ArrowDown')) { takeName(1); return true; }
  return false;
}

/* ---------------------------------------------------------------- name and folder contents */
function contentsFolder() {
  if (S.chosen && S.focus !== 'picker') return S.chosen;
  if (S.nf) return null;
  const h = highlighted();
  return h && h.type === 'folder' ? h.path : S.chosen;
}
function takeName(dir) {
  const folder = contentsFolder();
  if (!folder) return;
  const files = contentsOf(folder);
  if (!files.length) { showToast(`“${lastSeg(folder)}” has no files to take a name from.`); return; }
  const idx = !S.take || S.take.folder !== folder ? files.length - 1 : clamp(S.take.idx + dir, 0, files.length - 1);
  S.take = { folder, idx };
  S.name = stemOf(files[idx]);
  S.selectName = true;
}

/* ---------------------------------------------------------------- headless API (node checks) */
if (!HAS_DOM) {
  const keyFrom = (spec) => {
    const parts = spec.split('+');
    const key = parts.pop();
    return { key, cmd: parts.includes('cmd'), ctrl: parts.includes('ctrl'), alt: parts.includes('alt'), shift: parts.includes('shift') };
  };
  globalThis.MOCK = {
    S, T, items, selectable, highlighted, fuzzy, segmentMatches, createRow, moveTarget, contentsFolder,
    reset(concept) { S.done = { A: new Set(), B: new Set(), C: new Set() }; switchConcept(concept); S.focus = 'picker'; },
    type(text) {
      if (S.focus === 'newfolder') S.nf.value += text;
      else if (S.focus === 'name') S.name += text;
      else if (S.focus === 'sidebar') for (const ch of text) handleKey(keyFrom(ch), { start: 0, end: 0, len: 0 });
      else setQueryFromUser(S.query + text);
    },
    key(spec) {
      const len = S.focus === 'newfolder' ? S.nf.value.length : S.focus === 'name' ? S.name.length : S.query.length;
      return handleKey(keyFrom(spec), { start: len, end: len, len });
    },
    click(path) {  // click a folder row by path (first match)
      const i = selectable().findIndex((x) => x.type === 'folder' && x.path === path);
      if (i >= 0) { S.hl = i; unchoose(); }
      return i;
    },
  };
}

/* ================================================================ rendering (browser only) */
const DESC = {
  A: 'The field is the destination, written as a path: committed folders sit before the caret as clickable segments, then what you type. → (or Tab) accepts the highlighted completion into the path, ⌫ in an empty query removes the last segment, and a “/” in the query matches level by level. New folders are made in the same field: the create row (⇧⌘N or a click), or ⇧⌘N on a folder. There is no path bar; when a search under the path finds nothing, the whole archive is offered below a hairline.',
  B: 'The field holds only what you type. The location is shown in one place, the path bar at the top of the list. Choosing (Tab) marks the row with ✓ and keeps query and list, so ⇧Tab returns to exactly what you chose from; the “Files in …” header names the destination. ⌘↑ jumps to the archive root and keeps the query. New folder works as today.',
  C: 'Like B, but scope only ranks: inside a folder every search covers the whole archive. Matches under the folder come first (“In …”), the rest of the archive follows (“Elsewhere”), so a folder you stand in can never hide the target. ⌘↑ jumps to the root and keeps the query.',
};
const KEYREF = {
  A: [
    ['type', 'Search below the path (root: whole archive)'],
    ['/', 'Match level by level: ges/mar/phy'],
    ['↑ ↓', 'Highlight'],
    ['→', 'Complete: write the highlighted folder into the path'],
    ['← ⌫', 'In an empty query: remove the last segment'],
    ['Tab Return', 'Choose (path = destination), go to the name'],
    ['⇧⌘N', 'Create row: create it · folder: new folder inside it'],
    ['Esc ⌘↑', 'Clear the path; Esc again: back to the sidebar'],
    ['⌘Return', 'Move now'],
    ['click', 'A path segment cuts the path there'],
  ],
  B: [
    ['type', 'Search the location’s subtree'],
    ['↑ ↓', 'Highlight'],
    ['→', 'Step into the highlighted folder'],
    ['← ⌫', 'In an empty field: step out'],
    ['Tab Return', 'Choose (row ✓), go to the name'],
    ['⇧⌘N', 'New folder inside the highlighted folder'],
    ['⌘↑', 'Archive root, keeping the query'],
    ['Esc', 'Clear query and location; again: sidebar'],
    ['⌘Return', 'Move the highlighted folder now'],
  ],
  C: [
    ['type', 'Search everything, the location first'],
    ['↑ ↓', 'Highlight (across both sections)'],
    ['→', 'Step into the highlighted folder'],
    ['← ⌫', 'In an empty field: step out'],
    ['Tab Return', 'Choose (row ✓), go to the name'],
    ['⇧⌘N', 'New folder inside the highlighted folder'],
    ['⌘↑', 'Archive root, keeping the query'],
    ['Esc', 'Clear query and location; again: sidebar'],
    ['⌘Return', 'Move the highlighted folder now'],
  ],
  common: [
    ['Name: Return', 'Toast only; ⌘Return moves'],
    ['Name: ⇧Tab Esc', 'Back to the picker · Tab: to the sidebar'],
    ['Name: ⌥↑ ⌥↓', 'Take a name from the folder’s files'],
    ['Sidebar: type', 'Goes into the destination field · Tab: picker'],
    ['⌃1 ⌃2 ⌃3', 'Switch concept'],
  ],
};

let rendering = false;
let nfInputEl = null;
let lastListKey = '';

function segHtml(text, marks) {
  let html = '', inBold = false;
  for (let i = 0; i < text.length; i++) {
    const b = marks.has(i);
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

function renderHeader() {
  document.querySelectorAll('#conceptSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.concept === S.concept)));
  $('conceptDesc').textContent = DESC[S.concept];
  const ids = S.concept === 'C' ? ['t1', 't2', 't3', 't4', 't5'] : ['t1', 't2', 't3', 't4'];
  $('taskList').innerHTML = ids.map((id) => {
    const done = S.done[S.concept].has(id);
    return `<li class="${done ? 'done' : ''}"><span class="tick" aria-label="${done ? 'done' : 'not done yet'}">${done ? ICON.check : ''}</span><span class="tt">${TASKS[id].text}<span class="tk">${TASK_KEYS[S.concept][id]}</span></span></li>`;
  }).join('');
  const row = ([k, w]) => `<div class="kr"><span class="kk">${esc(k)}</span><span class="what">${esc(w)}</span></div>`;
  $('keyRef').innerHTML = `${KEYREF[S.concept].map(row).join('')}<div class="kr-gap"></div>${KEYREF.common.map(row).join('')}<p class="note">Ctrl works for ⌘ (⌃↩, ⌃⇧N, ⌃↑), useful where the browser keeps ⇧⌘N for itself.</p>`;
}

function placeholder() {
  if (S.concept === 'A') {
    if (S.nf) return `New folder in ${where(lastSeg(S.nf.parent))}`;
    if (S.chosen) return '';
    return S.scope ? 'Search here' : 'Search or type a path';
  }
  if (S.concept === 'B') return S.scope ? `Search in ${lastSeg(S.scope)}` : 'Search archive';
  return S.scope ? `Search, ${lastSeg(S.scope)} first` : 'Search';
}
function renderField() {
  const inp = $('filterInput');
  if (inp.value !== S.query) { inp.value = S.query; inp.setSelectionRange(S.query.length, S.query.length); }
  inp.placeholder = placeholder();
  const box = $('filterBox');
  box.classList.toggle('nfmode', S.concept === 'A' && !!S.nf);
  const apath = $('aPath');
  apath.hidden = S.concept !== 'A' || !S.scope;
  if (!apath.hidden) {
    const chain = chainOf(S.scope);
    apath.innerHTML = `<span class="ell" hidden>… / </span>` + chain.map((p, i) => `<span class="pseg"><button type="button" class="seg-btn" data-act="aseg" data-path="${esc(p)}" tabindex="-1" title="${esc(p)}: cut the path here">${esc(lastSeg(p))}</button><span class="psep">/</span></span>`).join('')
      + (chain.some(isNew) ? '<span class="badge-new">New</span>' : '');
    fitPath();
  }
  $('filterClear').hidden = !(S.query || (S.concept === 'A' && S.scope));
  $('filterClear').innerHTML = ICON.clear;
  renderGhost();
}
/* Long paths lose their head: "… / Margit / Physiotherapie /". */
function fitPath() {
  const apath = $('aPath');
  const box = $('filterBox');
  // Leave room for typing; with an empty query the path may take nearly the whole field.
  const max = Math.max(60, box.clientWidth - (S.query ? 140 : 108));
  const segs = [...apath.querySelectorAll('.pseg')];
  const ell = apath.querySelector('.ell');
  segs.forEach((s) => { s.hidden = false; });
  ell.hidden = true;
  for (let i = 0; i < segs.length - 1 && apath.scrollWidth > max; i++) { segs[i].hidden = true; ell.hidden = false; }
}
let measureCtx = null;
function renderGhost() {
  const ghost = $('ghost');
  ghost.textContent = '';
  if (S.concept !== 'A' || S.nf || S.focus !== 'picker') return;
  const inp = $('filterInput');
  if (!S.query || inp.selectionStart !== S.query.length || inp.selectionEnd !== S.query.length) return;
  const h = highlighted();
  if (!h || h.type !== 'folder') return;
  const typed = S.query.slice(S.query.lastIndexOf('/') + 1);
  const tf = foldStr(typed);
  const name = lastSeg(h.path);
  if (!tf || !foldStr(name).startsWith(tf)) return;
  let i = 0;
  while (i < name.length && foldStr(name.slice(0, i)).length < tf.length) i++;
  if (foldStr(name.slice(0, i)).length !== tf.length || i >= name.length) return;
  if (!measureCtx) measureCtx = document.createElement('canvas').getContext('2d');
  const cs = getComputedStyle(inp);
  measureCtx.font = `${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`;
  ghost.textContent = name.slice(i);
  ghost.style.left = `${measureCtx.measureText(S.query).width - inp.scrollLeft}px`;
}

function rowHtml(it, si, hlItem) {
  const isHl = it === hlItem;
  if (it.type === 'create') {
    const tip = S.concept === 'A' ? '⇧⌘N or a click creates it' : 'Tab, Return or ⇧⌘N creates it';
    return `<div class="res create${isHl ? ' hl' : ''}" role="option" aria-selected="${isHl}" id="row-${si}" data-act="create" data-si="${si}" title="${tip}">${ICON.plus}<span class="rt">New Folder “${esc(it.name)}” in ${esc(where(it.parent))}</span></div>`;
  }
  if (it.type === 'nfpreview') {
    const label = it.value ? pathHtml(it.value, new Set()) : '<span class="par">untitled folder</span>';
    return `<div class="res nfprev${isHl ? ' hl' : ''}" role="option" aria-selected="${isHl}" id="row-${si}">${ICON.folder}<span class="rt">${label}</span>${it.existing ? '' : '<span class="badge-new">New</span>'}</div>`;
  }
  const chosenMark = S.chosen && S.chosen === it.path && (S.concept !== 'A' || it.self);
  const hasKids = !it.self && kids(it.path).length > 0;
  const label = it.self ? `<span class="last">${esc(it.display)}</span><span class="par"> — this folder</span>` : pathHtml(it.display, it.marks);
  const cls = `res${isHl ? ' hl' : ''}${it.self ? ' self' : ''}${chosenMark ? ' chosen' : ''}${it.inert ? ' inert' : ''}`;
  const act = it.inert ? '' : ` data-act="row" data-si="${si}"`;
  return `<div class="${cls}" role="option" aria-selected="${isHl}" id="row-${si}"${act} title="${esc(it.path)}">${it.self ? ICON.here : ICON.folder}<span class="rt">${label}</span>${isNew(it.path) ? '<span class="badge-new">New</span>' : ''}${chosenMark ? `<span class="check" title="Chosen destination">${ICON.check}</span>` : ''}${hasKids ? `<button type="button" class="into" data-act="into" data-path="${esc(it.path)}" tabindex="-1" title="${S.concept === 'A' ? 'Into the path (→)' : 'Show subfolders (→)'}" aria-label="Into ${esc(lastSeg(it.path))}">${ICON.chev}</button>` : ''}</div>`

}
function renderPathBar() {
  const pb = $('pathBar');
  pb.hidden = S.concept === 'A';
  if (pb.hidden) return;
  const loc = S.nf ? S.nf.parent : S.scope;
  const crumbs = [{ path: '', name: 'Archive' }].concat(chainOf(loc).map((p) => ({ path: p, name: lastSeg(p) })));
  pb.innerHTML = crumbs.map((c, i) => `${i ? '<span class="sep" aria-hidden="true">›</span>' : ''}<button type="button" class="crumb${i === crumbs.length - 1 ? ' cur' : ''}" data-act="crumb" data-path="${esc(c.path)}" tabindex="-1" title="${c.path ? esc(c.path) : 'Archive root (⌘↑)'}">${esc(c.name)}</button>`).join('');
  pb.scrollLeft = pb.scrollWidth;
}
function renderList() {
  const list = $('list');
  const all = items();
  const sel = selectable();
  S.hl = clamp(S.hl, 0, Math.max(0, sel.length - 1));
  const hlItem = sel[S.hl];
  let si = -1, html = '';
  for (const it of all) {
    if (it.type === 'header') { html += `<div class="res-h${it.hairline ? ' hair' : ''}">${esc(it.text)}${it.count !== undefined ? `<span class="cnt">${it.count}</span>` : ''}</div>`; continue; }
    if (it.type === 'sep') { html += '<div class="res-sep"></div>'; continue; }
    if (it.type === 'info') { html += `<div class="res-empty">${esc(it.text)}</div>`; continue; }
    if (it.type === 'nfslot') {
      const rows = kids(it.parent).map((p) => ({ name: lastSeg(p), html: `<div class="res inert" title="${esc(p)}">${ICON.folder}<span class="rt"><span class="last">${esc(lastSeg(p))}</span></span>${isNew(p) ? '<span class="badge-new">New</span>' : ''}</div>` }));
      const first = (S.nf.value.split('/')[0] || '').trim();
      const before = rows.filter((r) => first && collator.compare(r.name, first) < 0), after = rows.filter((r) => !(first && collator.compare(r.name, first) < 0));
      const n = nfNotice(it.parent, S.nf.value);
      html += before.map((r) => r.html).join('') + `<div class="nf-row" id="nfRowBox"><div class="nf-line">${ICON.folder}<span id="nfSlot"></span></div><div class="nf-note${n.warn ? ' warn' : ''}">${esc(n.text)}</div></div>` + after.map((r) => r.html).join('');
      continue;
    }
    if (isSelectable(it)) si++;
    html += rowHtml(it, isSelectable(it) ? si : -1, hlItem);
  }
  list.innerHTML = html;
  const slot = $('nfSlot');
  if (slot) {
    if (!nfInputEl) createNfInput();
    nfInputEl.setAttribute('aria-label', `New folder name in ${where(S.nf.parent)}`);
    if (nfInputEl.value !== S.nf.value) nfInputEl.value = S.nf.value;
    const ss = nfInputEl.selectionStart, se = nfInputEl.selectionEnd;
    slot.replaceWith(nfInputEl);
    if (S.focus === 'newfolder') { nfInputEl.focus({ preventScroll: true }); try { nfInputEl.setSelectionRange(ss ?? S.nf.value.length, se ?? S.nf.value.length); } catch (err) { /* not a text field state */ } }
  }
  // Keep the highlight in view; reset scroll when the listing changes.
  const key = itemsCache.key;
  if (key !== lastListKey) { list.scrollTop = 0; lastListKey = key; }
  const target = list.querySelector('.res.hl') || $('nfRowBox');
  if (target) {
    const top = target.offsetTop, bottom = top + target.offsetHeight;
    if (top < list.scrollTop + 22) list.scrollTop = Math.max(0, top - 26);
    else if (bottom > list.scrollTop + list.clientHeight) list.scrollTop = bottom - list.clientHeight + 4;
    if (target.id) $('filterInput').setAttribute('aria-activedescendant', target.id);
  }
}
function renderBar() {
  const h = highlighted();
  const btn = $('newFolderBtn');
  btn.innerHTML = `${ICON.newFolder}<span>New Folder</span>`;
  const parent = S.nf ? S.nf.parent : h && h.type === 'folder' ? h.path : S.scope;
  btn.title = h && h.type === 'create' ? `New Folder “${h.name}” in ${where(h.parent)} (⇧⌘N)` : `New Folder in ${where(parent)} (⇧⌘N)`;
  btn.setAttribute('aria-label', btn.title);
  $('pickerHint').textContent = S.hint || (S.concept === 'A' ? '→ complete · ⌫ back · / path' : '→ into folder · ← out');
  $('pickerHint').classList.toggle('flash', !!S.hint);
}
function renderContents() {
  const box = $('contents');
  const folder = contentsFolder();
  const pathEl = $('contentsPath'), cnt = $('contentsCount');
  if (!folder) {
    pathEl.textContent = 'Files'; cnt.textContent = '';
    const h = highlighted();
    box.innerHTML = `<div class="ct-empty">${S.nf || (h && (h.type === 'create' || h.type === 'nfpreview')) ? 'A new folder is empty; docsort creates it when you move the file.' : 'Highlight a folder to see its files.'}</div>`;
    box.dataset.folder = '';
    return;
  }
  pathEl.textContent = `Files in ${crumbText(folder)}`; pathEl.title = folder;
  if (isNew(folder)) {
    cnt.textContent = '';
    box.innerHTML = '<div class="ct-empty">New folder. docsort creates it when you move the file, so cancelling leaves nothing behind.</div>';
    box.dataset.folder = folder;
    return;
  }
  const files = contentsOf(folder);
  cnt.textContent = files.length === 1 ? '1 file' : `${files.length} files`;
  const taken = S.take && S.take.folder === folder ? S.take.idx : -1;
  box.innerHTML = files.length
    ? files.map((n, i) => `<div class="ct${i === taken ? ' taken' : ''}" data-act="ct" data-i="${i}" title="Click to use “${esc(stemOf(n))}” as the name">${fileIcon(n)}<span class="tn">${esc(n)}</span></div>`).join('')
    : '<div class="ct-empty">No files yet.</div>';
  if (box.dataset.folder !== folder) { box.scrollTop = box.scrollHeight; box.dataset.folder = folder; }
}
function renderName() {
  const inp = $('nameInput');
  if (inp.value !== S.name) inp.value = S.name;
  const toast = $('toast');
  toast.hidden = !S.toast;
  toast.textContent = S.toast;
  const t = moveTarget();
  $('moveBtn').disabled = !t.path && !(t.create && !t.blocked);
}
function renderStatus() {
  const el = $('status');
  if (S.moved) { el.innerHTML = S.moved; el.classList.add('moved'); return; }
  el.classList.remove('moved');
  const t = moveTarget();
  const name = esc(effectiveStem() + FILE_EXT);
  if (t.path) el.innerHTML = `Move would file into <b>${esc(t.path)}</b> as <b>${name}</b>${isNew(t.path) ? ' (new folder)' : ''}.`;
  else if (t.create && !t.blocked) el.innerHTML = `Move would create <b>${esc(t.create.path)}</b> and file into it as <b>${name}</b>.`;
  else el.innerHTML = `Move: ${esc(t.blocked || 'nothing to file into yet.')}`;
}
function applyFocus() {
  const panelFocus = S.focus === 'picker' || S.focus === 'newfolder';
  $('panel').classList.toggle('pk-focus', panelFocus);
  $('sidebar').classList.toggle('focused', S.focus === 'sidebar');
  if (!S.pendingFocus) return;
  S.pendingFocus = false;
  const el = S.focus === 'picker' ? $('filterInput') : S.focus === 'newfolder' ? nfInputEl : S.focus === 'name' ? $('nameInput') : S.focus === 'sidebar' ? $('sidebar') : null;
  if (el && document.activeElement !== el) el.focus({ preventScroll: true });
  if (S.focus === 'picker') { const inp = $('filterInput'); inp.setSelectionRange(inp.value.length, inp.value.length); }
}
function render() {
  rendering = true;
  try {
    renderHeader();
    renderField();
    renderPathBar();
    renderList();
    renderBar();
    renderContents();
    renderName();
    renderStatus();
    applyFocus();
    if (S.selectName && S.focus === 'name') { $('nameInput').select(); S.selectName = false; }
    renderGhost();
  } finally {
    rendering = false;
  }
}

/* ---------------------------------------------------------------- DOM events */
function createNfInput() {
  nfInputEl = document.createElement('input');
  nfInputEl.id = 'nfInput';
  nfInputEl.type = 'text';
  nfInputEl.autocomplete = 'off';
  nfInputEl.spellcheck = false;
  nfInputEl.placeholder = 'Folder name';
  nfInputEl.addEventListener('input', () => { if (S.nf) { S.nf.value = nfInputEl.value; S.moved = ''; render(); } });
}
function keyOf(e) {
  let key = e.key;
  if (key.length === 1 && (e.metaKey || e.ctrlKey || e.altKey)) {
    if (/^Key[A-Z]$/.test(e.code)) key = e.code.slice(3).toLowerCase();
    else if (/^Digit\d$/.test(e.code)) key = e.code.slice(5);
  }
  if (key.length === 1 && /^[A-Z]$/.test(key) && e.shiftKey && (e.metaKey || e.ctrlKey)) key = key.toLowerCase();
  return { key, cmd: e.metaKey, ctrl: e.ctrlKey, alt: e.altKey, shift: e.shiftKey };
}
function caretOf(el) {
  if (el && typeof el.selectionStart === 'number') return { start: el.selectionStart, end: el.selectionEnd, len: el.value.length };
  return { start: 0, end: 0, len: 0 };
}
function stopOf(el) {
  if (!el) return 'none';
  if (el.id === 'filterInput') return 'picker';
  if (el.id === 'nfInput') return 'newfolder';
  if (el.id === 'nameInput') return 'name';
  if (el.id === 'sidebar') return 'sidebar';
  return 'none';
}
if (HAS_DOM) {
  // Capture phase, so ⌃1–3 and ⌘Return reach us whatever is focused.
  window.addEventListener('keydown', (e) => {
    if (e.isComposing) return;
    const k = keyOf(e);
    const a = document.activeElement;
    const stop = stopOf(a);
    if (stop !== S.focus && stop !== 'none') S.focus = stop;
    if (stop === 'none' && S.focus !== 'none' && !(k.ctrl && /^[123]$/.test(k.key))) S.focus = 'none';
    let handled = handleKey(k, caretOf(a));
    if (!handled && stop === 'none' && isMoveKey(k) && a && $('panel').contains(a)) { moveNow(); handled = true; }
    if (handled) {
      e.preventDefault();
      e.stopPropagation();
      if (!isMoveKey(k)) S.moved = '';
      render();
    }
  }, true);
  // After the browser moved the caret (← → Home End), the ghost text may appear or go.
  window.addEventListener('keyup', () => { if (S.concept === 'A') renderGhost(); });

  $('filterInput').addEventListener('input', (e) => {
    if (S.focus !== 'picker') S.focus = 'picker';
    setQueryFromUser(e.target.value);
    render();
  });
  $('nameInput').addEventListener('input', (e) => { S.name = e.target.value; S.take = null; S.moved = ''; render(); });
  $('filterInput').addEventListener('click', () => renderGhost());

  document.addEventListener('focusin', (e) => {
    if (rendering) return;
    const stop = stopOf(e.target);
    if (stop === 'none' || stop === S.focus) return;
    if (S.nf && S.concept !== 'A' && S.focus === 'newfolder' && stop !== 'newfolder') cancelNf(false);
    if (S.nf && S.concept === 'A' && stop !== 'picker') cancelNf(false);
    S.focus = stop;
    render();
  });
  document.addEventListener('focusout', () => {
    if (rendering) return;
    setTimeout(() => {
      if (rendering) return;
      const stop = stopOf(document.activeElement);
      if (stop === 'none' && S.focus !== 'none') { S.focus = 'none'; render(); }
    }, 0);
  });

  // Clicks inside the panel and on header controls keep focus where it is; handlers move it on purpose.
  document.addEventListener('mousedown', (e) => {
    if (e.target.closest('input')) return;
    if (e.target.closest('#panel') || e.target.closest('[data-act="concept"], [data-act="theme"], [data-act="reset"]')) e.preventDefault();
  });
  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-act]');
    if (!el) {
      if (e.target.closest('#filterBox')) { wantFocus('picker'); render(); }
      return;
    }
    const act = el.dataset.act;
    S.moved = '';
    switch (act) {
      case 'concept': switchConcept(el.dataset.concept); break;
      case 'theme': setTheme(el.dataset.themeChoice); return;
      case 'reset': S.done[S.concept] = new Set(); resetPanel(); wantFocus('picker'); break;
      case 'row': {
        if (e.detail >= 2) return;
        if (S.nf) cancelNf(false);
        unchoose();
        S.hl = +el.dataset.si;
        wantFocus('picker');
        break;
      }
      case 'into': if (e.detail >= 2) return; if (S.nf) cancelNf(false); stepInto(el.dataset.path); wantFocus('picker'); break;
      case 'create': {
        S.hl = +el.dataset.si;
        const h = highlighted();
        if (h && h.type === 'create') createFrom(h);
        break;
      }
      case 'crumb': if (S.nf) cancelNf(false); jumpTo(el.dataset.path); wantFocus('picker'); break;
      case 'aseg': if (S.nf) cancelNf(false); jumpTo(el.dataset.path); wantFocus('picker'); break;
      case 'clear': if (S.nf) cancelNf(false); clearAll(); wantFocus('picker'); break;
      case 'newfolder': newFolderCmd(); break;
      case 'ct': {
        const folder = contentsFolder();
        const files = folder ? contentsOf(folder) : [];
        const i = +el.dataset.i;
        if (!files[i]) return;
        S.take = { folder, idx: i };
        S.name = stemOf(files[i]);
        wantFocus('name'); S.selectName = true;
        break;
      }
      case 'move': moveNow(); break;
      default: return;
    }
    render();
  });
  /* A double-click acts on the row its first click highlighted: steps in, or chooses a folder without subfolders. */
  document.addEventListener('dblclick', (e) => {
    const el = e.target.closest('[data-act="row"]');
    if (!el) return;
    const h = highlighted();
    if (!h || h.type !== 'folder') return;
    if (!h.self && kids(h.path).length) stepInto(h.path);
    else choose();
    render();
  });
  window.addEventListener('resize', () => { if (S.concept === 'A' && S.scope) fitPath(); renderGhost(); });
}

/* ---------------------------------------------------------------- theme (no storage: the choice lasts for this visit) */
function setTheme(choice) {
  if (choice === 'auto') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', choice);
  document.querySelectorAll('#themeSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.themeChoice === choice)));
  wantFocus(S.focus === 'none' ? 'picker' : S.focus);
  render();
}

/* ---------------------------------------------------------------- start */
resetPanel();
if (HAS_DOM) {
  wantFocus('picker');
  render();
  // Some hosts focus the frame late; try once more when the page is fully loaded.
  window.addEventListener('load', () => { if (stopOf(document.activeElement) === 'none') { wantFocus('picker'); render(); } });
}
