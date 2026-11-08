'use strict';
/* docsort UX mockup. Plain DOM, no libraries. FOLDERS and KNOWN_CONTENTS come from the data script above. */

const TODAY = '2033-10-26';
const ARCHIVE_PATH = '~/Archiv';
const ARCHIVE_FOLDER_COUNT = `${FOLDERS.length.toLocaleString('en-US')} folders`;
const MAX_RESULTS = 50;
const MAX_RECENT = 20;

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ---------------------------------------------------------------- icons */
const stroke = (vb, d, w = 1.4) =>
  `<svg viewBox="${vb}" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICON = {
  sidebar: stroke('0 0 20 16', '<rect x="1.5" y="1.5" width="17" height="13" rx="3"/><path d="M7.2 1.5v13"/><path d="M3.6 4.6h1.6M3.6 6.9h1.6M3.6 9.2h1.6" stroke-width="1.2"/>'),
  inspector: stroke('0 0 20 16', '<rect x="1.5" y="1.5" width="17" height="13" rx="3"/><path d="M12.8 1.5v13"/><path d="M14.8 4.6h1.6M14.8 6.9h1.6M14.8 9.2h1.6" stroke-width="1.2"/>'),
  open: stroke('0 0 16 16', '<path d="M9.2 2.2h4.6v4.6"/><path d="M13.8 2.2 7.6 8.4"/><path d="M12 9.6v3a1.6 1.6 0 0 1-1.6 1.6H3.6A1.6 1.6 0 0 1 2 12.6V5.8a1.6 1.6 0 0 1 1.6-1.6h3"/>'),
  finder: stroke('0 0 16 16', '<rect x="1.6" y="1.6" width="12.8" height="12.8" rx="3"/><path d="M8.7 1.6C7.5 4.4 7.1 7 7.3 9.4h1.6c-.2 1.6-.2 3.3.2 5"/><path d="M4.9 5.2v1.2M11.1 5.2v1.2"/><path d="M4.6 10.4c2.1 1.5 4.7 1.5 6.8 0"/>'),
  trash: stroke('0 0 16 16', '<path d="M2.4 4.2h11.2M6 4.2V2.6h4v1.6M3.8 4.2l.8 9.6h6.8l.8-9.6M6.5 6.8v4.6M9.5 6.8v4.6"/>'),
  chev: stroke('0 0 12 12', '<path d="M4.5 2.5 8 6l-3.5 3.5"/>', 1.6),
  check: stroke('0 0 16 16', '<path d="M3.2 8.6 6.6 12 12.8 4.4"/>', 2),
  plus: stroke('0 0 12 12', '<path d="M6 1.5v9M1.5 6h9"/>', 1.5),
  minus: stroke('0 0 12 12', '<path d="M1.5 6h9"/>', 1.5),
  x: stroke('0 0 12 12', '<path d="M3 3l6 6M9 3 3 9"/>', 1.6),
  grip: stroke('0 0 12 12', '<path d="M2 3.5h8M2 6h8M2 8.5h8"/>', 1.2),
  warn: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1.3 15.3 14.4H.7Z M7.15 5.6h1.7l-.3 4.9h-1.1Z M8 11.4a.95.95 0 1 1 0 1.9.95.95 0 0 1 0-1.9Z"/></svg>',
  errorCircle: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1a7 7 0 1 1 0 14A7 7 0 0 1 8 1Z M7.15 4.2h1.7l-.3 5.2h-1.1Z M8 10.6a.95.95 0 1 1 0 1.9.95.95 0 0 1 0-1.9Z"/></svg>',
  clear: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M8 1a7 7 0 1 1 0 14A7 7 0 0 1 8 1Z M5.4 4.3 4.3 5.4 6.9 8l-2.6 2.6 1.1 1.1L8 9.1l2.6 2.6 1.1-1.1L9.1 8l2.6-2.6-1.1-1.1L8 6.9Z"/></svg>',
  folder: '<svg class="fold" viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" style="fill:var(--ficon-folder)"/><path d="M1 4.3h14" style="stroke:var(--ficon-folder-tab)" stroke-width=".8"/></svg>',
  /* The picker's "this folder" row: the folder with a downward "file here" arrow. */
  folderHere: '<svg class="fold" viewBox="0 0 16 13" aria-hidden="true"><path d="M1 2.2A1.2 1.2 0 0 1 2.2 1h3.6l1.5 1.6h6.5A1.2 1.2 0 0 1 15 3.8v7A1.2 1.2 0 0 1 13.8 12H2.2A1.2 1.2 0 0 1 1 10.8z" style="fill:var(--ficon-folder)"/><path d="M8 4.9v4.6M5.9 7.6 8 9.7l2.1-2.1" fill="none" style="stroke:var(--ficon-page)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  tray: stroke('0 0 64 64', '<path d="M8 38 14 14h36l6 24v14a4 4 0 0 1-4 4H12a4 4 0 0 1-4-4z"/><path d="M8 38h14l3 6h14l3-6h14"/><path d="M32 18v16M25 27l7 7 7-7"/>', 2.6),
  clock: stroke('0 0 16 16', '<circle cx="8" cy="8" r="6.3"/><path d="M8 4.4V8l2.6 1.6"/>'),
  folderPlus: stroke('0 0 18 15', '<path d="M1.5 3.2A1.5 1.5 0 0 1 3 1.7h3.7l1.6 1.7H15a1.5 1.5 0 0 1 1.5 1.5v7.4a1.5 1.5 0 0 1-1.5 1.5H3a1.5 1.5 0 0 1-1.5-1.5z"/><path d="M9 6.4v4.4M6.8 8.6h4.4"/>', 1.3),
  revert: stroke('0 0 16 16', '<path d="M3.6 6.2A5 5 0 1 1 3.4 10"/><path d="M3.3 2.8v3.6h3.6"/>', 1.5),
  done: stroke('0 0 64 64', '<circle cx="32" cy="32" r="26"/><path d="M20 33l8 8 16-18"/>', 3),
};
function progressRing(pct) {
  const c = 2 * Math.PI * 5.5;
  return `<svg class="prog" viewBox="0 0 14 14" aria-hidden="true"><circle cx="7" cy="7" r="5.5" fill="none" style="stroke:var(--progress-track)" stroke-width="2"/><circle cx="7" cy="7" r="5.5" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="${(c * pct).toFixed(2)} ${c.toFixed(2)}" transform="rotate(-90 7 7)"/></svg>`;
}
function fileIcon(kind, cls = '') {
  if (kind === 'folder') return `<span class="ficon ${cls}" style="width:16px;height:13px">${ICON.folder}</span>`;
  const band = { pdf: '--ficon-pdf', img: '--ficon-img', pages: '--ficon-pages' }[kind] || '--label3';
  const label = { pdf: 'PDF', img: 'JPG' }[kind] || '';
  return `<span class="ficon ${cls}"><svg viewBox="0 0 15 19" aria-hidden="true"><path d="M1.5 1.5h8l4 4v12h-12z" style="fill:var(--ficon-page);stroke:var(--ficon-stroke)" stroke-width=".8"/><path d="M9.5 1.5v4h4" fill="none" style="stroke:var(--ficon-stroke)" stroke-width=".8"/><rect x="1.9" y="11" width="11.2" height="4.6" style="fill:var(${band})"/>${label ? `<text x="7.5" y="14.5" text-anchor="middle" font-size="3.7" font-weight="700" font-family="-apple-system,Helvetica,sans-serif" style="fill:var(--ficon-page)">${label}</text>` : ''}</svg></span>`;
}
function kindOf(ext) {
  const e = ext.toLowerCase();
  if (e === '.pdf') return 'pdf';
  if (['.jpg', '.jpeg', '.png', '.heic'].includes(e)) return 'img';
  if (e === '.pages') return 'pages';
  return 'other';
}

/* ---------------------------------------------------------------- dates and numbers */
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
function dayDiff(iso) {
  const a = Date.UTC(+TODAY.slice(0, 4), +TODAY.slice(5, 7) - 1, +TODAY.slice(8, 10));
  const b = Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10));
  return Math.round((a - b) / 86400000);
}
function relDate(iso) {
  const d = dayDiff(iso);
  if (d === 0) return iso.length > 10 ? iso.slice(11, 16) : 'Today';
  if (d === 1) return 'Yesterday';
  const dt = new Date(Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10)));
  if (d < 7) return WEEKDAYS[dt.getUTCDay()];
  return `${dt.getUTCDate()} ${MONTHS[dt.getUTCMonth()]}`;
}
function longDate(iso) {
  return `${+iso.slice(8, 10)} ${MONTHS[+iso.slice(5, 7) - 1]} ${iso.slice(0, 4)}`;
}
const eur = (n) => n.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function seeded(seed) {
  let x = seed || 1;
  return () => { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 4294967296; };
}
const lastSeg = (p) => p.slice(p.lastIndexOf('/') + 1);
const parentOf = (p) => (p.includes('/') ? p.slice(0, p.lastIndexOf('/')) : '');
const shortName = (n, max = 22) => (n.length > max ? n.slice(0, max - 1) + '…' : n);

/* ---------------------------------------------------------------- previews (fake documents) */
/* Every document belongs to the fictional Weißenbacher household in the made-up town of Wettelau, the same invented
   world as the sample archive in docs/design/sample-data/. Names, numbers and amounts are made up. */
const HOUSEHOLD = 'Konrad und Margit Weißenbacher<br>Brunnfeldgasse 14/3<br>4999 Wettelau<br>Österreich';
const KONRAD = 'Konrad Weißenbacher<br>Brunnfeldgasse 14/3<br>4999 Wettelau<br>Österreich';
const MARGIT = 'Margit Weißenbacher<br>Brunnfeldgasse 14/3<br>4999 Wettelau<br>Österreich';
const MATTHIAS = 'Matthias Weißenbacher<br>Kanaalstraat 9, Zimmer 4<br>9999 ZZ Westerholm<br>Niederlande';
const CHOIR = 'Chorgemeinschaft Liederkranz Wettelau<br>z. Hd. Konrad Weißenbacher, Kassier<br>Brunnfeldgasse 14/3<br>4999 Wettelau';
function paper(inner, opts = {}) {
  const cls = opts.cls || '';
  return `<div class="paper ${cls}">${inner}${opts.foot ? `<div class="foot">${opts.foot}</div>` : ''}${opts.pg ? `<div class="pgno">${opts.pg}</div>` : ''}</div>`;
}
function lineItems(items, opts = {}) {
  // items: [description, qty, unit price gross]
  const vat = opts.vat ?? 20;
  let total = 0;
  const rows = items.map((it, i) => {
    const amount = Math.round(it[1] * it[2] * 100) / 100;
    total += amount;
    return `<tr>${opts.pos === false ? '' : `<td>${i + 1}</td>`}<td>${it[0]}</td><td class="num">${String(it[1]).replace('.', ',')}</td><td class="num">${eur(it[2])}</td><td class="num">${eur(amount)}</td></tr>`;
  }).join('');
  const net = total / (1 + vat / 100);
  const span = opts.pos === false ? 3 : 4;
  return `<table><thead><tr>${opts.pos === false ? '' : '<th>Pos.</th>'}<th>${opts.descHead || 'Artikel'}</th><th class="num">Menge</th><th class="num">Einzelpreis</th><th class="num">Betrag</th></tr></thead><tbody>${rows}
    <tr class="subtotal"><td colspan="${span}">Summe netto</td><td class="num">${eur(net)}</td></tr>
    <tr class="subtotal"><td colspan="${span}">USt ${vat} %</td><td class="num">${eur(total - net)}</td></tr>
    <tr class="total"><td colspan="${span}">${opts.totalLabel || 'Gesamtbetrag'}</td><td class="num">${eur(total)}</td></tr></tbody></table>`;
}
/* A two-column table of [label, amount, row class] rows; the class is 'subtotal', 'total' or empty. */
function amountTable(head, rows) {
  const body = rows.map(([label, amount, cls]) => `<tr${cls ? ` class="${cls}"` : ''}><td>${label}</td><td class="num">${typeof amount === 'number' ? eur(amount) : amount}</td></tr>`).join('');
  return `<table>${head ? `<thead><tr><th>${head[0]}</th><th class="num">${head[1]}</th></tr></thead>` : ''}<tbody>${body}</tbody></table>`;
}
function letterhead(logo, color, small) {
  return `<div class="lh"><div class="logo" style="color:var(${color})">${logo}</div><div class="lh-small">${small}</div></div>`;
}
function addressBlock(sender, recipient = HOUSEHOLD) {
  return `<div class="sender">${sender}</div><div class="addr">${recipient}</div>`;
}
function metaGrid(pairs) {
  return `<div class="meta-grid">${pairs.map(([k, v]) => `<span>${k}</span><span>${v}</span>`).join('')}</div>`;
}
function receiptLines(items) {
  let total = 0;
  const html = items.map(([d, q, p]) => {
    const a = Math.round(q * p * 100) / 100; total += a;
    return `<div class="rl"><span>${q !== 1 ? `${String(q).replace('.', ',')} x ` : ''}${d}</span><span>${eur(a).replace(' €', '')}</span></div>`;
  }).join('');
  return { html, total };
}
const dim = (s) => `<br><span style="color:var(--paper-fg2)">${s}</span>`;
const sum = (rows) => rows.reduce((a, r) => a + r[1], 0);
const PREVIEWS = {
  gehalt: () => {
    const earnings = [['Grundgehalt, Beschäftigungsausmaß 60 %', 2146.8], ['Zulage Musikschwerpunkt', 84], ['Fahrtkostenzuschuss', 18]];
    const deductions = [['Sozialversicherung Dienstnehmeranteil', -403.15], ['Lohnsteuer', -196.42], ['Betriebsratsumlage', -6.69]];
    const gross = sum(earnings);
    return [paper(
      letterhead('Privatschule Lerchenfeld', '--paper-accent-teal', 'Schulverein Lerchenfeld<br>Personalverrechnung<br>Lerchenfeldstraße 20 · 4999 Wettelau')
      + addressBlock('Schulverein Lerchenfeld · Lerchenfeldstraße 20 · 4999 Wettelau', MARGIT)
      + metaGrid([['Personalnummer', 'PN-000-0731'], ['Abrechnungsmonat', 'September 2033'], ['Erstellt am', '28.09.2033'], ['Verwendung', 'Lehrerin Musik, Teilzeit']])
      + '<h4>Gehaltszettel September 2033</h4><div class="sub">Gehaltsstufe 12 · Beschäftigungsausmaß 60 %</div>'
      + amountTable(['Bezüge', 'Betrag'], earnings.concat([['Bruttobezug', gross, 'subtotal']]))
      + amountTable(['Abzüge', 'Betrag'], deductions.concat([['Auszahlung', gross + sum(deductions), 'total']]))
      + '<p class="para">Die Auszahlung erfolgt am 30.09.2033 auf Ihr Konto AT00 0000 0000 0000 0000. Änderungen bei Adresse, Konto oder Familienstand melden Sie bitte der Personalverrechnung.</p>',
      { foot: '<span>Schulverein Lerchenfeld · ZVR 000000000</span><span>Seite 1 von 1</span>' })];
  },
  notenhaus: () => {
    const p1 = letterhead('Notenhaus Allegretto', '--paper-accent-plum', 'Notenhaus Allegretto GmbH<br>Geigergasse 5 · 4999 Wettelau<br>bestellung@notenhaus-allegretto.example')
      + addressBlock('Notenhaus Allegretto · Geigergasse 5 · 4999 Wettelau', CHOIR)
      + metaGrid([['Rechnungsnummer', 'NA-33-08812'], ['Rechnungsdatum', '13.10.2033'], ['Bestellung', 'WEB-000-58817'], ['Kundennummer', 'KD-000-2290'], ['Seite', '1 von 2']])
      + '<h4>Rechnung</h4><div class="sub">Sammelbestellung Adventprogramm · Lieferung an den Kassier</div>'
      + lineItems([
        ['Chorpartitur „Lichter im Advent“, SATB' + dim('Edition Hallmayr · Art.-Nr. CP-4410'), 28, 6.4],
        ['Klavierauszug „Kleine Weihnachtskantate“' + dim('für die Chorleitung · Art.-Nr. KA-1203'), 2, 19.8],
        ['Liederheft „Winterlieder aus dem Ilmtal“', 6, 8.5],
        ['Versand, Paket bis 5 kg', 1, 5.9],
      ], { vat: 10 })
      + '<div class="box">Zahlbar bis 27.10.2033 ohne Abzug. Lieferumfang und Hinweise zu Aufführungen auf Seite 2.</div>';
    const foot = '<span>Notenhaus Allegretto GmbH · FN 000000a · UID ATU00000000</span><span>IBAN AT00 0000 0000 0000 0000</span>';
    const delivered = [['Chorpartitur „Lichter im Advent“', 28, 28], ['Klavierauszug „Kleine Weihnachtskantate“', 2, 2], ['Liederheft „Winterlieder aus dem Ilmtal“', 6, 4]];
    const p2 = letterhead('Notenhaus Allegretto', '--paper-accent-plum', 'Rechnung NA-33-08812<br>13.10.2033')
      + '<h4>Lieferumfang</h4><table><thead><tr><th>Artikel</th><th class="num">Bestellt</th><th class="num">Geliefert</th></tr></thead><tbody>'
      + delivered.map(([a, b, c]) => `<tr><td>${a}</td><td class="num">${b}</td><td class="num">${c}</td></tr>`).join('') + '</tbody></table>'
      + '<p class="para">Zwei Liederhefte liefern wir nach, sobald der Nachdruck da ist; die Versandkosten dafür übernehmen wir.</p>'
      + '<h4 style="margin-top:22px">Aufführungen</h4>'
      + '<p class="para">Melden Sie öffentliche Aufführungen bitte wie gewohnt bei Ihrer Verwertungsgesellschaft. Das Kopieren der Partituren ist nicht gestattet.</p>'
      + '<p class="para">Unbenutzte Noten nehmen wir innerhalb von 14 Tagen zurück.</p>';
    return [paper(p1, { foot, pg: 'Seite 1 von 2' }), paper(p2, { foot, pg: 'Seite 2 von 2' })];
  },
  ilmnet: () => [paper(
    letterhead('ilmnet', '--paper-accent-violet', 'Ilmnet Breitband GmbH<br>Kundenservice 0800 000 000<br>ilmnet.example')
    + addressBlock('Ilmnet Breitband GmbH · Glasfaserring 1 · 4999 Wettelau')
    + metaGrid([['Rechnungsnummer', 'IN-33-10-55102'], ['Datum', '04.10.2033'], ['Kundennummer', 'KD-000-4471'], ['Zeitraum', '01.10.–31.10.2033']])
    + '<h4>Ihre Rechnung Oktober 2033</h4><div class="sub">Anschluss Brunnfeldgasse 14/3 · Ilmnet Faser 150</div>'
    + lineItems([['Internet Ilmnet Faser 150', 1, 39.9], ['Miete WLAN-Router', 1, 3], ['Festnetz-Flatrate Österreich', 1, 5]], { pos: false, descHead: 'Leistung' })
    + '<div class="box">Wir buchen den Betrag am 10.10.2033 von Ihrem Konto AT00 0000 0000 0000 0000 ab.</div>',
    { foot: '<span>Ilmnet Breitband GmbH · ilmnet.example</span><span>Seite 1 von 1</span>' })],
  regio: () => [paper(
    letterhead('Regio Plus', '--paper-accent-green', 'Verkehrsverbund Ilmtal GmbH<br>Kundencenter<br>Am Bahnhof 1 · 4999 Wettelau')
    + addressBlock('Verkehrsverbund Ilmtal · Am Bahnhof 1 · 4999 Wettelau', KONRAD)
    + metaGrid([['Kartennummer', 'RP-000-38817'], ['Datum', '20.10.2033'], ['Kundennummer', 'KD-000-6024'], ['Gültig ab', '01.11.2033']])
    + '<h4>Verlängerung Ihrer Jahreskarte</h4><div class="sub">Jahreskarte Regio Plus Senior · alle Zonen im Ilmtal · 12 Monate</div>'
    + lineItems([['Jahreskarte Regio Plus Senior', 1, 329], ['Fahrradmitnahme Jahrespass', 1, 45]], { pos: false, descHead: 'Leistung', vat: 10, totalLabel: 'Abgebucht' })
    + '<div class="box">Ihre bisherige Karte gilt bis zum Ende der Laufzeit. Die neue Karte liegt ab 01.11.2033 in der App; eine Plastikkarte schicken wir nur auf Wunsch.</div>',
    { foot: '<span>Verkehrsverbund Ilmtal GmbH · regioplus.example</span><span>Seite 1 von 1</span>' })],
  photo: () => {
    const r = receiptLines([['Service Trekkingrad', 1, 59], ['Bremsbeläge hinten', 1, 18.9], ['Kette 9-fach', 1, 24.5], ['Schlauch 28 Zoll', 2, 6.9]]);
    return [`<div class="photo" role="img" aria-label="Photo of a bicycle workshop receipt on a wooden table"><div class="rcpt">`
      + '<div class="c" style="font-weight:700;font-size:13px">Radwerkstatt Speiche</div><div class="c">Ufergasse 3 · 4999 Wettelau</div><hr>'
      + `<div>Auftrag 3318 · Weißenbacher K.</div><hr>${r.html}<hr>`
      + `<div class="rl" style="font-weight:700"><span>SUMME</span><span>${eur(r.total)}</span></div>`
      + `<div class="rl"><span>darin 20 % USt</span><span>${eur(r.total - r.total / 1.2)}</span></div><hr>`
      + '<div class="c">12.10.2033 16:37<br>Gute Fahrt!</div></div></div>'];
  },
  collegegeld: () => [paper(
    letterhead('Universiteit Westerholm', '--paper-accent-blue', 'Universiteit Westerholm<br>Studentenadministration<br>Havenplein 2 · Westerholm, Niederlande')
    + addressBlock('Universiteit Westerholm · Havenplein 2 · Westerholm', MATTHIAS)
    + metaGrid([['Rechnung', 'UW-33-104877'], ['Datum', '06.10.2033'], ['Studentennummer', 'ST-000-58213'], ['Fällig bis', '31.10.2033']])
    + '<h4>Rechnung Collegegeld, 1. Rate</h4><div class="sub">Bachelor Meeresbiologie · 3. Studienjahr · Herbstsemester 2033</div>'
    + amountTable(['Leistung', 'Betrag'], [['Gesetzliches Collegegeld, Jahresbetrag', 2535], ['davon 1. Rate von 2', 1267.5, 'subtotal'], ['Zu zahlen', 1267.5, 'total']])
    + '<p class="para">Bitte überweisen Sie den Betrag bis 31.10.2033 mit der Rechnungsnummer als Verwendungszweck. Die 2. Rate stellen wir zu Beginn des Frühjahrssemesters in Rechnung.</p>'
    + '<p class="para">Das Collegegeld ist von der Umsatzsteuer befreit.</p>',
    { foot: '<span>Universiteit Westerholm · uni-westerholm.example</span><span>Seite 1 von 1</span>' })],
  inschrijving: () => [paper(
    letterhead('Universiteit Westerholm', '--paper-accent-blue', 'Universiteit Westerholm<br>Studentenadministration<br>Havenplein 2 · Westerholm, Niederlande')
    + addressBlock('Universiteit Westerholm · Havenplein 2 · Westerholm', MATTHIAS)
    + metaGrid([['Bescheinigung', 'IB-33-58213'], ['Datum', '06.10.2033'], ['Studentennummer', 'ST-000-58213']])
    + '<h4>Inschrijvingsbewijs · Studienbestätigung</h4><div class="sub">zur Vorlage bei Behörden im Ausland</div>'
    + '<p class="para">Wir bestätigen, dass Herr Matthias Weißenbacher im Herbstsemester 2033 als ordentlicher Student in Vollzeit eingeschrieben ist.</p>'
    + '<div class="box"><b>Bachelor Meeresbiologie</b><br>3. Studienjahr · Fakultät für Natur- und Umweltwissenschaften<br>Eingeschrieben seit 01.09.2033</div>'
    + '<p class="para">Diese Bescheinigung wurde elektronisch erstellt und gilt ohne Unterschrift.</p>',
    { foot: '<span>Universiteit Westerholm · uni-westerholm.example</span><span>Seite 1 von 1</span>' })],
  kontoauszug: () => {
    const rows = [
      ['01.09.', 'Ruhegenuss September · Landespensionsservice Ilmtal', 2418.36],
      ['02.09.', 'Miete September · Heimstatt Ilmtal', -742.18],
      ['04.09.', 'Ilmnet Breitband · KD-000-4471', -47.9],
      ['10.09.', 'Teilbetrag Strom und Fernwärme · Stadtwerke Wettelau', -118],
      ['15.09.', 'Dauerauftrag Matthias Weißenbacher', -450],
      ['18.09.', 'rollmit Carsharing · Fahrten August', -36.4],
      ['22.09.', 'Kartenzahlung Wochenmarkt Wettelau', -28.6],
      ['30.09.', 'Gehalt September · Schulverein Lerchenfeld', 1642.54],
      ['30.09.', 'Kontoführung 3. Quartal', -14.7],
    ];
    const opening = 3512.07;
    const closing = rows.reduce((a, r) => a + r[2], opening);
    return [paper(
      letterhead('Bürgerbank Wettelau', '--paper-accent-slate', 'Bürgerbank Wettelau eG<br>Kirchengasse 9 · 4999 Wettelau<br>buergerbank-wettelau.example')
      + addressBlock('Bürgerbank Wettelau eG · Kirchengasse 9 · 4999 Wettelau')
      + metaGrid([['Kontoauszug', '9/2033'], ['IBAN', 'AT00 0000 0000 0000 0000'], ['Zeitraum', '01.09.–30.09.2033'], ['Erstellt', '01.10.2033']])
      + '<h4>Kontoauszug September 2033</h4><div class="sub">Gemeinschaftskonto Konrad und Margit Weißenbacher</div>'
      + `<table><thead><tr><th>Datum</th><th>Buchung</th><th class="num">Betrag</th></tr></thead><tbody><tr class="subtotal"><td></td><td>Kontostand 31.08.2033</td><td class="num">${eur(opening)}</td></tr>`
      + rows.map(([d, t, a]) => `<tr><td>${d}</td><td>${t}</td><td class="num">${eur(a)}</td></tr>`).join('')
      + `<tr class="total"><td></td><td>Kontostand 30.09.2033</td><td class="num">${eur(closing)}</td></tr></tbody></table>`,
      { foot: '<span>Bürgerbank Wettelau eG · BIC XXXXATXX</span><span>Seite 1 von 1</span>' })];
  },
  chor: () => {
    const agenda = ['Begrüßung und Feststellung der Beschlussfähigkeit', 'Bericht der Obfrau', 'Bericht der Chorleitung', 'Kassabericht 2033', 'Bericht der Kassaprüfer und Entlastung des Vorstands', 'Mitgliedsbeitrag 2034', 'Vorschau Adventsingen 2033 und Frühjahrskonzert 2034', 'Allfälliges'];
    return [paper(
      letterhead('Liederkranz', '--paper-accent-olive', 'Chorgemeinschaft Liederkranz Wettelau<br>Obfrau Theresia Ebenhofer<br>Lindenplatz 6 · 4999 Wettelau')
      + addressBlock('Chorgemeinschaft Liederkranz · Lindenplatz 6 · 4999 Wettelau', KONRAD)
      + metaGrid([['Datum', '14.10.2033'], ['Mitgliedsnummer', 'LK-000-0117'], ['Versammlung', '14.11.2033, 19:00 Uhr']])
      + '<h4>Einladung zur Jahreshauptversammlung 2033</h4><div class="sub">Freitag, 14. November 2033, 19:00 Uhr · Gasthof Zur Linde, Saal im 1. Stock</div>'
      + '<p class="para">Liebe Sängerinnen und Sänger, wir laden euch herzlich zur ordentlichen Jahreshauptversammlung ein. Die Chorprobe an diesem Abend entfällt.</p>'
      + `<table><thead><tr><th>Pkt.</th><th>Tagesordnung</th></tr></thead><tbody>${agenda.map((a, i) => `<tr><td>${i + 1}</td><td>${a}</td></tr>`).join('')}</tbody></table>`
      + `<div class="box">Der Vorstand schlägt vor, den Mitgliedsbeitrag ab 2034 von ${eur(48)} auf ${eur(52)} im Jahr anzuheben. Anträge an die Versammlung bitte bis 31.10.2033 schriftlich an die Obfrau.</div>`
      + '<p class="para">Im Anschluss sitzen wir wie jedes Jahr gemütlich beisammen. Wir freuen uns auf euer Kommen!</p>'
      + '<p class="para" style="margin-top:22px">Mit herzlichen Grüßen<br><br>Theresia Ebenhofer<br>Obfrau</p>',
      { cls: 'scan', foot: '<span>Chorgemeinschaft Liederkranz Wettelau · ZVR 000000000</span><span>liederkranz-wettelau.example · Seite 1 von 1</span>' })];
  },
  pension: () => {
    const p1 = letterhead('Landespensionsservice', '--paper-accent-brown', 'Amt der Landesregierung<br>Landespensionsservice Ilmtal<br>Regierungsplatz 3 · 4999 Wettelau')
      + addressBlock('Landespensionsservice Ilmtal · Regierungsplatz 3 · 4999 Wettelau', KONRAD)
      + metaGrid([['Geschäftszahl', 'LPS-000-33-7720'], ['Datum', '14.10.2033'], ['Personalnummer', 'PN-000-4412'], ['Sachbearbeitung', 'Frau Kogler']])
      + '<h4>Neuberechnung Ihres Ruhegenusses</h4><div class="sub">nach Anrechnung nachgewiesener Ausbildungszeiten</div>'
      + '<p class="para">Sehr geehrter Herr Weißenbacher, mit den von Ihnen vorgelegten Bestätigungen über Ausbildungszeiten bemessen wir Ihren Ruhegenuss ab 01.05.2033 neu.</p>'
      + amountTable(['Monatlicher Ruhegenuss, brutto', 'Betrag'], [['bisher', 2840.6], ['neu', 2893.1], ['Erhöhung', 52.5, 'total']])
      + '<div class="box">Die Nachzahlung für Mai bis Oktober 2033 überweisen wir mit dem Ruhegenuss für November. Die Aufstellung finden Sie auf Seite 2.</div>';
    const foot = '<span>Landespensionsservice Ilmtal · land-ilmtal.example</span><span>LPS-000-33-7720</span>';
    const months = ['Mai 2033', 'Juni 2033', 'Sonderzahlung Juni 2033', 'Juli 2033', 'August 2033', 'September 2033', 'Oktober 2033'];
    const gross = months.length * 52.5;
    const p2 = letterhead('Landespensionsservice', '--paper-accent-brown', 'Geschäftszahl LPS-000-33-7720<br>14.10.2033')
      + '<h4>Aufstellung der Nachzahlung</h4>'
      + amountTable(['Zeitraum', 'Differenz'], months.map((m) => [m, 52.5]).concat([['Summe brutto', gross, 'subtotal'], ['Lohnsteuer', -95.55, 'subtotal'], ['Krankenversicherung', -18.74, 'subtotal'], ['Nachzahlung netto', gross - 95.55 - 18.74, 'total']]))
      + '<h4 style="margin-top:22px">Rechtsmittelbelehrung</h4>'
      + '<p class="para">Sind Sie mit dieser Berechnung nicht einverstanden, können Sie binnen vier Wochen ab Zustellung schriftlich einen Bescheid verlangen.</p>'
      + '<p class="para" style="margin-top:40px">Für die Landesregierung: ______________________</p>';
    return [paper(p1, { cls: 'scan', foot, pg: 'Seite 1 von 2' }), paper(p2, { cls: 'scan', foot, pg: 'Seite 2 von 2' })];
  },
  optik: () => {
    const r = receiptLines([['Lesebrille +2,25 Fassung rund', 1, 89], ['Brillenetui Hartschale', 1, 9.9], ['Brillenkette Perlmutt', 1, 14.5], ['Reinigungsspray 30 ml', 2, 3.9]]);
    return [paper(
      `<div class="c" style="font-weight:800;font-size:17px;color:var(--paper-accent-cyan)">Optik Klarblick</div><div class="c">Rathausgasse 7 · 4999 Wettelau<br>UID ATU00000000</div><hr>${r.html}<hr>`
      + `<div class="rl" style="font-weight:700;font-size:12px"><span>SUMME EUR</span><span>${eur(r.total).replace(' €', '')}</span></div>`
      + `<div class="rl"><span>Bankomatkarte</span><span>${eur(r.total).replace(' €', '')}</span></div><hr>`
      + `<div class="rl"><span>darin USt 20 %</span><span>${eur(r.total - r.total / 1.2).replace(' €', '')}</span></div>`
      + '<hr><div class="c">11.10.2033 10:12 · Kassa 1<br>Beleg 33-1011-0457</div><div class="barcode"></div><div class="c">Kundenkarte KK-000-0915 · Nachjustieren jederzeit kostenlos.</div>',
      { cls: 'receipt scan' })];
  },
  hollerau: () => [paper(
    letterhead('Hollerau Versicherung', '--paper-accent-red', 'Hollerau Versicherung AG<br>Kundenservice Privat<br>Versicherungsallee 2 · 4999 Wettelau')
    + addressBlock('Hollerau Versicherung AG · Versicherungsallee 2 · 4999 Wettelau', KONRAD)
    + metaGrid([['Polizze', 'HV-000-77120'], ['Nachtrag', '3'], ['Datum', '19.10.2033'], ['Gültig ab', '01.11.2033']])
    + '<h4>Nachtrag zur Hundehaftpflichtversicherung</h4><div class="sub">Versichertes Tier: Fritzi, Beagle-Mischling · Chip 000 000 000 000 000</div>'
    + amountTable(['Leistung', 'Jahresprämie'], [['Haftpflicht, Versicherungssumme 3 Mio. €', 64.8], ['Neu: Schäden an gemieteten Ferienwohnungen', 7.2], ['Versicherungssteuer 11 %', 7.92, 'subtotal'], ['Jahresprämie neu', 79.92, 'total']])
    + '<p class="para">Alle übrigen Bedingungen Ihrer Polizze bleiben unverändert. Die Prämie buchen wir wie bisher im November ab.</p>',
    { cls: 'scan', foot: '<span>Hollerau Versicherung AG · hollerau.example</span><span>Seite 1 von 1</span>' })],
};
/* A plain one-page letter for invented files (history entries, simulated downloads and scans, the linked inbox). */
const GENERIC_FILLER = [
  'Anbei erhalten Sie das Schreiben zu Ihrem Anliegen. Bitte bewahren Sie es bei Ihren Unterlagen auf und prüfen Sie, ob alle Angaben stimmen.',
  'Bei Rückfragen nennen Sie bitte die Referenz oben. Sie erreichen uns montags bis freitags zwischen 8 und 16 Uhr.',
];
function genericPaper(doc) {
  const color = doc.color || '--paper-accent-letter';
  return paper(
    letterhead(esc(doc.logo), color, esc(doc.sender || doc.logo))
    + addressBlock(esc(doc.sender || doc.logo))
    + metaGrid([['Datum', doc.date || '—'], ['Referenz', doc.ref || '—']])
    + `<h4>${esc(doc.title)}</h4><div class="sub">${esc(doc.sub || '')}</div>`
    + GENERIC_FILLER.map((p) => `<p class="para">${p}</p>`).join('')
    + '<p class="para">Mit freundlichen Grüßen</p>',
    { cls: doc.scan ? 'scan' : '', foot: `<span>${esc(doc.sender || doc.logo)}</span><span>Seite 1 von 1</span>` });
}

/* ---------------------------------------------------------------- data: inboxes and files */
const DEFAULT_INBOXES = [
  { id: 'dl', name: 'Web-Downloads', path: '~/Archiv/_Neu/Web-Downloads' },
  { id: 'sc', name: 'Scanner', path: '~/Archiv/_Neu/Scanner' },
];
const DOWNLOADS = DEFAULT_INBOXES[0];
const SCANNER = DEFAULT_INBOXES[1];
const EXTRA_INBOXES = [
  { id: 'ma', name: 'Mail-Anhänge', path: '~/Archiv/_Neu/Mail-Anhänge' },
  { id: 'ph', name: 'Handy-Import', path: '~/Pictures/Handy-Import' },
];
function mkFile(id, inbox, name, ext, modified, extra) {
  return Object.assign({ id, inbox, group: null, origName: name, ext, modified, created: modified.slice(0, 10), status: 'inbox', location: null, kind: kindOf(ext) }, extra);
}
const PDF_DOC = 'PDF document';
const STUDY_GROUP = 'Uni Westerholm Herbst 2033';
const FILES = [
  mkFile('dl-fahrplan', 'dl', 'Fahrplanheft_Ilmtalbahn_Winter_2033.pdf.crdownload', '.pdf', '2033-10-26T09:38', { downloading: 0.42, size: '2,6 MB of 6,2 MB', kindLabel: 'Chrome download', preview: null }),
  mkFile('dl-chronik', 'dl', 'Chronik Liederkranz Entwurf.pages', '.pages', '2033-10-22T21:30', { size: '412 KB', kindLabel: 'Pages document', preview: 'none', app: 'Pages' }),
  mkFile('dl-img', 'dl', 'PXL_20331012_163905.jpg', '.jpg', '2033-10-12T16:41', { size: '2,9 MB', kindLabel: 'JPEG image', preview: 'photo', dims: '3072 × 4080' }),
  mkFile('dl-uw-rechnung', 'dl', 'Rechnung_Collegegeld_1e-termijn.pdf', '.pdf', '2033-10-07T21:12', { group: STUDY_GROUP, size: '96 KB', kindLabel: PDF_DOC, preview: 'collegegeld', pages: 1 }),
  mkFile('dl-uw-bewijs', 'dl', 'Inschrijvingsbewijs_ST-000-58213.pdf', '.pdf', '2033-10-07T21:13', { group: STUDY_GROUP, size: '71 KB', kindLabel: PDF_DOC, preview: 'inschrijving', pages: 1 }),
  mkFile('dl-gehalt', 'dl', 'Gehaltszettel_2033-09_Weissenbacher.pdf', '.pdf', '2033-09-28T16:05', { size: '84 KB', kindLabel: PDF_DOC, preview: 'gehalt', pages: 1 }),
  mkFile('dl-bank', 'dl', 'Kontoauszug_2033-09_Buergerbank.pdf', '.pdf', '2033-10-02T08:14', { size: '47 KB', kindLabel: PDF_DOC, preview: 'kontoauszug', pages: 1 }),
  mkFile('dl-notenhaus', 'dl', 'Rechnung_NA-33-08812.pdf', '.pdf', '2033-10-13T11:20', { size: '112 KB', kindLabel: PDF_DOC, preview: 'notenhaus', pages: 2 }),
  mkFile('dl-ilmnet', 'dl', 'Ilmnet Rechnung Oktober 2033 (1).pdf', '.pdf', '2033-10-24T20:48', { size: '58 KB', kindLabel: PDF_DOC, preview: 'ilmnet', pages: 1 }),
  mkFile('dl-regio', 'dl', 'Regio_Plus_Verlaengerung_K-Weissenbacher.pdf', '.pdf', '2033-10-20T19:12', { size: '61 KB', kindLabel: PDF_DOC, preview: 'regio', pages: 1 }),
  mkFile('sc-optik', 'sc', '2033-10-11_Optik Klarblick.pdf', '.pdf', '2033-10-11T19:30', { size: '168 KB', kindLabel: PDF_DOC, preview: 'optik', pages: 1 }),
  mkFile('sc-chor', 'sc', '2033-10-16_Chorgerneinschaft L1ederkranz Wette1au Einladung Jahreshauptversamrn.pdf', '.pdf', '2033-10-16T18:44', { size: '231 KB', kindLabel: PDF_DOC, preview: 'chor', pages: 1 }),
  mkFile('sc-pension', 'sc', '2033-10-19_Landespensionsservice Neuberechnung.pdf', '.pdf', '2033-10-19T17:02', { size: '2,4 MB', kindLabel: PDF_DOC, preview: 'pension', pages: 2, slow: true }),
  mkFile('sc-hollerau', 'sc', '2033-10-21_Hollerau Versicherung.pdf', '.pdf', '2033-10-21T18:15', { size: '189 KB', kindLabel: PDF_DOC, preview: 'hollerau', pages: 1 }),
];
/* An inbox that is a link to a folder elsewhere, so it needs its own access grant (the "needs access" state). */
const LINKED_INBOX = { id: 'ln', name: 'Gemeinsam', path: '~/Archiv/_Neu/Gemeinsam' };
const LINKED_FILES = [
  mkFile('ln-einladung', 'ln', 'Einladung_Mieterversammlung_2033-11.pdf', '.pdf', '2033-10-18T14:05', { size: '143 KB', kindLabel: PDF_DOC, preview: 'generic', pages: 1,
    doc: { logo: 'Heimstatt Ilmtal', color: '--paper-accent-amber', sender: 'Wohnbaugenossenschaft Heimstatt Ilmtal · Mühlgraben 2 · 4999 Wettelau', title: 'Einladung zur Mieterversammlung', sub: 'Wohnanlage Brunnfeldgasse 10–16', date: '18.10.2033', ref: 'HI-33-0412', scan: true } }),
];
/* Files the "Simulate new download" button drops into the downloads inbox, one per click. */
const ARRIVALS = [
  { name: 'Stadtwerke_Teilbetrag_November_2033.pdf', doc: { logo: 'Stadtwerke Wettelau', color: '--paper-accent-orange', sender: 'Stadtwerke Wettelau GmbH · Kraftwerkstraße 3 · 4999 Wettelau', title: 'Teilbetragsvorschreibung Strom und Fernwärme', sub: 'Brunnfeldgasse 14/3 · November 2033', date: '25.10.2033', ref: 'SW-000-30418' } },
  { name: 'rollmit_Fahrtenabrechnung_2033-10.pdf', doc: { logo: 'rollmit', color: '--paper-accent-green', sender: 'rollmit Carsharing eG · Am Bahnhof 5 · 4999 Wettelau', title: 'Fahrtenabrechnung Oktober 2033', sub: '3 Fahrten · Mitgliedsnummer RM-000-1187', date: '26.10.2033', ref: 'RM-33-10-1187' } },
  { name: 'Dienstplan Stadtbücherei Okt–Dez 2033.pdf', doc: { logo: 'Stadtbücherei Wettelau', color: '--paper-accent-rose', sender: 'Stadtbücherei Wettelau · Schulgasse 11 · 4999 Wettelau', title: 'Dienstplan Ehrenamt 4. Quartal 2033', sub: 'Ausleihtheke und Vorlesestunde', date: '24.10.2033', ref: 'SB-33-Q4-07' } },
];
/* What "Simulate scan arriving in a new subfolder" drops into the scanner inbox: a scan job that writes its own folder. */
const SCAN_FOLDER_ARRIVAL = {
  group: 'Stapel 2033-10-26',
  files: [
    { name: '2033-10-26_Tierarztpraxis Aschauer Honorarnote.pdf', doc: { logo: 'Tierarztpraxis Dr. Aschauer', color: '--paper-accent-cyan', sender: 'Tierarztpraxis Dr. Aschauer · Weidenallee 8 · 4999 Wettelau', title: 'Honorarnote', sub: 'Patientin: Fritzi, Beagle-Mischling', date: '24.10.2033', ref: 'TA-33-0961', scan: true } },
    { name: '2033-10-26_Tierarztpraxis Aschauer Befund.pdf', doc: { logo: 'Tierarztpraxis Dr. Aschauer', color: '--paper-accent-cyan', sender: 'Tierarztpraxis Dr. Aschauer · Weidenallee 8 · 4999 Wettelau', title: 'Befundbericht Zahnkontrolle', sub: 'Zur Honorarnote TA-33-0961', date: '24.10.2033', ref: 'TA-33-0961', scan: true } },
  ],
};

/* Filing history before this session: invented entries in the archive's naming style, into folders of the sample
   archive. `gone` marks a file moved or deleted outside the app since. */
const SEED_HISTORY = [
  ['2032-02-11T19:20', DOWNLOADS.name, 'Jahreslohnzettel_2031_Lerchenfeld.pdf', '2031 Jahreslohnzettel Schulverein Lerchenfeld.pdf', 'Arbeit Margit/Jahreslohnzettel/2031'],
  ['2032-04-03T10:05', SCANNER.name, '2032-04-02_Pfarre St. Aegidius.pdf', '2032-04-02 Kirchenbeitrag Vorschreibung.pdf', 'Vereine & Ehrenamt/Kirchenbeitrag Pfarre St. Ägidius/2032'],
  ['2032-06-28T18:40', SCANNER.name, '2032-06-27_Vermessungsamt Wettelau.pdf', '2032-06-27 Einladung Abschiedsfeier.pdf', 'Pension Konrad/Dienstzeit Vermessungsamt/2032-06 Abschiedsfeier'],
  ['2032-07-15T20:10', DOWNLOADS.name, 'Bescheid_Ruhegenuss_PN-000-4412.pdf', '2032-07-12 Bescheid Ruhegenuss.pdf', 'Pension Konrad/2. Bescheid Ruhegenuss/Bescheid'],
  ['2032-09-02T08:30', DOWNLOADS.name, 'Nachtzug_Ticket_Westerholm.pdf', '2032-09-10 Nachtzug Hinfahrt.pdf', 'Reisen/2032-09 Besuch Matthias Westerholm/Bahn', true],
  ['2032-11-19T19:55', SCANNER.name, '2032-11-18_Heimstatt Ilmtal.pdf', '2032-11-18 Betriebskostenabrechnung 2031.pdf', 'Wohnung Brunnfeldgasse/Betriebskosten/2031'],
  ['2033-01-09T17:45', DOWNLOADS.name, 'Hundeabgabe_2033_Stadtgemeinde.pdf', '2033-01-05 Hundeabgabe 2033.pdf', 'Hund Fritzi/Hundeabgabe/2033'],
  ['2033-03-21T19:30', DOWNLOADS.name, 'Bescheid_2032_KW.pdf', '2033-03-18 Bescheid Steuerausgleich Konrad.pdf', 'Steuern/Steuerausgleich/2032/Konrad'],
  ['2033-05-22T21:00', SCANNER.name, '2033-05-21_Liederkranz Abrechnung.pdf', '2033-05-20 Abrechnung Frühjahrskonzert.pdf', 'Chor Liederkranz/Kassa/2033'],
  ['2033-06-30T19:15', DOWNLOADS.name, 'Cijferlijst_ST-000-58213.pdf', '2033-06-28 Prüfungsergebnisse Sommer.pdf', 'Matthias/Studium Westerholm/2. Studienjahr/Prüfungen'],
  ['2033-08-14T18:05', SCANNER.name, '2033-08-12_Tierarztpraxis Aschauer.pdf', '2033-08-12 Auffrischung Fritzi.pdf', 'Hund Fritzi/Tierarzt/Impfungen'],
  ['2033-09-23T20:20', SCANNER.name, '2033-09-22_Augenarzt Dr. Zoehrer.pdf', '2033-09-22 Befund Augenarzt Dr. Zöhrer.pdf', 'Gesundheit/Konrad/Augenarzt & Brillen'],
  ['2033-10-05T09:10', DOWNLOADS.name, 'Ilmnet Rechnung Oktober 2033.pdf', '2033-10-04 Rechnung Oktober.pdf', 'Kommunikation/Ilmnet Internet/Rechnungen'],
].map(([at, inbox, orig, newName, dest, gone], i) => ({ id: 'h' + i, at, kind: 'move', inbox, orig, newName, dest, fileId: null, gone: !!gone }));
/* Recent destinations at the start, newest first. */
const START_RECENT = ['Mobilität/Jahreskarte Regio Plus', 'Kommunikation/Ilmnet Internet/Rechnungen', 'Chor Liederkranz/Kassa/2033', 'Gesundheit/Konrad/Augenarzt & Brillen', 'Bank & Geld/Girokonto Bürgerbank/2033-Q3', 'Arbeit Margit/Gehaltszettel/2033', 'Chor Liederkranz/Vorstand & Protokolle/2033'];
/* The file filed in place before the page opens, and where it went. */
const PREFILED = { id: 'dl-regio', at: '2033-10-26T09:24', folder: 'Mobilität/Jahreskarte Regio Plus', name: '2033-10-20 Verlängerung Jahreskarte Konrad.pdf' };
/* What the reserved suggestions slot offers. */
const SUGGESTED = { folder: 'Chor Liederkranz/Noten', name: '2033-10-13 Notenhaus Allegretto Adventprogramm' };

/* ---------------------------------------------------------------- state */
const S = {
  mode: 'normal',
  archiveSet: true,
  inboxes: DEFAULT_INBOXES.map((x) => ({ ...x })),
  savedInboxes: null,
  files: FILES.concat(LINKED_FILES),
  sel: null,
  groupsOpen: {},
  sectionsCollapsed: {},
  recent: START_RECENT.slice(),
  folders: FOLDERS.slice(),
  foldersVersion: 0,
  created: new Set(),
  added: {},
  removed: {},
  pending: [],
  undo: [],
  redo: [],
  query: '',
  scope: null,
  hl: 0,
  chosen: null,
  chosenQuery: '',
  chosenScope: null,
  newFolder: null,
  namePick: null,
  contentsShown: null,
  nameHintTimer: 0,
  sidebarHidden: false,
  panelHidden: false,
  zoom: 'fit',
  failArmed: true,
  moveError: null,
  nameNotice: null,
  status: null,
  statusTimer: 0,
  focus: 'sidebar',
  lastStop: 'sidebar',
  indexing: true,
  loaded: new Set(),
  loadingTimer: 0,
  sheet: null,
  ql: false,
  kbd: false,
  settings: false,
  ctx: null,
  menu: null,
  stSel: 0,
  stEditing: null,
  showSugg: false,
  previewKey: '',
  linkedGranted: false,
  arrivals: 0,
  scanFolders: 0,
  clock: 9 * 60 + 41,
  history: SEED_HISTORY.slice(),
  hs: false,
  hsSel: null,
  hsQuery: '',
  hsStatus: '',
};

/* One file already filed in place this session, so the checked-off row, renaming a filed file and Move Back are
   visible from the start. */
(function seedFiled() {
  const f = S.files.find((x) => x.id === PREFILED.id);
  const before = { status: 'inbox', location: null };
  const after = { status: 'moved', location: { folder: PREFILED.folder, name: PREFILED.name } };
  placeFile(f, after);
  S.undo.push({ type: 'move', id: f.id, before, after, created: [], replaced: null, label: `Move of “${shortName(f.origName)}”` });
  S.history.push({ id: 'h-seed', at: PREFILED.at, kind: 'move', inbox: S.inboxes.find((i) => i.id === f.inbox).name, orig: f.origName, newName: after.location.name, dest: after.location.folder, fileId: f.id, gone: false });
})();

/* ---------------------------------------------------------------- folder model */
let childIndex = null;
function children(path) {
  if (!childIndex || childIndex.v !== S.foldersVersion) {
    const map = new Map();
    for (const p of S.folders) {
      const par = parentOf(p);
      if (!map.has(par)) map.set(par, []);
      map.get(par).push(p);
    }
    for (const arr of map.values()) arr.sort((a, b) => a.localeCompare(b, 'de'));
    childIndex = { v: S.foldersVersion, map };
  }
  return childIndex.map.get(path) || [];
}
const folderExists = (p) => S.folders.includes(p);
const isPending = (p) => S.pending.includes(p);

const generatedCache = new Map();
/* Generated folder contents never go back before the sample archive's first year. */
const GENERATED_FIRST_YEAR = 2031;
const GEN_WORDS = ['Rechnung', 'Bestätigung', 'Schreiben', 'Vertrag', 'Information', 'Mitteilung', 'Beleg', 'Antrag', 'Bescheid', 'Polizze', 'Kontoauszug', 'Lieferschein', 'Angebot', 'Zahlungsbestätigung'];
function baseContents(folder) {
  if (S.created.has(folder)) return [];
  if (KNOWN_CONTENTS[folder]) return KNOWN_CONTENTS[folder];
  if (generatedCache.has(folder)) return generatedCache.get(folder);
  const rnd = seeded(hashStr(folder));
  let list = [];
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
/* Files filed in earlier sessions (from the seeded history) that are still where they were put. */
function historyContents(folder) {
  return SEED_HISTORY.filter((e) => e.dest === folder && !e.gone && !e.movedBack).map((e) => e.newName);
}
/* Files in a folder, alphabetical. `self` marks the selected filed file's own entry. */
function folderFiles(folder, selfFile = null) {
  const removed = S.removed[folder] || new Set();
  const added = S.added[folder] || [];
  const base = [...new Set(baseContents(folder).concat(historyContents(folder)))].filter((n) => !removed.has(n));
  const all = base.map((n) => ({ name: n, added: false })).concat(added.map((n) => ({ name: n, added: true })));
  const selfName = selfFile && selfFile.status === 'moved' && selfFile.location.folder === folder ? selfFile.location.name : null;
  for (const x of all) x.self = x.added && x.name === selfName;
  all.sort((a, b) => a.name.localeCompare(b.name, 'de'));
  return all;
}
/* The name in `folder` that `fullName` collides with (case-insensitive), ignoring the file being renamed itself. */
function findConflict(folder, fullName, selfFile = null) {
  if (isPending(folder)) return null;
  const lower = fullName.toLowerCase();
  const hit = folderFiles(folder, selfFile).find((x) => !x.self && x.name.toLowerCase() === lower);
  return hit ? hit.name : null;
}
const folderExistingCI = (path) => S.folders.find((p) => p.toLowerCase() === path.toLowerCase()) || S.pending.find((p) => p.toLowerCase() === path.toLowerCase()) || null;
function addFolderPath(path) {
  // Creates path and any missing parents; returns the folders that were created.
  const made = [];
  const parts = path.split('/');
  for (let i = 1; i <= parts.length; i++) {
    const p = parts.slice(0, i).join('/');
    if (!folderExists(p)) { S.folders.push(p); S.created.add(p); made.push(p); }
  }
  if (made.length) S.foldersVersion++;
  return made;
}
function removeFolderIfEmpty(path) {
  if (!S.created.has(path)) return;
  if (children(path).length || (S.added[path] || []).length) return;
  S.folders = S.folders.filter((p) => p !== path);
  S.created.delete(path);
  S.foldersVersion++;
}

/* ---------------------------------------------------------------- file placement */
function displayName(f) { return f.status === 'inbox' ? f.origName : f.location.name; }
function stemOfName(f, n) {
  if (f.downloading) return n.replace(/\.pdf\.crdownload$/, '');
  return n.toLowerCase().endsWith(f.ext.toLowerCase()) ? n.slice(0, n.length - f.ext.length) : n;
}
/* The name without extension as it is now (for a filed file: its name in the archive). */
const stemOf = (f) => stemOfName(f, displayName(f));
/* The name it had in the inbox, which Revert restores. */
const originalStem = (f) => stemOfName(f, f.origName);
function placeFile(f, st) {
  if (f.status === 'moved') {
    const arr = S.added[f.location.folder] || [];
    S.added[f.location.folder] = arr.filter((n) => n !== f.location.name);
  }
  f.status = st.status;
  f.location = st.location ? { ...st.location } : null;
  if (f.status === 'moved') {
    (S.added[f.location.folder] = S.added[f.location.folder] || []).push(f.location.name);
  }
}
const snapshot = (f) => ({ status: f.status, location: f.location ? { ...f.location } : null });
const fileById = (id) => S.files.find((f) => f.id === id);

/* ---------------------------------------------------------------- derived state */
const isFirstLaunch = () => !S.archiveSet || S.inboxes.length === 0;
const inboxUnreachable = (inbox) => S.mode === 'unreachable' && inbox.id === SCANNER.id;
const inboxNeedsAccess = (inbox) => inbox.id === LINKED_INBOX.id && !S.linkedGranted;
const inboxBlocked = (inbox) => inboxUnreachable(inbox) || inboxNeedsAccess(inbox);
const archiveUnavailable = () => S.mode === 'archive';
const inboxOf = (f) => S.inboxes.find((i) => i.id === f.inbox);
/* Every file of an inbox this session, filed and trashed ones included: they keep their row. */
function inboxFiles(inbox) {
  if (inboxBlocked(inbox)) return [];
  // "Empty inboxes" hides the sample files; files that arrive later (Simulate new download, moved back) still show.
  // Files moved or deleted outside docsort (Simulate removal in Finder) are gone from the list.
  return S.files.filter((f) => f.inbox === inbox.id && !f.removedOutside && (S.mode !== 'empty' || f.arrival));
}
const unfiledCount = (inbox) => inboxFiles(inbox).filter((f) => f.status === 'inbox').length;
/* Items of an inbox in display order: loose files and subfolder groups, oldest first. A group sits at its folder's
   date, which is the date of its newest file. */
function inboxItems(inbox) {
  const files = inboxFiles(inbox);
  const items = [];
  const groups = new Map();
  for (const f of files) {
    if (f.group) {
      if (!groups.has(f.group)) { const g = { type: 'group', name: f.group, inbox: inbox.id, files: [] }; groups.set(f.group, g); items.push(g); }
      groups.get(f.group).files.push(f);
    } else items.push({ type: 'file', file: f });
  }
  for (const g of groups.values()) {
    g.files.sort((a, b) => a.modified.localeCompare(b.modified));
    g.modified = g.files[g.files.length - 1].modified;
  }
  items.sort((a, b) => (a.modified || a.file.modified).localeCompare(b.modified || b.file.modified));
  return items;
}
const groupKey = (inboxId, name) => `g:${inboxId}:${name}`;
/* Selectable rows in order, used for arrow keys. */
function navRows() {
  const rows = [];
  if (isFirstLaunch()) return rows;
  for (const inbox of S.inboxes) {
    if (S.sectionsCollapsed[inbox.id]) continue;
    for (const it of inboxItems(inbox)) {
      if (it.type === 'file') rows.push({ key: 'f:' + it.file.id, file: it.file });
      else {
        const gk = groupKey(it.inbox, it.name);
        rows.push({ key: gk, group: it });
        if (S.groupsOpen[gk]) for (const f of it.files) rows.push({ key: 'f:' + f.id, file: f, child: true });
      }
    }
  }
  return rows;
}
/* All files in visual order regardless of collapsed groups and sections (for advancing the selection). */
function visualFiles() {
  const out = [];
  if (isFirstLaunch()) return out;
  for (const inbox of S.inboxes) for (const it of inboxItems(inbox)) {
    if (it.type === 'file') out.push(it.file); else out.push(...it.files);
  }
  return out;
}
const unfiledOrder = () => visualFiles().filter((f) => f.status === 'inbox');
const filedCount = () => visualFiles().filter((f) => f.status === 'moved').length;
function selectedFile() {
  if (!S.sel || !S.sel.startsWith('f:')) return null;
  const f = fileById(S.sel.slice(2));
  return f && isVisibleFile(f) ? f : null;
}
function isVisibleFile(f) {
  if (isFirstLaunch()) return false;
  const inbox = inboxOf(f);
  return !!inbox && inboxFiles(inbox).includes(f);
}
function selectedGroup() {
  if (!S.sel || !S.sel.startsWith('g:')) return null;
  const [, inboxId, ...rest] = S.sel.split(':');
  const name = rest.join(':');
  const inbox = S.inboxes.find((i) => i.id === inboxId);
  if (!inbox) return null;
  return inboxItems(inbox).find((it) => it.type === 'group' && it.name === name) || null;
}
const isFiled = (f) => !!f && f.status !== 'inbox';
const isMoved = (f) => !!f && f.status === 'moved';
/* The filing panel works for unfiled files and for filed ones (rename or move on); not for trashed ones. */
const filingActive = () => { const f = selectedFile(); return !!f && f.status !== 'trashed' && !isFirstLaunch(); };

/* ---------------------------------------------------------------- fuzzy matching */
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
  // quick subsequence check
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
/* Marks for `tok`: the first path segment that contains it as a run of characters, so "hund" in
   "Hund Fritzi/Hundeschule Pfotenweg" marks the first "Hund". Without such a segment, the scorer's own positions. */
function firstSegmentMarks(tok, p, fallback) {
  for (let off = 0; off <= p.f.length;) {
    const end = p.f.indexOf('/', off) < 0 ? p.f.length : p.f.indexOf('/', off);
    const at = p.f.slice(off, end).indexOf(tok);
    if (at >= 0) return Array.from({ length: tok.length }, (_, k) => p.map[off + at + k]);
    off = end + 1;
  }
  return fallback.map((j) => p.map[j]);
}
/* Does a word in the last segment start with `tok`? */
function lastSegmentWordStarts(tok, p) {
  for (let j = p.lastStart; j < p.f.length; j++) if (p.wordStart[j] && p.f.startsWith(tok, j)) return true;
  return false;
}
/* Depth below the scope costs more than length, so among comparable matches a direct child ranks before a
   grandchild and a top-level folder before a deep one; a recent destination gets a smaller boost than two levels. */
const DEPTH_COST = 3;
const RECENT_BOOST = 7;
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
      for (const j of r.pos) if (j < p.lastStart) allInLast = false;
      for (const i of firstSegmentMarks(t, p, r.pos)) marks.add(i);
    }
    if (!ok) continue;
    if (allInLast) score += 6;
    if (tokens.some((t) => lastSegmentWordStarts(t, p))) score += 5;
    score -= c.display.length * 0.12 + (c.display.split('/').length - 1) * DEPTH_COST;
    const ri = recentBoost.indexOf(c.path);
    if (ri >= 0) score += RECENT_BOOST - ri * 0.25;
    out.push({ ...c, score, marks });
  }
  out.sort((a, b) => b.score - a.score || a.display.length - b.display.length);
  return out.slice(0, MAX_RESULTS);
}

/* ---------------------------------------------------------------- destination results */
let resultsCache = { key: '', items: [] };
function computeResults() {
  const key = [S.query, S.scope, S.foldersVersion, S.pending.join('|'), S.recent.join('|'), S.indexing].join('\u0001');
  if (resultsCache.key === key) return resultsCache.items;
  const items = [];
  const q = S.query.trim();
  const pend = S.pending.map((p) => ({ path: p, isNew: true }));
  if (S.scope) {
    // Candidate B: the list shows the current folder's subfolders; typing filters its whole subtree.
    const prefix = S.scope + '/';
    if (!q) {
      // The first row stands for the folder you are in, so Tab chooses it without stepping back out.
      items.push({ type: 'folder', path: S.scope, display: lastSeg(S.scope), marks: new Set(), self: true, isNew: isPending(S.scope) });
      const rows = children(S.scope).map((p) => ({ type: 'folder', path: p, display: p.slice(prefix.length), marks: new Set() }));
      for (const x of pend) if (x.path.startsWith(prefix) && !folderExists(prefix + x.path.slice(prefix.length).split('/')[0])) rows.push({ type: 'folder', path: x.path, display: x.path.slice(prefix.length), marks: new Set(), isNew: true });
      rows.sort((a, b) => a.display.localeCompare(b.display, 'de', { sensitivity: 'base' }));
      items.push(...rows);
    } else {
      const cands = S.folders.filter((p) => p.startsWith(prefix)).map((p) => ({ path: p, display: p.slice(prefix.length) }))
        .concat(pend.filter((x) => x.path.startsWith(prefix)).map((x) => ({ path: x.path, display: x.path.slice(prefix.length), isNew: true })));
      for (const r of fuzzy(q, cands, S.recent)) items.push({ type: 'folder', ...r });
    }
  } else if (!q) {
    if (S.recent.some(folderExists)) {
      items.push({ type: 'header', text: 'Recent' });
      for (const p of S.recent.filter(folderExists).slice(0, MAX_RECENT)) items.push({ type: 'folder', path: p, display: p, marks: new Set(), recent: true });
    }
    for (const x of pend) items.push({ type: 'folder', path: x.path, display: x.path, marks: new Set(), isNew: true });
    items.push({ type: 'header', text: 'All folders' });
    for (const p of children('')) items.push({ type: 'folder', path: p, display: p, marks: new Set() });
  } else if (S.indexing) {
    items.push({ type: 'info', text: 'Indexing archive…' });
  } else {
    const cands = S.folders.map((p) => ({ path: p, display: p })).concat(pend.map((x) => ({ path: x.path, display: x.path, isNew: true })));
    for (const r of fuzzy(q, cands, S.recent)) items.push({ type: 'folder', ...r });
  }
  if (q && !items.some((x) => x.type === 'folder') && !(S.indexing && !S.scope)) items.push({ type: 'create', name: q });
  resultsCache = { key, items };
  return items;
}
const selectable = (items) => items.filter((x) => x.type === 'folder' || x.type === 'create');
function highlighted() {
  const sel = selectable(computeResults());
  return sel[Math.min(S.hl, sel.length - 1)] || null;
}
/* Parent for the no-match row "New Folder … in <parent>": the folder you are browsing in, or the archive root;
   never the closest fuzzy match, which would be arbitrary. */
const createParent = () => S.scope || '';
/* Folder whose contents the panel shows. */
function contentsFolder() {
  if (S.newFolder) return null;
  if (S.chosen) return S.chosen;
  const h = highlighted();
  return h && h.type === 'folder' ? h.path : null;
}

/* ---------------------------------------------------------------- rendering helpers */
let measureCtx = null;
function textWidth(t, font) {
  if (!measureCtx) measureCtx = document.createElement('canvas').getContext('2d');
  measureCtx.font = font;
  return measureCtx.measureText(t).width;
}
function midTrunc(text, maxPx, font = '13px -apple-system, BlinkMacSystemFont, system-ui, sans-serif') {
  if (textWidth(text, font) <= maxPx) return text;
  let lo = 1, hi = text.length;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    const head = Math.ceil(mid * 0.55), tail = mid - head;
    const s = text.slice(0, head) + '…' + text.slice(text.length - tail);
    if (textWidth(s, font) <= maxPx) lo = mid; else hi = mid - 1;
  }
  const head = Math.ceil(lo * 0.55), tail = lo - head;
  return text.slice(0, head) + '…' + text.slice(text.length - tail);
}
function pathHtml(display, marks, isNew) {
  const cut = display.lastIndexOf('/');
  let html = '<span class="par">';
  let inBold = false;
  for (let i = 0; i < display.length; i++) {
    if (i === cut + 1) { if (inBold) { html += '</b>'; inBold = false; } html += '</span><span class="last">'; }
    const b = marks.has(i);
    if (b && !inBold) { html += '<b>'; inBold = true; }
    if (!b && inBold) { html += '</b>'; inBold = false; }
    html += esc(display[i]);
  }
  if (inBold) html += '</b>';
  html += '</span>';
  if (cut < 0) html = html.replace('<span class="par"></span>', '');
  return html + (isNew ? ' <span class="badge-new">New</span>' : '');
}
const tokenText = (p) => p.replace(/\//g, ' › ');

/* ---------------------------------------------------------------- render: sidebar */
function renderSidebar() {
  const list = $('sidebarList');
  const win = $('win');
  win.classList.toggle('no-sidebar', S.sidebarHidden);
  $('tbSidebar').innerHTML = ICON.sidebar;
  $('tbSidebar').title = `${S.sidebarHidden ? 'Show' : 'Hide'} Sidebar (⌃⌘S)`;
  $('sbHistoryIco').innerHTML = ICON.clock;
  if (isFirstLaunch()) { list.innerHTML = ''; list.removeAttribute('aria-activedescendant'); return; }
  // A file that arrived while docsort was open keeps its accent dot until it is first selected.
  const current = selectedFile();
  if (current) current.unseen = false;
  let html = '';
  const row = (key, inner, cls = '', label = '', title = '') =>
    `<div class="row ${cls}${S.sel === key ? ' sel' : ''}" id="row-${cssId(key)}" data-key="${esc(key)}" role="option" aria-selected="${S.sel === key}" aria-label="${esc(label)}"${title ? ` title="${esc(title)}"` : ''}>${inner}</div>`;
  S.inboxes.forEach((inbox, idx) => {
    const unreachable = inboxUnreachable(inbox);
    const needsAccess = inboxNeedsAccess(inbox);
    const items = inboxItems(inbox);
    const count = unfiledCount(inbox);
    const collapsed = !!S.sectionsCollapsed[inbox.id];
    const warn = unreachable ? 'Folder not found' : needsAccess ? 'Needs access' : '';
    html += `<div class="sb-sec${collapsed ? ' collapsed' : ''}" data-sec="${inbox.id}" title="⌘${idx + 1}"><span class="chev">${ICON.chev.replace('<svg', '<svg style="transform:rotate(90deg)"')}</span>${esc(inbox.name)}${warn ? `<span class="warn-ico" title="${warn}">${ICON.warn}</span>` : ''}<span class="cnt">${warn ? '' : count}</span></div>`;
    if (collapsed) return;
    if (unreachable) {
      html += `<div class="sb-problem"><span class="why">Folder not found</span><span class="path">${esc(inbox.path)}</span><div class="btns"><button type="button" class="btn small" data-act="locate-inbox" id="locateInbox">Locate…</button><button type="button" class="btn small" data-act="settings" id="inboxSettings">Settings…</button></div></div>`;
      return;
    }
    if (needsAccess) {
      html += `<div class="sb-problem"><span class="why">docsort needs permission to open ${esc(inbox.name)}</span><span class="path">${esc(inbox.path)} is a link to a folder outside the archive.</span><div class="btns"><button type="button" class="btn small" data-act="grant-access" id="grantAccess">Grant Access…</button></div></div>`;
      return;
    }
    if (!items.length) { html += `<div class="row empty">No files</div>`; return; }
    for (const it of items) {
      if (it.type === 'file') html += fileRow(it.file, row);
      else {
        const gk = groupKey(it.inbox, it.name);
        const open = !!S.groupsOpen[gk];
        const date = relDate(it.modified);
        const left = it.files.filter((f) => f.status === 'inbox').length;
        const unseen = it.files.some((f) => f.unseen);
        html += row(gk, `<span class="gutter"><span class="disc" data-disc="${esc(gk)}" title="${open ? 'Collapse (←)' : 'Expand (→)'}">${ICON.chev}</span></span>${rowIcon(fileIcon('folder'), unseen)}<span class="rtext"><span class="rname" data-full="${esc(it.name)}">${esc(it.name)}</span></span><span class="rdate">${left ? `${left} · ` : ''}${date}</span>`, open ? 'open' : '', `Folder ${it.name}, ${it.files.length} files`);
        if (open) for (const f of it.files) html += fileRow(f, row, 'child');
      }
    }
  });
  list.innerHTML = html;
  truncateRows();
  const selEl = S.sel ? document.getElementById('row-' + cssId(S.sel)) : null;
  if (selEl) list.setAttribute('aria-activedescendant', selEl.id); else list.removeAttribute('aria-activedescendant');
}
/* Unfiled rows show the file icon and name; filed rows a check and the new name; trashed rows a trash icon and the
   struck-through name. All stay in place.
   Row anatomy as in Finder's list view: a disclosure gutter (empty for a file, the chevron for a folder), then one
   icon column shared by files, folders and the filed / trashed marks, then the name. The new-file dot sits on the
   icon's top-leading corner, so it never moves the icon or the name. */
const GUTTER = '<span class="gutter" aria-hidden="true"></span>';
const rowIcon = (icon, unseen) => `<span class="ricon">${icon}${unseen ? NEW_DOT : ''}</span>`;
function fileRow(f, row, cls = '') {
  const date = relDate(f.modified);
  if (f.status === 'moved') {
    const tip = `→ ${f.location.folder}\nwas ${f.origName}`;
    return row('f:' + f.id, `${GUTTER}${rowIcon(`<span class="status-ico ok" aria-hidden="true">${ICON.check}</span>`)}<span class="rtext"><span class="rname" data-full="${esc(f.location.name)}" data-tip="${esc(tip)}">${esc(f.location.name)}</span></span><span class="rdate">${date}</span>`, cls + ' filed', `${f.location.name}, filed to ${f.location.folder}`, tip);
  }
  if (f.status === 'trashed') {
    return row('f:' + f.id, `${GUTTER}${rowIcon(`<span class="status-ico trash" aria-hidden="true">${ICON.trash}</span>`)}<span class="rtext"><span class="rname" data-full="${esc(f.location.name)}" data-tip="In the Trash">${esc(f.location.name)}</span></span><span class="rdate">${date}</span>`, cls + ' trashed', `${f.location.name}, in the Trash`, 'In the Trash');
  }
  const icon = f.downloading ? progressRing(f.downloading) : fileIcon(f.kind);
  return row('f:' + f.id, `${GUTTER}${rowIcon(icon, f.unseen)}<span class="rtext"><span class="rname" data-full="${esc(f.origName)}">${esc(f.origName)}</span></span><span class="rdate">${date}</span>`, cls + (f.flash ? ' arrived' : ''), f.unseen ? `${f.origName}, new` : f.origName);
}
const NEW_DOT = '<span class="new-dot" aria-hidden="true" title="New"></span>';
/* Outside changes add or remove rows; the rows on screen stay where they are. The anchor is the selected row if it
   is visible, else the first visible row, and the list scrolls so the anchor keeps its place on screen. */
function keepSidebarAnchor(change) {
  const list = $('sidebarList');
  const top = list.scrollTop, bottom = top + list.clientHeight;
  const rows = [...list.querySelectorAll('.row[data-key]')];
  const visible = (r) => r.offsetTop + r.offsetHeight > top && r.offsetTop < bottom;
  const anchor = rows.find((r) => r.dataset.key === S.sel && visible(r)) || rows.find(visible);
  const key = anchor ? anchor.dataset.key : null;
  const offset = anchor ? anchor.offsetTop - top : 0;
  change();
  const again = key ? [...list.querySelectorAll('.row[data-key]')].find((r) => r.dataset.key === key) : null;
  if (again) list.scrollTop = again.offsetTop - offset;
}
/* Middle-truncate row names to the width the layout actually gives them, as Finder does. */
function truncateRows() {
  const els = document.querySelectorAll('#sidebarList .rname[data-full]');
  if (!els.length) return;
  const cs = getComputedStyle(els[0]);
  const font = `${cs.fontSize} ${cs.fontFamily}`;
  els.forEach((el) => {
    const full = el.dataset.full;
    const avail = el.clientWidth;
    if (avail > 0) el.textContent = midTrunc(full, avail - 1, font);
    el.title = el.dataset.tip || full;
  });
}
const cssId = (key) => key.replace(/[^a-zA-Z0-9_-]/g, '_');
function scrollSelIntoView() {
  const el = S.sel ? document.getElementById('row-' + cssId(S.sel)) : null;
  if (el) el.scrollIntoView({ block: 'nearest' });
}

/* ---------------------------------------------------------------- render: toolbar */
function renderToolbar() {
  const f = selectedFile();
  const g = selectedGroup();
  let title = '<span class="app">docsort</span>';
  if (f) {
    const inbox = inboxOf(f);
    const where = inbox.name + (f.group ? ' › ' + f.group : '');
    const dest = f.status === 'moved' ? `<span class="dest" title="${esc(f.location.folder)}">→ ${esc(f.location.folder)}</span>` : f.status === 'trashed' ? '<span class="dest">→ Trash</span>' : '';
    title += `<span class="inbox">${esc(where)}</span><span class="sep">›</span><span class="fname" title="${esc(displayName(f))}">${esc(displayName(f))}</span>${dest}`;
  } else if (g) {
    const inbox = S.inboxes.find((i) => i.id === g.inbox);
    title += `<span class="inbox">${esc(inbox.name)}</span><span class="sep">›</span><span class="fname">${esc(g.name)}</span>`;
  }
  $('tbTitle').innerHTML = title;
  $('tbOpen').innerHTML = ICON.open;
  $('tbReveal').innerHTML = ICON.finder;
  $('tbTrash').innerHTML = ICON.trash;
  $('tbPanel').innerHTML = ICON.inspector;
  $('tbPanel').title = `${S.panelHidden ? 'Show' : 'Hide'} Filing Panel (⌥⌘I)`;
  $('tbOpen').disabled = !(f && !f.downloading);
  $('tbReveal').disabled = !f;
  $('tbTrash').disabled = !f || f.status === 'trashed';
}

/* ---------------------------------------------------------------- render: preview */
function inboxNamesText() {
  const names = S.inboxes.map((i) => i.name);
  if (names.length <= 1) return names.join('');
  return names.slice(0, -1).join(', ') + ' and ' + names[names.length - 1];
}
function previewContent(f, forQL = false) {
  if (f.downloading) {
    return { center: true, html: `${progressRing(f.downloading).replace('class="prog"', 'class="prog" style="width:56px;height:56px;color:var(--accent)"')}<h3>Downloading…</h3><p>${esc(f.origName.replace(/\.crdownload$/, ''))} is still downloading. You can file it when the download is complete.</p><div class="progress"><div style="width:${Math.round(f.downloading * 100)}%"></div></div><div class="meta">${esc(f.size)} · ${Math.round(f.downloading * 100)} %</div>`, footer: `${esc(f.kindLabel)} · ${esc(f.size)} · Started ${longDate(f.modified)}` };
  }
  if (f.preview === 'none') {
    return { center: true, html: `${fileIcon('pages', 'big-ico').replace('class="ficon', 'style="width:96px;height:120px" class="ficon')}<h3>${esc(displayName(f))}</h3><div class="meta">${esc(f.kindLabel)} · ${esc(f.size)}<br>Created ${longDate(f.created)} · Modified ${longDate(f.modified)}</div><p>There is no preview for this kind of file.</p>${forQL ? '' : `<button type="button" class="btn big" id="openWithBtn" data-act="open">Open with ${esc(f.app)}<span class="k">⌘O</span></button>`}`, footer: `${esc(f.kindLabel)} · ${esc(f.size)} · Modified ${longDate(f.modified)}` };
  }
  const pages = f.preview === 'generic' ? [genericPaper(f.doc)] : PREVIEWS[f.preview]();
  const kind = f.kind === 'img' ? `${esc(f.kindLabel)} · ${f.dims}` : `${pages.length === 1 ? '1 page' : pages.length + ' pages'}`;
  const where = f.status === 'moved' ? ` · ${esc(f.location.folder)}` : f.status === 'trashed' ? ' · In Trash' : '';
  return { center: false, html: pages.join(''), pagesCount: pages.length, footer: `${kind} · ${esc(f.size)} · ${f.kind === 'img' ? 'Taken' : 'Created'} ${longDate(f.created)} · Modified ${longDate(f.modified)}${where}`, image: f.kind === 'img' };
}
function renderPreview(force = false) {
  const f = selectedFile();
  const g = selectedGroup();
  const unfiled = unfiledOrder().length;
  const key = [S.sel, f && f.status, f && f.location && f.location.folder, f && f.location && f.location.name, S.mode, isFirstLaunch(), unfiled === 0, filedCount(), inboxNamesText(), f && S.loaded.has(f.id)].join('|');
  if (!force && key === S.previewKey) { applyZoom(); return; }
  S.previewKey = key;
  const pages = $('pvPages'), footer = $('pvFooter'), scroll = $('pvScroll');
  clearTimeout(S.loadingTimer);
  scroll.scrollTop = 0;
  const center = (html, foot = '') => { pages.innerHTML = `<div class="pv-center">${html}</div>`; pages.dataset.center = '1'; footer.textContent = foot; applyZoom(); };
  if (isFirstLaunch()) {
    center(`<span class="welcome-ico">${ICON.tray}</span><h3>Welcome to docsort</h3><p>Choose your archive folder and inbox folders to start.</p><button type="button" class="btn default big" id="welcomeSettings" data-act="settings">Open Settings…<span class="k">⌘,</span></button>`);
    return;
  }
  if (!f && !g) {
    if (unfiled === 0) {
      const n = filedCount();
      center(`<span class="done-ico">${ICON.done}</span><h3>All filed</h3><p>${n === 1 ? '1 file' : n + ' files'} filed this session. ${esc(inboxNamesText())} ${S.inboxes.length === 1 ? 'is' : 'are'} empty.</p>`);
    } else center(`<p>Select a file in the sidebar to see it here.</p>`);
    return;
  }
  if (g) {
    center(`${fileIcon('folder').replace('style="width:16px;height:13px"', 'style="width:80px;height:66px"')}<h3>${esc(g.name)}</h3><div class="meta">Folder in ${esc(S.inboxes.find((i) => i.id === g.inbox).name)} · ${g.files.length} files · ${longDate(g.modified)}</div><p>${S.groupsOpen[S.sel] ? 'Select one of its files to file it.' : 'Press → to show its files, then select one to file it.'}</p>`, `Folder · ${g.files.length} files`);
    return;
  }
  if (f.slow && !S.loaded.has(f.id)) {
    pages.innerHTML = ''; footer.textContent = 'Loading…';
    S.loadingTimer = setTimeout(() => {
      pages.innerHTML = '<div class="pv-center"><div class="spinner" role="progressbar" aria-label="Loading preview"></div></div>';
      S.loadingTimer = setTimeout(() => { S.loaded.add(f.id); renderPreview(true); }, 700);
    }, 200);
    return;
  }
  const c = previewContent(f);
  if (c.center) { center(c.html, ''); footer.innerHTML = c.footer; return; }
  pages.dataset.center = '';
  pages.dataset.image = c.image ? '1' : '';
  pages.innerHTML = c.html;
  S.pvFooterBase = c.footer;
  S.pvPages = c.pagesCount;
  applyZoom();
  updatePageIndicator();
}
function fitZoom(container, pagesEl) {
  const kids = [...pagesEl.children];
  if (!kids.length || pagesEl.dataset.center === '1') return 1;
  const w = Math.max(...kids.map((k) => k.offsetWidth));
  const availW = container.clientWidth - 44;
  if (pagesEl.dataset.image === '1') {
    const h = Math.max(...kids.map((k) => k.offsetHeight));
    return Math.max(0.2, Math.min(availW / w, (container.clientHeight - 52) / h, 1.5));
  }
  return Math.max(0.3, Math.min(availW / w, 1.6));
}
function effectiveZoom() {
  const pages = $('pvPages');
  return S.zoom === 'fit' ? fitZoom($('pvScroll'), pages) : S.zoom;
}
function applyZoom() {
  const pages = $('pvPages');
  if (pages.dataset.center === '1') { pages.style.setProperty('--pz', 1); return; }
  pages.style.setProperty('--pz', 1);
  pages.style.setProperty('--pz', effectiveZoom().toFixed(3));
}
function updatePageIndicator() {
  const pages = $('pvPages');
  if (pages.dataset.center === '1' || !S.pvFooterBase) return;
  const scroll = $('pvScroll');
  const kids = [...pages.children];
  let current = 1;
  const z = parseFloat(pages.style.getPropertyValue('--pz')) || 1;
  const mid = scroll.scrollTop + scroll.clientHeight / 3;
  kids.forEach((k, i) => { if (k.offsetTop * z <= mid) current = i + 1; });
  const zoomTxt = S.zoom === 'fit' ? '' : ` · ${Math.round(S.zoom * 100)} %`;
  const pageTxt = S.pvPages > 1 ? `Page ${current} of ${S.pvPages} · ` : '';
  $('pvFooter').innerHTML = pageTxt + S.pvFooterBase.replace(/^\d+ pages? · /, S.pvPages > 1 ? '' : '1 page · ') + zoomTxt;
}

/* ---------------------------------------------------------------- render: panel */
function renderPanel() {
  const win = $('win');
  win.classList.toggle('no-panel', S.panelHidden);
  $('suggSlot').hidden = !S.showSugg || isFirstLaunch();
  const f = selectedFile();
  const g = selectedGroup();
  const form = $('filingForm');
  const filedInfo = $('filedInfo');
  const archiveNotice = $('archiveNotice');
  archiveNotice.hidden = !archiveUnavailable() || isFirstLaunch();
  if (!archiveNotice.hidden) {
    archiveNotice.innerHTML = `${ICON.warn}<div><div>Archive folder not available: <b>${ARCHIVE_PATH}</b></div><div style="margin-top:6px"><button type="button" class="btn small" data-act="locate-archive" id="locateArchive">Locate…</button></div></div>`;
  }
  renderFileStrip(isFirstLaunch() ? null : f);
  if (isFirstLaunch()) {
    form.hidden = true; filedInfo.hidden = true; return;
  }
  if (f && f.status === 'trashed') {
    form.hidden = true;
    filedInfo.hidden = false;
    const inbox = inboxOf(f);
    filedInfo.innerHTML = `<dl><dt>Name</dt><dd>${esc(f.location.name)}</dd><dt>From</dt><dd>${esc(inbox.name)}${f.group ? ' › ' + esc(f.group) : ''}</dd></dl>`;
    return;
  }
  filedInfo.hidden = true;
  form.hidden = false;
  const active = !!f;
  form.classList.toggle('inactive', !active);
  $('panelEmpty').hidden = active;
  if (!active) $('panelEmpty').textContent = g ? `Select a file inside “${g.name}” to file it.` : 'Select a file in the sidebar to file it.';
  const archiveDown = archiveUnavailable();
  const destInput = $('destInput'), nameInput = $('nameInput');
  destInput.disabled = !active || archiveDown;
  nameInput.disabled = !active || archiveDown;
  // destination field: chosen folder as a token, or the current folder as a scope chip
  const token = $('destToken'), scopeChip = $('destScope');
  if (S.chosen) {
    token.hidden = false;
    token.title = S.chosen;
    token.innerHTML = `<span class="t">${esc(tokenText(S.chosen))}</span>${isPending(S.chosen) ? '<span class="badge-new new">New</span>' : ''}`;
    destInput.placeholder = '';
  } else {
    token.hidden = true;
    destInput.placeholder = archiveDown ? 'Archive not available' : S.scope ? `Search in ${lastSeg(S.scope)}` : 'Search folders';
  }
  scopeChip.hidden = !S.scope || !!S.chosen;
  if (S.scope) { scopeChip.innerHTML = `<span class="t">in ${esc(lastSeg(S.scope))}</span>`; scopeChip.title = `Searching inside ${S.scope}. Backspace steps out.`; }
  if (!S.chosen && destInput.value !== S.query) destInput.value = S.query;
  $('destClear').hidden = !(S.query || S.chosen || S.scope);
  $('destClear').innerHTML = ICON.clear;
  renderPathBar();
  renderResults();
  renderContents();
  // name
  $('nameExt').textContent = f ? f.ext : '';
  nameInput.placeholder = f ? stemOf(f) : '';
  updateNameExtras();
  // move error / blocked
  const err = $('moveError');
  err.hidden = !S.moveError;
  if (S.moveError) err.innerHTML = `<div class="head">${ICON.errorCircle}<span>Couldn’t move “${esc(S.moveError.name)}”</span></div><div>${esc(S.moveError.reason)} The file is still in ${esc(S.moveError.inbox)}.</div><div class="btns"><button type="button" class="btn small" id="retryBtn" data-act="retry">Try Again</button></div>`;
  const blocked = $('moveBlocked');
  const blockText = !f ? '' : f.downloading ? 'This file is still downloading. You can move it when the download is complete.' : '';
  blocked.hidden = !blockText;
  blocked.textContent = blockText;
  updateMoveButton();
}
/* For a filed or trashed file: a one-line strip at the top of the panel that says where the file is now, with the
   action that undoes it at its trailing end. The path middle-truncates to the width the strip gives it. */
function renderFileStrip(f) {
  const strip = $('fileStrip');
  strip.hidden = !isFiled(f);
  if (strip.hidden) { strip.innerHTML = ''; return; }
  const inbox = inboxOf(f).name;
  const when = handledWhen(f);
  const trashed = f.status === 'trashed';
  strip.classList.toggle('trashed', trashed);
  const text = trashed
    ? `<span class="fs-lead">Moved to Trash</span>`
    : `<span class="fs-lead">Filed to&nbsp;</span><span class="fs-path" data-full="${esc(f.location.folder)}">${esc(f.location.folder)}</span>`;
  const btn = trashed
    ? `<button type="button" class="btn small no-focus" id="putBackBtn" data-act="moveBack" title="Put back in ${esc(inbox)} (⌥⌘Z)">Put Back</button>`
    : `<button type="button" class="btn small no-focus" id="moveBackBtn" data-act="moveBack" title="Move back to ${esc(inbox)} (⌥⌘Z)">Move Back</button>`;
  strip.innerHTML = `<span class="fs-ico ${trashed ? 'trash' : 'ok'}" aria-hidden="true">${trashed ? ICON.trash : ICON.check}</span><span class="fs-text">${text}${when ? `<span class="fs-when">&nbsp;· ${esc(when)}</span>` : ''}</span>${btn}`;
  const whenTip = when ? ` · ${when}` : '';
  strip.title = trashed ? `Moved to Trash${whenTip}, from ${inbox}` : `Filed to ${ARCHIVE_PATH}/${f.location.folder}${whenTip}\nwas “${f.origName}” in ${inbox}`;
  const path = strip.querySelector('.fs-path');
  if (path) {
    // a narrow panel gives the path priority: the time goes first (it stays in the tooltip), then the path's middle
    const whenEl = strip.querySelector('.fs-when');
    if (whenEl && path.scrollWidth > path.clientWidth) whenEl.remove();
    const cs = getComputedStyle(path);
    const avail = path.clientWidth;
    if (avail > 0) path.textContent = midTrunc(path.dataset.full, avail - 1, `${cs.fontSize} ${cs.fontFamily}`);
  }
}
/* When the file got where it is now: "today 09:41", or the day for an earlier one. */
function handledWhen(f) {
  const kinds = f.status === 'trashed' ? ['trash'] : ['move', 'rename'];
  const e = S.history.slice().reverse().find((x) => x.fileId === f.id && kinds.includes(x.kind));
  if (!e) return '';
  return dayDiff(e.at) === 0 ? `today ${e.at.slice(11, 16)}` : relDate(e.at.slice(0, 10));
}
/* Path bar above the list while inside a folder: Archive › Hund Fritzi › Tierarzt; segments are clickable. */
function renderPathBar() {
  const bar = $('pathBar');
  const show = !!S.scope && !!selectedFile() && !archiveUnavailable();
  bar.hidden = !show;
  if (!show) return;
  const parts = S.scope.split('/');
  let html = `<button type="button" class="seg-btn" data-scope="" title="${esc(ARCHIVE_PATH)}">Archive</button>`;
  parts.forEach((p, i) => {
    const path = parts.slice(0, i + 1).join('/');
    html += `<span class="pb-sep">›</span><button type="button" class="seg-btn${i === parts.length - 1 ? ' cur' : ''}" data-scope="${esc(path)}">${esc(p)}</button>`;
  });
  bar.innerHTML = html;
}
/* Where a move would go and under which name, or null. */
function filingTarget() {
  const f = selectedFile();
  if (!f) return null;
  const h = S.newFolder ? null : highlighted();
  const dest = S.chosen || (h && h.type === 'folder' ? h.path : null);
  return dest ? { dest, full: effectiveStem(f) + f.ext } : null;
}
/* For a filed file: 'rename' when only the name changed, 'move' when the folder changed, 'none' otherwise. */
function changeKind(f, t = filingTarget()) {
  if (!isMoved(f)) return 'move';
  if (!t) return 'none';
  if (t.dest !== f.location.folder) return 'move';
  return t.full !== f.location.name ? 'rename' : 'none';
}
/* The default button carries its shortcut as a key-cap badge: "Move ⌘↩" (or "Rename ⌘↩" for a filed file). */
function updateMoveButton() {
  const f = selectedFile();
  const kind = f ? changeKind(f) : 'move';
  const label = kind === 'rename' ? 'Rename' : 'Move';
  const btn = $('moveBtn');
  btn.innerHTML = `${label}<span class="kcap" aria-hidden="true">⌘ ↩</span>`;
  btn.title = `${label} (⌘Return)`;
  btn.setAttribute('aria-label', label);
  btn.disabled = !canMove();
}
function renderResults() {
  if (S.newFolder && document.activeElement && document.activeElement.id === 'newFolderInput') return;
  const box = $('results');
  const f = selectedFile();
  if (!f || archiveUnavailable()) {
    box.innerHTML = archiveUnavailable() && f ? '<div class="res-empty">Destination search needs the archive folder. Preview, Open, Reveal and Move to Trash still work.</div>' : '';
    updateNewFolderBtn();
    return;
  }
  const items = computeResults();
  const sel = selectable(items);
  if (S.hl >= sel.length) S.hl = Math.max(0, sel.length - 1);
  let si = -1;
  let html = '';
  const hlItem = S.newFolder ? null : sel[S.hl];
  let newRowPlaced = !S.newFolder;
  for (const it of items) {
    if (it.type === 'header') { html += `<div class="res-h">${esc(it.text)}</div>`; continue; }
    if (it.type === 'info') { html += `<div class="res-empty">${esc(it.text)} Recent destinations already work.</div>`; continue; }
    si++;
    const isHl = it === hlItem && !S.chosen;
    const isChosen = S.chosen && it.type === 'folder' && it.path === S.chosen;
    const cls = `res${isHl || isChosen ? ' hl' : ''}${it.type === 'create' ? ' create' : ''}`;
    if (it.type === 'create') {
      const par = createParent();
      html += `<div class="${cls}" role="option" id="res-${si}" data-si="${si}" aria-selected="${isHl}">${ICON.folderPlus}<span class="rt">New Folder “${esc(it.name)}” in ${esc(par ? tokenText(par) : 'Archive')}</span><span class="sub-cnt">⇧⌘N</span></div>`;
    } else if (it.self) {
      html += `<div class="${cls} self" role="option" id="res-${si}" data-si="${si}" aria-selected="${isHl}" aria-label="${esc(it.display)}, this folder" title="${esc(it.path)}">${ICON.folderHere}<span class="rt"><span class="last">${esc(it.display)}</span><span class="self-tag">this folder</span>${it.isNew ? ' <span class="badge-new">New</span>' : ''}</span></div>`;
      if (sel.length > 1 || S.newFolder) html += '<div class="res-sep" role="separator"></div>';
    } else {
      if (!newRowPlaced && it.display.localeCompare(S.newFolder.value || '', 'de', { sensitivity: 'base' }) > 0) { html += newFolderRow(); newRowPlaced = true; }
      const kids = children(it.path).length;
      html += `<div class="${cls}" role="option" id="res-${si}" data-si="${si}" data-sort="${esc(it.display)}" aria-selected="${isHl}" title="${esc(it.path)}">${ICON.folder}<span class="rt">${pathHtml(it.display, it.marks, it.isNew)}</span>${kids ? `<span class="kids" data-step="${si}" title="Show its ${kids} subfolders (→)">${ICON.chev}</span>` : ''}</div>`;
    }
  }
  if (!newRowPlaced) html += newFolderRow();
  if (!sel.length && !S.newFolder && !items.some((x) => x.type === 'info')) html += `<div class="res-empty">${S.scope ? `No subfolders in “${esc(lastSeg(S.scope))}”. ← goes back.` : 'No folders.'}</div>`;
  const keepTop = box.scrollTop;
  box.innerHTML = html;
  box.scrollTop = keepTop;
  const hlEl = box.querySelector('.res.hl');
  if (hlEl) {
    const top = hlEl.offsetTop, bottom = top + hlEl.offsetHeight;
    if (top < box.scrollTop + 22) box.scrollTop = Math.max(0, top - 26);
    else if (bottom > box.scrollTop + box.clientHeight) box.scrollTop = bottom - box.clientHeight + 4;
    $('destInput').setAttribute('aria-activedescendant', hlEl.id);
  }
  if (S.newFolder) {
    const inp = $('newFolderInput');
    if (inp) {
      inp.value = S.newFolder.value || '';
      updateNewFolderNote();
      if (S.newFolder.focus) { S.newFolder.focus = false; inp.focus(); }
      $('newRow').scrollIntoView({ block: 'nearest' });
    }
  }
  updateNewFolderBtn();
}
function newFolderRow() {
  return `<div class="newrow" id="newRow">${ICON.folder}<div class="nf"><input id="newFolderInput" type="text" autocomplete="off" spellcheck="false" placeholder="Folder name" aria-label="New folder name in ${esc(S.newFolder.parent || 'Archive')}"><div class="nh" id="newFolderNote"></div></div></div>`;
}
/* The parent a New Folder command would use: the chosen or highlighted folder, else the current folder. */
function newFolderParent() {
  if (S.chosen && !isPending(S.chosen)) return S.chosen;
  const h = highlighted();
  if (h && h.type === 'folder' && !h.isNew) return h.path;
  return S.scope || '';
}
function updateNewFolderBtn() {
  const btn = $('newFolderBtn');
  btn.innerHTML = ICON.folderPlus;
  const on = filingActive() && !archiveUnavailable() && !S.newFolder;
  btn.disabled = !on;
  const par = newFolderParent();
  btn.title = `New Folder in ${par || 'Archive'} (⇧⌘N)`;
  btn.setAttribute('aria-label', btn.title);
}
/* Keeps the editable row at its alphabetical place among its siblings while typing, by moving the siblings so the
   focused field never leaves the DOM. */
function repositionNewRow() {
  const row = $('newRow');
  if (!row) return;
  const box = $('results');
  const v = (S.newFolder.value || '').split('/')[0].trim();
  const sibs = [...box.querySelectorAll('.res[data-sort]')];
  const before = sibs.filter((el) => el.dataset.sort.localeCompare(v, 'de', { sensitivity: 'base' }) <= 0 || !v);
  const after = sibs.filter((el) => !before.includes(el));
  if (!v) { for (const el of sibs.slice().reverse()) box.insertBefore(el, row.nextSibling); }
  else {
    for (const el of before) box.insertBefore(el, row);
    for (const el of after.slice().reverse()) box.insertBefore(el, row.nextSibling);
  }
  row.scrollIntoView({ block: 'nearest' });
}
function newFolderTarget() {
  const raw = (S.newFolder.value || '').trim().replace(/\/+/g, '/').replace(/^\/|\/$/g, '');
  const parts = raw.split('/').map((x) => x.trim()).filter(Boolean);
  if (!parts.length) return null;
  const path = (S.newFolder.parent ? S.newFolder.parent + '/' : '') + parts.join('/');
  return { path, parts, existing: folderExistingCI(path) };
}
function updateNewFolderNote() {
  const note = $('newFolderNote');
  if (!note) return;
  const t = newFolderTarget();
  note.classList.toggle('dup', !!(t && t.existing));
  if (t && t.existing) note.textContent = `“${lastSeg(S.newFolder.parent) || 'Archive'}” already contains a folder named “${lastSeg(t.existing)}”. Return selects it.`;
  else if (t && t.parts.length > 1) note.textContent = `Creates ${t.parts.join(' › ')} · Return or Tab confirms · Esc cancels`;
  else note.textContent = 'Return or Tab confirms · Esc cancels';
}
function renderContents() {
  const box = $('contents');
  const folder = contentsFolder();
  const f = selectedFile();
  const pathEl = $('contentsPath'), cnt = $('contentsCount');
  if (S.newFolder && f) {
    $('contentsLabel').firstChild.textContent = 'In';
    pathEl.textContent = (S.newFolder.parent || 'Archive') + ' › new folder'; cnt.textContent = '';
    box.innerHTML = '<div class="ct-empty">docsort creates the new folder when you move the file, so cancelling leaves nothing behind.</div>';
    S.contentsShown = null;
    return;
  }
  if (!f || !folder || archiveUnavailable()) {
    pathEl.textContent = ''; cnt.textContent = '';
    $('contentsLabel').firstChild.textContent = 'Folder contents';
    box.innerHTML = `<div class="ct-empty">${f && !archiveUnavailable() ? 'Highlight a folder to see its files.' : ''}</div>`;
    S.contentsShown = null;
    return;
  }
  $('contentsLabel').firstChild.textContent = 'In';
  pathEl.textContent = folder;
  pathEl.title = folder;
  if (isPending(folder)) {
    cnt.textContent = '';
    box.innerHTML = '<div class="ct-empty">New folder. docsort creates it when you move the file, so cancelling leaves nothing behind.</div>';
    S.contentsShown = folder;
    return;
  }
  const files = folderFiles(folder, f);
  cnt.textContent = files.length === 1 ? '1 file' : `${files.length} files`;
  const target = currentTargetName();
  const conflict = target ? findConflict(folder, target, f) : null;
  const html = files.map((x, i) => {
    const ext = (x.name.match(/\.[^.]+$/) || [''])[0];
    const c = conflict && x.name === conflict;
    const picked = S.namePick && S.namePick.folder === folder && S.namePick.name === x.name;
    return `<div class="ct${c ? ' conflict' : ''}${x.added && !x.self ? ' added' : ''}${x.self ? ' self' : ''}${picked ? ' picked' : ''}" data-ct="${i}"${c ? ' id="conflictRow"' : ''} title="${x.self ? 'This file' : 'Click to use this name'}">${fileIcon(kindOf(ext))}<span class="tn">${esc(x.name)}</span></div>`;
  }).join('');
  const keepTop = box.scrollTop;
  box.innerHTML = html || '<div class="ct-empty">No files</div>';
  if (folder !== S.contentsShown) {
    // a new highlight: start at the bottom, where the archive's date-named files are newest
    S.contentsShown = folder;
    S.namePick = null;
    box.scrollTop = box.scrollHeight;
  } else box.scrollTop = keepTop;
  const focusRow = $('conflictRow') || box.querySelector('.ct.picked');
  if (focusRow) {
    const top = focusRow.offsetTop;
    if (top < box.scrollTop || top > box.scrollTop + box.clientHeight - 22) box.scrollTop = top - 30;
  }
}
function currentTargetName() {
  const f = selectedFile();
  if (!f) return null;
  return effectiveStem(f) + f.ext;
}
function effectiveStem(f) {
  let v = $('nameInput').value.trim();
  if (!v) return stemOf(f);
  const ext = f.ext.toLowerCase();
  while (v.toLowerCase().endsWith(ext) && v.length > ext.length) v = v.slice(0, v.length - ext.length).trimEnd();
  return v;
}
function updateNameNotice() {
  const n = $('nameNotice');
  const f = selectedFile();
  const folder = contentsFolder();
  let text = '';
  if (S.nameNotice) text = S.nameNotice;
  else if (f && folder && !archiveUnavailable()) {
    const target = currentTargetName();
    const hit = findConflict(folder, target, f);
    if (hit) text = hit === target ? `“${hit}” already exists in this folder.` : `“${hit}” already exists in this folder. Names that differ only in case count as the same.`;
  }
  n.hidden = !text;
  n.innerHTML = text ? `${ICON.warn}<span>${esc(text)}</span>` : '';
}
/* Conflict notice, revert control and the Move/Rename button follow the name field. */
function updateNameExtras() {
  updateNameNotice();
  const f = selectedFile();
  const rv = $('revertBtn');
  rv.innerHTML = ICON.revert;
  const differs = !!f && filingActive() && !archiveUnavailable() && effectiveStem(f) !== originalStem(f);
  rv.hidden = !differs;
  if (f) { rv.title = `Revert to “${originalStem(f)}” (⇧⌘R)`; rv.setAttribute('aria-label', rv.title); }
  updateMoveButton();
}
function canMove() {
  const f = selectedFile();
  if (!f || !filingActive() || f.downloading || archiveUnavailable()) return false;
  const t = filingTarget();
  return !!t && changeKind(f, t) !== 'none';
}

/* ---------------------------------------------------------------- render: status bar */
function setStatus(html, opts = {}) {
  S.status = { html, kind: opts.kind || 'info', link: opts.link || null };
  clearTimeout(S.statusTimer);
  S.statusTimer = setTimeout(() => { S.status = null; renderStatus(); }, opts.ms || 12000);
  renderStatus(true);
}
function renderStatus(flash = false) {
  const bar = $('statusbar');
  const unfiled = unfiledOrder().length;
  const idle = isFirstLaunch() ? 'Not set up' : `${unfiled === 1 ? '1 file' : unfiled + ' files'} to file · ${filedCount()} filed this session`;
  if (!S.status) { bar.innerHTML = `<span>${esc(idle)}</span><span class="right">${esc(ARCHIVE_PATH)} · ${ARCHIVE_FOLDER_COUNT}</span>`; return; }
  const st = S.status;
  const ico = st.kind === 'ok' ? `<span class="ok">${ICON.check}</span>` : st.kind === 'err' ? `<span style="color:var(--danger)">${ICON.errorCircle}</span>` : '';
  const link = st.link ? `<span>·</span><button type="button" class="link" id="statusLink" data-act="${st.link.act}">${esc(st.link.label)}</button>` : '';
  bar.innerHTML = `${ico}<span class="msg${st.kind === 'err' ? ' err' : ''}">${st.html}</span>${link}<span class="right">${esc(idle)}</span>`;
  if (flash) { bar.classList.remove('flash'); void bar.offsetWidth; bar.classList.add('flash'); }
}

/* ---------------------------------------------------------------- render: all */
function render() {
  validateSelection();
  renderSidebar();
  renderToolbar();
  renderPreview();
  renderPanel();
  renderStatus();
  if (S.settings) renderSettings();
  if (S.hs) renderHistory();
  updateSegs();
}
/* Keeps the selection on a visible row; falls back to the first unfiled file, or none ("All filed"). */
function validateSelection() {
  const rows = navRows();
  if (S.sel && rows.some((r) => r.key === S.sel)) return;
  if (S.sel && S.sel.startsWith('f:')) {
    const f = fileById(S.sel.slice(2));
    if (f && isVisibleFile(f) && f.group && !S.sectionsCollapsed[f.inbox]) { S.groupsOpen[groupKey(f.inbox, f.group)] = true; return; }
  }
  const keys = new Set(rows.map((r) => r.key));
  const first = unfiledOrder().find((f) => keys.has('f:' + f.id) || (f.group && !S.sectionsCollapsed[f.inbox]));
  setSelection(first ? 'f:' + first.id : null, { silent: true });
}

/* ---------------------------------------------------------------- selection and filing state */
/* Fresh panel state for the selected file. A filed file starts with its current folder chosen (its siblings listed
   around it) and its current name in the name field. */
function resetFiling() {
  S.query = ''; S.scope = null; S.hl = 0; S.chosen = null; S.chosenQuery = ''; S.chosenScope = null;
  S.newFolder = null; S.pending = []; S.moveError = null; S.nameNotice = null; S.namePick = null; S.contentsShown = null;
  hideNameHint();
  S.zoom = 'fit';
  if (S.mode === 'fail') S.failArmed = true;
  const f = S.sel && S.sel.startsWith('f:') ? fileById(S.sel.slice(2)) : null;
  $('destInput').value = '';
  $('nameInput').value = f && f.status !== 'trashed' ? stemOf(f) : '';
  if (isMoved(f)) {
    S.scope = parentOf(f.location.folder) || null;
    S.chosenScope = S.scope;
    S.chosen = f.location.folder;
    const i = selectable(computeResults()).findIndex((x) => x.type === 'folder' && x.path === S.chosen);
    S.hl = Math.max(0, i);
  }
}
function setSelection(key, opts = {}) {
  const changed = key !== S.sel;
  S.sel = key;
  if (changed || opts.reset) resetFiling();
  if (opts.silent) return;
  render();
  scrollSelIntoView();
}
function moveSelection(delta) {
  const rows = navRows();
  if (!rows.length) return;
  let i = rows.findIndex((r) => r.key === S.sel);
  if (i < 0) i = delta > 0 ? -1 : rows.length;
  const ni = Math.max(0, Math.min(rows.length - 1, i + delta));
  setSelection(rows[ni].key);
}
function revealFile(f) {
  openGroupFor(f);
  S.sectionsCollapsed[f.inbox] = false;
}
/* Index in visual order where a search for the next/previous file starts. */
function visualIndex(order) {
  const f = selectedFile();
  if (f) return order.indexOf(f);
  const g = selectedGroup();
  return g ? order.indexOf(g.files[0]) - 1 : -1;
}
function selectNextUnfiled(dir) {
  const order = visualFiles();
  const idx = visualIndex(order);
  const range = dir > 0 ? order.slice(idx + 1) : order.slice(0, Math.max(0, idx)).reverse();
  const next = range.find((f) => f.status === 'inbox');
  if (!next) { setStatus('No more unfiled files in that direction.'); return; }
  revealFile(next);
  setSelection('f:' + next.id);
}
function openGroupFor(f) { if (f.group) S.groupsOpen[groupKey(f.inbox, f.group)] = true; }
/* After a move or trash: the next unfiled row below, skipping filed and trashed rows and wrapping into the next
   section (and from the last section to the top). None left: no selection, and the preview shows "All filed". */
function advanceAfter(f) {
  const order = visualFiles();
  const idx = order.indexOf(f);
  const unfiled = (x) => x.status === 'inbox' && x !== f;
  const next = order.slice(idx + 1).find(unfiled) || order.slice(0, Math.max(0, idx)).find(unfiled);
  if (next) { revealFile(next); S.sel = 'f:' + next.id; } else S.sel = null;
  resetFiling();
}

/* ---------------------------------------------------------------- focus */
const STOP_IDS = { sidebar: 'sidebarList', preview: 'pvScroll', dest: 'destInput', name: 'nameInput' };
function stopOf(el) {
  if (!el) return 'none';
  if (el.id === 'sidebarList') return 'sidebar';
  if (el.id === 'pvScroll') return 'preview';
  if (el.id === 'destInput' || el.id === 'newFolderInput') return 'dest';
  if (el.id === 'nameInput') return 'name';
  return 'other';
}
function focusStop(stop, opts = {}) {
  const el = $(STOP_IDS[stop]);
  if (!el || el.disabled) { $('sidebarList').focus({ preventScroll: true }); return; }
  el.focus({ preventScroll: true });
  if (opts.selectAll && el.select) el.select();
  if (opts.caretEnd && el.setSelectionRange) el.setSelectionRange(el.value.length, el.value.length);
}
const focusName = () => focusStop('name', { selectAll: true });
document.addEventListener('focusin', onFocusChange);
document.addEventListener('focusout', () => setTimeout(onFocusChange, 0));
function onFocusChange() {
  const a = document.activeElement;
  const win = $('win');
  const inWin = win.contains(a);
  const stop = inWin ? stopOf(a) : 'none';
  if (stop !== S.focus) {
    S.focus = stop;
    if (['sidebar', 'preview', 'dest', 'name'].includes(stop)) S.lastStop = stop;
    win.dataset.focus = stop;
  }
  win.classList.toggle('inactive', !inWin && !(S.menu));
  $('settingsWin').classList.toggle('inactive', !$('settingsWin').contains(a));
  $('histWin').classList.toggle('inactive', !$('histWin').contains(a));
}

/* ---------------------------------------------------------------- commands: choosing a destination */
function startFiling() {
  const g = selectedGroup();
  if (g) { toggleGroup(S.sel, !S.groupsOpen[S.sel]); return; }
  chooseDestination();
}
/* Focus the destination filter (⌘L, Tab or Return from the sidebar). With `text`, typing in the sidebar continues
   in the filter. */
function chooseDestination(text = null) {
  const f = selectedFile();
  if (!f || isFirstLaunch() || !filingActive()) return;
  if (archiveUnavailable()) { setStatus('Destination search needs the archive folder. Use Locate… in the filing panel.'); return; }
  if (S.panelHidden) { S.panelHidden = false; render(); }
  if (S.newFolder) cancelNewFolder({ refocus: false });
  if (text === null) { focusStop('dest', { selectAll: true }); return; }
  if (S.chosen) unchoose();
  S.query += text;
  S.hl = 0;
  $('destInput').value = S.query;
  renderPanel();
  focusStop('dest', { caretEnd: true });
}
function chooseHighlighted() {
  const h = highlighted();
  if (!h) return;
  if (h.type === 'create') { createFolderFromQuery(); return; }
  chooseFolder(h.path);
}
function chooseFolder(path) {
  S.chosenQuery = S.query; S.chosenScope = S.scope;
  S.chosen = path;
  $('destInput').value = '';
  render();
  focusName();
}
function unchoose(restore = true) {
  if (!S.chosen) return;
  const was = S.chosen;
  S.chosen = null;
  if (restore) {
    S.query = S.chosenQuery; S.scope = S.chosenScope;
    $('destInput').value = S.query;
    const sel = selectable(computeResults());
    const i = sel.findIndex((x) => x.type === 'folder' && x.path === was);
    S.hl = i >= 0 ? i : 0;
  }
}
function clearDestination() {
  S.chosen = null; S.query = ''; S.scope = null; S.hl = 0; $('destInput').value = '';
  renderPanel();
}
function setHighlight(i) {
  const sel = selectable(computeResults());
  if (!sel.length) return;
  S.hl = Math.max(0, Math.min(sel.length - 1, i));
  renderResults(); renderContents(); updateNameExtras();
}
/* Show `scope`'s subfolders (null: the archive root) and highlight `hlPath` if it is listed. */
function setScope(scope, hlPath = null) {
  if (S.chosen) unchoose(false);
  S.scope = scope || null; S.query = ''; $('destInput').value = '';
  const sel = selectable(computeResults());
  const i = hlPath ? sel.findIndex((x) => x.type === 'folder' && x.path === hlPath && !x.self) : -1;
  S.hl = Math.max(0, i);
  renderPanel();
}
/* → : into the highlighted (or chosen) folder, with or without subfolders; the list shows the folder itself as its
   first row, highlighted, then its subfolders. */
function stepIn() {
  if (S.chosen) unchoose();
  const h = highlighted();
  if (!h || h.type !== 'folder' || h.self) { renderPanel(); return; }
  setScope(h.path);
}
/* ← : out to the parent of the current folder, highlighting the folder we came from (not the parent's own
   "this folder" row). At the root, a nested result steps out to the folder that contains it. */
function stepOut() {
  if (S.chosen) unchoose();
  if (S.scope) { const from = S.scope; setScope(parentOf(from), from); return; }
  const h = highlighted();
  if (h && h.type === 'folder' && h.path.includes('/')) setScope(parentOf(h.path), h.path);
  else renderPanel();
}

/* ---------------------------------------------------------------- commands: new folder */
function newFolderCmd() {
  if (!filingActive() || archiveUnavailable()) return;
  if (S.panelHidden) { S.panelHidden = false; render(); }
  if (S.newFolder) { const inp = $('newFolderInput'); if (inp) inp.focus(); return; }
  const h = S.chosen ? null : highlighted();
  if (h && h.type === 'create') { createFolderFromQuery(); return; }
  const parent = newFolderParent();
  const prev = { query: S.query, scope: S.scope, hl: S.hl, chosen: S.chosen, chosenQuery: S.chosenQuery, chosenScope: S.chosenScope };
  S.chosen = null; S.scope = parent || null; S.query = ''; $('destInput').value = '';
  S.newFolder = { parent, value: '', prev, focus: true };
  renderPanel();
}
function cancelNewFolder(opts = {}) {
  if (!S.newFolder) return;
  const p = S.newFolder.prev;
  S.newFolder = null;
  Object.assign(S, { query: p.query, scope: p.scope, hl: p.hl, chosen: p.chosen, chosenQuery: p.chosenQuery, chosenScope: p.chosenScope });
  $('destInput').value = p.chosen ? '' : p.query;
  renderPanel();
  if (opts.refocus !== false) focusStop('dest', { caretEnd: true });
}
/* Tab or Return in the new-folder row. A same-name sibling is chosen instead of creating a duplicate. */
function confirmNewFolder() {
  const t = newFolderTarget();
  if (!t) { cancelNewFolder(); return false; }
  const parent = S.newFolder.parent;
  S.newFolder = null;
  S.scope = parent || null; S.query = '';
  if (t.existing) { chooseFolder(t.existing); setStatus(`Chose the existing folder <b>${esc(t.existing)}</b>.`, { ms: 4000 }); return true; }
  if (!isPending(t.path)) S.pending.push(t.path);
  chooseFolder(t.path);
  return true;
}
function createFolderFromQuery() {
  const q = S.query.trim().replace(/\/+/g, '/').replace(/^\/|\/$/g, '');
  if (!q) return;
  const parent = createParent();
  const path = (parent ? parent + '/' : '') + q;
  const existing = folderExistingCI(path);
  if (existing) { chooseFolder(existing); return; }
  if (!isPending(path)) S.pending.push(path);
  chooseFolder(path);
}

/* ---------------------------------------------------------------- commands: the name */
function onNameInput() {
  S.nameNotice = null;
  hideNameHint();
  renderContents();
  updateNameExtras();
}
function onNewFolderInput() {
  S.newFolder.value = $('newFolderInput').value;
  repositionNewRow();
  updateNewFolderNote();
}
function setName(stem) {
  const inp = $('nameInput');
  inp.value = stem;
  inp.focus({ preventScroll: true });
  inp.select();
  onNameInput();
}
/* ↺ and ⇧⌘R: back to the name the file had in its inbox. */
function revertName() {
  const f = selectedFile();
  if (!f || !filingActive()) return;
  setName(originalStem(f));
}
/* ⌥↑ / ⌥↓ and clicks in Folder contents: take an existing name. The first ⌥↑ or ⌥↓ takes the bottom (newest) one. */
function takeName(dir) {
  const f = selectedFile();
  const folder = contentsFolder();
  if (!f || !folder || isPending(folder) || !filingActive()) return;
  const names = folderFiles(folder, f).filter((x) => !x.self).map((x) => x.name);
  if (!names.length) return;
  let i = S.namePick && S.namePick.folder === folder ? names.indexOf(S.namePick.name) : -1;
  i = i < 0 ? names.length - 1 : Math.max(0, Math.min(names.length - 1, i + dir));
  pickName(folder, names[i]);
}
function pickName(folder, name) {
  const f = selectedFile();
  S.namePick = { folder, name };
  const ext = (name.match(/\.[^.]+$/) || [''])[0];
  setName(ext && ext.toLowerCase() === f.ext.toLowerCase() ? name.slice(0, -ext.length) : name.replace(/\.[^.]+$/, ''));
}
/* Return in the name field: a toast floats just below the field for about two seconds. It overlays what is below
   and takes no layout space, so nothing shifts. */
function showNameHint() {
  const f = selectedFile();
  const toast = $('nameHint');
  toast.textContent = f && changeKind(f) === 'rename' ? 'Press ⌘Return to rename' : 'Press ⌘Return to move';
  toast.classList.add('show');
  clearTimeout(S.nameHintTimer);
  S.nameHintTimer = setTimeout(hideNameHint, 2000);
}
function hideNameHint() { clearTimeout(S.nameHintTimer); $('nameHint').classList.remove('show'); }
function flashNameNotice(text) {
  S.nameNotice = text;
  updateNameNotice();
  clearTimeout(flashNameNotice.t);
  flashNameNotice.t = setTimeout(() => { S.nameNotice = null; updateNameNotice(); }, 3500);
}

/* ---------------------------------------------------------------- commands: move, rename, trash, undo */
function doMove() {
  const f = selectedFile();
  if (!f || !filingActive()) return;
  if (archiveUnavailable()) { setStatus('Move is unavailable while the archive folder is missing.', { kind: 'err' }); return; }
  if (f.downloading) { setStatus(`“${esc(f.origName)}” is still downloading.`, { kind: 'err' }); return; }
  if (S.newFolder && !confirmNewFolder()) return;
  const t = filingTarget();
  if (!t) { focusStop('dest'); setStatus('Choose a destination folder first.'); return; }
  const stem = effectiveStem(f);
  if (/[:/]/.test(stem)) { flashNameNotice('Names can’t contain “:” or “/”.'); return; }
  if (changeKind(f, t) === 'none') { setStatus('Nothing to change: the file already has this folder and name.', { ms: 4000 }); return; }
  const conflict = findConflict(t.dest, t.full, f);
  if (conflict) { openSheet({ id: f.id, dest: t.dest, stem, full: t.full, conflict }); return; }
  performMove(f, t.dest, t.full, null);
}
function performMove(f, dest, full, replaced) {
  const inbox = inboxOf(f);
  const wasFiled = isMoved(f);
  if (S.mode === 'fail' && S.failArmed) {
    S.failArmed = false;
    S.moveError = { name: displayName(f), reason: `You don’t have permission to write to “${lastSeg(dest)}”, or the volume is full.`, inbox: wasFiled ? f.location.folder : inbox.name, retry: { dest, full, replaced } };
    renderPanel();
    setStatus(`Couldn’t move “${esc(displayName(f))}”.`, { kind: 'err' });
    $('retryBtn') && $('retryBtn').focus();
    return;
  }
  const before = snapshot(f);
  const kind = wasFiled && dest === f.location.folder ? 'rename' : 'move';
  const prevName = wasFiled ? before.location.name : f.origName;
  const created = isPending(dest) ? addFolderPath(dest) : [];
  if (replaced) (S.removed[dest] = S.removed[dest] || new Set()).add(replaced);
  // replacing a file this session moved there: send that one to the Trash too
  const replacedFile = replaced ? S.files.find((x) => x !== f && x.status === 'moved' && x.location.folder === dest && x.location.name === replaced) : null;
  const replacedBefore = replacedFile ? snapshot(replacedFile) : null;
  if (replacedFile) placeFile(replacedFile, { status: 'trashed', location: { trash: true, name: replaced } });
  const after = { status: 'moved', location: { folder: dest, name: full } };
  placeFile(f, after);
  if (kind === 'move') S.recent = [dest].concat(S.recent.filter((p) => p !== dest)).slice(0, MAX_RECENT);
  const verb = replaced ? 'Replace' : kind === 'rename' ? 'Rename' : 'Move';
  S.undo.push({ type: kind, id: f.id, before, after, created, replaced, replacedFile: replacedFile && replacedFile.id, replacedBefore, label: `${verb} of “${shortName(prevName)}”` });
  S.redo = [];
  S.pending = [];
  addHistory({ kind, inbox: inbox.name, orig: prevName, newName: full, dest, fileId: f.id });
  const newTxt = created.length ? ' (new folder)' : '';
  const msg = replaced
    ? `Replaced “${esc(full)}” in ${esc(dest)}. The old file is in the Trash.`
    : kind === 'rename' ? `Renamed to <b>${esc(full)}</b> in ${esc(dest)}`
      : `Moved to <b>${esc(dest)}</b>${newTxt} as <b>${esc(full)}</b>`;
  if (wasFiled) resetFiling(); else advanceAfter(f);
  render();
  scrollSelIntoView();
  focusStop('sidebar');
  setStatus(msg, { kind: 'ok', link: { act: 'undo', label: 'Undo ⌘Z' } });
}
function retryMove() {
  const f = selectedFile();
  if (!f || !S.moveError) return;
  const r = S.moveError.retry;
  S.moveError = null;
  if (r.trash) { doTrash(); return; }
  performMove(f, r.dest, r.full, r.replaced);
}
function doTrash() {
  const f = selectedFile();
  if (!f || f.status === 'trashed') return;
  const inbox = inboxOf(f);
  if (S.mode === 'fail' && S.failArmed && !isFiled(f)) {
    S.failArmed = false;
    S.moveError = { name: displayName(f), reason: 'The Trash isn’t available on this volume.', inbox: inbox.name, retry: { trash: true } };
    renderPanel(); setStatus(`Couldn’t move “${esc(displayName(f))}” to the Trash.`, { kind: 'err' });
    return;
  }
  const before = snapshot(f);
  const name = displayName(f);
  const after = { status: 'trashed', location: { trash: true, name } };
  const wasFiled = isFiled(f);
  placeFile(f, after);
  S.undo.push({ type: 'trash', id: f.id, before, after, label: `Move to Trash of “${shortName(name)}”` });
  S.redo = [];
  addHistory({ kind: 'trash', inbox: inbox.name, orig: name, newName: '—', dest: 'Trash', fileId: f.id });
  if (!wasFiled) advanceAfter(f); else resetFiling();
  render(); scrollSelIntoView();
  if (S.focus !== 'sidebar') focusStop('sidebar');
  setStatus(`Moved “${esc(name)}” to the Trash`, { kind: 'ok', link: { act: 'undo', label: 'Undo ⌘Z' } });
}
/* ⌥⌘Z, the panel's status strip, the context menu and History: return one filed (or trashed) file to its inbox. */
function moveBack(f = selectedFile(), opts = {}) {
  if (!f || !isFiled(f)) { if (!opts.quiet) setStatus('Move Back works on a filed or trashed file.'); return; }
  const inbox = inboxOf(f);
  const before = snapshot(f);
  const after = { status: 'inbox', location: null };
  const trashed = f.status === 'trashed';
  const fromName = before.location.name;
  placeFile(f, after);
  S.undo.push({ type: 'back', id: f.id, before, after, label: `${trashed ? 'Put Back' : 'Move Back'} of “${shortName(f.origName)}”` });
  S.redo = [];
  addHistory({ kind: 'back', inbox: inbox.name, orig: fromName, newName: f.origName, dest: trashed ? 'Trash' : before.location.folder, fileId: f.id });
  revealFile(f);
  S.sel = 'f:' + f.id; resetFiling();
  render(); scrollSelIntoView();
  if (!opts.fromHistory) focusStop('sidebar');
  setStatus(`${trashed ? 'Put back' : 'Moved back'} “${esc(f.origName)}” to ${esc(inbox.name)}${f.group ? ' › ' + esc(f.group) : ''}`, { kind: 'ok', link: { act: 'undo', label: 'Undo ⌘Z' } });
}
const placesFiles = (a) => a.type === 'move' || a.type === 'rename';
function undo() {
  const a = S.undo.pop();
  if (!a) { setStatus('Nothing to undo.'); return; }
  const f = fileById(a.id);
  placeFile(f, a.before);
  if (placesFiles(a)) {
    if (a.replaced) S.removed[a.after.location.folder].delete(a.replaced);
    if (a.replacedFile) placeFile(fileById(a.replacedFile), a.replacedBefore);
    for (const p of a.created.slice().reverse()) removeFolderIfEmpty(p);
  }
  S.redo.push(a);
  revealFile(f);
  S.sel = 'f:' + f.id; resetFiling();
  render(); scrollSelIntoView(); focusStop('sidebar');
  setStatus(`Undid ${esc(a.label)}`, { link: { act: 'redo', label: 'Redo ⇧⌘Z' } });
}
function redo() {
  const a = S.redo.pop();
  if (!a) { setStatus('Nothing to redo.'); return; }
  const f = fileById(a.id);
  if (placesFiles(a)) {
    for (const p of a.created) addFolderPath(p);
    if (a.replaced) (S.removed[a.after.location.folder] = S.removed[a.after.location.folder] || new Set()).add(a.replaced);
    if (a.replacedFile) placeFile(fileById(a.replacedFile), { status: 'trashed', location: { trash: true, name: a.replaced } });
  }
  placeFile(f, a.after);
  S.undo.push(a);
  if (a.type !== 'back' && a.before.status === 'inbox') advanceAfter(f);
  else { revealFile(f); S.sel = 'f:' + f.id; resetFiling(); }
  render(); scrollSelIntoView(); focusStop('sidebar');
  setStatus(`Redid ${esc(a.label)}`, { link: { act: 'undo', label: 'Undo ⌘Z' } });
}

/* ---------------------------------------------------------------- commands: other */
function openCmd() {
  const f = selectedFile();
  if (!f) return;
  if (f.downloading) { setStatus('The file is still downloading.'); return; }
  const app = f.app || 'Preview';
  const where = f.status === 'moved' ? ` from ${esc(f.location.folder)}` : f.status === 'trashed' ? ' from the Trash' : '';
  setStatus(`Opened “${esc(displayName(f))}”${where} in ${app}`, { ms: 5000 });
}
function revealCmd() {
  const f = selectedFile();
  if (!f) return;
  const inbox = inboxOf(f);
  const where = f.status === 'moved' ? `${ARCHIVE_PATH}/${f.location.folder}` : f.status === 'trashed' ? 'the Trash' : inbox.path + (f.group ? '/' + f.group : '');
  setStatus(`Revealed “${esc(displayName(f))}” in Finder (${esc(where)})`, { ms: 5000 });
}
function toggleGroup(key, open) {
  S.groupsOpen[key] = open;
  if (!open && S.sel && S.sel.startsWith('f:')) {
    const f = fileById(S.sel.slice(2));
    if (f && f.group && groupKey(f.inbox, f.group) === key) setSelection(key, { silent: true });
  }
  render(); scrollSelIntoView();
}
function jumpInbox(n) {
  const inbox = S.inboxes[n - 1];
  if (!inbox || isFirstLaunch()) return;
  S.sectionsCollapsed[inbox.id] = false;
  const items = inboxItems(inbox);
  if (items.length) {
    const it = items[0];
    setSelection(it.type === 'file' ? 'f:' + it.file.id : groupKey(it.inbox, it.name));
  } else { render(); setStatus(`${esc(inbox.name)} has no files.`); }
  focusStop('sidebar');
}
function zoom(kind) {
  if (kind === 'fit') S.zoom = 'fit';
  else {
    const z = effectiveZoom();
    S.zoom = Math.max(0.25, Math.min(4, kind === 'in' ? z * 1.25 : z / 1.25));
  }
  applyZoom(); updatePageIndicator();
  if (S.ql) applyQLZoom();
}
function toggleSidebar() { S.sidebarHidden = !S.sidebarHidden; if (S.sidebarHidden && S.focus === 'sidebar') focusStop('preview'); render(); applyZoom(); }
function togglePanel() { S.panelHidden = !S.panelHidden; if (S.panelHidden && (S.focus === 'dest' || S.focus === 'name')) focusStop('sidebar'); render(); applyZoom(); }
function refreshCmd() { S.indexing = true; render(); setTimeout(() => { S.indexing = false; resultsCache.key = ''; renderPanel(); }, 500); setStatus(`Rescanned inboxes and archive · ${ARCHIVE_FOLDER_COUNT}`, { ms: 4000 }); }
/* Live folder watching. Changes made outside docsort are applied as they come: an arrival is inserted at its date
   position and keeps an accent dot until first selected; the selection and the rows on screen do not move. */
function simulateArrival() {
  if (isFirstLaunch() || !S.inboxes.some((i) => i.id === DOWNLOADS.id)) { setStatus(`${DOWNLOADS.name} is not one of the inboxes right now.`); return; }
  const t = ARRIVALS[S.arrivals % ARRIVALS.length];
  const round = Math.floor(S.arrivals / ARRIVALS.length);
  S.arrivals++;
  const name = round ? t.name.replace(/\.pdf$/, ` (${round + 1}).pdf`) : t.name;
  const f = mkFile('dl-new-' + S.arrivals, DOWNLOADS.id, name, '.pdf', `${TODAY}T10:${String(20 + S.arrivals).padStart(2, '0')}`, { size: '88 KB', kindLabel: 'PDF document', preview: 'generic', pages: 1, doc: t.doc, arrival: true, flash: true, unseen: true });
  keepSidebarAnchor(() => { S.files.push(f); render(); });
  setStatus(`New file in ${esc(inboxOf(f).name)}: “${esc(name)}”`, { ms: 5000 });
  setTimeout(() => { f.flash = false; keepSidebarAnchor(renderSidebar); }, 2400);
}
/* A scanner job that writes its own subfolder: the group row appears at the folder's date position. */
function simulateScanFolder() {
  const scans = S.inboxes.find((i) => i.id === SCANNER.id);
  if (isFirstLaunch() || !scans || inboxBlocked(scans)) { setStatus(`${SCANNER.name} is not reachable right now.`); return; }
  S.scanFolders++;
  const n = S.scanFolders;
  const group = n > 1 ? `${SCAN_FOLDER_ARRIVAL.group} ${n}` : SCAN_FOLDER_ARRIVAL.group;
  const files = SCAN_FOLDER_ARRIVAL.files.map((t, i) => mkFile(`sc-new-${n}-${i}`, SCANNER.id, t.name, '.pdf', `${TODAY}T10:${String(40 + n * 2 + i).padStart(2, '0')}`,
    { group, size: '190 KB', kindLabel: 'PDF document', preview: 'generic', pages: 1, doc: t.doc, arrival: true, flash: true, unseen: true }));
  keepSidebarAnchor(() => { S.files.push(...files); render(); });
  setStatus(`New folder in ${esc(scans.name)}: “${esc(group)}” with ${files.length} files`, { ms: 5000 });
  setTimeout(() => { for (const f of files) f.flash = false; keepSidebarAnchor(renderSidebar); }, 2400);
}
/* "Simulate removal in Finder": the selected unfiled file (else the first unfiled one in the scanner inbox) is moved away by
   someone else. Its row disappears; if it was selected, the selection moves to the next unfiled file below, as after
   a move, and anything typed in the filing panel for it is discarded. */
function simulateRemoval() {
  const sel = selectedFile();
  const target = sel && sel.status === 'inbox' ? sel : visualFiles().find((f) => f.inbox === SCANNER.id && f.status === 'inbox');
  if (!target) { setStatus(`Nothing to remove: select an unfiled file, or keep one in ${SCANNER.name}.`); return; }
  const inbox = inboxOf(target);
  const wasSelected = target === sel;
  if (S.sheet && S.sheet.id === target.id) closeSheet();
  const apply = () => {
    if (wasSelected) advanceAfter(target);
    target.removedOutside = true;
    S.undo = S.undo.filter((a) => a.id !== target.id && a.replacedFile !== target.id);
    S.redo = S.redo.filter((a) => a.id !== target.id && a.replacedFile !== target.id);
    render();
  };
  if (wasSelected) { apply(); scrollSelIntoView(); } else keepSidebarAnchor(apply);
  if (S.ql) renderQL();
  setStatus(`‘${esc(target.origName)}’ was removed from ${esc(inbox.name)} outside docsort.`, { ms: 8000 });
}
function grantAccess() {
  S.linkedGranted = true;
  render();
  setStatus(`docsort can now open ${LINKED_INBOX.name} (${LINKED_INBOX.path}).`, { kind: 'ok', ms: 5000 });
  focusStop('sidebar');
}

/* ---------------------------------------------------------------- sheet */
function openSheet(ctx) {
  S.sheet = ctx;
  $('sheetTitle').textContent = `An item named “${ctx.conflict}” already exists in this location.`;
  $('sheetText').textContent = `Do you want to replace it with the one you’re moving? Replace moves the existing file in “${ctx.dest}” to the Trash; you can undo it.`;
  $('sheetWrap').hidden = false;
  $('sheetKeepBoth').focus();
}
function closeSheet() { S.sheet = null; $('sheetWrap').hidden = true; }
function sheetKeepBoth() {
  const ctx = S.sheet; closeSheet();
  const f = fileById(ctx.id);
  let n = 2, name;
  do { name = `${ctx.stem} ${n}${f.ext}`; n++; } while (findConflict(ctx.dest, name, f));
  performMove(f, ctx.dest, name, null);
}
function sheetReplace() {
  const ctx = S.sheet; closeSheet();
  performMove(fileById(ctx.id), ctx.dest, ctx.full, ctx.conflict);
}
function sheetCancel() { closeSheet(); focusStop('name'); }

/* ---------------------------------------------------------------- Quick Look */
function openQL() {
  const f = selectedFile();
  if (!f) return;
  S.ql = true; $('qlWrap').hidden = false; renderQL(); $('ql').focus({ preventScroll: true });
}
function renderQL() {
  const f = selectedFile();
  if (!f) { closeQL(); return; }
  $('qlTitle').textContent = displayName(f);
  $('qlClose').innerHTML = ICON.x;
  $('qlOpen').textContent = `Open with ${f.app || 'Preview'}`;
  $('qlOpen').hidden = !!f.downloading;
  const c = previewContent(f, true);
  const body = $('qlBody');
  body.innerHTML = c.center ? `<div class="pv-center">${c.html}</div>` : `<div class="pv-pages" id="qlPages" data-image="${c.image ? 1 : ''}">${c.html}</div>`;
  applyQLZoom();
}
function applyQLZoom() {
  const p = $('qlPages');
  if (!p) return;
  p.style.setProperty('--qlz', 1);
  const body = $('qlBody');
  const z = fitZoom(body, p) * (S.zoom === 'fit' ? 1 : S.zoom / effectiveZoom());
  p.style.setProperty('--qlz', z.toFixed(3));
}
function closeQL() { S.ql = false; $('qlWrap').hidden = true; focusStop('sidebar'); }

/* ---------------------------------------------------------------- shortcuts overlay */
const KEYMAP = [
  ['The rule', [
    ['⌘Return', 'Move (or Rename) the selected file. The only key that files.'], ['Tab / Return', 'Next step: sidebar → destination → name. Never files.'],
    ['⇧Tab', 'Back one step, keeping what you entered'], ['Esc', 'Clear the current field; when it is empty, back one step'],
  ]],
  ['Anywhere in the main window', [
    ['⌘Return', 'Move with the chosen destination and name', 'File › Move'], ['⌘L', 'Focus the destination filter (also ⌃L)', 'File › Choose Destination…'],
    ['⌘O', 'Open in default app', 'File › Open'], ['⌥⌘R', 'Reveal in Finder', 'File › Reveal in Finder'], ['⌘⌫', 'Move to Trash', 'File › Move to Trash (not while editing text)'],
    ['⌘Z / ⇧⌘Z', 'Undo / Redo (moves, renames, new folders, trash)', 'Edit'], ['⌥⌘Z', 'Move a filed file back to its inbox', 'File › Move Back to Inbox'],
    ['⌘Y', 'History (also ⌃Y, or the History row at the bottom of the sidebar)', 'Window › History'], ['⌘R', 'Rescan inboxes and archive', 'View › Refresh'],
    ['⌃⌘S', 'Show/hide sidebar', 'View'], ['⌥⌘I', 'Show/hide filing panel', 'View'], ['⌘1 … ⌘9', 'Jump to inbox section (also ⌃1 …)', 'Go'],
    ['⌥⌘↓ / ⌥⌘↑', 'Next / previous unfiled file', 'Go'], ['⌘+ / ⌘− / ⌘0', 'Zoom preview in / out / to fit', 'View'], ['⌘,', 'Settings', 'docsort'],
    ['⌘/', 'This overlay', 'Help'],
  ]],
  ['Sidebar focused', [['↑ / ↓', 'Previous / next file; preview follows'], ['→ / ←', 'Expand / collapse a subfolder group'], ['type', 'Start the destination filter with that text'], ['Tab / Return', 'Go to the destination picker'], ['Space', 'Quick Look'], ['PgUp / PgDn', 'Scroll the preview (fn↑ / fn↓)']]],
  ['Destination picker focused', [['type', 'Fuzzy filter; inside a folder, its subtree. Empty shows Recent.'], ['↑ / ↓', 'Move highlight'], ['→ / ←', 'Into the highlighted folder, whose first row is the folder itself / out to its parent (also ⌘↓ / ⌘↑)'], ['⌫', 'In an empty filter: step out'], ['Tab / Return', 'Choose highlighted folder, go to name'], ['⇧⌘N', 'New folder inside highlighted folder (also ⌃⇧N)'], ['⌘Return', 'Move now with the pre-filled name'], ['Esc', 'Clear filter; when empty, back to sidebar'], ['⇧Tab', 'Back to sidebar']]],
  ['New folder row', [['type', 'Folder name; a slash makes nested folders'], ['Tab / Return', 'Confirm: becomes the destination, focus to name'], ['Esc', 'Cancel']]],
  ['Name field focused', [['type', 'Edit name; extension is fixed'], ['⌥↑ / ⌥↓', 'Take the previous / next name from Folder contents'], ['⇧⌘R', 'Revert to the original name (also ⌃⇧R)'], ['⌘Return', 'Move (Rename for a filed file)'], ['Return', 'Shows the toast “Press ⌘Return to move”; does not file'], ['⇧Tab', 'Back to destination'], ['Esc', 'Back to destination']]],
  ['History window', [['↑ / ↓', 'Select entry'], ['⌘F', 'Search'], ['⌘O / ⌥⌘R', 'Open / Reveal in Finder'], ['⌥⌘Z', 'Move Back (Put Back for a trashed file)'], ['Esc', 'Clear search, then close']]],
  ['Sheets and alerts', [['Return', 'Default button (Keep Both)'], ['Esc', 'Cancel'], ['Tab, Space', 'Reach and press Replace'], ['⌘R', 'Replace (in the sheet)']]],
];
function renderKbd() {
  $('kbdOverlay').innerHTML = `<header><h3 id="kbdTitle">Keyboard shortcuts</h3><span class="note">In the browser some ⌘ shortcuts may be taken by the browser (⌘W, ⌘T, ⌘N, ⌘L, ⌘Y, ⌘1…⌘9, ⇧⌘N, ⇧⌘R, ⌥⌘I). Fallbacks: ⌃L, ⌃Y, ⌃1…⌃9, ⌃⇧N, ⌃⇧R; every command is also in the menu bar above the window.</span><button type="button" class="btn" id="kbdClose">Done</button></header>`
    + `<div class="cols">${KEYMAP.map(([title, rows]) => `<section><h4>${title}</h4>${rows.map(([k, w, m]) => `<div class="kr"><span class="keys">${k}</span><span class="what">${w}${m ? `<small>${m}</small>` : ''}</span></div>`).join('')}</section>`).join('')}</div>`;
}
function openKbd() { S.kbd = true; renderKbd(); $('kbdWrap').hidden = false; $('kbdOverlay').focus({ preventScroll: true }); }
function closeKbd() { S.kbd = false; $('kbdWrap').hidden = true; focusStop(S.lastStop); }

/* ---------------------------------------------------------------- menus (menu bar and context menu) */
const CMD = {
  about: { label: 'About docsort', run: () => setStatus('docsort · UX mockup of the main window'), on: () => true },
  settings: { label: 'Settings…', keys: '⌘,', run: () => openSettings(), on: () => true },
  quit: { label: 'Quit docsort', keys: '⌘Q', run: () => {}, on: () => false },
  chooseDest: { label: 'Choose Destination…', keys: '⌘L', run: () => chooseDestination(), on: () => filingActive() && !archiveUnavailable() },
  move: { label: () => { const f = selectedFile(); return f && changeKind(f) === 'rename' ? 'Rename' : 'Move'; }, keys: '⌘↩', run: doMove, on: canMove },
  newFolder: { label: 'New Folder…', keys: '⇧⌘N', run: newFolderCmd, on: () => filingActive() && !archiveUnavailable() },
  open: { label: 'Open', keys: '⌘O', run: openCmd, on: () => !!selectedFile() && !selectedFile().downloading },
  reveal: { label: 'Reveal in Finder', keys: '⌥⌘R', run: revealCmd, on: () => !!selectedFile() },
  quicklook: { label: 'Quick Look', keys: 'Space', run: openQL, on: () => !!selectedFile() },
  trash: { label: 'Move to Trash', keys: '⌘⌫', run: doTrash, on: () => !!selectedFile() && selectedFile().status !== 'trashed' },
  moveBack: { label: () => (selectedFile() && selectedFile().status === 'trashed' ? 'Put Back' : 'Move Back to Inbox'), keys: '⌥⌘Z', run: () => moveBack(), on: () => isFiled(selectedFile()) },
  revert: { label: 'Revert to Original Name', keys: '⇧⌘R', run: revertName, on: () => { const f = selectedFile(); return !!f && filingActive() && effectiveStem(f) !== originalStem(f); } },
  history: { label: 'History', keys: '⌘Y', run: () => openHistory(), on: () => true },
  undo: { label: () => (S.undo.length ? `Undo ${S.undo[S.undo.length - 1].label}` : 'Undo'), keys: '⌘Z', run: undo, on: () => S.undo.length > 0 },
  redo: { label: () => (S.redo.length ? `Redo ${S.redo[S.redo.length - 1].label}` : 'Redo'), keys: '⇧⌘Z', run: redo, on: () => S.redo.length > 0 },
  sidebar: { label: () => (S.sidebarHidden ? 'Show Sidebar' : 'Hide Sidebar'), keys: '⌃⌘S', run: toggleSidebar, on: () => true },
  panel: { label: () => (S.panelHidden ? 'Show Filing Panel' : 'Hide Filing Panel'), keys: '⌥⌘I', run: togglePanel, on: () => true },
  zoomIn: { label: 'Zoom In', keys: '⌘+', run: () => zoom('in'), on: () => !!selectedFile() },
  zoomOut: { label: 'Zoom Out', keys: '⌘−', run: () => zoom('out'), on: () => !!selectedFile() },
  zoomFit: { label: 'Zoom to Fit', keys: '⌘0', run: () => zoom('fit'), on: () => !!selectedFile() },
  refresh: { label: 'Refresh', keys: '⌘R', run: refreshCmd, on: () => !isFirstLaunch() },
  next: { label: 'Next Unfiled File', keys: '⌥⌘↓', run: () => selectNextUnfiled(1), on: () => unfiledOrder().length > 0 },
  prev: { label: 'Previous Unfiled File', keys: '⌥⌘↑', run: () => selectNextUnfiled(-1), on: () => unfiledOrder().length > 0 },
  shortcuts: { label: 'Keyboard Shortcuts', keys: '⌘/', run: openKbd, on: () => true },
};
function menuDefs() {
  const go = ['next', 'prev', '-'].concat(S.inboxes.slice(0, 9).map((inb, i) => ({ label: inb.name, keys: `⌘${i + 1}`, run: () => jumpInbox(i + 1), on: () => !isFirstLaunch() })));
  return [
    { title: 'docsort', app: true, items: ['about', '-', 'settings', '-', 'quit'] },
    { title: 'File', items: ['chooseDest', 'move', 'newFolder', '-', 'open', 'reveal', 'quicklook', '-', 'trash', 'moveBack'] },
    { title: 'Edit', items: ['undo', 'redo', '-', 'revert'] },
    { title: 'View', items: ['sidebar', 'panel', '-', 'zoomIn', 'zoomOut', 'zoomFit', '-', 'refresh'] },
    { title: 'Go', items: go },
    { title: 'Window', items: ['history'] },
    { title: 'Help', items: ['shortcuts'] },
  ];
}
const resolveItem = (it) => (it === '-' ? '-' : typeof it === 'string' ? CMD[it] : it);
function menuHtml(items, active) {
  return items.map((raw, i) => {
    const it = resolveItem(raw);
    if (it === '-') return '<div class="msep" role="separator"></div>';
    const label = typeof it.label === 'function' ? it.label() : it.label;
    const on = it.on();
    return `<div class="mi${on ? '' : ' dis'}${i === active ? ' act' : ''}" role="menuitem" aria-disabled="${!on}" data-i="${i}"><span>${esc(label)}</span>${it.keys ? `<span class="k">${it.keys}</span>` : ''}</div>`;
  }).join('');
}
function renderMenubar() {
  $('menubar').innerHTML = menuDefs().map((m, i) => `<button type="button" class="mb-item${m.app ? ' app' : ''}" id="mb-${i}" data-mi="${i}" aria-haspopup="menu" aria-expanded="${S.menu && S.menu.i === i}">${m.title}</button>`).join('') + `<span class="mb-clock">${WEEKDAYS[new Date(TODAY).getUTCDay()]} ${+TODAY.slice(8, 10)} ${MONTHS[+TODAY.slice(5, 7) - 1]} 09:41</span>`;
}
function openMenu(i) {
  const defs = menuDefs();
  S.menu = { i, items: defs[i].items, active: -1 };
  renderMenubar();
  const btn = $('mb-' + i);
  const drop = $('menuDrop');
  drop.innerHTML = menuHtml(S.menu.items, -1);
  drop.style.left = btn.offsetLeft + 'px';
  drop.style.top = btn.offsetTop + btn.offsetHeight + 2 + 'px';
  drop.hidden = false;
}
function closeMenu() { S.menu = null; $('menuDrop').hidden = true; renderMenubar(); onFocusChange(); }
function runMenuItem(raw) {
  const it = resolveItem(raw);
  if (it === '-' || !it.on()) return false;
  it.run();
  return true;
}
function menuKey(e, items, state, rerender, close) {
  const k = e.key;
  const enabledIdx = items.map((r, i) => (resolveItem(r) !== '-' && resolveItem(r).on() ? i : -1)).filter((i) => i >= 0);
  if (k === 'Escape') { close(); }
  else if (k === 'ArrowDown' || k === 'ArrowUp') {
    const pos = enabledIdx.indexOf(state.active);
    const np = k === 'ArrowDown' ? (pos + 1) % enabledIdx.length : (pos <= 0 ? enabledIdx.length - 1 : pos - 1);
    state.active = enabledIdx[np]; rerender();
  } else if (k === 'Enter' || k === ' ') {
    if (state.active >= 0) { const raw = items[state.active]; close(); runMenuItem(raw); }
  } else return false;
  return true;
}
function openCtx(x, y) {
  const f = selectedFile();
  if (!f) return;
  // the row's menu says "Move Back"; the File menu keeps the longer "Move Back to Inbox"
  const back = { ...CMD.moveBack, label: f.status === 'trashed' ? 'Put Back' : 'Move Back' };
  const items = f.status === 'inbox'
    ? ['open', 'reveal', 'quicklook', '-', { label: 'Choose Destination…', keys: '⇥', run: () => chooseDestination(), on: () => !archiveUnavailable() }, '-', 'trash']
    : f.status === 'moved' ? ['open', 'reveal', 'quicklook', '-', { label: 'Rename…', run: () => { if (!archiveUnavailable()) focusName(); }, on: () => !archiveUnavailable() }, back, '-', 'trash'] : ['open', 'reveal', 'quicklook', '-', back];
  S.ctx = { items, active: -1 };
  const m = $('ctxMenu');
  m.innerHTML = `<div class="menu" role="menu" style="position:static">${menuHtml(items, -1)}</div>`;
  const wr = $('win').getBoundingClientRect();
  m.style.left = Math.min(x - wr.left, 1240 - 260) + 'px';
  m.style.top = Math.min(y - wr.top, 760 - 200) + 'px';
  m.hidden = false;
  const row = document.getElementById('row-' + cssId(S.sel));
  if (row) row.classList.add('ctx');
}
function closeCtx() { S.ctx = null; $('ctxMenu').hidden = true; document.querySelectorAll('.row.ctx').forEach((r) => r.classList.remove('ctx')); }

/* ---------------------------------------------------------------- settings window */
function openSettings() {
  if (S.menu) closeMenu();
  S.settings = true; S.stEditing = null;
  $('settingsWin').hidden = false;
  renderSettings();
  $('stTable').focus({ preventScroll: true });
}
function closeSettings() {
  S.settings = false; S.stEditing = null; $('settingsWin').hidden = true;
  focusStop(isFirstLaunch() ? 'preview' : S.lastStop);
}
function renderSettings() {
  $('stClose').innerHTML = '';
  const pc = $('stArchivePath');
  if (!S.archiveSet) { pc.className = 'pc missing'; pc.innerHTML = 'Not set'; $('stArchiveCount').textContent = 'Choose the folder that holds your archive.'; }
  else if (archiveUnavailable()) { pc.className = 'pc'; pc.innerHTML = `<span style="color:var(--warn);display:inline-flex;width:14px">${ICON.warn}</span>${ARCHIVE_PATH} <span style="color:var(--warn-fg)">· Not available</span>`; $('stArchiveCount').textContent = 'docsort keeps this setting and recovers when the folder is back.'; }
  else { pc.className = 'pc'; pc.innerHTML = `${ICON.folder}<span>${ARCHIVE_PATH}</span>`; $('stArchiveCount').textContent = S.indexing ? 'Indexing…' : ARCHIVE_FOLDER_COUNT; }
  const t = $('stTable');
  if (S.stSel >= S.inboxes.length) S.stSel = S.inboxes.length - 1;
  let html = '<div class="th" role="row"><span></span><span role="columnheader">Name</span><span role="columnheader">Folder</span><span role="columnheader">Status</span></div>';
  if (!S.inboxes.length) html += '<div class="tempty">No inboxes. Click + to add a folder.</div>';
  S.inboxes.forEach((inb, i) => {
    const bad = inboxUnreachable(inb) ? 'Not found' : inboxNeedsAccess(inb) ? 'Needs access' : '';
    const editing = S.stEditing === i;
    html += `<div class="tr${i === S.stSel ? ' sel' : ''}" role="row" draggable="true" data-i="${i}" aria-selected="${i === S.stSel}"><span class="grip" title="Drag to reorder">${ICON.grip}</span><span class="nm" role="gridcell">${editing ? `<input id="stNameEdit" value="${esc(inb.name)}" aria-label="Inbox name">` : esc(inb.name)}</span><span class="fpath" role="gridcell" title="${esc(inb.path)}">${esc(inb.path)}</span><span role="gridcell">${bad ? `<span class="st-bad">${ICON.warn}${bad}</span>` : '<span class="st-ok">OK</span>'}</span></div>`;
  });
  t.innerHTML = html;
  $('stAdd').innerHTML = ICON.plus; $('stRemove').innerHTML = ICON.minus;
  $('stRemove').disabled = !S.inboxes.length;
  $('stAdd').disabled = S.inboxes.length >= 4;
  if (S.stEditing !== null) { const inp = $('stNameEdit'); inp.focus(); inp.select(); }
}
function settingsChanged() {
  if (!isFirstLaunch() && S.mode === 'first') S.mode = 'normal';
  render();
}
function stAdd() {
  const pool = DEFAULT_INBOXES.concat(EXTRA_INBOXES);
  const next = pool.find((p) => !S.inboxes.some((i) => i.id === p.id));
  if (!next) return;
  S.inboxes.push({ ...next });
  S.stSel = S.inboxes.length - 1;
  settingsChanged();
  setStatus(`Added inbox “${esc(next.name)}” (${esc(next.path)})`, { ms: 5000 });
}
function stRemove() {
  if (!S.inboxes.length) return;
  const [gone] = S.inboxes.splice(S.stSel, 1);
  S.stSel = Math.max(0, S.stSel - 1);
  settingsChanged();
  setStatus(`Removed inbox “${esc(gone.name)}”. Its files were not touched.`, { ms: 5000 });
}
function stChoose() {
  S.archiveSet = true;
  if (S.mode === 'archive') S.mode = 'normal';
  S.indexing = true;
  setTimeout(() => { S.indexing = false; resultsCache.key = ''; render(); }, 600);
  settingsChanged();
}
function stCommitEdit(save) {
  const i = S.stEditing;
  if (i === null) return;
  const inp = $('stNameEdit');
  if (save && inp && inp.value.trim()) S.inboxes[i].name = inp.value.trim();
  else if (!save && S.stEditBackup !== undefined) S.inboxes[i].name = S.stEditBackup;
  S.stEditing = null;
  render();
  $('stTable').focus({ preventScroll: true });
}

/* ---------------------------------------------------------------- history window */
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const pad2 = (n) => String(n).padStart(2, '0');
function dayLabel(iso) {
  const d = dayDiff(iso);
  const dt = new Date(Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10)));
  const full = `${DAY_NAMES[dt.getUTCDay()]}, ${dt.getUTCDate()} ${MONTH_NAMES[dt.getUTCMonth()]} ${dt.getUTCFullYear()}`;
  return d === 0 ? `Today · ${full}` : d === 1 ? `Yesterday · ${full}` : full;
}
/* The mockup's clock: every recorded action takes a minute, starting at the menu bar's 09:41. */
function nowIso() { S.clock++; return `${TODAY}T${pad2(Math.floor(S.clock / 60))}:${pad2(S.clock % 60)}`; }
function addHistory(e) {
  e.at = nowIso();
  e.id = 'h-' + S.clock + '-' + S.history.length;
  S.history.push(e);
  if (S.hs) { S.hsSel = e.id; renderHistory(true); }
}
/* Is the file still where the entry put it? Seeded entries carry a fixed answer. */
function entryGone(e) {
  if (!e.fileId) return e.gone || !!e.movedBack;
  const f = fileById(e.fileId);
  if (f.removedOutside) return true;
  if (e.kind === 'move' || e.kind === 'rename') return !(f.status === 'moved' && f.location.folder === e.dest && f.location.name === e.newName);
  if (e.kind === 'back') return f.status !== 'inbox';
  return f.status !== 'trashed';
}
function entryDestLabel(e) {
  if (e.kind === 'back') return `${e.inbox} (moved back from ${e.dest})`;
  if (e.kind === 'trash') return 'Trash';
  return e.dest;
}
function historyRows() {
  const tokens = S.hsQuery.split(/\s+/).filter(Boolean).map((t) => t.split('').map(foldChar).join(''));
  const fold = (x) => x.split('').map(foldChar).join('');
  return S.history.slice().sort((a, b) => a.at.localeCompare(b.at)).filter((e) => {
    if (!tokens.length) return true;
    const hay = fold([e.at.slice(11, 16), e.orig, e.inbox, e.newName, entryDestLabel(e), e.kind === 'rename' ? 'renamed' : ''].join(' '));
    return tokens.every((t) => hay.includes(t));
  });
}
const selectedEntry = () => S.history.find((e) => e.id === S.hsSel) || null;
function openHistory() {
  if (S.menu) closeMenu();
  const first = !S.hs;
  S.hs = true;
  $('histWin').hidden = false;
  if (first) { S.hsQuery = ''; $('hsSearch').value = ''; S.hsStatus = ''; const rows = historyRows(); S.hsSel = rows.length ? rows[rows.length - 1].id : null; }
  renderHistory(true);
  $('hsTable').focus({ preventScroll: true });
}
function closeHistory() {
  S.hs = false;
  $('histWin').hidden = true;
  focusStop(isFirstLaunch() ? 'preview' : S.lastStop);
}
function renderHistory(scrollToSel = false) {
  const table = $('hsTable');
  const rows = historyRows();
  if (S.hsSel && !rows.some((e) => e.id === S.hsSel)) S.hsSel = rows.length ? rows[rows.length - 1].id : null;
  let html = '<div class="hs-th" role="row"><span role="columnheader">Filed</span><span role="columnheader">Original name</span><span role="columnheader">Inbox</span><span role="columnheader">New name</span><span role="columnheader">Destination</span></div>';
  let day = '';
  for (const e of rows) {
    const d = e.at.slice(0, 10);
    if (d !== day) { day = d; html += `<div class="hs-day" role="row">${esc(dayLabel(e.at))}</div>`; }
    const gone = entryGone(e);
    const kindTag = e.kind === 'rename' ? '<span class="tag">Renamed</span>' : e.kind === 'back' ? '<span class="tag">Moved back</span>' : e.kind === 'trash' ? '<span class="tag">Trashed</span>' : '';
    html += `<div class="hs-tr${e.id === S.hsSel ? ' sel' : ''}${gone ? ' gone' : ''}" role="row" data-h="${esc(e.id)}" aria-selected="${e.id === S.hsSel}">`
      + `<span class="t">${e.at.slice(11, 16)}</span><span title="${esc(e.orig)}">${esc(e.orig)}</span><span>${esc(e.inbox)}</span>`
      + `<span title="${esc(e.newName)}">${kindTag}${esc(e.newName)}</span>`
      + `<span class="dst" title="${esc(entryDestLabel(e))}"><span class="d">${esc(entryDestLabel(e))}</span>${gone ? '<span class="gone-tag">Moved or deleted since</span>' : ''}</span></div>`;
  }
  if (!rows.length) html += `<div class="hs-none">No entries match “${esc(S.hsQuery)}”.</div>`;
  const keep = table.scrollTop;
  table.innerHTML = html;
  table.scrollTop = keep;
  if (scrollToSel) { const el = table.querySelector('.hs-tr.sel'); if (el) el.scrollIntoView({ block: 'nearest' }); else table.scrollTop = table.scrollHeight; }
  renderHistorySide();
  $('hsFoot').innerHTML = `<span>${rows.length === S.history.length ? `${rows.length} entries` : `${rows.length} of ${S.history.length} entries`}</span><span class="msg">${S.hsStatus}</span>`;
  $('hsClose').innerHTML = '';
}
function entryThumb(e) {
  const f = e.fileId ? fileById(e.fileId) : null;
  if (f && f.preview && f.preview !== 'none' && f.preview !== 'generic' && PREVIEWS[f.preview]) return PREVIEWS[f.preview]()[0];
  if (f && f.preview === 'generic') return genericPaper(f.doc);
  const words = e.newName.replace(/\.[^.]+$/, '').replace(/^\d{4}-\d{2}(-\d{2})?\s*|^\d{8}_/, '').split(/[\s_]+/);
  return genericPaper({ logo: lastSeg(e.dest === 'Trash' ? e.inbox : e.dest), title: words.join(' ') || e.newName, sub: e.orig, date: `${e.at.slice(8, 10)}.${e.at.slice(5, 7)}.${e.at.slice(0, 4)}` });
}
function renderHistorySide() {
  const side = $('hsSide');
  const e = selectedEntry();
  if (!e) { side.innerHTML = '<div class="hs-empty">Select an entry to see the file.</div>'; return; }
  const gone = entryGone(e);
  const f = e.fileId ? fileById(e.fileId) : null;
  const inList = !!f && isVisibleFile(f);
  const canBack = !gone && (e.kind === 'move' || e.kind === 'rename' || e.kind === 'trash');
  const when = `${+e.at.slice(8, 10)} ${MONTHS[+e.at.slice(5, 7) - 1]} ${e.at.slice(0, 4)}, ${e.at.slice(11, 16)}`;
  let btns;
  if (gone) btns = '<button type="button" class="btn small" data-hs="revealFolder">Reveal Folder in Finder</button>';
  else {
    btns = `<button type="button" class="btn small" data-hs="open">Open<span class="k">⌘O</span></button><button type="button" class="btn small" data-hs="reveal">Reveal in Finder<span class="k">⌥⌘R</span></button>`;
    if (canBack) btns += `<button type="button" class="btn small" data-hs="back">${e.kind === 'trash' ? 'Put Back' : 'Move Back'}<span class="k">⌥⌘Z</span></button>`;
  }
  if (inList) btns += '<button type="button" class="btn small" data-hs="show">Show in Main Window</button>';
  side.innerHTML = `<div class="hs-thumb${gone ? ' gone' : ''}"><div class="hs-page">${entryThumb(e)}</div></div>`
    + `<div class="hs-meta"><div class="nm">${esc(e.kind === 'trash' ? e.orig : e.newName)}</div>`
    + `<div>${esc(entryDestLabel(e))}</div><div class="sub">${esc(when)} · from ${esc(e.inbox)}${e.kind === 'move' && e.orig !== e.newName ? ` · was “${esc(e.orig)}”` : ''}</div>`
    + (gone ? '<div class="notice warn">' + ICON.warn + '<span>Moved or deleted since. The file is no longer at this place.</span></div>' : '')
    + `</div><div class="hs-btns">${btns}</div>`;
}
function hsSelect(delta) {
  const rows = historyRows();
  if (!rows.length) return;
  let i = rows.findIndex((e) => e.id === S.hsSel);
  i = i < 0 ? rows.length - 1 : Math.max(0, Math.min(rows.length - 1, i + delta));
  S.hsSel = rows[i].id;
  S.hsStatus = '';
  renderHistory(true);
}
function hsAction(act) {
  const e = selectedEntry();
  if (!e) return;
  const gone = entryGone(e);
  const f = e.fileId ? fileById(e.fileId) : null;
  const name = e.kind === 'trash' ? e.orig : e.newName;
  if (act === 'revealFolder') S.hsStatus = `Revealed folder “${esc(e.dest === 'Trash' ? 'Trash' : e.dest)}” in Finder`;
  else if (gone) S.hsStatus = `“${esc(name)}” is no longer at ${esc(entryDestLabel(e))}.`;
  else if (act === 'open') S.hsStatus = `Opened “${esc(name)}” in Preview`;
  else if (act === 'reveal') S.hsStatus = `Revealed “${esc(name)}” in Finder (${esc(e.kind === 'trash' ? 'the Trash' : e.kind === 'back' ? e.inbox : ARCHIVE_PATH + '/' + e.dest)})`;
  else if (act === 'back') {
    if (!(e.kind === 'move' || e.kind === 'rename' || e.kind === 'trash')) return;
    if (f) moveBack(f, { fromHistory: true });
    else historyMoveBack(e);
    S.hsStatus = `Moved “${esc(name)}” back to ${esc(e.inbox)}`;
  } else if (act === 'show') {
    if (!f || !isVisibleFile(f)) return;
    revealFile(f);
    closeHistory();
    setSelection('f:' + f.id);
    focusStop('sidebar');
    return;
  }
  renderHistory();
}
/* Move Back for a file filed in an earlier session: it reappears in its inbox at its date position. */
function historyMoveBack(e) {
  e.movedBack = true;
  const inbox = S.inboxes.find((i) => i.name === e.inbox) || S.inboxes[0];
  if (!inbox) return;
  const ext = (e.orig.match(/\.[^.]+$/) || ['.pdf'])[0];
  const f = mkFile('hb-' + e.id, inbox.id, e.orig, ext, e.at, { size: '96 KB', kindLabel: 'PDF document', preview: 'generic', pages: 1, arrival: true, flash: true,
    doc: { logo: lastSeg(e.dest), title: e.newName.replace(/\.[^.]+$/, ''), sub: e.orig, date: `${e.at.slice(8, 10)}.${e.at.slice(5, 7)}.${e.at.slice(0, 4)}` } });
  S.files.push(f);
  S.undo.push({ type: 'back', id: f.id, before: { status: 'moved', location: { folder: e.dest, name: e.newName } }, after: { status: 'inbox', location: null }, label: `Move Back of “${shortName(e.orig)}”` });
  S.redo = [];
  addHistory({ kind: 'back', inbox: inbox.name, orig: e.newName, newName: e.orig, dest: e.dest, fileId: f.id });
  render();
  setTimeout(() => { f.flash = false; renderSidebar(); }, 2400);
  setStatus(`Moved back “${esc(e.orig)}” to ${esc(inbox.name)}`, { kind: 'ok', link: { act: 'undo', label: 'Undo ⌘Z' } });
}
function historyKey(k, e) {
  const inSearch = document.activeElement === $('hsSearch');
  if (is(k, 'Escape')) {
    if (inSearch && $('hsSearch').value) { $('hsSearch').value = ''; S.hsQuery = ''; renderHistory(true); }
    else closeHistory();
    return true;
  }
  if (is(k, 'cmd+w') || is(k, 'cmd+y') || is(k, 'ctrl+y')) { closeHistory(); return true; }
  if (is(k, 'cmd+f')) { $('hsSearch').focus(); $('hsSearch').select(); return true; }
  if (is(k, 'ArrowDown') || is(k, 'ArrowUp')) { hsSelect(k.key === 'ArrowDown' ? 1 : -1); return true; }
  if (is(k, 'cmd+o')) { hsAction('open'); return true; }
  if (is(k, 'cmd+alt+r')) { hsAction('reveal'); return true; }
  if (is(k, 'cmd+alt+z')) { hsAction('back'); return true; }
  if (is(k, 'cmd+z')) { undo(); renderHistory(); return true; }
  if (is(k, 'cmd+shift+z')) { redo(); renderHistory(); return true; }
  return false;
}
$('hsClose').addEventListener('click', closeHistory);
$('hsSearch').addEventListener('input', () => { S.hsQuery = $('hsSearch').value; S.hsStatus = ''; renderHistory(true); });
$('hsTable').addEventListener('mousedown', (e) => {
  const tr = e.target.closest('.hs-tr');
  if (!tr) return;
  S.hsSel = tr.dataset.h; S.hsStatus = '';
  renderHistory();
  $('hsTable').focus({ preventScroll: true });
  e.preventDefault();
});
$('hsTable').addEventListener('dblclick', (e) => { if (e.target.closest('.hs-tr')) hsAction('open'); });
$('hsSide').addEventListener('click', (e) => { const b = e.target.closest('[data-hs]'); if (b) hsAction(b.dataset.hs); });
$('histWin').addEventListener('mousedown', (e) => { if (!e.target.closest('input, button, .hs-table')) { e.preventDefault(); $('hsTable').focus({ preventScroll: true }); } });

/* ---------------------------------------------------------------- state switcher and page controls */
function setMode(m) {
  if (m === 'first') {
    if (S.inboxes.length) S.savedInboxes = S.inboxes;
    S.inboxes = []; S.archiveSet = false;
  } else {
    S.archiveSet = true;
    if (!S.inboxes.length) S.inboxes = (S.savedInboxes || DEFAULT_INBOXES).map((x) => ({ ...x }));
    // the switcher always shows both default inboxes, keeping renames and order of the ones present
    for (const d of DEFAULT_INBOXES) if (!S.inboxes.some((i) => i.id === d.id)) S.inboxes.push({ ...d });
    // The linked inbox (a link that needs its own access grant) exists only in its state
    S.inboxes = S.inboxes.filter((i) => i.id !== LINKED_INBOX.id);
    if (m === 'linked') { S.inboxes.push({ ...LINKED_INBOX }); S.linkedGranted = false; }
  }
  S.mode = m;
  S.failArmed = true;
  S.moveError = null;
  if (m === 'archive') { S.chosen = null; S.newFolder = null; }
  resultsCache.key = '';
  S.previewKey = '';
  render();
  const messages = {
    normal: 'State: normal.', first: 'State: first launch. Open Settings to choose the folders.', empty: 'State: all inboxes empty.',
    unreachable: `State: the ${SCANNER.name} folder cannot be found.`, archive: 'State: the archive folder is not available.', fail: 'State: the next move or trash fails once; Try Again succeeds.',
    linked: `State: the ${LINKED_INBOX.name} inbox is a link to a folder outside the archive and needs its own access grant.`,
  };
  setStatus(messages[m], { ms: 6000 });
}
function updateSegs() {
  const mode = isFirstLaunch() ? 'first' : S.mode;
  document.querySelectorAll('#stateSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.state === mode)));
}
function setTheme(choice) {
  if (choice === 'auto') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', choice);
  document.querySelectorAll('#themeSeg button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.themeChoice === choice)));
  try { localStorage.setItem('docsort-mock-theme', choice); } catch (err) { /* storage unavailable: keep the choice for this visit only */ }
}

/* ---------------------------------------------------------------- keyboard */
function keyOf(e) {
  let key = e.key;
  if (key === ' ') key = 'space';
  else if (key.length === 1) {
    if (e.altKey && /^Key[A-Z]$/.test(e.code)) key = e.code.slice(3).toLowerCase();
    else if (e.altKey && /^Digit\d$/.test(e.code)) key = e.code.slice(5);
    else key = key.toLowerCase();
  }
  return { key, cmd: e.metaKey, ctrl: e.ctrlKey, alt: e.altKey, shift: e.shiftKey, code: e.code };
}
function is(k, spec) {
  const parts = spec.split('+');
  const key = parts.pop();
  const want = { cmd: parts.includes('cmd'), ctrl: parts.includes('ctrl'), alt: parts.includes('alt'), shift: parts.includes('shift') };
  const anyShift = parts.includes('anyshift');
  return k.key === key && k.cmd === want.cmd && k.ctrl === want.ctrl && k.alt === want.alt && (anyShift || k.shift === want.shift);
}
const textFocused = () => { const a = document.activeElement; return a && a.tagName === 'INPUT' && a.type === 'text'; };
function globalKey(k, e) {
  if (is(k, 'cmd+l') || is(k, 'ctrl+l')) { chooseDestination(); return true; }
  if (is(k, 'cmd+Enter')) { doMove(); return true; }
  if (is(k, 'cmd+o')) { openCmd(); return true; }
  if (is(k, 'cmd+alt+r')) { revealCmd(); return true; }
  if (is(k, 'cmd+shift+r') || is(k, 'ctrl+shift+r')) { revertName(); return true; }
  if (is(k, 'cmd+Backspace')) { if (textFocused()) return false; doTrash(); return true; }
  if (is(k, 'cmd+z')) { undo(); return true; }
  if (is(k, 'cmd+shift+z')) { redo(); return true; }
  if (is(k, 'cmd+alt+z')) { moveBack(); return true; }
  if (is(k, 'cmd+y') || is(k, 'ctrl+y')) { openHistory(); return true; }
  if (is(k, 'cmd+r')) { refreshCmd(); return true; }
  if (is(k, 'cmd+ctrl+s')) { toggleSidebar(); return true; }
  if (is(k, 'cmd+alt+i')) { togglePanel(); return true; }
  if ((k.cmd || k.ctrl) && !(k.cmd && k.ctrl) && !k.alt && !k.shift && /^[1-9]$/.test(k.key)) { jumpInbox(+k.key); return true; }
  if (is(k, 'cmd+alt+ArrowDown')) { selectNextUnfiled(1); return true; }
  if (is(k, 'cmd+alt+ArrowUp')) { selectNextUnfiled(-1); return true; }
  if (k.cmd && !k.alt && !k.ctrl && (k.key === '+' || k.key === '=')) { zoom('in'); return true; }
  if (k.cmd && !k.alt && !k.ctrl && (k.key === '-' || k.key === '−')) { zoom('out'); return true; }
  if (is(k, 'cmd+0')) { zoom('fit'); return true; }
  if (is(k, 'cmd+,')) { openSettings(); return true; }
  if (k.cmd && !k.alt && !k.ctrl && (k.key === '/' || k.key === '?')) { openKbd(); return true; }
  if (is(k, 'cmd+shift+n') || is(k, 'ctrl+shift+n')) { newFolderCmd(); return true; }
  if (is(k, 'cmd+w')) { setStatus('⌘W would close the window; the mockup keeps it open.', { ms: 3000 }); return true; }
  return false;
}
/* A plain printable key, Space excluded (Space is Quick Look). */
const isPrintable = (k, e) => !k.cmd && !k.ctrl && !k.alt && e.key.length === 1 && e.key !== ' ';
function sidebarKey(k, e) {
  if (is(k, 'ArrowDown')) { moveSelection(1); return true; }
  if (is(k, 'ArrowUp')) { moveSelection(-1); return true; }
  if (is(k, 'Home')) { const r = navRows(); if (r.length) setSelection(r[0].key); return true; }
  if (is(k, 'End')) { const r = navRows(); if (r.length) setSelection(r[r.length - 1].key); return true; }
  if (is(k, 'ArrowRight') || is(k, 'ArrowLeft')) {
    const open = k.key === 'ArrowRight';
    if (S.sel && S.sel.startsWith('g:')) {
      if (open && S.groupsOpen[S.sel]) moveSelection(1);
      else toggleGroup(S.sel, open);
    } else if (!open) {
      const f = selectedFile();
      if (f && f.group) toggleGroup(groupKey(f.inbox, f.group), false);
    }
    return true;
  }
  if (is(k, 'Enter')) { startFiling(); return true; }
  if (is(k, 'Tab')) { if (!filingActive() || archiveUnavailable() || S.panelHidden) return false; chooseDestination(); return true; }
  if (is(k, 'space')) { openQL(); return true; }
  if (is(k, 'PageDown') || is(k, 'PageUp')) { const sc = $('pvScroll'); sc.scrollBy({ top: (k.key === 'PageDown' ? 1 : -1) * sc.clientHeight * 0.9 }); return true; }
  if (is(k, 'Escape')) return true;
  // type to search: the key goes straight into the destination filter
  if (isPrintable(k, e)) { if (filingActive() && !archiveUnavailable()) chooseDestination(e.key); return true; }
  return false;
}
function previewKey(k) {
  if (is(k, 'Escape') || is(k, 'shift+Tab')) { focusStop('sidebar'); return true; }
  if (is(k, 'Tab')) { if (!filingActive() || archiveUnavailable() || S.panelHidden) return false; chooseDestination(); return true; }
  return false;
}
function destKey(k, e) {
  const inp = $('destInput');
  const caretAtEnd = inp.selectionStart === inp.value.length && inp.selectionEnd === inp.value.length;
  if (is(k, 'ArrowDown')) { if (S.chosen) unchoose(); setHighlight(S.hl + 1); return true; }
  if (is(k, 'ArrowUp')) { if (S.chosen) unchoose(); setHighlight(S.hl - 1); return true; }
  if (is(k, 'ArrowRight') && caretAtEnd) { stepIn(); return true; }
  if (is(k, 'ArrowLeft') && inp.value === '') { stepOut(); return true; }
  if (is(k, 'cmd+ArrowDown')) { stepIn(); return true; }
  if (is(k, 'cmd+ArrowUp')) { stepOut(); return true; }
  if (is(k, 'Enter') || is(k, 'Tab')) { if (S.chosen) focusName(); else chooseHighlighted(); return true; }
  if (is(k, 'shift+Tab')) { focusStop('sidebar'); return true; }
  if (is(k, 'Escape')) {
    if (S.chosen || S.query || S.scope) clearDestination();
    else focusStop('sidebar');
    return true;
  }
  if (is(k, 'Backspace') && inp.value === '' && inp.selectionStart === 0) {
    if (S.chosen) { unchoose(); renderPanel(); focusStop('dest', { caretEnd: true }); return true; }
    if (S.scope) { stepOut(); return true; }
  }
  return false;
}
function newFolderKey(k) {
  if (is(k, 'Enter') || is(k, 'Tab')) { confirmNewFolder(); return true; }
  if (is(k, 'Escape') || is(k, 'shift+Tab')) { cancelNewFolder(); return true; }
  if (is(k, 'cmd+Enter')) { if (confirmNewFolder()) doMove(); return true; }
  return false;
}
function nameKey(k) {
  if (is(k, 'Enter')) { showNameHint(); return true; }
  if (is(k, 'Tab')) { focusStop('sidebar'); return true; }
  if (is(k, 'shift+Tab')) { focusStop('dest', { caretEnd: true }); return true; }
  if (is(k, 'Escape')) { focusStop('dest', { caretEnd: true }); return true; }
  if (is(k, 'alt+ArrowUp')) { takeName(-1); return true; }
  if (is(k, 'alt+ArrowDown')) { takeName(1); return true; }
  return false;
}
function settingsKey(k, e) {
  if (S.stEditing !== null && document.activeElement && document.activeElement.id === 'stNameEdit') {
    if (is(k, 'Enter')) { stCommitEdit(true); return true; }
    if (is(k, 'Escape')) { stCommitEdit(false); return true; }
    return false;
  }
  if (is(k, 'Escape') || is(k, 'cmd+w') || is(k, 'cmd+,')) { closeSettings(); return true; }
  if (document.activeElement === $('stTable')) {
    if (is(k, 'ArrowDown')) { S.stSel = Math.min(S.inboxes.length - 1, S.stSel + 1); renderSettings(); return true; }
    if (is(k, 'ArrowUp')) { S.stSel = Math.max(0, S.stSel - 1); renderSettings(); return true; }
    if (is(k, 'alt+ArrowDown') || is(k, 'alt+ArrowUp')) { stMove(S.stSel, S.stSel + (k.key === 'ArrowDown' ? 1 : -1)); return true; }
    if (is(k, 'Enter') && S.inboxes.length) { startStEdit(S.stSel); return true; }
    if ((is(k, 'Backspace') || is(k, 'Delete')) && S.inboxes.length) { stRemove(); return true; }
  }
  return false;
}
function startStEdit(i) { S.stEditing = i; S.stEditBackup = S.inboxes[i].name; renderSettings(); }
function stMove(from, to) {
  if (to < 0 || to >= S.inboxes.length || from === to) return;
  const [it] = S.inboxes.splice(from, 1);
  S.inboxes.splice(to, 0, it);
  S.stSel = to;
  render();
}
function onKey(e) {
  const k = keyOf(e);
  if (S.menu) {
    if (k.key === 'ArrowLeft' || k.key === 'ArrowRight') { const n = menuDefs().length; openMenu((S.menu.i + (k.key === 'ArrowRight' ? 1 : n - 1)) % n); e.preventDefault(); return; }
    if (menuKey(e, S.menu.items, S.menu, () => { $('menuDrop').innerHTML = menuHtml(S.menu.items, S.menu.active); }, closeMenu)) { e.preventDefault(); e.stopPropagation(); }
    return;
  }
  if (S.ctx) {
    if (!menuKey(e, S.ctx.items, S.ctx, () => { $('ctxMenu').firstChild.innerHTML = menuHtml(S.ctx.items, S.ctx.active); }, closeCtx)) closeCtx();
    e.preventDefault(); e.stopPropagation();
    return;
  }
  const a = document.activeElement;
  if (S.settings && $('settingsWin').contains(a)) {
    if (settingsKey(k, e)) { e.preventDefault(); e.stopPropagation(); }
    return;
  }
  if (S.hs && $('histWin').contains(a)) {
    if (historyKey(k, e)) { e.preventDefault(); e.stopPropagation(); }
    return;
  }
  if (!$('win').contains(a)) return;
  if (S.sheet) {
    if (is(k, 'Enter')) { sheetKeepBoth(); }
    else if (is(k, 'Escape')) { sheetCancel(); }
    else if (is(k, 'cmd+r')) { sheetReplace(); }
    else if (is(k, 'Tab') || is(k, 'shift+Tab')) {
      const btns = [$('sheetKeepBoth'), $('sheetReplace'), $('sheetCancel')];
      const i = btns.indexOf(a);
      btns[(i + (k.shift ? btns.length - 1 : 1)) % btns.length].focus();
    } else if (is(k, 'space')) { return; }
    e.preventDefault(); e.stopPropagation();
    return;
  }
  if (S.ql) {
    if (is(k, 'space') || is(k, 'Escape')) closeQL();
    else if (is(k, 'ArrowDown') || is(k, 'ArrowUp')) { moveSelection(k.key === 'ArrowDown' ? 1 : -1); renderQL(); }
    else if (globalKey(k, e)) { /* handled */ }
    else return;
    e.preventDefault(); e.stopPropagation();
    return;
  }
  if (S.kbd) {
    if (is(k, 'Escape') || (k.cmd && (k.key === '/' || k.key === '?'))) { closeKbd(); e.preventDefault(); }
    return;
  }
  let handled = false;
  const stop = stopOf(a);
  if (a && a.id === 'newFolderInput') handled = newFolderKey(k);
  else if (stop === 'dest') handled = destKey(k, e);
  else if (stop === 'name') handled = nameKey(k);
  if (!handled) handled = globalKey(k, e);
  if (!handled && stop === 'sidebar') handled = sidebarKey(k, e);
  if (!handled && stop === 'preview') handled = previewKey(k);
  if (handled) { e.preventDefault(); e.stopPropagation(); }
}
document.addEventListener('keydown', onKey, true);

/* ---------------------------------------------------------------- mouse */
function onAct(act, el) {
  switch (act) {
    case 'undo': undo(); break;
    case 'redo': redo(); break;
    case 'settings': openSettings(); break;
    case 'open': openCmd(); break;
    case 'moveBack': moveBack(); break;
    case 'grant-access': grantAccess(); break;
    case 'retry': retryMove(); break;
    case 'locate-inbox': setMode('normal'); setStatus(`Found ${SCANNER.name} at ${SCANNER.path} again.`, { kind: 'ok', ms: 5000 }); focusStop('sidebar'); break;
    case 'locate-archive': setMode('normal'); S.indexing = true; render(); setTimeout(() => { S.indexing = false; resultsCache.key = ''; render(); }, 600); setStatus(`Archive folder found at ${ARCHIVE_PATH}. Indexing…`, { kind: 'ok', ms: 5000 }); break;
    default: break;
  }
}
document.addEventListener('click', (e) => {
  const actEl = e.target.closest('[data-act]');
  if (actEl && !actEl.disabled) { onAct(actEl.dataset.act, actEl); return; }
});
$('win').addEventListener('mousedown', (e) => {
  if (e.button !== 0) return;
  if (S.ctx && !e.target.closest('#ctxMenu')) closeCtx();
  if (S.menu) closeMenu();
  const t = e.target;
  // toolbar and small buttons do not take focus, as in AppKit
  if (t.closest('.tb-btn') || t.closest('.statusbar .link') || t.closest('.no-focus')) { e.preventDefault(); return; }
  if (t.closest('input, button, .ql, .ov, .sheet')) return;
  // the disclosure triangle expands or collapses a subfolder group without changing the selection
  const disc = t.closest('.disc[data-disc]');
  if (disc) { e.preventDefault(); const key = disc.dataset.disc; toggleGroup(key, !S.groupsOpen[key]); focusStop('sidebar'); return; }
  const row = t.closest('.row[data-key]');
  if (row) { e.preventDefault(); setSelection(row.dataset.key); focusStop('sidebar'); return; }
  const sec = t.closest('.sb-sec');
  if (sec) { e.preventDefault(); const id = sec.dataset.sec; S.sectionsCollapsed[id] = !S.sectionsCollapsed[id]; render(); focusStop('sidebar'); return; }
  const kids = t.closest('.kids[data-step]');
  if (kids) {
    e.preventDefault();
    if (S.chosen) unchoose(false);
    S.hl = +kids.dataset.step;
    stepIn();
    focusStop('dest', { caretEnd: true });
    return;
  }
  const ct = t.closest('.ct[data-ct]');
  if (ct) {
    e.preventDefault();
    const folder = contentsFolder();
    const x = folder && folderFiles(folder, selectedFile())[+ct.dataset.ct];
    if (x && !x.self && filingActive()) pickName(folder, x.name);
    return;
  }
  const res = t.closest('.res[data-si]');
  if (res) {
    e.preventDefault();
    const si = +res.dataset.si;
    if (S.chosen) unchoose(false);
    S.hl = si;
    const h = selectable(computeResults())[si];
    if (h && h.type === 'create') { focusStop('dest'); createFolderFromQuery(); }
    else if (h) chooseFolder(h.path);
    return;
  }
  if (t.closest('#destBox')) { e.preventDefault(); focusStop('dest'); return; }
  if (t.closest('#nameBox')) { e.preventDefault(); focusStop('name'); return; }
  if (t.closest('.sidebar')) { e.preventDefault(); focusStop('sidebar'); return; }
  if (t.closest('.preview')) { if (!t.closest('.paper')) e.preventDefault(); focusStop('preview'); return; }
  if (t.closest('.panel')) { e.preventDefault(); if (filingActive()) focusStop(S.lastStop === 'name' ? 'name' : 'dest'); else focusStop('sidebar'); return; }
  e.preventDefault();
  focusStop(S.lastStop);
});
$('win').addEventListener('dblclick', (e) => {
  if (e.target.closest('.disc')) return;
  const row = e.target.closest('.row[data-key]');
  if (row) startFiling();
});
$('win').addEventListener('contextmenu', (e) => {
  const row = e.target.closest('.row[data-key]');
  if (!row) return;
  e.preventDefault();
  setSelection(row.dataset.key);
  focusStop('sidebar');
  openCtx(e.clientX, e.clientY);
});
$('ctxMenu').addEventListener('mousedown', (e) => {
  e.preventDefault();
  const mi = e.target.closest('.mi');
  if (!mi || mi.classList.contains('dis')) return;
  const raw = S.ctx.items[+mi.dataset.i];
  closeCtx();
  runMenuItem(raw);
});
document.addEventListener('mousedown', (e) => {
  if (S.ctx && !e.target.closest('#ctxMenu')) closeCtx();
  if (S.menu && !e.target.closest('#menuDrop') && !e.target.closest('#menubar')) closeMenu();
}, true);
$('menubar').addEventListener('mousedown', (e) => {
  const b = e.target.closest('.mb-item');
  e.preventDefault();
  if (!b) return;
  const i = +b.dataset.mi;
  if (S.menu && S.menu.i === i) closeMenu(); else openMenu(i);
});
$('menubar').addEventListener('mouseover', (e) => {
  const b = e.target.closest('.mb-item');
  if (b && S.menu && S.menu.i !== +b.dataset.mi) openMenu(+b.dataset.mi);
});
$('menubar').addEventListener('keydown', (e) => {
  const b = e.target.closest('.mb-item');
  if (b && (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown') && !S.menu) { e.preventDefault(); openMenu(+b.dataset.mi); S.menu.active = -1; }
});
$('menuDrop').addEventListener('mousedown', (e) => {
  e.preventDefault();
  const mi = e.target.closest('.mi');
  if (!mi || mi.classList.contains('dis')) return;
  const raw = S.menu.items[+mi.dataset.i];
  closeMenu();
  if (S.focus === 'none' && !S.settings) focusStop(S.lastStop);
  runMenuItem(raw);
});
$('tbSidebar').addEventListener('mousedown', (e) => e.preventDefault());
$('tbSidebar').addEventListener('click', toggleSidebar);
$('tbPanel').addEventListener('click', togglePanel);
$('tbOpen').addEventListener('click', openCmd);
$('tbReveal').addEventListener('click', revealCmd);
$('tbTrash').addEventListener('click', doTrash);
$('sbHistory').addEventListener('click', () => openHistory());
$('newFolderBtn').addEventListener('click', newFolderCmd);
$('revertBtn').addEventListener('click', revertName);
$('pathBar').addEventListener('click', (e) => {
  const b = e.target.closest('.seg-btn');
  if (!b) return;
  const path = b.dataset.scope;
  // going up highlights the folder we came from
  const from = S.scope || '';
  const child = from.startsWith(path ? path + '/' : '') && from !== path ? (path ? path + '/' : '') + from.slice(path ? path.length + 1 : 0).split('/')[0] : null;
  setScope(path || null, child);
  focusStop('dest', { caretEnd: true });
});
$('moveBtn').addEventListener('mousedown', (e) => e.preventDefault());
$('moveBtn').addEventListener('click', doMove);
$('destClear').addEventListener('mousedown', (e) => e.preventDefault());
$('destClear').addEventListener('click', () => { clearDestination(); focusStop('dest'); });
$('destInput').addEventListener('input', () => {
  const v = $('destInput').value;
  if (S.chosen) S.chosen = null;
  S.query = v; S.hl = 0;
  renderPanel();
});
$('destInput').addEventListener('focus', () => { if (S.newFolder) cancelNewFolder({ refocus: false }); });
$('results').addEventListener('input', (e) => { if (e.target.id === 'newFolderInput' && S.newFolder) onNewFolderInput(); });
$('results').addEventListener('beforeinput', (e) => {
  if (e.target.id === 'newFolderInput' && e.data && e.data.includes(':')) { e.preventDefault(); setStatus('Folder names can’t contain “:”.', { kind: 'err', ms: 3000 }); }
});
$('nameInput').addEventListener('beforeinput', (e) => {
  if (e.data && /[:/]/.test(e.data)) { e.preventDefault(); flashNameNotice('Names can’t contain “:” or “/”.'); }
});
$('nameInput').addEventListener('input', onNameInput);
$('nameInput').addEventListener('focus', () => { if (S.newFolder) cancelNewFolder({ refocus: false }); });
$('pvScroll').addEventListener('scroll', updatePageIndicator, { passive: true });
$('sheetKeepBoth').addEventListener('click', sheetKeepBoth);
$('sheetReplace').addEventListener('click', sheetReplace);
$('sheetCancel').addEventListener('click', sheetCancel);
$('qlClose').addEventListener('click', closeQL);
$('qlOpen').addEventListener('click', openCmd);
$('qlWrap').addEventListener('mousedown', (e) => { if (e.target.id === 'qlWrap') { e.preventDefault(); closeQL(); } });
$('kbdWrap').addEventListener('click', (e) => { if (e.target.id === 'kbdWrap' || e.target.id === 'kbdClose') closeKbd(); });
$('suggDest1').addEventListener('click', () => { if (filingActive()) chooseFolder(SUGGESTED.folder); });
$('suggName1').addEventListener('click', () => { if (filingActive()) setName(SUGGESTED.name); });
// page controls
document.querySelectorAll('#stateSeg button').forEach((b) => b.addEventListener('click', () => { setMode(b.dataset.state); focusStop(isFirstLaunch() ? 'preview' : 'sidebar'); }));
document.querySelectorAll('#themeSeg button').forEach((b) => b.addEventListener('click', () => setTheme(b.dataset.themeChoice)));
$('openSettingsBtn').addEventListener('click', openSettings);
$('openShortcutsBtn').addEventListener('click', openKbd);
$('simulateBtn').addEventListener('click', simulateArrival);
$('simulateScanBtn').addEventListener('click', simulateScanFolder);
$('simulateRemoveBtn').addEventListener('click', simulateRemoval);
$('suggestToggle').addEventListener('change', (e) => { S.showSugg = e.target.checked; renderPanel(); });
// settings window
$('stClose').addEventListener('click', closeSettings);
$('stAdd').addEventListener('click', stAdd);
$('stRemove').addEventListener('click', stRemove);
$('stChoose').addEventListener('click', stChoose);
$('stTable').addEventListener('mousedown', (e) => {
  const tr = e.target.closest('.tr');
  if (!tr || e.target.closest('input')) return;
  S.stSel = +tr.dataset.i; renderSettings(); $('stTable').focus({ preventScroll: true });
});
$('stTable').addEventListener('dblclick', (e) => {
  const tr = e.target.closest('.tr');
  if (tr && e.target.closest('.nm')) startStEdit(+tr.dataset.i);
});
$('stTable').addEventListener('input', (e) => {
  if (e.target.id === 'stNameEdit' && S.stEditing !== null) {
    S.inboxes[S.stEditing].name = e.target.value || S.stEditBackup;
    renderSidebar(); renderToolbar(); renderMenubar();
  }
});
$('stTable').addEventListener('focusout', (e) => { if (e.target.id === 'stNameEdit' && S.stEditing !== null) setTimeout(() => { if (S.stEditing !== null && document.activeElement.id !== 'stNameEdit') stCommitEdit(true); }, 0); });
let dragFrom = null;
$('stTable').addEventListener('dragstart', (e) => {
  const tr = e.target.closest('.tr');
  if (!tr) return;
  dragFrom = +tr.dataset.i; tr.classList.add('dragging');
  e.dataTransfer.effectAllowed = 'move';
  try { e.dataTransfer.setData('text/plain', String(dragFrom)); } catch (err) { /* some browsers refuse custom data; the index is kept in dragFrom */ }
});
$('stTable').addEventListener('dragover', (e) => {
  const tr = e.target.closest('.tr');
  if (dragFrom === null || !tr) return;
  e.preventDefault();
  document.querySelectorAll('#stTable .tr').forEach((r) => r.classList.remove('drop-before', 'drop-after'));
  const r = tr.getBoundingClientRect();
  tr.classList.add(e.clientY < r.top + r.height / 2 ? 'drop-before' : 'drop-after');
});
$('stTable').addEventListener('drop', (e) => {
  const tr = e.target.closest('.tr');
  if (dragFrom === null || !tr) return;
  e.preventDefault();
  const r = tr.getBoundingClientRect();
  let to = +tr.dataset.i + (e.clientY < r.top + r.height / 2 ? 0 : 1);
  if (to > dragFrom) to -= 1;
  const from = dragFrom; dragFrom = null;
  stMove(from, to);
  renderSettings();
});
$('stTable').addEventListener('dragend', () => { dragFrom = null; renderSettings(); });
$('settingsWin').addEventListener('mousedown', (e) => { if (!e.target.closest('input, button, .tbl')) { e.preventDefault(); $('stTable').focus({ preventScroll: true }); } });

/* ---------------------------------------------------------------- start */
(function start() {
  try { const t = localStorage.getItem('docsort-mock-theme'); if (t) setTheme(t); } catch (err) { /* storage unavailable */ }
  renderMenubar();
  resetFiling();
  render();
  scrollSelIntoView();
  setTimeout(() => { S.indexing = false; resultsCache.key = ''; renderPanel(); }, 700);
  focusStop('sidebar');
  onFocusChange();
})();
