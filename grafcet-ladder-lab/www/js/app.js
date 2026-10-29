// Application : navigation, atelier (automate, câblage, programmes, machine,
// diagnostic), boucle de simulation, tutoriels, cours, quiz et aide.
const App = (() => {
  const { el, clear, toast, modal } = U;
  const view = document.getElementById('view');

  // ------------------------------------------------------------ Projet
  function newProject(machineId, mode = 'ladder') {
    const m = Machines.byId[machineId];
    return {
      version: 1, name: m.name, machine: machineId, config: PLC.defaultConfig(),
      wiring: Object.assign({}, m.defaultWiring), symbols: [], mode,
      ladder: { rungs: [] },
      grafcet: { steps: [{ id: 0, initial: true, actions: [], comment: 'attente' }], transitions: [] },
    };
  }

  const S = {
    view: 'home', tab: 'machine', course: null,
    project: U.load('project', null) || newProject('convoyeur'),
    tuto: U.load('tuto', null), // {id, step}
    progress: U.load('progress', {}), // {tid: {done:bool, steps:{i:true}}}
    quizBest: U.load('quizBest', 0),
    ladderUI: { tool: 'NO' },
  };
  const machine = () => Machines.byId[S.project.machine];

  // ------------------------------------------------------------ Simulation
  const RT = { plc: null, running: false, cpuFault: null, mstate: null, mview: null, live: null, last: 0, sig: null, faultShown: false, outs: {}, ins: {} };
  function resetMachine() { RT.mstate = machine().create(); RT.faultShown = false; RT.mview = null; }
  resetMachine();

  function sig(p) { return JSON.stringify([p.config, p.wiring, p.symbols, p.mode, p.mode === 'ladder' ? p.ladder : p.grafcet]); }

  let compiled = null;
  function compileProject() {
    const p = S.project, m = machine();
    const table = PLC.symbolTable(p, m);
    const wiredOut = new Set(m.io.filter((io) => io.kind === 'DO' && p.wiring[io.sym]).map((io) => p.wiring[io.sym].toUpperCase()));
    const ctx = { table, cfg: p.config, wiredOut, mode: p.mode };
    const prog = p.mode === 'ladder' ? Ladder.compile(p.ladder, ctx) : Grafcet.compile(p.grafcet, ctx);
    const cfgDiags = PLC.validateConfig(p.config, prog.elems);
    const wireDiags = PLC.validateWiring(p, m);
    const progDiags = prog.diags;
    compiled = { table, prog, cfgDiags, wireDiags, progDiags, all: cfgDiags.concat(wireDiags, progDiags), cycle: PLC.cycleTime(p.config, prog.elems) };
    return compiled;
  }

  function transfer() {
    const c = compileProject();
    if (Diag.hasErrors(c.all)) {
      const n = c.all.filter((d) => d.level === 'error').length;
      modal('Transfert impossible', el('div', {},
        el('p', {}, Diag.make('RUN-01').why),
        el('p', {}, `${n} erreur(s) à corriger. Les explications sont dans l'onglet Diagnostic.`)),
      [{ label: 'Voir le diagnostic', value: 'go', primary: true }, { label: 'Fermer', value: null }]).then((v) => { if (v === 'go') { S.tab = 'diag'; render(); } });
      return false;
    }
    const p = S.project;
    RT.plc = {
      prog: c.prog, mode: p.mode, cfg: U.clone(p.config), wiring: U.clone(p.wiring), cycle: c.cycle,
      mem: new PLC.Memory(), gstate: p.mode === 'grafcet' ? Grafcet.createState(c.prog) : null, table: c.table,
    };
    RT.sig = sig(p);
    RT.running = false; RT.cpuFault = null; RT.live = null;
    toast(`Transfert réussi vers ${p.config.ip} ✔ — passe en RUN`, 'ok');
    renderRunBar();
    return true;
  }

  function setRun(on) {
    if (on && !RT.plc) { if (!transfer()) return; }
    if (on && RT.cpuFault) { toast('Le CPU est en défaut : refais un transfert.', 'warn'); return; }
    RT.running = on;
    if (on && RT.plc) {
      RT.plc.mem = new PLC.Memory();
      if (RT.plc.mode === 'grafcet') RT.plc.gstate = Grafcet.createState(RT.plc.prog);
    }
    if (!on) RT.live = null;
    renderRunBar();
    if (S.tab === 'ladder' || S.tab === 'grafcet') renderTab();
  }

  function moduleAt(cfg, addr) {
    const a = PLC.checkAddr(addr, cfg);
    return a.ok ? a.module : null;
  }

  let acc = 0, uiAcc = 0, tutoAcc = 0;
  function tick(now) {
    const dt = Math.min(100, now - (RT.last || now));
    RT.last = now;
    const m = machine(), st = RT.mstate;
    const plc = RT.plc;
    const cfg = plc ? plc.cfg : S.project.config;
    const wiring = plc ? plc.wiring : S.project.wiring;
    // 1. entrées physiques → image des entrées
    const phys = m.inputs(st);
    RT.ins = phys;
    const mem = plc ? plc.mem : null;
    for (const io of m.io) {
      if (io.kind !== 'DI' || !mem) continue;
      const addr = wiring[io.sym];
      if (!addr) continue;
      const mod = moduleAt(cfg, addr);
      if (!mod || PLC.CATALOG[mod.type].kind !== 'DI') continue;
      const logicOk = !io.sensor || (mod.logic || 'PNP') === io.sensor;
      mem.set(addr.toUpperCase(), logicOk && !!phys[io.sym]);
    }
    // 2. traitement
    if (plc && RT.running && !st.fault) {
      acc += dt;
      const period = plc.cfg.task.mode === 'periodique' ? Math.max(plc.cfg.task.period, 5) : 10;
      let n = 0;
      while (acc >= period && n < 10) {
        acc -= period; n++;
        mem.clock += period;
        if (plc.cycle > plc.cfg.watchdog) { RT.cpuFault = Diag.make('RUN-02', [plc.cycle, plc.cfg.watchdog]); RT.running = false; renderRunBar(); break; }
        if (plc.mode === 'ladder') RT.live = Ladder.scan(plc.prog, mem, period);
        else Grafcet.scan(plc.prog, plc.gstate, mem, period);
        mem.firstCycle = false;
      }
    } else acc = 0;
    // 3. sorties → actionneurs
    const outs = {};
    for (const io of m.io) {
      if (io.kind !== 'DO') continue;
      const addr = wiring[io.sym];
      let on = false;
      if (plc && RT.running && addr) {
        const mod = moduleAt(cfg, addr);
        if (mod && PLC.CATALOG[mod.type].kind === 'DO' && PLC.CATALOG[mod.type].volts.includes(io.volt)) on = mem.get(addr.toUpperCase());
      }
      outs[io.sym] = on;
    }
    RT.outs = outs;
    if (!st.fault) { st.t += dt; m.step(st, outs, dt); }
    // 4. affichage
    uiAcc += dt; tutoAcc += dt;
    if (S.view === 'workshop') {
      if (S.tab === 'machine') updateMachineView();
      if (uiAcc > 160) {
        uiAcc = 0;
        if (RT.running && S.tab === 'ladder' && !isEditing()) renderTab();
        if (S.tab === 'grafcet' && RT.plc && RT.plc.gstate) updateGrafcetLive();
        if (S.tab === 'wiring') updateWiringLive();
      }
    }
    if (st.fault && !RT.faultShown) {
      RT.faultShown = true;
      showFault(st.fault);
    }
    if (tutoAcc > 400) { tutoAcc = 0; checkTuto(); }
    requestAnimationFrame(tick);
  }
  const isEditing = () => { const a = document.activeElement; return a && (a.tagName === 'INPUT' || a.tagName === 'SELECT' || a.tagName === 'TEXTAREA'); };

  function showFault(f) {
    modal('⚠ Défaut machine : ' + f.title, el('div', {},
      el('p', {}, f.why),
      el('p', { class: 'hint' }, 'La machine est figée. Corrige ton programme puis appuie sur « Réinitialiser la machine ».')),
    [{ label: 'Réinitialiser la machine', value: 'reset', primary: true }, { label: 'Fermer', value: null }]).then((v) => {
      if (v === 'reset') { resetMachine(); setRun(false); render(); }
    });
  }

  // ------------------------------------------------------------ Navigation
  function go(v, extra = {}) { Object.assign(S, extra); S.view = v; render(); view.scrollTop = 0; window.scrollTo(0, 0); }
  document.getElementById('nav').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-view]');
    if (b) go(b.dataset.view, b.dataset.view === 'courses' ? { course: null } : {});
  });

  function save() { U.store('project', S.project); U.store('tuto', S.tuto); U.store('progress', S.progress); }

  function changed(full = true) {
    save();
    compileProject();
    if (full) renderTab();
    renderRunBar();
    renderTuto();
  }

  function render() {
    for (const b of document.querySelectorAll('#nav button')) b.classList.toggle('active', b.dataset.view === S.view);
    clear(view);
    ({ home: renderHome, courses: renderCourses, tutorials: renderTutorials, workshop: renderWorkshop, quiz: renderQuiz, help: renderHelp })[S.view]();
  }

  // ------------------------------------------------------------ Accueil
  function renderHome() {
    const done = Content.tutorials.filter((t) => S.progress[t.id] && S.progress[t.id].done).length;
    view.appendChild(el('section', { class: 'hero' },
      el('h1', {}, 'Ton atelier d\'automatisme de poche'),
      el('p', {}, 'Apprends le GRAFCET, le Ladder et la configuration d\'automates sur des machines virtuelles. Chaque erreur est expliquée simplement. Spécial BTS ATI.'),
      el('div', { class: 'progress' }, el('div', { class: 'bar', style: { width: `${(done / Content.tutorials.length) * 100}%` } })),
      el('p', { class: 'small' }, `${done} / ${Content.tutorials.length} tutoriels terminés`),
      el('div', { class: 'row-btns' },
        el('button', { class: 'btn primary big', onclick: () => go('tutorials') }, '🎯 Commencer les tutos'),
        el('button', { class: 'btn big', onclick: () => go('workshop') }, '🔧 Ouvrir l\'atelier'))));
    view.appendChild(el('h2', { class: 'section-title' }, 'Nouveau projet libre'));
    const grid = el('div', { class: 'cards' });
    for (const m of Machines.list) {
      grid.appendChild(el('div', { class: 'card machine-card' },
        el('div', { class: 'mc-icon' }, m.icon),
        el('div', { class: 'card-title' }, m.name),
        el('span', { class: 'chip' }, m.level),
        el('p', {}, m.desc),
        el('div', { class: 'row-btns' },
          el('button', { class: 'btn small', onclick: () => startProject(m.id, 'ladder') }, 'En Ladder'),
          el('button', { class: 'btn small', onclick: () => startProject(m.id, 'grafcet') }, 'En GRAFCET'))));
    }
    view.appendChild(grid);
    view.appendChild(el('div', { class: 'card' },
      el('div', { class: 'card-title' }, 'À propos'),
      el('p', {}, 'L\'automate VARKON VK-200 et les machines sont imaginaires : ils reprennent les principes des vrais automates modulaires (rack, CPU, cartes, adressage %I/%Q, réseau IP) pour que tu puisses t\'entraîner partout, même sans matériel. Tout fonctionne hors ligne.')));
  }

  async function startProject(mid, mode) {
    const ok = await modal('Nouveau projet', el('p', {}, `Créer un projet « ${Machines.byId[mid].name} » en ${mode === 'ladder' ? 'Ladder' : 'GRAFCET'} ? Le projet actuel de l'atelier sera remplacé.`),
      [{ label: 'Créer', value: true, primary: true }, { label: 'Annuler', value: false }]);
    if (!ok) return;
    S.project = newProject(mid, mode);
    S.tuto = null;
    loadedProject();
    S.tab = 'machine';
    go('workshop');
  }
  function loadedProject() {
    RT.plc = null; RT.running = false; RT.cpuFault = null; RT.live = null;
    resetMachine();
    save();
    compileProject();
  }

  // ------------------------------------------------------------ Cours
  function renderCourses() {
    if (S.course) {
      const c = Content.courses.find((x) => x.id === S.course);
      const i = Content.courses.indexOf(c);
      view.appendChild(el('button', { class: 'btn small back', onclick: () => go('courses', { course: null }) }, '← Tous les cours'));
      view.appendChild(el('article', { class: 'card course' }, el('h2', {}, `${c.icon} ${c.title}`), el('div', { class: 'course-body', html: c.html })));
      view.appendChild(el('div', { class: 'row-btns' },
        i > 0 ? el('button', { class: 'btn', onclick: () => go('courses', { course: Content.courses[i - 1].id }) }, '← Précédent') : null,
        i < Content.courses.length - 1 ? el('button', { class: 'btn primary', onclick: () => go('courses', { course: Content.courses[i + 1].id }) }, 'Suivant →') : null));
      return;
    }
    view.appendChild(el('h2', { class: 'section-title' }, 'Cours'));
    view.appendChild(el('p', { class: 'hint' }, 'Tout ce qu\'il faut savoir, expliqué simplement. Lis-les dans l\'ordre la première fois.'));
    const list = el('div', { class: 'list' });
    Content.courses.forEach((c, i) => list.appendChild(el('button', { class: 'list-item', onclick: () => go('courses', { course: c.id }) },
      el('span', { class: 'li-icon' }, c.icon), el('span', { class: 'li-text' }, `${i + 1}. ${c.title}`), el('span', { class: 'li-arrow' }, '›'))));
    view.appendChild(list);
  }

  // ------------------------------------------------------------ Tutoriels
  function renderTutorials() {
    view.appendChild(el('h2', { class: 'section-title' }, 'Tutoriels guidés'));
    view.appendChild(el('p', { class: 'hint' }, 'Chaque tutoriel charge une machine dans l\'atelier et te guide pas à pas. Les étapes se valident toutes seules quand tu as réussi.'));
    const list = el('div', { class: 'list' });
    Content.tutorials.forEach((t, i) => {
      const pr = S.progress[t.id];
      const m = Machines.byId[t.machine];
      list.appendChild(el('button', { class: 'list-item', onclick: () => startTuto(t) },
        el('span', { class: 'li-icon' }, pr && pr.done ? '✅' : m.icon),
        el('span', { class: 'li-text' }, el('b', {}, `${i + 1}. ${t.title}`), el('br'), el('small', {}, `${m.name} · ${t.mode === 'ladder' ? 'Ladder' : 'GRAFCET'} · ${'★'.repeat(t.level)}`)),
        el('span', { class: 'li-arrow' }, '›')));
    });
    view.appendChild(list);
  }

  async function startTuto(t) {
    if (S.tuto && S.tuto.id === t.id) { go('workshop'); return; }
    const ok = await modal(t.title, el('div', {}, el('p', {}, t.intro), el('p', { class: 'hint' }, 'Le projet actuel de l\'atelier sera remplacé par celui du tutoriel.')),
      [{ label: 'C\'est parti !', value: true, primary: true }, { label: 'Annuler', value: false }]);
    if (!ok) return;
    S.project = newProject(t.machine, t.mode);
    t.setup(S.project);
    S.tuto = { id: t.id, step: 0 };
    loadedProject();
    S.tab = 'machine';
    go('workshop');
  }

  function tutoCtx() {
    const c = compiled || compileProject();
    return { project: S.project, diags: c.all, cfgDiags: c.cfgDiags, wireDiags: c.wireDiags, running: RT.running, mstate: RT.mstate };
  }
  function checkTuto() {
    if (!S.tuto) return;
    const t = Content.tutorials.find((x) => x.id === S.tuto.id);
    if (!t) return;
    const stp = t.steps[S.tuto.step];
    if (!stp || !stp.check) return;
    let ok = false;
    try { ok = stp.check(tutoCtx()); } catch (e) { ok = false; }
    const pr = S.progress[t.id] = S.progress[t.id] || { steps: {} };
    if (ok && !pr.steps[S.tuto.step]) {
      pr.steps[S.tuto.step] = true;
      toast('✔ Étape réussie : ' + stp.title, 'ok');
      if (S.tuto.step < t.steps.length - 1) S.tuto.step++;
      else { pr.done = true; toast('🎉 Tutoriel terminé !', 'ok'); }
      save();
      renderTuto();
    }
  }

  function renderTuto() {
    const box = document.getElementById('tutoBox');
    if (!box) return;
    clear(box);
    if (!S.tuto) { box.hidden = true; return; }
    const t = Content.tutorials.find((x) => x.id === S.tuto.id);
    if (!t) { box.hidden = true; return; }
    box.hidden = false;
    const i = S.tuto.step, stp = t.steps[i];
    const pr = S.progress[t.id] || { steps: {} };
    const collapsed = S.tutoCollapsed;
    box.appendChild(el('div', { class: 'tuto-head', onclick: () => { S.tutoCollapsed = !S.tutoCollapsed; renderTuto(); } },
      el('span', {}, `🎯 ${t.title} — étape ${i + 1}/${t.steps.length}`), el('span', {}, collapsed ? '▾' : '▴')));
    if (collapsed) return;
    box.appendChild(el('div', { class: 'tuto-steps' }, t.steps.map((s, k) => el('span', { class: 'dot' + (k === i ? ' cur' : '') + (pr.steps[k] ? ' ok' : '') }))));
    box.appendChild(el('h4', {}, (pr.steps[i] ? '✔ ' : '') + stp.title));
    box.appendChild(el('div', { class: 'tuto-text', html: stp.text }));
    if (stp.check && !pr.steps[i]) box.appendChild(el('p', { class: 'hint' }, '⏳ Cette étape se valide automatiquement quand c\'est réussi.'));
    box.appendChild(el('div', { class: 'row-btns' },
      i > 0 ? el('button', { class: 'btn small', onclick: () => { S.tuto.step--; save(); renderTuto(); } }, '← Précédent') : null,
      i < t.steps.length - 1 ? el('button', { class: 'btn small primary', onclick: () => { if (!stp.check) { pr.steps[i] = true; S.progress[t.id] = pr; } S.tuto.step++; save(); renderTuto(); } }, 'Étape suivante →')
        : el('button', { class: 'btn small primary', onclick: () => { pr.done = true; S.progress[t.id] = pr; S.tuto = null; save(); toast('Bravo ! Choisis le tutoriel suivant.', 'ok'); go('tutorials'); } }, 'Terminer ✔'),
      t.solution ? el('button', { class: 'btn small', onclick: async () => {
        const ok = await modal('Voir la solution ?', el('p', {}, 'La solution va remplacer ton programme actuel. Essaie d\'abord de trouver par toi-même avec le Diagnostic ! Tu pourras comparer.'),
          [{ label: 'Charger la solution', value: true, primary: true }, { label: 'Annuler', value: false }]);
        if (ok) { t.solution(S.project); changed(); }
      } }, '💡 Solution') : null,
      el('button', { class: 'btn small', onclick: () => { S.tuto = null; save(); renderTuto(); } }, 'Quitter')));
  }

  // ------------------------------------------------------------ Atelier
  const TABS = [['machine', '🏭 Machine'], ['config', '⚙️ Automate'], ['wiring', '🔌 Câblage'], ['grafcet', '🔀 GRAFCET'], ['ladder', '🪜 Ladder'], ['diag', '🩺 Diagnostic']];

  function renderWorkshop() {
    compileProject();
    view.appendChild(el('div', { id: 'runbar', class: 'runbar' }));
    view.appendChild(el('div', { id: 'tutoBox', class: 'tuto', hidden: true }));
    const tabs = el('div', { class: 'tabs', role: 'tablist' });
    for (const [id, label] of TABS) {
      const b = el('button', { role: 'tab', class: 'tab' + (S.tab === id ? ' active' : ''), onclick: () => { S.tab = id; render(); } }, label);
      if (id === 'diag') b.appendChild(el('span', { id: 'diagBadge', class: 'badge' }));
      tabs.appendChild(b);
    }
    view.appendChild(tabs);
    view.appendChild(el('div', { id: 'tab', class: 'tabpane' }));
    renderRunBar(); renderTuto(); renderTab();
    const at = tabs.querySelector('.active');
    if (at) at.scrollIntoView({ inline: 'center', block: 'nearest' });
  }

  function renderRunBar() {
    const bar = document.getElementById('runbar');
    if (!bar) return;
    clear(bar);
    const c = compiled || compileProject();
    const errs = c.all.filter((d) => d.level === 'error').length, warns = c.all.filter((d) => d.level === 'warning').length;
    const outdated = RT.plc && RT.sig !== sig(S.project);
    const state = RT.cpuFault ? ['err', 'DÉFAUT'] : RT.running ? ['run', 'RUN'] : RT.plc ? ['stop', 'STOP'] : ['none', 'VIDE'];
    bar.appendChild(el('div', { class: 'rb-left' },
      el('span', { class: `led ${state[0]}` }), el('b', {}, state[1]),
      el('span', { class: 'rb-name' }, `${machine().icon} ${S.project.name} · ${S.project.mode === 'ladder' ? 'Ladder' : 'GRAFCET'}`),
      outdated ? el('span', { class: 'chip warn', title: Diag.make('RUN-03').why }, '⟳ pas à jour') : null));
    bar.appendChild(el('div', { class: 'rb-right' },
      el('button', { class: 'btn small', onclick: transfer, title: 'Vérifier puis envoyer le programme dans l\'automate' }, '⇪ Transférer'),
      RT.running ? el('button', { class: 'btn small danger', onclick: () => setRun(false) }, '■ STOP')
        : el('button', { class: 'btn small primary', onclick: () => setRun(true) }, '▶ RUN')));
    const badge = document.getElementById('diagBadge');
    if (badge) { badge.textContent = errs ? errs : warns ? warns : '✓'; badge.className = 'badge ' + (errs ? 'err' : warns ? 'warn' : 'ok'); }
  }

  function renderTab() {
    const pane = document.getElementById('tab');
    if (!pane) return;
    const y = window.scrollY;
    clear(pane);
    RT.mview = null;
    ({ machine: tabMachine, config: tabConfig, wiring: tabWiring, grafcet: tabGrafcet, ladder: tabLadder, diag: tabDiag })[S.tab](pane);
    window.scrollTo(0, y);
  }

  // ---------- Machine
  function tabMachine(pane) {
    const m = machine(), st = RT.mstate;
    pane.appendChild(el('details', { class: 'card', open: S.storyOpen !== false ? true : null, ontoggle: (e) => { S.storyOpen = e.target.open; } },
      el('summary', { class: 'card-title' }, `📄 Cahier des charges — ${m.name}`), el('p', {}, m.story)));
    const box = el('div', { class: 'card machine-box' });
    RT.mview = m.view();
    box.appendChild(RT.mview.node);
    const panel = el('div', { class: 'pupitre' });
    for (const c of m.controls) {
      if (c.kind === 'action') { panel.appendChild(el('button', { class: 'btn small', onclick: () => m.action(RT.mstate, c.id) }, c.label)); continue; }
      const b = el('button', { class: `pbtn ${c.color}`, 'data-sym': c.sym, 'aria-label': c.label }, el('span', { class: 'cap' }), el('span', { class: 'pl' }, c.label));
      if (c.kind === 'push') {
        const down = (e) => { e.preventDefault(); RT.mstate.btn[c.sym] = true; RT.mstate.hold[c.sym] = RT.mstate.t + 250; b.classList.add('down'); };
        const up = () => { RT.mstate.btn[c.sym] = false; b.classList.remove('down'); };
        b.addEventListener('pointerdown', down);
        b.addEventListener('pointerup', up); b.addEventListener('pointerleave', up); b.addEventListener('pointercancel', up);
        b.addEventListener('keydown', (e) => { if (e.key === ' ' || e.key === 'Enter') down(e); });
        b.addEventListener('keyup', up);
      } else {
        b.addEventListener('click', () => { RT.mstate.btn[c.sym] = !RT.mstate.btn[c.sym]; b.classList.toggle('down', RT.mstate.btn[c.sym]); });
        if (RT.mstate.btn[c.sym]) b.classList.add('down');
      }
      panel.appendChild(b);
    }
    box.appendChild(panel);
    box.appendChild(el('p', { class: 'hint' }, 'Boutons : maintiens appuyé. L\'AU (coup de poing) reste enfoncé : touche-le à nouveau pour le déverrouiller.'));
    box.appendChild(el('div', { id: 'faultBox' }));
    box.appendChild(el('div', { class: 'row-btns' }, el('button', { class: 'btn small', onclick: () => { resetMachine(); renderTab(); } }, '⟲ Réinitialiser la machine')));
    pane.appendChild(box);
    const two = el('div', { class: 'two-col' });
    two.appendChild(el('div', { class: 'card' }, el('div', { class: 'card-title' }, '🎯 Objectifs'), el('ul', { id: 'goals', class: 'goals' })));
    two.appendChild(el('div', { class: 'card' }, el('div', { class: 'card-title' }, '📟 Entrées / sorties en direct'), el('div', { id: 'ioLive', class: 'io-live' })));
    pane.appendChild(two);
    pane.appendChild(el('div', { class: 'card' }, el('div', { class: 'card-title' }, '📝 Journal'), el('ul', { id: 'log', class: 'log' })));
    void st;
    updateMachineView(true);
  }

  let lastIoSig = '';
  function updateMachineView(force) {
    if (!RT.mview) return;
    const m = machine(), st = RT.mstate;
    RT.mview.update(st, RT.ins, RT.outs);
    const fb = document.getElementById('faultBox');
    if (fb) {
      const want = st.fault ? st.fault.title : '';
      if (fb.dataset.f !== want) {
        fb.dataset.f = want;
        clear(fb);
        if (st.fault) fb.appendChild(el('div', { class: 'fault' }, el('b', {}, '⚠ ' + st.fault.title), el('p', {}, st.fault.why)));
      }
    }
    const plc = RT.plc;
    const wiring = plc ? plc.wiring : S.project.wiring;
    const ioSig = JSON.stringify([RT.ins, RT.outs, plc && RT.running, st.msgs.length, st.msgs[st.msgs.length - 1], m.goals.map((g) => !!g.done(st))]);
    if (!force && ioSig === lastIoSig) return;
    lastIoSig = ioSig;
    const io = document.getElementById('ioLive');
    if (io) {
      clear(io);
      for (const x of m.io) {
        const addr = wiring[x.sym] || '—';
        let v;
        if (x.kind === 'DI') v = plc && wiring[x.sym] ? plc.mem.get(wiring[x.sym].toUpperCase()) : !!RT.ins[x.sym];
        else v = !!RT.outs[x.sym];
        io.appendChild(el('div', { class: 'io-row' }, el('span', { class: 'led small ' + (v ? 'on' : '') }),
          el('b', {}, x.sym), el('code', {}, addr), el('span', { class: 'io-lbl' }, x.label)));
      }
      if (!plc) io.appendChild(el('p', { class: 'hint' }, 'Aucun programme transféré : les entrées affichées sont les signaux bruts des capteurs.'));
    }
    const goals = document.getElementById('goals');
    if (goals) { clear(goals); for (const g of m.goals) { const d = !!g.done(st); goals.appendChild(el('li', { class: d ? 'ok' : '' }, (d ? '✅ ' : '⬜ ') + g.text)); } }
    const log = document.getElementById('log');
    if (log) { clear(log); for (const msg of st.msgs.slice().reverse()) log.appendChild(el('li', {}, `${(msg.t / 1000).toFixed(1)} s — ${msg.text}`)); if (!st.msgs.length) log.appendChild(el('li', { class: 'hint' }, 'Rien pour l\'instant.')); }
  }

  // ---------- Automate
  function tabConfig(pane) {
    const cfg = S.project.config;
    const c = compiled;
    const rackCard = el('div', { class: 'card' }, el('div', { class: 'card-title' }, 'Rack VK-200 (touche un emplacement)'));
    const rack = el('div', { class: 'rack' });
    for (let i = 0; i < PLC.SLOTS; i++) {
      const mod = cfg.rack[i];
      const info = mod ? PLC.CATALOG[mod.type] : null;
      rack.appendChild(el('button', { class: 'slot' + (info ? ' kind-' + info.kind : ' empty'), onclick: () => editSlot(i) },
        el('div', { class: 'slot-num' }, i),
        el('div', { class: 'slot-name' }, info ? info.name : (i === 0 ? 'Alim ?' : i === 1 ? 'CPU ?' : 'vide')),
        info && info.kind === 'DI' ? el('div', { class: 'slot-sub' }, `%I${i}.0-${info.channels - 1} · ${mod.logic || 'PNP'}`) : null,
        info && info.kind === 'DO' ? el('div', { class: 'slot-sub' }, `%Q${i}.0-${info.channels - 1}`) : null));
    }
    rackCard.appendChild(el('div', { class: 'rack-scroll' }, rack));
    let draw = 0;
    cfg.rack.forEach((m) => { if (m) draw += PLC.CATALOG[m.type].draw || 0; });
    const psu = cfg.rack[0] && PLC.CATALOG[cfg.rack[0].type].kind === 'PSU' ? PLC.CATALOG[cfg.rack[0].type] : null;
    const pct = psu ? Math.min(100, (draw / psu.supply) * 100) : 100;
    rackCard.appendChild(el('div', { class: 'budget' },
      el('div', {}, `Bilan de consommation : ${draw} mA / ${psu ? psu.supply + ' mA' : 'pas d\'alimentation'}`),
      el('div', { class: 'progress' }, el('div', { class: 'bar' + (pct >= 100 ? ' over' : pct > 80 ? ' hi' : ''), style: { width: pct + '%' } }))));
    const cpu = PLC.cpuOf(cfg);
    if (cpu) rackCard.appendChild(el('p', { class: 'hint' }, `${cpu.name} : ${cpu.desc}. Temps de cycle estimé : ${c.cycle} ms.`));
    pane.appendChild(rackCard);

    const net = el('div', { class: 'card' }, el('div', { class: 'card-title' }, '🌐 Réseau Ethernet'),
      el('p', { class: 'hint' }, `PC de l'atelier : ${PLC.PC.ip} / ${PLC.PC.mask}`),
      field('Adresse IP de l\'automate', cfg.ip, (v) => { cfg.ip = v.trim(); changed(false); renderConfigDiags(); }, '192.168.1.20'),
      field('Masque de sous-réseau', cfg.mask, (v) => { cfg.mask = v.trim(); changed(false); renderConfigDiags(); }, '255.255.255.0'));
    pane.appendChild(net);
    const task = el('div', { class: 'card' }, el('div', { class: 'card-title' }, '⏱ Tâche maître et chien de garde'),
      el('label', { class: 'field' }, 'Mode d\'exécution',
        el('select', { onchange: (e) => { cfg.task.mode = e.target.value; changed(); } },
          el('option', { value: 'cyclique', selected: cfg.task.mode === 'cyclique' ? true : null }, 'Cyclique (le plus courant)'),
          el('option', { value: 'periodique', selected: cfg.task.mode === 'periodique' ? true : null }, 'Périodique'))),
      cfg.task.mode === 'periodique' ? field('Période (ms)', cfg.task.period, (v) => { cfg.task.period = parseInt(v, 10) || 0; changed(false); renderConfigDiags(); }, '20', 'number') : null,
      field('Chien de garde (ms)', cfg.watchdog, (v) => { cfg.watchdog = parseInt(v, 10) || 0; changed(false); renderConfigDiags(); }, '150', 'number'));
    pane.appendChild(task);
    pane.appendChild(el('div', { id: 'cfgDiags' }));
    renderConfigDiags();
  }
  function renderConfigDiags() {
    const box = document.getElementById('cfgDiags');
    if (!box) return;
    clear(box);
    const d = compiled.cfgDiags;
    box.appendChild(d.length ? diagList(d) : el('div', { class: 'card ok-card' }, '✅ Configuration matérielle correcte.'));
  }
  function field(label, value, onChange, ph, type = 'text') {
    return el('label', { class: 'field' }, label, el('input', { type, value: value ?? '', placeholder: ph, inputmode: type === 'number' ? 'numeric' : 'decimal', onchange: (e) => onChange(e.target.value) }));
  }

  async function editSlot(i) {
    const cfg = S.project.config;
    const cur = cfg.rack[i];
    const sel = el('div', { class: 'module-list' });
    let choice = cur ? cur.type : '';
    const groups = [['PSU', 'Alimentations'], ['CPU', 'Processeurs'], ['DI', 'Cartes d\'entrées'], ['DO', 'Cartes de sorties']];
    const advise = i === 0 ? 'PSU' : i === 1 ? 'CPU' : 'IO';
    sel.appendChild(el('p', { class: 'hint' }, i === 0 ? 'L\'emplacement 0 reçoit l\'alimentation.' : i === 1 ? 'L\'emplacement 1 reçoit le CPU.' : `Emplacement ${i} : une carte d'E/S. Ses adresses seront %I${i}.x ou %Q${i}.x.`));
    for (const [k, title] of groups) {
      sel.appendChild(el('div', { class: 'mod-group' }, title + ((advise === k || (advise === 'IO' && (k === 'DI' || k === 'DO'))) ? ' (conseillé ici)' : '')));
      for (const [id, info] of Object.entries(PLC.CATALOG)) {
        if (info.kind !== k) continue;
        sel.appendChild(el('label', { class: 'mod-opt' }, el('input', { type: 'radio', name: 'mod', value: id, checked: choice === id ? true : null, onchange: () => { choice = id; } }),
          el('span', {}, el('b', {}, info.name), el('br'), el('small', {}, `${info.desc} · consommation ${info.draw || 0} mA${info.supply ? ' · fournit ' + info.supply + ' mA' : ''}`))));
      }
    }
    let logic = cur && cur.logic ? cur.logic : 'PNP';
    sel.appendChild(el('label', { class: 'field' }, 'Logique des entrées (cartes DI seulement)',
      el('select', { onchange: (e) => { logic = e.target.value; } },
        el('option', { value: 'PNP', selected: logic === 'PNP' ? true : null }, 'PNP (logique positive)'),
        el('option', { value: 'NPN', selected: logic === 'NPN' ? true : null }, 'NPN (logique négative)'))));
    const res = await modal(`Emplacement ${i}`, sel, [{ label: 'Valider', value: 'ok', primary: true }, { label: 'Vider l\'emplacement', value: 'del' }, { label: 'Annuler', value: null }]);
    if (res === 'del') cfg.rack[i] = null;
    else if (res === 'ok' && choice) cfg.rack[i] = PLC.CATALOG[choice].kind === 'DI' ? { type: choice, logic } : { type: choice };
    else return;
    changed();
  }

  // ---------- Câblage
  function tabWiring(pane) {
    const p = S.project, m = machine();
    const ins = PLC.ioAddresses(p.config, 'DI'), outs = PLC.ioAddresses(p.config, 'DO');
    const card = el('div', { class: 'card' }, el('div', { class: 'card-title' }, '🔌 Tableau d\'affectation des entrées / sorties'),
      el('p', { class: 'hint' }, 'Relie chaque appareil de la machine à une voie de carte. Les noms (mnémoniques) sont ensuite utilisables dans tes programmes.'));
    const table = el('table', { class: 'wtable' }, el('thead', {}, el('tr', {}, el('th', {}, ''), el('th', {}, 'Nom'), el('th', {}, 'Appareil'), el('th', {}, 'Adresse'))));
    const tb = el('tbody', {});
    for (const io of m.io) {
      const cur = p.wiring[io.sym] || '';
      const opts = [''].concat(io.kind === 'DI' ? ins : outs, io.kind === 'DI' ? outs : ins);
      if (cur && !opts.includes(cur)) opts.push(cur);
      const select = el('select', { onchange: (e) => { if (e.target.value) p.wiring[io.sym] = e.target.value; else delete p.wiring[io.sym]; changed(); } },
        opts.map((a) => el('option', { value: a, selected: a === cur ? true : null }, a === '' ? '— non câblé —' : a + (PLC.checkAddr(a, p.config).ok ? '' : ' (n\'existe pas)'))));
      tb.appendChild(el('tr', {},
        el('td', {}, el('span', { class: 'led small', 'data-live': io.sym })),
        el('td', {}, el('b', {}, io.sym), el('div', { class: 'io-kind ' + io.kind }, io.kind === 'DI' ? 'entrée' : 'sortie')),
        el('td', {}, io.label, el('br'), el('small', {}, [io.dev, io.sensor ? '' : '', io.volt ? (io.volt === '230VAC' ? '230 V AC' : '24 V DC') : ''].filter(Boolean).join(' · '))),
        el('td', {}, select)));
    }
    table.appendChild(tb);
    card.appendChild(el('div', { class: 'table-scroll' }, table));
    pane.appendChild(card);
    pane.appendChild(compiled.wireDiags.length ? diagList(compiled.wireDiags) : el('div', { class: 'card ok-card' }, '✅ Câblage correct.'));

    // mnémoniques utilisateur
    const sym = el('div', { class: 'card' }, el('div', { class: 'card-title' }, '🏷️ Mnémoniques internes (%M, %T, %C)'),
      el('p', { class: 'hint' }, 'Donne un nom à tes bits internes, temporisations et compteurs. Ex : Marche_mem → %M0, Tempo_mel → %T0.'));
    (p.symbols || []).forEach((s, i) => sym.appendChild(el('div', { class: 'g-row' },
      el('input', { value: s.name, placeholder: 'nom', onchange: (e) => { s.name = e.target.value.trim(); changed(false); } }),
      el('input', { value: s.addr, placeholder: '%M0', class: 'small-in', onchange: (e) => { s.addr = e.target.value.trim().toUpperCase(); changed(false); } }),
      el('input', { value: s.comment || '', placeholder: 'commentaire', onchange: (e) => { s.comment = e.target.value; changed(false); } }),
      el('button', { class: 'icon-btn danger', onclick: () => { p.symbols.splice(i, 1); changed(); } }, '🗑'))));
    sym.appendChild(el('button', { class: 'btn small', onclick: () => {
      const used = new Set((p.symbols || []).map((s) => s.addr));
      let n = 0; while (used.has('%M' + n)) n++;
      (p.symbols = p.symbols || []).push({ name: '', addr: '%M' + n, comment: '' }); changed();
    } }, '+ Mnémonique'));
    sym.appendChild(el('p', { class: 'hint' }, 'Bits système toujours disponibles : INIT (%S1, premier cycle) et CLIGNO (%S6, clignotant 1 Hz).'));
    pane.appendChild(sym);
    updateWiringLive();
  }
  function updateWiringLive() {
    const m = machine(), plc = RT.plc;
    for (const io of m.io) {
      const led = document.querySelector(`[data-live="${io.sym}"]`);
      if (!led) continue;
      const v = io.kind === 'DI' ? (plc && plc.wiring[io.sym] ? plc.mem.get(plc.wiring[io.sym].toUpperCase()) : RT.ins[io.sym]) : RT.outs[io.sym];
      led.classList.toggle('on', !!v);
    }
  }

  // ---------- Langage
  function modeSwitch(pane) {
    const p = S.project;
    pane.appendChild(el('div', { class: 'mode-switch' }, el('span', {}, 'Langage exécuté par l\'automate :'),
      ...[['ladder', 'Ladder'], ['grafcet', 'GRAFCET']].map(([v, l]) => el('button', { class: 'seg' + (p.mode === v ? ' active' : ''), onclick: () => { p.mode = v; changed(); } }, l))));
    if ((S.tab === 'ladder') !== (p.mode === 'ladder')) {
      pane.appendChild(el('p', { class: 'note' }, `ℹ L'automate exécute actuellement le programme ${p.mode === 'ladder' ? 'Ladder' : 'GRAFCET'}. Ce que tu modifies ici ne sera pas exécuté tant que tu ne changes pas le langage ci-dessus.`));
    }
  }
  function ioSuggestions(kind) {
    const m = machine(), p = S.project;
    const list = m.io.filter((io) => !kind || io.kind === kind).map((io) => ({ name: io.sym, label: `${p.wiring[io.sym] || 'non câblé'} — ${io.label}` }));
    for (const s of p.symbols || []) if (s.name) list.push({ name: s.name, label: `${s.addr} — ${s.comment || ''}` });
    return list;
  }

  function tabGrafcet(pane) {
    modeSwitch(pane);
    const ed = el('div', {});
    pane.appendChild(ed);
    Grafcet.renderEditor(ed, {
      project: S.project, gstate: RT.running && RT.plc && RT.plc.gstate ? RT.plc.gstate : null,
      inputs: ioSuggestions().concat(S.project.grafcet.steps.map((s) => ({ name: `X${s.id}`, label: `étape ${s.id} active` }))),
      outputs: ioSuggestions('DO').concat((S.project.symbols || []).filter((s) => s.addr.startsWith('%M')).map((s) => ({ name: s.name, label: s.addr }))),
      onChange: () => changed(),
      convert: convertGrafcet,
    });
    const gd = compiled.progDiags;
    if (S.project.mode === 'grafcet') pane.appendChild(gd.length ? diagList(gd) : el('div', { class: 'card ok-card' }, '✅ GRAFCET correct.'));
    pane.appendChild(el('div', { id: 'gLive' }));
  }
  function updateGrafcetLive() {
    const gv = document.querySelector('.grafcet-view');
    const plc = RT.plc;
    if (!gv || !plc || !plc.gstate) return;
    const active = RT.running ? plc.gstate.active : new Set();
    const key = [...active].sort().join(',') + RT.running;
    if (gv.dataset.k !== key) {
      gv.dataset.k = key;
      clear(gv).appendChild(Grafcet.render(S.project.grafcet, { active }));
      document.querySelectorAll('.g-item.active').forEach((n) => n.classList.remove('active'));
    }
    const live = document.getElementById('gLive');
    if (live) {
      const conf = plc.gstate.conflicts;
      const k2 = JSON.stringify(conf);
      if (live.dataset.k !== k2) {
        live.dataset.k = k2;
        clear(live);
        if (conf.length) live.appendChild(diagList(conf.map((c) => Diag.make('GRA-09', [c.ids.join(' et '), c.step]))));
      }
    }
  }
  async function convertGrafcet() {
    const p = S.project;
    const errs = Grafcet.compile(p.grafcet, { table: compiled.table, cfg: p.config }).diags.filter((d) => d.level === 'error');
    if (errs.length) { toast('Corrige d\'abord les erreurs du GRAFCET.', 'warn'); return; }
    const ok = await modal('Générer le Ladder', el('p', {}, 'Le programme Ladder actuel sera remplacé par la traduction du GRAFCET, et l\'automate passera en mode Ladder.'),
      [{ label: 'Générer', value: true, primary: true }, { label: 'Annuler', value: false }]);
    if (!ok) return;
    let res;
    try { res = Grafcet.toLadder(p.grafcet, p.config); } catch (e) { toast(e.message, 'err'); return; }
    p.ladder = { rungs: res.rungs };
    const names = new Set(res.symbols.map((s) => s.name.toUpperCase()));
    const addrs = new Set(res.symbols.map((s) => s.addr));
    p.symbols = (p.symbols || []).filter((s) => !names.has((s.name || '').toUpperCase()) && !addrs.has(s.addr)).concat(res.symbols);
    p.mode = 'ladder';
    S.tab = 'ladder';
    changed();
    render();
    toast(`${res.rungs.length} lignes générées.${res.notes.length ? ' ' + res.notes.join(' ') : ''}`, 'ok');
  }

  function tabLadder(pane) {
    modeSwitch(pane);
    const ed = el('div', {});
    pane.appendChild(ed);
    Ladder.renderEditor(ed, {
      project: S.project, state: S.ladderUI, running: RT.running && RT.plc && RT.plc.mode === 'ladder',
      live: RT.running ? RT.live : null, mem: RT.plc ? RT.plc.mem : null, table: compiled.table,
      onChange: (full = true) => changed(full),
      pickVar,
    });
    const ld = compiled.progDiags;
    if (S.project.mode === 'ladder') pane.appendChild(ld.length ? diagList(ld) : el('div', { class: 'card ok-card' }, '✅ Programme Ladder correct.'));
  }

  async function pickVar(cell) {
    const p = S.project, m = machine();
    const isTimer = cell.t === 'TON' || cell.t === 'TOF', isCtr = cell.t === 'CTU';
    const isCoil = Ladder.COILS.includes(cell.t);
    let value = cell.v || '';
    if (!value && isTimer) { let n = 0; const used = usedAddr('%T'); while (used.has('%T' + n)) n++; value = '%T' + n; }
    if (!value && isCtr) { let n = 0; const used = usedAddr('%C'); while (used.has('%C' + n)) n++; value = '%C' + n; }
    const input = el('input', { value, placeholder: 'nom ou adresse (ex : KM1, %M0)', autocapitalize: 'off', autocomplete: 'off', spellcheck: 'false' });
    const pv = el('input', { value: isTimer ? U.fmtDuration(cell.p) : cell.p || '', placeholder: isTimer ? 'ex : 3s, 500ms' : 'ex : 5' });
    const chips = el('div', { class: 'chips' });
    const addChip = (name, sub, cls) => chips.appendChild(el('button', { class: 'chip-btn ' + cls, type: 'button', onclick: () => { input.value = name; } }, el('b', {}, name), el('small', {}, sub)));
    const groups = [];
    if (!isTimer && !isCtr) {
      if (!isCoil) groups.push(['Entrées', m.io.filter((io) => io.kind === 'DI'), 'in']);
      groups.push(['Sorties', m.io.filter((io) => io.kind === 'DO'), 'out']);
    }
    for (const [title, list, cls] of groups) {
      chips.appendChild(el('div', { class: 'chip-title' }, title));
      for (const io of list) addChip(io.sym, p.wiring[io.sym] || 'non câblé', cls);
    }
    const own = (p.symbols || []).filter((s) => s.name && (isTimer ? s.addr.startsWith('%T') : isCtr ? s.addr.startsWith('%C') : true));
    if (own.length) { chips.appendChild(el('div', { class: 'chip-title' }, 'Mnémoniques internes')); for (const s of own) addChip(s.name, s.addr, 'mem'); }
    if (!isCoil) { chips.appendChild(el('div', { class: 'chip-title' }, 'Système')); addChip('INIT', '%S1 premier cycle', 'sys'); addChip('CLIGNO', '%S6 clignotant', 'sys'); }
    if (!isCoil && !isTimer && !isCtr) {
      const tc = [...usedAddr('%T'), ...usedAddr('%C')];
      if (tc.length) { chips.appendChild(el('div', { class: 'chip-title' }, 'Tempos / compteurs utilisés')); for (const a of tc) addChip(a, a.startsWith('%T') ? 'sortie de tempo' : 'sortie de compteur', 'sys'); }
    }
    const body = el('div', {},
      el('p', { class: 'hint' }, Ladder.LABEL[cell.t]),
      el('label', { class: 'field' }, isTimer ? 'Temporisation (%T)' : isCtr ? 'Compteur (%C)' : 'Variable', input),
      (isTimer || isCtr) ? el('label', { class: 'field' }, isTimer ? 'Durée (PT)' : 'Présélection (PV)', pv) : null,
      chips);
    const res = await modal(isCoil ? 'Choisir la variable à écrire' : 'Choisir la variable à lire', body, [{ label: 'OK', value: 'ok', primary: true }, { label: 'Annuler', value: null }]);
    if (res !== 'ok') return null;
    const out = { v: input.value.trim() };
    if (isTimer) { const d = U.parseDuration(pv.value); if (d == null) toast('Durée non comprise : écris par exemple 3s ou 500ms.', 'warn'); out.p = d || undefined; }
    if (isCtr) out.p = parseInt(pv.value, 10) || undefined;
    return out;
  }
  function usedAddr(prefix) {
    const s = new Set();
    for (const r of S.project.ladder.rungs) for (const c of Object.values(r.cells)) {
      if (!c.v) continue;
      const a = PLC.resolve(c.v, compiled.table);
      if (a && a.startsWith(prefix)) s.add(a);
    }
    return s;
  }

  // ---------- Diagnostic
  function tabDiag(pane) {
    const c = compiled;
    const groups = [['Configuration de l\'automate', c.cfgDiags], ['Câblage', c.wireDiags], [`Programme (${S.project.mode === 'ladder' ? 'Ladder' : 'GRAFCET'})`, c.progDiags]];
    const errs = c.all.filter((d) => d.level === 'error').length;
    pane.appendChild(el('div', { class: 'card ' + (errs ? 'err-card' : 'ok-card') },
      errs ? `❌ ${errs} erreur(s) bloquent le transfert. Touche une erreur pour y aller.` : '✅ Aucune erreur bloquante : tu peux transférer le programme.'));
    if (RT.cpuFault) pane.appendChild(diagList([RT.cpuFault]));
    if (RT.plc && RT.sig !== sig(S.project)) pane.appendChild(diagList([Diag.make('RUN-03')]));
    for (const [title, list] of groups) {
      pane.appendChild(el('h3', { class: 'section-title' }, title));
      pane.appendChild(list.length ? diagList(list) : el('p', { class: 'hint' }, 'Rien à signaler.'));
    }
    pane.appendChild(el('div', { class: 'card' }, el('div', { class: 'card-title' }, 'Légende'),
      el('p', {}, '🔴 Erreur : bloque le transfert. 🟠 Avertissement : le programme peut tourner mais il y a sûrement un problème. 🔵 Info : à vérifier.')));
  }

  function diagList(list) {
    const box = el('div', { class: 'diag-list' });
    const order = { error: 0, warning: 1, info: 2 };
    for (const d of list.slice().sort((a, b) => order[a.level] - order[b.level])) {
      const item = el('details', { class: 'diag ' + d.level },
        el('summary', {}, el('span', { class: 'dicon' }, d.level === 'error' ? '🔴' : d.level === 'warning' ? '🟠' : '🔵'),
          el('span', { class: 'dtitle' }, d.title), el('code', { class: 'dcode' }, d.code)),
        el('div', { class: 'dbody' },
          d.why ? el('p', {}, el('b', {}, 'Pourquoi ? '), d.why) : null,
          d.fix ? el('p', {}, el('b', {}, 'Comment corriger ? '), d.fix) : null,
          d.where && d.where.tab && d.where.tab !== S.tab ? el('button', { class: 'btn small', onclick: () => { S.tab = d.where.tab; if (d.where.rung != null) S.ladderUI.focusRung = d.where.rung; render(); } }, 'Aller à l\'endroit →') : null));
      box.appendChild(item);
    }
    return box;
  }

  // ------------------------------------------------------------ Quiz
  let Q = null;
  function renderQuiz() {
    if (!Q) {
      view.appendChild(el('h2', { class: 'section-title' }, 'Quiz d\'entraînement'));
      view.appendChild(el('div', { class: 'card' },
        el('p', {}, `${Content.quiz.length} questions sur l'automate, le câblage, le Ladder et le GRAFCET. Chaque réponse est expliquée.`),
        el('p', {}, `Meilleur score : ${S.quizBest} / ${Content.quiz.length}`),
        el('button', { class: 'btn primary big', onclick: () => { Q = { i: 0, score: 0, order: shuffle([...Content.quiz.keys()]), answered: null }; render(); } }, 'Commencer')));
      return;
    }
    if (Q.i >= Q.order.length) {
      S.quizBest = Math.max(S.quizBest, Q.score); U.store('quizBest', S.quizBest);
      view.appendChild(el('div', { class: 'card' }, el('h2', {}, `Score : ${Q.score} / ${Q.order.length}`),
        el('p', {}, Q.score >= Q.order.length * 0.8 ? 'Excellent ! Tu maîtrises les bases. 🎉' : Q.score >= Q.order.length * 0.5 ? 'Pas mal ! Relis les cours sur les questions ratées.' : 'Courage : relis les cours puis réessaie.'),
        el('button', { class: 'btn primary', onclick: () => { Q = null; render(); } }, 'Recommencer')));
      return;
    }
    const q = Content.quiz[Q.order[Q.i]];
    const card = el('div', { class: 'card quiz' }, el('div', { class: 'small' }, `Question ${Q.i + 1} / ${Q.order.length} · score ${Q.score}`), el('h3', {}, q.q));
    q.a.forEach((a, k) => card.appendChild(el('button', {
      class: 'answer' + (Q.answered != null ? (k === q.ok ? ' good' : k === Q.answered ? ' bad' : '') : ''), disabled: Q.answered != null ? true : null,
      onclick: () => { Q.answered = k; if (k === q.ok) Q.score++; render(); },
    }, a)));
    if (Q.answered != null) {
      card.appendChild(el('div', { class: Q.answered === q.ok ? 'tip' : 'warn' }, (Q.answered === q.ok ? '✔ Bonne réponse. ' : '✘ Raté. ') + q.why));
      card.appendChild(el('button', { class: 'btn primary', onclick: () => { Q.i++; Q.answered = null; render(); } }, 'Suivante →'));
    }
    view.appendChild(card);
  }
  function shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }

  // ------------------------------------------------------------ Aide
  function renderHelp() {
    view.appendChild(el('h2', { class: 'section-title' }, 'Aide'));
    const search = el('input', { class: 'search', placeholder: '🔍 Rechercher une erreur ou un mot (ex : double bobine, PNP, LAD-08)…', value: S.helpQ || '',
      oninput: (e) => { S.helpQ = e.target.value; fill(); } });
    view.appendChild(search);
    const out = el('div', {});
    view.appendChild(out);
    view.appendChild(el('div', { class: 'card' }, el('div', { class: 'card-title' }, '💾 Sauvegarde du projet'),
      el('p', { class: 'hint' }, 'Ton projet est enregistré automatiquement sur cet appareil. Tu peux aussi le copier pour le partager ou le garder.'),
      el('div', { class: 'row-btns' },
        el('button', { class: 'btn small', onclick: exportProject }, 'Exporter le projet'),
        el('button', { class: 'btn small', onclick: importProject }, 'Importer un projet'),
        el('button', { class: 'btn small danger', onclick: resetAll }, 'Tout réinitialiser'))));
    function fill() {
      clear(out);
      const q = (S.helpQ || '').toLowerCase().trim();
      const match = (...s) => !q || s.join(' ').toLowerCase().includes(q);
      const g = Content.glossary.filter(([t, d]) => match(t, d));
      const errs = Object.entries(Diag.catalog).filter(([code, e]) => match(code, e.title, e.why, e.fix));
      out.appendChild(el('h3', { class: 'section-title' }, `Glossaire (${g.length})`));
      out.appendChild(el('dl', { class: 'gloss card' }, g.map(([t, d]) => [el('dt', {}, t), el('dd', {}, d)])));
      out.appendChild(el('h3', { class: 'section-title' }, `Toutes les erreurs expliquées (${errs.length})`));
      out.appendChild(diagList(errs.map(([code, e]) => ({ code, level: e.level, title: e.title.replace(/\{\d\}/g, '…'), why: e.why.replace(/\{\d\}/g, '…'), fix: e.fix.replace(/\{\d\}/g, '…') }))));
    }
    fill();
  }
  async function exportProject() {
    const ta = el('textarea', { class: 'code-area', readonly: true }, JSON.stringify(S.project));
    setTimeout(() => ta.select(), 60);
    modal('Exporter le projet', el('div', {}, el('p', { class: 'hint' }, 'Copie ce texte et garde-le (notes, message…).'), ta),
      [{ label: 'Copier', value: () => { try { navigator.clipboard.writeText(ta.value); toast('Copié !', 'ok'); } catch (e) { /* presse-papiers indisponible */ } }, primary: true }, { label: 'Fermer', value: null }]);
  }
  async function importProject() {
    const ta = el('textarea', { class: 'code-area', placeholder: 'Colle ici le texte d\'un projet exporté' });
    const v = await modal('Importer un projet', ta, [{ label: 'Importer', value: () => ta.value, primary: true }, { label: 'Annuler', value: null }]);
    if (!v) return;
    try {
      const p = JSON.parse(v);
      if (!p.machine || !Machines.byId[p.machine] || !p.config || !p.ladder || !p.grafcet) throw new Error('format');
      S.project = p; S.tuto = null; loadedProject(); toast('Projet importé ✔', 'ok'); go('workshop');
    } catch (e) { toast('Ce texte n\'est pas un projet valide.', 'err'); }
  }
  async function resetAll() {
    const ok = await modal('Tout réinitialiser ?', el('p', {}, 'Le projet, la progression des tutoriels et le score du quiz seront effacés.'), [{ label: 'Effacer', value: true, primary: true }, { label: 'Annuler', value: false }]);
    if (!ok) return;
    S.project = newProject('convoyeur'); S.tuto = null; S.progress = {}; S.quizBest = 0; U.store('quizBest', 0);
    loadedProject(); go('home');
  }

  // ------------------------------------------------------------ Thème
  const themeBtn = document.getElementById('themeBtn');
  const applyTheme = (t) => { if (t) document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme; };
  applyTheme(U.load('theme', null));
  themeBtn.addEventListener('click', () => {
    const cur = document.documentElement.dataset.theme || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    const nt = cur === 'dark' ? 'light' : 'dark';
    applyTheme(nt); U.store('theme', nt);
  });

  // Bouton retour Android : revenir à l'accueil plutôt que quitter
  window.addEventListener('popstate', () => { if (S.view !== 'home') { go('home'); history.pushState(null, ''); } });
  history.pushState(null, '');

  compileProject();
  render();
  requestAnimationFrame(tick);
  return { S, RT, compileProject, transfer, setRun, go, newProject };
})();
