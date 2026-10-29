// Langage Ladder (schéma à contacts) : modèle, vérification, exécution et éditeur.
// Une ligne (« rung ») est une grille de `rows` rangées × 8 colonnes.
// Colonnes 0 à 6 : contacts et fils. Colonne 7 : bobines / blocs.
// Liaison verticale « r,c » : relie la sortie (côté droit) de la case (r,c) à celle de (r+1,c).
const Ladder = (() => {
  const COLS = 8, COIL = 7;
  const CONTACTS = ['NO', 'NC', 'P', 'N'];
  const COILS = ['C', 'CN', 'S', 'R', 'TON', 'TOF', 'CTU'];
  const LABEL = {
    NO: 'Contact ouvert (NO) : laisse passer quand la variable vaut 1',
    NC: 'Contact fermé (NC) : laisse passer quand la variable vaut 0',
    P: 'Front montant : laisse passer UN seul cycle quand la variable passe de 0 à 1',
    N: 'Front descendant : UN seul cycle quand la variable passe de 1 à 0',
    H: 'Fil horizontal : relie deux cases',
    C: 'Bobine : variable = 1 tant que la ligne est alimentée',
    CN: 'Bobine inverse : variable = 0 quand la ligne est alimentée',
    S: 'Bobine SET (mise à 1 mémorisée) : reste à 1 même si la ligne n\'est plus alimentée',
    R: 'Bobine RESET (mise à 0)',
    TON: 'Temporisation à l\'enclenchement : %T passe à 1 après la durée, si l\'entrée reste à 1',
    TOF: 'Temporisation au déclenchement : %T reste à 1 pendant la durée après que l\'entrée retombe',
    CTU: 'Compteur : +1 à chaque front montant ; %C passe à 1 quand la valeur atteint la présélection',
  };

  const newRung = () => ({ comment: '', rows: 1, cells: {}, v: [] });
  const key = (r, c) => `${r},${c}`;

  function groups(rung, c) {
    // regroupe les rangées reliées par des liaisons verticales à la colonne c
    const parent = [...Array(rung.rows).keys()];
    const find = (x) => (parent[x] === x ? x : (parent[x] = find(parent[x])));
    for (const l of rung.v) {
      const [r, cc] = l.split(',').map(Number);
      if (cc === c && r + 1 < rung.rows) parent[find(r)] = find(r + 1);
    }
    return (r) => find(r);
  }

  // Propagation de la « puissance » à travers la grille.
  // conducts(cell, r, c) → bool. Retourne {out: {key: bool}, coilIn: {r: bool}}
  function flow(rung, conducts) {
    const out = {}, coilIn = {};
    let inp = new Array(rung.rows).fill(true); // rail de gauche
    for (let c = 0; c < COLS; c++) {
      const o = new Array(rung.rows).fill(false);
      for (let r = 0; r < rung.rows; r++) {
        const cell = rung.cells[key(r, c)];
        if (!cell) continue;
        if (c === COIL) { coilIn[r] = inp[r]; o[r] = inp[r]; }
        else o[r] = inp[r] && conducts(cell, r, c);
        out[key(r, c)] = o[r];
      }
      if (c === COIL) break;
      const g = groups(rung, c);
      const acc = {};
      for (let r = 0; r < rung.rows; r++) acc[g(r)] = acc[g(r)] || o[r];
      inp = inp.map((_, r) => !!acc[g(r)]);
    }
    return { out, coilIn };
  }

  // Cases dont la sortie peut atteindre une bobine (parcours inverse)
  function reachesCoil(rung) {
    const res = {};
    for (let c = COIL; c >= 0; c--) {
      const g = c < COIL ? groups(rung, c) : null;
      for (let r = 0; r < rung.rows; r++) {
        const cell = rung.cells[key(r, c)];
        if (!cell) continue;
        if (c === COIL) { res[key(r, c)] = true; continue; }
        let ok = false;
        for (let r2 = 0; r2 < rung.rows && !ok; r2++) if (g(r2) === g(r) && res[key(r2, c + 1)]) ok = true;
        res[key(r, c)] = ok;
      }
    }
    return res;
  }

  // Vérifie et « compile » le programme. ctx : {table, cfg, wiredOut:Set, mode}
  function compile(ladder, ctx) {
    const diags = [];
    const rungs = [];
    const coilUse = {};
    let elems = 0;
    ladder.rungs.forEach((rung, ri) => {
      const n = ri + 1;
      const cells = Object.entries(rung.cells);
      if (!cells.length) return;
      elems += cells.length;
      const res = { rows: rung.rows, cells: {}, v: rung.v.slice() };
      let hasCoil = false, missingVar = false;
      for (const [k, cell] of cells) {
        const isCoil = COILS.includes(cell.t);
        if (isCoil) hasCoil = true;
        if (cell.t === 'H') { res.cells[k] = { t: 'H' }; continue; }
        if (!cell.v) { missingVar = true; res.cells[k] = { t: cell.t }; continue; }
        const addr = PLC.resolve(cell.v, ctx.table);
        if (!addr) { diags.push(Diag.make('LAD-03', [n, cell.v], { tab: 'ladder', rung: ri })); res.cells[k] = { t: cell.t }; continue; }
        const a = PLC.checkAddr(addr, ctx.cfg);
        if (!a.ok) diags.push(Diag.make('LAD-05', [n, addr, a.reason], { tab: 'ladder', rung: ri }));
        if (isCoil) {
          if (a.kind === 'I') diags.push(Diag.make('LAD-04', [n, cell.v.startsWith('%') ? addr : `${cell.v} = ${addr}`], { tab: 'ladder', rung: ri }));
          if (a.kind === 'S') diags.push(Diag.make('LAD-15', [n, addr], { tab: 'ladder', rung: ri }));
          if ((cell.t === 'TON' || cell.t === 'TOF') && a.kind !== 'T') diags.push(Diag.make('LAD-10', [n, cell.v, '%T'], { tab: 'ladder', rung: ri }));
          if (cell.t === 'CTU' && a.kind !== 'C') diags.push(Diag.make('LAD-10', [n, cell.v, '%C'], { tab: 'ladder', rung: ri }));
          if ((cell.t === 'TON' || cell.t === 'TOF') && !(cell.p > 0)) diags.push(Diag.make('LAD-09', [n, cell.v], { tab: 'ladder', rung: ri }));
          if (cell.t === 'CTU' && !(cell.p > 0)) diags.push(Diag.make('LAD-13', [n, cell.v], { tab: 'ladder', rung: ri }));
          if (cell.t === 'C' || cell.t === 'CN') (coilUse[addr] = coilUse[addr] || { name: cell.v, rungs: [] }).rungs.push(n);
          if (a.kind === 'Q' && !ctx.wiredOut.has(addr)) diags.push(Diag.make('LAD-12', [`${cell.v} (${addr})`], { tab: 'ladder', rung: ri }));
        }
        res.cells[k] = { t: cell.t, a: addr, p: cell.p };
      }
      if (missingVar) diags.push(Diag.make('LAD-02', [n], { tab: 'ladder', rung: ri }));
      if (!hasCoil) { diags.push(Diag.make('LAD-01', [n], { tab: 'ladder', rung: ri })); return; }
      // structure
      const all = flow(rung, () => true);
      const none = flow(rung, (cell) => cell.t === 'H');
      const reach = reachesCoil(rung);
      let cut = false, dangling = false, always = false;
      for (let r = 0; r < rung.rows; r++) {
        if (!rung.cells[key(r, COIL)]) continue;
        if (!all.coilIn[r]) cut = true;
        else if (none.coilIn[r]) always = true;
      }
      for (const [k] of cells) {
        const c = +k.split(',')[1];
        if (c === COIL) continue;
        if (!all.out[k] || !reach[k]) dangling = true;
      }
      if (cut) diags.push(Diag.make('LAD-06', [n], { tab: 'ladder', rung: ri }));
      else if (dangling) diags.push(Diag.make('LAD-07', [n], { tab: 'ladder', rung: ri }));
      if (always) diags.push(Diag.make('LAD-11', [n], { tab: 'ladder', rung: ri }));
      res.index = ri;
      rungs.push(res);
    });
    for (const [addr, u] of Object.entries(coilUse)) {
      const uniq = [...new Set(u.rungs)];
      if (uniq.length > 1) diags.push(Diag.make('LAD-08', [`${u.name} (${addr})`, uniq.join(' et ')], { tab: 'ladder', rung: uniq[0] - 1 }));
    }
    if (!elems && ctx.mode === 'ladder') diags.push(Diag.make('LAD-14', [], { tab: 'ladder' }));
    return { rungs, diags, elems };
  }

  // Exécution d'un cycle. Retourne la puissance de chaque case (pour l'affichage).
  function scan(prog, mem, dt) {
    const live = {};
    for (const rung of prog.rungs) {
      const ri = rung.index;
      const f = flow(rung, (cell, r, c) => {
        if (cell.t === 'H') return true;
        if (!cell.a) return false;
        const v = mem.get(cell.a);
        const pk = `L${ri}:${r},${c}`;
        if (cell.t === 'NO') return v;
        if (cell.t === 'NC') return !v;
        const prev = mem.prev.get(pk);
        mem.prev.set(pk, v);
        if (cell.t === 'P') return v && prev === false;
        if (cell.t === 'N') return !v && prev === true;
        return false;
      });
      for (let r = 0; r < rung.rows; r++) {
        const cell = rung.cells[key(r, COIL)];
        if (!cell || !cell.a) continue;
        const p = !!f.coilIn[r];
        switch (cell.t) {
          case 'C': mem.set(cell.a, p); break;
          case 'CN': mem.set(cell.a, !p); break;
          case 'S': if (p) mem.set(cell.a, true); break;
          case 'R':
            if (p) {
              if (cell.a.startsWith('%C')) mem.resetCounter(cell.a);
              else if (cell.a.startsWith('%T')) mem.resetTimer(cell.a);
              else mem.set(cell.a, false);
            }
            break;
          case 'TON': case 'TOF': mem.timer(cell.a, cell.t, p, cell.p || 0, dt); break;
          case 'CTU': mem.counter(cell.a, p, cell.p || 0, `L${ri}:${r}`); break;
        }
      }
      live[ri] = f.out;
    }
    return live;
  }

  // ---------------------------------------------------------------- Éditeur
  const TOOLS = [
    { id: 'NO', sym: '┤ ├', name: 'Contact NO' },
    { id: 'NC', sym: '┤/├', name: 'Contact NC' },
    { id: 'P', sym: '┤P├', name: 'Front ↑' },
    { id: 'N', sym: '┤N├', name: 'Front ↓' },
    { id: 'H', sym: '───', name: 'Fil' },
    { id: 'V', sym: ' │ ', name: 'Liaison ↓' },
    { id: 'C', sym: '( )', name: 'Bobine' },
    { id: 'CN', sym: '(/)', name: 'Bobine inv.' },
    { id: 'S', sym: '(S)', name: 'Set' },
    { id: 'R', sym: '(R)', name: 'Reset' },
    { id: 'TON', sym: 'TON', name: 'Tempo TON' },
    { id: 'TOF', sym: 'TOF', name: 'Tempo TOF' },
    { id: 'CTU', sym: 'CTU', name: 'Compteur' },
    { id: 'EDIT', sym: '✎', name: 'Modifier' },
    { id: 'DEL', sym: '⌫', name: 'Effacer' },
  ];

  const CW = 64, CH = 54;
  function cellSVG(cell, powered, name, extra) {
    const g = U.svg('svg', { viewBox: `0 0 ${CW} ${CH}`, class: 'cell-svg' });
    const y = 30;
    const col = powered ? 'var(--on)' : 'var(--wire)';
    const line = (x1, x2) => g.appendChild(U.svg('line', { x1, y1: y, x2, y2: y, stroke: col, 'stroke-width': 2.5 }));
    if (!cell) return g;
    const label = (txt, cls = 'cell-var') => g.appendChild(U.svg('text', { x: CW / 2, y: 12, 'text-anchor': 'middle', class: cls }, txt));
    if (cell.t === 'H') { line(0, CW); return g; }
    if (CONTACTS.includes(cell.t)) {
      line(0, 22); line(42, CW);
      g.appendChild(U.svg('line', { x1: 22, y1: y - 11, x2: 22, y2: y + 11, stroke: col, 'stroke-width': 2.5 }));
      g.appendChild(U.svg('line', { x1: 42, y1: y - 11, x2: 42, y2: y + 11, stroke: col, 'stroke-width': 2.5 }));
      if (cell.t === 'NC') g.appendChild(U.svg('line', { x1: 24, y1: y + 10, x2: 40, y2: y - 10, stroke: col, 'stroke-width': 2 }));
      if (cell.t === 'P' || cell.t === 'N') g.appendChild(U.svg('text', { x: 32, y: y + 5, 'text-anchor': 'middle', class: 'cell-mark' }, cell.t));
      if (extra && extra.value) g.appendChild(U.svg('rect', { x: 23, y: y - 9, width: 18, height: 18, fill: 'var(--on)', opacity: 0.25 }));
      label(short(name) || '???', name ? 'cell-var' : 'cell-var missing');
      return g;
    }
    // bobines et blocs
    line(0, 18);
    if (['TON', 'TOF', 'CTU'].includes(cell.t)) {
      g.appendChild(U.svg('rect', { x: 18, y: y - 13, width: 40, height: 22, rx: 3, fill: extra && extra.value ? 'var(--on-soft)' : 'var(--panel)', stroke: col, 'stroke-width': 2 }));
      g.appendChild(U.svg('text', { x: 38, y: y + 2, 'text-anchor': 'middle', class: 'cell-mark' }, cell.t));
      const sub = cell.t === 'CTU' ? `PV=${cell.p || '?'}${extra && extra.cv != null ? ' CV=' + extra.cv : ''}`
        : `${U.fmtDuration(cell.p) || '?'}${extra && extra.et != null && extra.et > 0 ? ' ' + (extra.et / 1000).toFixed(1) : ''}`;
      g.appendChild(U.svg('text', { x: 38, y: y + 21, 'text-anchor': 'middle', class: 'cell-sub' }, sub));
    } else {
      g.appendChild(U.svg('path', { d: `M28 ${y - 12} Q20 ${y} 28 ${y + 12}`, fill: 'none', stroke: col, 'stroke-width': 2.5 }));
      g.appendChild(U.svg('path', { d: `M40 ${y - 12} Q48 ${y} 40 ${y + 12}`, fill: 'none', stroke: col, 'stroke-width': 2.5 }));
      if (extra && extra.value) g.appendChild(U.svg('circle', { cx: 34, cy: y, r: 7, fill: 'var(--on)', opacity: 0.35 }));
      const mark = { CN: '/', S: 'S', R: 'R' }[cell.t];
      if (mark) g.appendChild(U.svg('text', { x: 34, y: y + 5, 'text-anchor': 'middle', class: 'cell-mark' }, mark));
      line(48, CW);
    }
    label(short(name) || '???', name ? 'cell-var' : 'cell-var missing');
    return g;
  }
  const short = (n) => (n && n.length > 8 ? n.slice(0, 7) + '…' : n);

  // ui : {project, live, mem, table, onChange, pickVar(cell) → Promise}
  function renderEditor(root, ui) {
    U.clear(root);
    const lad = ui.project.ladder;
    let tool = ui.state.tool || 'NO';
    const palette = U.el('div', { class: 'palette', role: 'toolbar', 'aria-label': 'Outils Ladder' });
    for (const t of TOOLS) {
      palette.appendChild(U.el('button', {
        class: 'tool' + (t.id === tool ? ' active' : ''), title: LABEL[t.id] || t.name,
        onclick: () => { ui.state.tool = t.id; renderEditor(root, ui); },
      }, U.el('span', { class: 'tool-sym' }, t.sym), U.el('span', { class: 'tool-name' }, t.name)));
    }
    root.appendChild(palette);
    root.appendChild(U.el('p', { class: 'hint' }, toolHint(tool)));

    lad.rungs.forEach((rung, ri) => {
      const box = U.el('div', { class: 'rung' + (ui.state.focusRung === ri ? ' focus' : '') });
      const head = U.el('div', { class: 'rung-head' },
        U.el('span', { class: 'rung-num' }, `L${ri + 1}`),
        U.el('input', { class: 'rung-comment', value: rung.comment || '', placeholder: 'Commentaire (à quoi sert cette ligne ?)',
          onchange: (e) => { rung.comment = e.target.value; ui.onChange(false); } }),
        U.el('button', { class: 'icon-btn', title: 'Monter', onclick: () => move(ri, -1) }, '↑'),
        U.el('button', { class: 'icon-btn', title: 'Descendre', onclick: () => move(ri, 1) }, '↓'),
        U.el('button', { class: 'icon-btn', title: 'Ajouter une rangée (branche parallèle)', onclick: () => { rung.rows++; ui.onChange(); } }, '+⎸'),
        U.el('button', { class: 'icon-btn', title: 'Retirer la dernière rangée', onclick: () => removeRow(rung) }, '−⎸'),
        U.el('button', { class: 'icon-btn danger', title: 'Supprimer la ligne', onclick: () => { if (confirm(`Supprimer la ligne L${ri + 1} ?`)) { lad.rungs.splice(ri, 1); ui.onChange(); } } }, '🗑'));
      box.appendChild(head);
      const scroller = U.el('div', { class: 'rung-scroll' });
      const grid = U.el('div', { class: 'rung-grid', style: { gridTemplateColumns: `6px repeat(${COLS}, var(--cw)) 6px` } });
      const live = ui.live && ui.live[ri];
      for (let r = 0; r < rung.rows; r++) {
        grid.appendChild(U.el('div', { class: 'rail left' + (ui.running ? ' on' : '') }));
        for (let c = 0; c < COLS; c++) {
          const k = key(r, c);
          const cell = rung.cells[k];
          const powered = !!(live && live[k]);
          const extra = cell ? cellExtra(cell, ui) : null;
          const name = cell && cell.v ? cell.v : '';
          const div = U.el('div', {
            class: 'cell' + (c === COIL ? ' coilcol' : '') + (cell ? '' : ' empty'),
            title: cell ? `${LABEL[cell.t] || ''}${cell.v ? ' — ' + cell.v : ''}` : (c === COIL ? 'Colonne des bobines' : 'Case vide'),
            onclick: () => applyTool(rung, r, c),
          }, cellSVG(cell, powered, name, extra));
          if (rung.v.includes(k)) div.appendChild(U.el('div', { class: 'vlink' + (powered || (live && live[key(r + 1, c)]) ? ' on' : '') }));
          grid.appendChild(div);
        }
        grid.appendChild(U.el('div', { class: 'rail right' + (ui.running ? ' on' : '') }));
      }
      scroller.appendChild(grid);
      box.appendChild(scroller);
      root.appendChild(box);
    });

    root.appendChild(U.el('div', { class: 'row-btns' },
      U.el('button', { class: 'btn primary', onclick: () => { lad.rungs.push(newRung()); ui.state.focusRung = lad.rungs.length - 1; ui.onChange(); } }, '+ Ligne'),
      U.el('button', { class: 'btn', onclick: () => { if (confirm('Effacer tout le programme Ladder ?')) { lad.rungs = []; ui.onChange(); } } }, 'Tout effacer')));

    function toolHint(t) {
      if (t === 'V') return 'Liaison verticale : touche une case pour relier sa sortie (côté droit) à la rangée du dessous. Sert à faire des branches en parallèle (= OU).';
      if (t === 'EDIT') return 'Touche un élément pour changer sa variable ou sa durée.';
      if (t === 'DEL') return 'Touche une case pour l\'effacer.';
      if (COILS.includes(t)) return `${LABEL[t]}. Les bobines se placent dans la dernière colonne (à droite).`;
      return LABEL[t] || '';
    }
    function move(ri, d) {
      const j = ri + d;
      if (j < 0 || j >= lad.rungs.length) return;
      [lad.rungs[ri], lad.rungs[j]] = [lad.rungs[j], lad.rungs[ri]];
      ui.onChange();
    }
    function removeRow(rung) {
      if (rung.rows <= 1) return;
      const r = rung.rows - 1;
      for (let c = 0; c < COLS; c++) delete rung.cells[key(r, c)];
      rung.v = rung.v.filter((l) => +l.split(',')[0] < r - 1);
      rung.rows--;
      ui.onChange();
    }
    async function applyTool(rung, r, c) {
      const k = key(r, c);
      ui.state.focusRung = lad.rungs.indexOf(rung);
      if (tool === 'DEL') { delete rung.cells[k]; rung.v = rung.v.filter((l) => l !== k); ui.onChange(); return; }
      if (tool === 'V') {
        if (c === COIL) { U.toast('Pas de liaison verticale après la colonne des bobines.', 'warn'); return; }
        if (r + 1 >= rung.rows) rung.rows++;
        const i = rung.v.indexOf(k);
        if (i >= 0) rung.v.splice(i, 1); else rung.v.push(k);
        ui.onChange(); return;
      }
      if (tool === 'EDIT') {
        const cell = rung.cells[k];
        if (!cell || cell.t === 'H') return;
        const res = await ui.pickVar(cell);
        if (res) { Object.assign(cell, res); ui.onChange(); }
        return;
      }
      const isCoil = COILS.includes(tool);
      if (isCoil && c !== COIL) { U.toast('Une bobine se place dans la DERNIÈRE colonne (à droite).', 'warn'); return; }
      if (!isCoil && c === COIL) { U.toast('La dernière colonne est réservée aux bobines. Place les contacts à gauche.', 'warn'); return; }
      if (tool === 'H') { rung.cells[k] = { t: 'H' }; ui.onChange(); return; }
      const old = rung.cells[k];
      const cell = { t: tool, v: old && old.t !== 'H' ? old.v : '', p: old ? old.p : undefined };
      const res = await ui.pickVar(cell);
      if (!res) return;
      rung.cells[k] = Object.assign(cell, res);
      // complète automatiquement avec des fils jusqu'à la bobine pour aider les débutants
      ui.onChange();
    }
  }

  function cellExtra(cell, ui) {
    if (!ui.running || !ui.mem || !cell.v || cell.t === 'H') return null;
    const addr = PLC.resolve(cell.v, ui.table);
    if (!addr) return null;
    if (cell.t === 'TON' || cell.t === 'TOF') { const t = ui.mem.timers[addr]; return { value: t && t.q, et: t ? t.et : 0 }; }
    if (cell.t === 'CTU') { const cc = ui.mem.counters[addr]; return { value: cc && cc.q, cv: cc ? cc.cv : 0 }; }
    return { value: ui.mem.get(addr) };
  }

  // Construit une ligne à partir de produits (somme de produits) et d'une liste de bobines.
  // products : [[{t:'NO'|'NC'|'P'|'N', v}...]...] ; coils : [{t, v, p}]
  function buildRung(products, coils, comment = '') {
    if (!products.length) return null;
    const rows = Math.max(products.length, coils.length);
    const rung = { comment, rows, cells: {}, v: [] };
    products.forEach((prod, r) => {
      if (prod.length > COIL) throw new Error(`Trop de conditions en série (${prod.length}) pour une seule ligne (7 maximum).`);
      for (let c = 0; c < COIL; c++) rung.cells[key(r, c)] = c < prod.length ? { t: prod[c].t, v: prod[c].v } : { t: 'H' };
    });
    coils.forEach((cl, r) => { rung.cells[key(r, COIL)] = { t: cl.t, v: cl.v, p: cl.p }; });
    for (let r = 0; r + 1 < rows; r++) rung.v.push(key(r, COIL - 1));
    // les rangées de bobines seules n'ont pas de contacts : elles reçoivent le courant par la liaison verticale
    return rung;
  }

  return { COLS, COIL, CONTACTS, COILS, LABEL, newRung, compile, scan, renderEditor, buildRung, key };
})();
