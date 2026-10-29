// GRAFCET (norme NF EN 60848) : modèle, vérification, exécution, dessin, éditeur et
// traduction en Ladder.
// Modèle : { steps: [{id, initial, actions:[{type:'N'|'S'|'R', v, cond}], comment}],
//            transitions: [{id, from:[id], to:[id], cond}] }
const Grafcet = (() => {
  const empty = () => ({ steps: [], transitions: [] });

  // ctx : {table, cfg}
  function compile(g, ctx) {
    const diags = [];
    const steps = new Map();
    if (!g.steps.length) { diags.push(Diag.make('GRA-12', [], { tab: 'grafcet' })); return { diags, ok: false, elems: 0 }; }
    for (const s of g.steps) {
      if (steps.has(s.id)) diags.push(Diag.make('GRA-10', [s.id], { tab: 'grafcet' }));
      steps.set(s.id, s);
    }
    if (!g.steps.some((s) => s.initial)) diags.push(Diag.make('GRA-01', [], { tab: 'grafcet' }));
    const resolveVar = (name) => {
      if (/^X\d+$/i.test(name)) return 'X' + parseInt(name.slice(1), 10);
      return PLC.resolve(name, ctx.table);
    };
    const trans = [];
    const hasIn = new Set(), hasOut = new Set();
    for (const t of g.transitions) {
      const ct = { id: t.id, from: t.from.slice(), to: t.to.slice(), src: t.cond };
      if (!t.from.length) diags.push(Diag.make('GRA-04', [t.id, 'avant (amont)'], { tab: 'grafcet' }));
      if (!t.to.length) diags.push(Diag.make('GRA-04', [t.id, 'après (aval)'], { tab: 'grafcet' }));
      for (const s of t.from.concat(t.to)) if (!steps.has(s)) diags.push(Diag.make('GRA-03', [t.id, s], { tab: 'grafcet' }));
      t.from.forEach((s) => hasOut.add(s));
      t.to.forEach((s) => hasIn.add(s));
      try {
        ct.ast = Expr.parse(t.cond);
        for (const v of Expr.vars(ct.ast)) {
          const a = resolveVar(v);
          if (!a) diags.push(Diag.make('GRA-02', [t.id, `variable inconnue « ${v} »`,
            'Ce nom n\'est ni une mnémonique de la machine, ni une adresse, ni une étape Xn. Attention à l\'orthographe.'], { tab: 'grafcet' }));
          else if (a.startsWith('%')) {
            const c = PLC.checkAddr(a, ctx.cfg);
            if (!c.ok) diags.push(Diag.make('GRA-02', [t.id, `adresse ${a} inexistante`, c.reason], { tab: 'grafcet' }));
          } else if (!steps.has(+a.slice(1))) diags.push(Diag.make('GRA-02', [t.id, `l'étape ${a} n'existe pas`, 'Xn désigne l\'état de l\'étape n.'], { tab: 'grafcet' }));
        }
        for (const tp of Expr.tempos(ct.ast)) if (!steps.has(tp.step)) diags.push(Diag.make('GRA-11', [tp.step], { tab: 'grafcet' }));
        if (ct.ast.op === 'const' && ct.ast.v) diags.push(Diag.make('GRA-13', [t.id], { tab: 'grafcet' }));
      } catch (e) {
        diags.push(Diag.make('GRA-02', [t.id, e.message, e.help || ''], { tab: 'grafcet' }));
      }
      trans.push(ct);
    }
    const actions = [];
    for (const s of g.steps) {
      if (!s.initial && !hasIn.has(s.id)) diags.push(Diag.make('GRA-05', [s.id], { tab: 'grafcet' }));
      if (!hasOut.has(s.id)) diags.push(Diag.make('GRA-06', [s.id], { tab: 'grafcet' }));
      for (const a of s.actions || []) {
        if (!a.v) continue;
        const addr = PLC.resolve(a.v, ctx.table);
        if (!addr) { diags.push(Diag.make('GRA-07', [s.id, a.v], { tab: 'grafcet' })); continue; }
        const c = PLC.checkAddr(addr, ctx.cfg);
        if (c.kind === 'I') { diags.push(Diag.make('GRA-08', [s.id, a.v], { tab: 'grafcet' })); continue; }
        if (!c.ok) { diags.push(Diag.make('LAD-05', [`étape ${s.id}`, addr, c.reason], { tab: 'grafcet' })); continue; }
        let cond = null;
        if (a.cond && a.cond.trim()) {
          try { cond = Expr.parse(a.cond); } catch (e) {
            diags.push(Diag.make('GRA-02', [`(condition de l'action ${a.v}, étape ${s.id})`, e.message, e.help || ''], { tab: 'grafcet' }));
          }
        }
        actions.push({ step: s.id, type: a.type || 'N', addr, cond });
      }
    }
    return { diags, steps: g.steps.map((s) => ({ id: s.id, initial: !!s.initial })), trans, actions, resolveVar,
      elems: g.steps.length * 2 + g.transitions.length * 3 };
  }

  // État d'exécution
  function createState(prog) {
    const active = new Set(prog.steps.filter((s) => s.initial).map((s) => s.id));
    const since = {};
    active.forEach((s) => { since[s] = 0; });
    return { active, since, time: 0, conflicts: [] };
  }

  // Un cycle du GRAFCET : évaluation des transitions franchissables, franchissement
  // simultané, recherche de stabilité (évolutions fugaces), puis actions.
  function scan(prog, st, mem, dt) {
    st.time += dt;
    const ctx = {
      get: (name) => {
        const a = prog.resolveVar(name);
        if (!a) return false;
        if (a[0] === 'X') return st.active.has(+a.slice(1));
        return mem.get(a);
      },
      edge: (name, rising) => {
        const a = prog.resolveVar(name);
        const v = a && a[0] === 'X' ? st.active.has(+a.slice(1)) : mem.get(a);
        const prev = mem.prev.get('G:' + a);
        return rising ? v && prev === false : !v && prev === true;
      },
      tempo: (step, ms) => st.active.has(step) && st.time - st.since[step] >= ms,
    };
    st.conflicts = [];
    for (let iter = 0; iter < 8; iter++) {
      const fire = prog.trans.filter((t) => t.ast && t.from.length && t.from.every((s) => st.active.has(s)) && Expr.evaluate(t.ast, ctx));
      if (!fire.length) break;
      // conflits : deux transitions d'une même étape franchies ensemble
      const byStep = {};
      for (const t of fire) for (const s of t.from) (byStep[s] = byStep[s] || []).push(t.id);
      for (const [s, ids] of Object.entries(byStep)) if (ids.length > 1) st.conflicts.push({ step: s, ids });
      const deact = new Set(), act = new Set();
      for (const t of fire) { t.from.forEach((s) => deact.add(s)); t.to.forEach((s) => act.add(s)); }
      for (const s of deact) if (!act.has(s)) st.active.delete(s);
      for (const s of act) { if (!st.active.has(s) || deact.has(s)) st.since[s] = st.time; st.active.add(s); }
    }
    // mémorise les valeurs pour les fronts
    for (const t of prog.trans) if (t.ast) for (const v of Expr.vars(t.ast)) {
      const a = prog.resolveVar(v);
      if (!a) continue;
      mem.prev.set('G:' + a, a[0] === 'X' ? st.active.has(+a.slice(1)) : mem.get(a));
    }
    // actions : continues (N) = OU de toutes les étapes actives ; S/R mémorisées
    const cont = new Map();
    for (const a of prog.actions) if (a.type === 'N') cont.set(a.addr, false);
    for (const a of prog.actions) {
      if (!st.active.has(a.step)) continue;
      if (a.cond && !Expr.evaluate(a.cond, ctx)) continue;
      if (a.type === 'N') cont.set(a.addr, true);
      else if (a.type === 'S') mem.set(a.addr, true);
      else if (a.type === 'R') mem.set(a.addr, false);
    }
    for (const [addr, v] of cont) mem.set(addr, v);
  }

  // ---------------------------------------------------------------- Dessin
  const SW = 64, SH = 40, GX = 150, GY = 120;
  function layout(g) {
    const rank = {}, order = [];
    const stepIds = g.steps.map((s) => s.id);
    const queue = g.steps.filter((s) => s.initial).map((s) => s.id);
    if (!queue.length && stepIds.length) queue.push(stepIds[0]);
    queue.forEach((s) => { rank[s] = 0; order.push(s); });
    let changed = true, guard = 0;
    while (changed && guard++ < 200) {
      changed = false;
      for (const t of g.transitions) {
        if (!t.from.length || !t.from.every((s) => rank[s] != null)) continue;
        const r = Math.max(...t.from.map((s) => rank[s])) + 1;
        for (const s of t.to) if (rank[s] == null && stepIds.includes(s)) { rank[s] = r; order.push(s); changed = true; }
      }
    }
    let maxR = Math.max(0, ...Object.values(rank));
    for (const s of stepIds) if (rank[s] == null) { rank[s] = ++maxR; order.push(s); }
    // positions horizontales
    const pos = {}, used = {};
    const tx = {};
    const place = (s, want) => {
      const r = rank[s];
      used[r] = used[r] || [];
      let x = want;
      while (used[r].some((u) => Math.abs(u - x) < GX - 10)) x += GX;
      used[r].push(x);
      pos[s] = { x, y: 30 + r * GY };
    };
    for (const s of order) {
      if (pos[s]) continue;
      if (rank[s] === 0) { place(s, 0); continue; }
      // transition qui mène à cette étape en descendant
      const t = g.transitions.find((t) => t.to.includes(s) && t.from.length && t.from.every((f) => pos[f] && rank[f] < rank[s]));
      if (t) {
        const out = g.transitions.filter((o) => o.from.length && o.from[0] === t.from[0] && o.to.some((x) => rank[x] > rank[t.from[0]]));
        const idx = out.indexOf(t);
        const base = t.from.reduce((a, f) => a + pos[f].x, 0) / t.from.length + (idx - (out.length - 1) / 2) * GX;
        const k = t.to.indexOf(s);
        place(s, base + (k - (t.to.length - 1) / 2) * GX);
      } else place(s, 0);
    }
    const minX = Math.min(...Object.values(pos).map((p) => p.x), 0);
    for (const p of Object.values(pos)) p.x -= minX - 110;
    // transitions
    for (const t of g.transitions) {
      const from = t.from.filter((s) => pos[s]), to = t.to.filter((s) => pos[s]);
      if (!from.length) continue;
      const fx = from.reduce((a, s) => a + pos[s].x, 0) / from.length;
      const fy = Math.max(...from.map((s) => pos[s].y)) + SH;
      const forward = to.length && to.every((s) => rank[s] > Math.max(...from.map((f) => rank[f])));
      let x = fx;
      const siblings = g.transitions.filter((o) => o.from.length === 1 && from.length === 1 && o.from[0] === from[0]);
      if (siblings.length > 1) x = fx + (siblings.indexOf(t) - (siblings.length - 1) / 2) * GX;
      if (forward && to.length === 1 && siblings.length > 1) x = pos[to[0]].x;
      if (forward && to.length > 1) x = to.reduce((a, s) => a + pos[s].x, 0) / to.length;
      tx[t.id] = { x, y: fy + (forward ? Math.min(GY - SH, (Math.min(...to.map((s) => pos[s].y)) - fy)) / 2 : 30), forward, from, to };
    }
    const width = Math.max(...Object.values(pos).map((p) => p.x), 0) + 260;
    const height = Math.max(...Object.values(pos).map((p) => p.y), 0) + SH + 80;
    return { pos, tx, width, height };
  }

  function render(g, opt = {}) {
    const L = layout(g);
    const active = opt.active || new Set();
    const s = U.svg('svg', { class: 'grafcet-svg', width: L.width, height: L.height, viewBox: `0 0 ${L.width} ${L.height}` });
    const line = (pts, cls = 'g-link') => s.appendChild(U.svg('polyline', { points: pts.map((p) => p.join(',')).join(' '), class: cls, fill: 'none' }));
    let loopLane = 0;
    for (const t of g.transitions) {
      const T = L.tx[t.id];
      if (!T) continue;
      const lit = opt.fireable && opt.fireable.has(t.id);
      // liaisons amont
      if (T.from.length > 1) {
        const xs = T.from.map((f) => L.pos[f].x);
        const yb = T.y - 14;
        for (const f of T.from) line([[L.pos[f].x, L.pos[f].y + SH], [L.pos[f].x, yb]]);
        s.appendChild(U.svg('line', { x1: Math.min(...xs) - 10, y1: yb, x2: Math.max(...xs) + 10, y2: yb, class: 'g-double' }));
        s.appendChild(U.svg('line', { x1: Math.min(...xs) - 10, y1: yb + 4, x2: Math.max(...xs) + 10, y2: yb + 4, class: 'g-double' }));
        line([[T.x, yb + 4], [T.x, T.y]]);
      } else {
        const f = L.pos[T.from[0]];
        line([[f.x, f.y + SH], [f.x, T.y - 18], [T.x, T.y - 18], [T.x, T.y]]);
      }
      // barre de transition
      s.appendChild(U.svg('line', { x1: T.x - 16, y1: T.y, x2: T.x + 16, y2: T.y, class: 'g-trans' + (lit ? ' lit' : '') }));
      s.appendChild(U.svg('text', { x: T.x - 22, y: T.y + 5, 'text-anchor': 'end', class: 'g-tnum' }, `(${t.id})`));
      s.appendChild(U.svg('text', { x: T.x + 22, y: T.y + 5, class: 'g-cond' }, t.cond || '?'));
      // liaisons aval
      if (T.forward) {
        if (T.to.length > 1) {
          const xs = T.to.map((x) => L.pos[x].x);
          const yb = T.y + 14;
          line([[T.x, T.y], [T.x, yb]]);
          s.appendChild(U.svg('line', { x1: Math.min(...xs) - 10, y1: yb, x2: Math.max(...xs) + 10, y2: yb, class: 'g-double' }));
          s.appendChild(U.svg('line', { x1: Math.min(...xs) - 10, y1: yb + 4, x2: Math.max(...xs) + 10, y2: yb + 4, class: 'g-double' }));
          for (const x of T.to) line([[L.pos[x].x, yb + 4], [L.pos[x].x, L.pos[x].y]]);
        } else {
          const d = L.pos[T.to[0]];
          const ym = (T.y + d.y) / 2 + 6;
          line([[T.x, T.y], [T.x, ym], [d.x, ym], [d.x, d.y]]);
        }
      } else if (T.to.length) {
        // retour (reprise de séquence) : on passe par la gauche, flèche vers le haut
        const lane = 40 + (loopLane++ % 4) * 14;
        for (const x of T.to) {
          const d = L.pos[x];
          const minX = Math.min(d.x, T.x) - SW / 2 - lane;
          const yDown = T.y + 18;
          line([[T.x, T.y], [T.x, yDown], [minX, yDown], [minX, d.y - 16], [d.x, d.y - 16], [d.x, d.y]]);
          const ay = (yDown + d.y - 16) / 2;
          s.appendChild(U.svg('path', { d: `M${minX - 6} ${ay + 6} L${minX} ${ay - 4} L${minX + 6} ${ay + 6}`, class: 'g-arrow' }));
        }
      }
    }
    // étapes
    for (const st of g.steps) {
      const p = L.pos[st.id];
      if (!p) continue;
      const on = active.has(st.id);
      const gr = U.svg('g', { class: 'g-step' + (on ? ' active' : ''), 'data-step': st.id });
      gr.appendChild(U.svg('rect', { x: p.x - SW / 2, y: p.y, width: SW, height: SH, class: 'g-box' }));
      if (st.initial) gr.appendChild(U.svg('rect', { x: p.x - SW / 2 + 4, y: p.y + 4, width: SW - 8, height: SH - 8, class: 'g-box inner' }));
      gr.appendChild(U.svg('text', { x: p.x, y: p.y + SH / 2 + 6, 'text-anchor': 'middle', class: 'g-num' }, st.id));
      if (on) gr.appendChild(U.svg('circle', { cx: p.x, cy: p.y + SH - 7, r: 4, class: 'g-token' }));
      // actions
      const acts = (st.actions || []).filter((a) => a.v);
      if (acts.length) {
        gr.appendChild(U.svg('line', { x1: p.x + SW / 2, y1: p.y + SH / 2, x2: p.x + SW / 2 + 14, y2: p.y + SH / 2, class: 'g-link' }));
        let ax = p.x + SW / 2 + 14;
        for (const a of acts) {
          const txt = (a.type === 'S' ? `${a.v} := 1` : a.type === 'R' ? `${a.v} := 0` : a.v) + (a.cond ? `  si ${a.cond}` : '');
          const w = Math.max(48, txt.length * 7.4 + 14);
          gr.appendChild(U.svg('rect', { x: ax, y: p.y + 4, width: w, height: SH - 8, class: 'g-action' + (on ? ' on' : '') }));
          gr.appendChild(U.svg('text', { x: ax + w / 2, y: p.y + SH / 2 + 5, 'text-anchor': 'middle', class: 'g-atext' }, txt));
          if (a.type === 'S' || a.type === 'R') gr.appendChild(U.svg('path', { d: `M${ax + w / 2 - 5} ${p.y + 4} L${ax + w / 2} ${p.y - 4} L${ax + w / 2 + 5} ${p.y + 4}`, class: 'g-link' }));
          ax += w;
        }
      }
      if (st.comment) gr.appendChild(U.svg('text', { x: p.x - SW / 2 - 6, y: p.y + SH / 2 + 4, 'text-anchor': 'end', class: 'g-comment' }, st.comment));
      s.appendChild(gr);
    }
    return s;
  }

  // ---------------------------------------------------------------- Éditeur
  function parseList(str) {
    return String(str || '').split(/[,;\s]+/).filter(Boolean).map((x) => parseInt(x.replace(/^X/i, ''), 10)).filter((x) => !isNaN(x));
  }

  function renderEditor(root, ui) {
    U.clear(root);
    const g = ui.project.grafcet;
    const view = U.el('div', { class: 'grafcet-view' });
    view.appendChild(render(g, { active: ui.gstate ? ui.gstate.active : null }));
    root.appendChild(U.el('div', { class: 'card' },
      U.el('div', { class: 'card-title' }, 'Schéma (dessiné automatiquement)'),
      U.el('div', { class: 'grafcet-scroll' }, view),
      U.el('p', { class: 'hint' }, 'Le dessin se met à jour tout seul. Une étape active (jeton) apparaît en vert pendant la simulation. Double carré = étape initiale.')));

    // Étapes
    const stepsCard = U.el('div', { class: 'card' }, U.el('div', { class: 'card-title' }, 'Étapes et actions'));
    g.steps.forEach((st, i) => {
      const row = U.el('div', { class: 'g-row' },
        U.el('label', { class: 'g-field small' }, 'N°', U.el('input', { type: 'number', min: 0, value: st.id, onchange: (e) => { const old = st.id; st.id = parseInt(e.target.value, 10) || 0; renumber(old, st.id); ui.onChange(); } })),
        U.el('label', { class: 'g-check' }, U.el('input', { type: 'checkbox', checked: st.initial ? true : null, onchange: (e) => { st.initial = e.target.checked; ui.onChange(); } }), 'initiale'),
        U.el('input', { class: 'g-comment-in', placeholder: 'Commentaire (ex : attente)', value: st.comment || '', onchange: (e) => { st.comment = e.target.value; ui.onChange(); } }),
        U.el('button', { class: 'icon-btn danger', title: 'Supprimer l\'étape', onclick: () => { g.steps.splice(i, 1); ui.onChange(); } }, '🗑'));
      const acts = U.el('div', { class: 'g-actions' });
      (st.actions || []).forEach((a, j) => {
        acts.appendChild(U.el('div', { class: 'g-action-row' },
          U.el('select', { onchange: (e) => { a.type = e.target.value; ui.onChange(); } },
            [['N', 'continue'], ['S', 'mémorisée := 1'], ['R', 'mémorisée := 0']].map(([v, l]) => U.el('option', { value: v, selected: a.type === v ? true : null }, l))),
          varInput(a.v, (v) => { a.v = v; ui.onChange(); }, ui.outputs, 'action (ex : KM1)'),
          U.el('input', { class: 'g-cond-in', placeholder: 'condition (facultatif)', value: a.cond || '', onchange: (e) => { a.cond = e.target.value; ui.onChange(); } }),
          U.el('button', { class: 'icon-btn', title: 'Retirer l\'action', onclick: () => { st.actions.splice(j, 1); ui.onChange(); } }, '✕')));
      });
      acts.appendChild(U.el('button', { class: 'btn small', onclick: () => { (st.actions = st.actions || []).push({ type: 'N', v: '', cond: '' }); ui.onChange(); } }, '+ Action'));
      stepsCard.appendChild(U.el('div', { class: 'g-item' + (ui.gstate && ui.gstate.active.has(st.id) ? ' active' : '') }, row, acts));
    });
    stepsCard.appendChild(U.el('button', { class: 'btn primary', onclick: () => {
      const id = g.steps.length ? Math.max(...g.steps.map((s) => s.id)) + 1 : 0;
      g.steps.push({ id, initial: g.steps.length === 0, actions: [], comment: '' });
      ui.onChange();
    } }, '+ Étape'));
    root.appendChild(stepsCard);

    // Transitions
    const trCard = U.el('div', { class: 'card' }, U.el('div', { class: 'card-title' }, 'Transitions et réceptivités'),
      U.el('p', { class: 'hint' }, 'Écris la réceptivité avec « . » pour ET, « + » pour OU, « / » pour NON, « ↑ » pour un front montant, t/X2/3s pour une temporisation. Pour une divergence ou convergence en ET, sépare les étapes par des virgules (ex : 2,3).'));
    g.transitions.forEach((t, i) => {
      let err = '';
      try { Expr.parse(t.cond); } catch (e) { err = e.message; }
      trCard.appendChild(U.el('div', { class: 'g-item' },
        U.el('div', { class: 'g-row' },
          U.el('span', { class: 'g-tlabel' }, `(${t.id})`),
          U.el('label', { class: 'g-field' }, 'de', U.el('input', { value: t.from.join(','), placeholder: 'ex : 1', onchange: (e) => { t.from = parseList(e.target.value); ui.onChange(); } })),
          U.el('label', { class: 'g-field' }, 'vers', U.el('input', { value: t.to.join(','), placeholder: 'ex : 2', onchange: (e) => { t.to = parseList(e.target.value); ui.onChange(); } })),
          U.el('button', { class: 'icon-btn danger', title: 'Supprimer la transition', onclick: () => { g.transitions.splice(i, 1); ui.onChange(); } }, '🗑')),
        U.el('div', { class: 'g-row' },
          varInput(t.cond, (v) => { t.cond = v; ui.onChange(); }, ui.inputs, 'réceptivité (ex : dcy . S1)', 'g-recept'),
          U.el('div', { class: 'op-btns' }, ['.', '+', '/', '↑', '(', ')'].map((op) => U.el('button', { class: 'btn tiny', title: { '.': 'ET', '+': 'OU', '/': 'NON', '↑': 'front montant', '(': '', ')': '' }[op], onclick: (e) => {
            const inp = e.target.closest('.g-item').querySelector('.g-recept');
            inp.value = (inp.value + ' ' + op + (op === '/' || op === '↑' || op === '(' ? '' : ' ')).replace(/\s+/g, ' ').trimStart();
            inp.focus();
          } }, op)))),
        err ? U.el('div', { class: 'inline-err' }, '⚠ ' + err) : null));
    });
    trCard.appendChild(U.el('button', { class: 'btn primary', onclick: () => {
      const id = g.transitions.length ? Math.max(...g.transitions.map((t) => t.id)) + 1 : 0;
      const last = g.steps[g.steps.length - 1];
      g.transitions.push({ id, from: last ? [last.id] : [], to: [], cond: '' });
      ui.onChange();
    } }, '+ Transition'));
    root.appendChild(trCard);

    root.appendChild(U.el('div', { class: 'card' },
      U.el('div', { class: 'card-title' }, 'Traduire en Ladder'),
      U.el('p', {}, 'Le logiciel peut écrire pour toi le Ladder équivalent avec la méthode « Set / Reset » vue en cours. Chaque étape devient un bit interne %M, chaque transition un bit de franchissement. Compare ensuite avec ce que tu aurais fait !'),
      U.el('button', { class: 'btn primary', onclick: ui.convert }, 'Générer le Ladder équivalent')));

    function renumber(old, nw) {
      for (const t of g.transitions) {
        t.from = t.from.map((s) => (s === old ? nw : s));
        t.to = t.to.map((s) => (s === old ? nw : s));
      }
    }
  }

  function varInput(value, onChange, suggestions, placeholder, cls = '') {
    const id = 'dl' + Math.random().toString(36).slice(2, 8);
    return U.el('span', { class: 'var-in' },
      U.el('input', { class: cls, list: id, value: value || '', placeholder, autocapitalize: 'off', autocomplete: 'off', spellcheck: 'false', onchange: (e) => onChange(e.target.value.trim()) }),
      U.el('datalist', { id }, (suggestions || []).map((s) => U.el('option', { value: s.name }, s.label))));
  }

  // ---------------------------------------------------------------- GRAFCET → Ladder
  // Méthode : bits d'étape Xn → %Mn, bits de franchissement FTn → %M(200+n),
  // temporisations t/Xn/d → %Tk. Ordre : initialisation, tempos, transitions,
  // désactivations (R), activations (S), puis actions.
  function toLadder(g, cfg) {
    const notes = [];
    const cpu = PLC.cpuOf(cfg);
    const ftBase = cpu ? Math.min(200, cpu.mem - 64) : 200;
    const symbols = [];
    const stepSym = (id) => `X${id}`;
    for (const s of g.steps) symbols.push({ name: stepSym(s.id), addr: `%M${s.id}`, comment: `Étape ${s.id}${s.comment ? ' : ' + s.comment : ''}` });
    for (const t of g.transitions) symbols.push({ name: `FT${t.id}`, addr: `%M${ftBase + t.id}`, comment: `Franchissement de la transition ${t.id}` });
    const tempoMap = new Map();
    const tempoName = (step, ms) => {
      const k = `${step}/${ms}`;
      if (!tempoMap.has(k)) {
        const i = tempoMap.size;
        tempoMap.set(k, { name: `T_X${step}_${i}`, addr: `%T${i}`, step, ms });
        symbols.push({ name: `T_X${step}_${i}`, addr: `%T${i}`, comment: `Temporisation t/X${step}/${U.fmtDuration(ms)}` });
      }
      return tempoMap.get(k).name;
    };
    const lit = (l) => {
      if (l.kind === 'tempo') return { t: l.neg ? 'NC' : 'NO', v: tempoName(l.step, l.ms) };
      if (l.kind === 're') { if (l.neg) notes.push('Un « NON front » a été simplifié en contact fermé.'); return { t: l.neg ? 'NC' : 'P', v: l.name }; }
      if (l.kind === 'fe') return { t: l.neg ? 'NC' : 'N', v: l.name };
      return { t: l.neg ? 'NC' : 'NO', v: l.name };
    };
    const rungs = [];
    const add = (products, coils, comment) => { const r = Ladder.buildRung(products, coils, comment); if (r) rungs.push(r); };
    // 1. initialisation
    const init = g.steps.filter((s) => s.initial), others = g.steps.filter((s) => !s.initial);
    const initCoils = init.map((s) => ({ t: 'S', v: stepSym(s.id) })).concat(others.map((s) => ({ t: 'R', v: stepSym(s.id) })));
    for (let i = 0; i < initCoils.length; i += 6) add([[{ t: 'NO', v: 'INIT' }]], initCoils.slice(i, i + 6), i === 0 ? 'Initialisation : au premier cycle, on active les étapes initiales et on désactive les autres' : 'Initialisation (suite)');
    // 2. transitions
    const parsed = g.transitions.map((t) => { try { return { t, ast: Expr.parse(t.cond) }; } catch (e) { return { t, ast: null }; } });
    for (const { t, ast } of parsed) {
      if (!ast) { notes.push(`Transition ${t.id} ignorée : réceptivité incorrecte.`); continue; }
      const dnf = Expr.toDNF(ast);
      const xs = t.from.map((s) => ({ t: 'NO', v: stepSym(s) }));
      const prods = dnf.map((p) => xs.concat(p.map(lit)));
      if (!prods.length) { notes.push(`Transition ${t.id} : réceptivité toujours fausse.`); continue; }
      add(prods, [{ t: 'C', v: `FT${t.id}` }], `Transition ${t.id} franchissable : étape(s) ${t.from.join(', ')} active(s) ET réceptivité « ${t.cond} »`);
    }
    // 4. désactivation puis activation
    for (const { t, ast } of parsed) if (ast && t.from.length) add([[{ t: 'NO', v: `FT${t.id}` }]], t.from.map((s) => ({ t: 'R', v: stepSym(s) })), `Franchissement ${t.id} : désactivation de l'étape amont`);
    for (const { t, ast } of parsed) if (ast && t.to.length) add([[{ t: 'NO', v: `FT${t.id}` }]], t.to.map((s) => ({ t: 'S', v: stepSym(s) })), `Franchissement ${t.id} : activation de l'étape aval`);
    // 5. actions
    const cont = new Map();
    for (const s of g.steps) for (const a of s.actions || []) {
      if (!a.v) continue;
      let conds = [[]];
      if (a.cond && a.cond.trim()) { try { conds = Expr.toDNF(Expr.parse(a.cond)); } catch (e) { conds = [[]]; } }
      const prods = conds.map((p) => [{ t: 'NO', v: stepSym(s.id) }].concat(p.map(lit)));
      if (a.type === 'N') { if (!cont.has(a.v)) cont.set(a.v, []); cont.get(a.v).push(...prods); }
      else add(prods, [{ t: a.type, v: a.v }], `Action mémorisée de l'étape ${s.id} : ${a.v} := ${a.type === 'S' ? 1 : 0}`);
    }
    for (const [v, prods] of cont) add(prods, [{ t: 'C', v }], `Sortie ${v} : active dans les étapes ${[...new Set(prods.map((p) => p[0].v))].join(', ')} (une seule bobine par sortie !)`);
    // 6. temporisations : placées juste après l'initialisation pour être à jour avant les transitions
    const tempoRungs = [];
    for (const tp of tempoMap.values()) {
      tempoRungs.push(Ladder.buildRung([[{ t: 'NO', v: stepSym(tp.step) }]], [{ t: 'TON', v: tp.name, p: tp.ms }], `Temporisation : compte ${U.fmtDuration(tp.ms)} depuis l'activation de l'étape ${tp.step}`));
    }
    rungs.splice(Math.ceil(initCoils.length / 6), 0, ...tempoRungs);
    return { rungs, symbols, notes };
  }

  return { empty, compile, createState, scan, render, renderEditor, toLadder, layout };
})();
