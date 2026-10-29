// Automate simulé « VARKON VK-200 » (marque et modèle fictifs, inspirés des automates
// modulaires réels). Rack de 10 emplacements :
//   emplacement 0 = alimentation, 1 = CPU, 2..9 = cartes d'entrées/sorties.
// Adressage : %I<emplacement>.<voie> pour les entrées, %Q<emplacement>.<voie> pour les sorties.
const PLC = (() => {
  const CATALOG = {
    PSU3: { kind: 'PSU', name: 'ALIM-24/3A', desc: 'Alimentation 230 V AC → 24 V DC, 3 A', supply: 3000 },
    PSU5: { kind: 'PSU', name: 'ALIM-24/5A', desc: 'Alimentation 230 V AC → 24 V DC, 5 A', supply: 5000 },
    CPU210: { kind: 'CPU', name: 'CPU VK-210', desc: 'CPU d\'entrée de gamme : 4 cartes max, 256 %M, 16 %T, 8 %C, port Ethernet',
      maxModules: 4, mem: 256, timers: 16, counters: 8, base: 3, perElem: 0.08, draw: 350 },
    CPU220: { kind: 'CPU', name: 'CPU VK-220', desc: 'CPU performant : 8 cartes max, 512 %M, 64 %T, 32 %C, port Ethernet',
      maxModules: 8, mem: 512, timers: 64, counters: 32, base: 1.5, perElem: 0.03, draw: 450 },
    DI8: { kind: 'DI', name: 'DI8-24DC', desc: '8 entrées TOR 24 V DC, logique réglable PNP/NPN', channels: 8, draw: 60 },
    DI16: { kind: 'DI', name: 'DI16-24DC', desc: '16 entrées TOR 24 V DC, logique réglable PNP/NPN', channels: 16, draw: 90 },
    DO8R: { kind: 'DO', name: 'DO8-REL', desc: '8 sorties à relais (contact sec) : 24 V DC ou 230 V AC, 2 A', channels: 8, draw: 220, volts: ['24VDC', '230VAC'] },
    DO8T: { kind: 'DO', name: 'DO8-TRA', desc: '8 sorties transistor 24 V DC, 0,5 A (rapides, sans usure)', channels: 8, draw: 70, volts: ['24VDC'] },
  };
  const SLOTS = 10;
  const PC = { ip: '192.168.1.10', mask: '255.255.255.0' };

  function defaultConfig() {
    return {
      rack: [{ type: 'PSU3' }, { type: 'CPU210' }, { type: 'DI8', logic: 'PNP' }, { type: 'DO8R' },
        null, null, null, null, null, null],
      ip: '192.168.1.20', mask: '255.255.255.0',
      task: { mode: 'cyclique', period: 20 }, watchdog: 150,
    };
  }
  function emptyConfig() {
    return { rack: new Array(SLOTS).fill(null), ip: '', mask: '255.255.255.0',
      task: { mode: 'cyclique', period: 20 }, watchdog: 150 };
  }

  function cpuOf(cfg) {
    const m = cfg.rack[1];
    return m && CATALOG[m.type] && CATALOG[m.type].kind === 'CPU' ? CATALOG[m.type] : null;
  }

  function parseIP(s) {
    const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(String(s || '').trim());
    if (!m) return null;
    const n = m.slice(1).map(Number);
    return n.every((x) => x >= 0 && x <= 255) ? n : null;
  }
  function validMask(n) {
    if (!n) return false;
    const bits = n.map((x) => x.toString(2).padStart(8, '0')).join('');
    return /^1+0*$/.test(bits);
  }

  // Estimation du temps de cycle (ms) en fonction de la taille du programme.
  function cycleTime(cfg, elems) {
    const cpu = cpuOf(cfg);
    if (!cpu) return 0;
    return Math.round((cpu.base + elems * cpu.perElem) * 10) / 10;
  }

  function validateConfig(cfg, elems = 0) {
    const d = [];
    const r = cfg.rack;
    if (!r[0] || CATALOG[r[0].type].kind !== 'PSU') d.push(Diag.make('CFG-01', [], { tab: 'config' }));
    if (!r[1] || CATALOG[r[1].type].kind !== 'CPU') d.push(Diag.make('CFG-02', [], { tab: 'config' }));
    let draw = 0, ioCount = 0, hasDI = false, hasDO = false;
    r.forEach((m, i) => {
      if (!m) return;
      const c = CATALOG[m.type];
      draw += c.draw || 0;
      if (c.kind === 'PSU' && i !== 0) d.push(Diag.make('CFG-05', [c.name, i], { tab: 'config' }));
      if (c.kind === 'CPU' && i !== 1) d.push(Diag.make('CFG-05', [c.name, i], { tab: 'config' }));
      if ((c.kind === 'DI' || c.kind === 'DO') && i < 2) d.push(Diag.make('CFG-05', [c.name, i], { tab: 'config' }));
      if (c.kind === 'DI' || c.kind === 'DO') { ioCount++; if (c.kind === 'DI') hasDI = true; else hasDO = true; }
    });
    const psu = r[0] && CATALOG[r[0].type].kind === 'PSU' ? CATALOG[r[0].type] : null;
    if (psu && draw > psu.supply) d.push(Diag.make('CFG-03', [draw, psu.supply], { tab: 'config' }));
    const cpu = cpuOf(cfg);
    if (cpu && ioCount > cpu.maxModules) d.push(Diag.make('CFG-04', [ioCount, cpu.maxModules], { tab: 'config' }));
    if (!hasDI || !hasDO) d.push(Diag.make('CFG-13', [], { tab: 'config' }));
    // Réseau
    const ip = parseIP(cfg.ip), mask = parseIP(cfg.mask);
    if (!ip) d.push(Diag.make('CFG-06', [cfg.ip || '(vide)'], { tab: 'config' }));
    if (!validMask(mask)) d.push(Diag.make('CFG-07', [cfg.mask || '(vide)'], { tab: 'config' }));
    if (ip && validMask(mask)) {
      const pc = parseIP(PC.ip);
      const net = (a) => a.map((x, k) => x & mask[k]);
      const hostAll0 = ip.every((x, k) => (x & ~mask[k] & 255) === 0);
      const hostAll1 = ip.every((x, k) => ((x | mask[k]) & 255) === 255);
      if (hostAll0 || hostAll1) {
        d.push(Diag.make('CFG-10', [cfg.ip], { tab: 'config' }));
      } else if (net(ip).join('.') !== net(pc).join('.')) {
        d.push(Diag.make('CFG-08', [PC.ip, cfg.mask, cfg.ip, pc.slice(0, 3).join('.')], { tab: 'config' }));
      } else if (ip.join('.') === pc.join('.')) {
        d.push(Diag.make('CFG-09', [], { tab: 'config' }));
      }
    }
    // Tâche
    const ct = cycleTime(cfg, elems);
    if (cpu && cfg.watchdog < ct) d.push(Diag.make('CFG-11', [cfg.watchdog, ct], { tab: 'config' }));
    if (cpu && cfg.task.mode === 'periodique' && cfg.task.period < ct) d.push(Diag.make('CFG-12', [cfg.task.period, ct], { tab: 'config' }));
    return d;
  }

  // Analyse d'une adresse. Retourne {ok, kind, slot, ch, n, reason}
  function checkAddr(addr, cfg) {
    const A = String(addr).toUpperCase();
    let m;
    if ((m = /^%([IQ])(\d+)\.(\d+)$/.exec(A))) {
      const kind = m[1], slot = +m[2], ch = +m[3];
      const mod = cfg.rack[slot];
      const want = kind === 'I' ? 'DI' : 'DO';
      if (slot >= SLOTS) return { ok: false, kind, slot, ch, reason: `Le rack n'a que ${SLOTS} emplacements (0 à ${SLOTS - 1}).` };
      if (!mod) return { ok: false, kind, slot, ch, reason: `L'emplacement ${slot} est vide : il n'y a pas de carte à cet endroit.` };
      const c = CATALOG[mod.type];
      if (c.kind !== want) return { ok: false, kind, slot, ch, reason: `L'emplacement ${slot} contient une carte ${c.name} (${c.kind === 'DI' ? 'entrées' : c.kind === 'DO' ? 'sorties' : c.kind}), pas une carte ${want === 'DI' ? 'd\'entrées' : 'de sorties'}.` };
      if (ch >= c.channels) return { ok: false, kind, slot, ch, reason: `La carte ${c.name} n'a que ${c.channels} voies (0 à ${c.channels - 1}).` };
      return { ok: true, kind, slot, ch, module: mod };
    }
    if ((m = /^%([MTCS])(\d+)$/.exec(A))) {
      const kind = m[1], n = +m[2];
      const cpu = cpuOf(cfg);
      if (!cpu) return { ok: false, kind, n, reason: 'Il n\'y a pas de CPU dans la configuration.' };
      const max = kind === 'M' ? cpu.mem : kind === 'T' ? cpu.timers : kind === 'C' ? cpu.counters : 8;
      if (n >= max) return { ok: false, kind, n, reason: `Le ${cpu.name} possède ${max} ${kind === 'M' ? 'bits internes' : kind === 'T' ? 'temporisations' : kind === 'C' ? 'compteurs' : 'bits système'} (%${kind}0 à %${kind}${max - 1}).` };
      return { ok: true, kind, n };
    }
    return { ok: false, kind: null, reason: 'Ce n\'est pas une adresse valide.' };
  }

  // Liste de toutes les adresses d'E/S disponibles
  function ioAddresses(cfg, kind) {
    const list = [];
    cfg.rack.forEach((m, slot) => {
      if (!m) return;
      const c = CATALOG[m.type];
      if (c.kind !== kind) return;
      for (let ch = 0; ch < c.channels; ch++) list.push(`%${kind === 'DI' ? 'I' : 'Q'}${slot}.${ch}`);
    });
    return list;
  }

  function validateWiring(project, machine) {
    const d = [];
    const cfg = project.config;
    const used = {};
    for (const io of machine.io) {
      const addr = project.wiring[io.sym];
      if (!addr) { d.push(Diag.make('CAB-06', [io.sym], { tab: 'wiring' })); continue; }
      const a = checkAddr(addr, cfg);
      const isIn = io.kind === 'DI';
      if (a.kind === 'Q' && isIn) { d.push(Diag.make('CAB-02', [io.sym, addr], { tab: 'wiring' })); continue; }
      if (a.kind === 'I' && !isIn) { d.push(Diag.make('CAB-03', [io.sym, addr], { tab: 'wiring' })); continue; }
      if (!a.ok) { d.push(Diag.make('CAB-01', [io.sym, addr, a.slot ?? '?'], { tab: 'wiring' })); continue; }
      (used[addr] = used[addr] || []).push(io.sym);
      const c = CATALOG[a.module.type];
      if (!isIn && io.volt && !c.volts.includes(io.volt)) d.push(Diag.make('CAB-05', [io.sym, io.volt === '230VAC' ? '230 V AC' : io.volt, c.name], { tab: 'wiring' }));
      if (isIn && io.sensor && (a.module.logic || 'PNP') !== io.sensor) d.push(Diag.make('CAB-07', [io.sym, io.sensor, a.module.logic || 'PNP'], { tab: 'wiring' }));
    }
    for (const [addr, syms] of Object.entries(used)) if (syms.length > 1) d.push(Diag.make('CAB-04', [addr, syms.join(', ')], { tab: 'wiring' }));
    return d;
  }

  // Table des mnémoniques complète : E/S de la machine + symboles utilisateur + système
  function symbolTable(project, machine) {
    const t = new Map();
    t.set('INIT', { addr: '%S1', comment: 'Bit système : vrai pendant le premier cycle seulement' });
    t.set('CLIGNO', { addr: '%S6', comment: 'Bit système : clignotant 1 Hz (0,5 s / 0,5 s)' });
    for (const io of machine.io) if (project.wiring[io.sym]) t.set(io.sym.toUpperCase(), { addr: project.wiring[io.sym].toUpperCase(), name: io.sym, comment: io.label });
    for (const s of project.symbols || []) if (s.name && s.addr) t.set(s.name.toUpperCase(), { addr: s.addr.toUpperCase(), name: s.name, comment: s.comment || '' });
    return t;
  }

  function resolve(name, table) {
    if (!name) return null;
    const N = String(name).trim();
    if (N.startsWith('%')) return N.toUpperCase();
    const e = table.get(N.toUpperCase());
    return e ? e.addr : null;
  }

  // Mémoire et temporisations/compteurs pendant l'exécution
  class Memory {
    constructor() { this.bits = new Map(); this.prev = new Map(); this.timers = {}; this.counters = {}; this.firstCycle = true; this.clock = 0; }
    get(addr) {
      if (!addr) return false;
      if (addr === '%S1') return this.firstCycle;
      if (addr === '%S6') return (this.clock % 1000) < 500;
      if (addr.startsWith('%T')) return !!(this.timers[addr] && this.timers[addr].q);
      if (addr.startsWith('%C')) return !!(this.counters[addr] && this.counters[addr].q);
      return !!this.bits.get(addr);
    }
    set(addr, v) { this.bits.set(addr, !!v); }
    timer(addr, type, input, pt, dt) {
      const t = this.timers[addr] || (this.timers[addr] = { type, et: 0, q: false, pt, in: false });
      t.type = type; t.pt = pt;
      if (type === 'TON') {
        if (input) { t.et = Math.min(pt, t.et + dt); t.q = t.et >= pt; } else { t.et = 0; t.q = false; }
      } else { // TOF : sortie vraie tout de suite, retombe pt ms après la disparition de l'entrée
        if (input) { t.et = 0; t.q = true; } else if (t.q) { t.et = Math.min(pt, t.et + dt); if (t.et >= pt) t.q = false; }
      }
      t.in = input;
    }
    counter(addr, input, pv, key) {
      const c = this.counters[addr] || (this.counters[addr] = { cv: 0, pv, q: false, last: {} });
      c.pv = pv;
      if (input && !c.last[key]) c.cv = Math.min(9999, c.cv + 1);
      c.last[key] = input;
      c.q = c.cv >= c.pv;
    }
    resetCounter(addr) { const c = this.counters[addr]; if (c) { c.cv = 0; c.q = false; } }
    resetTimer(addr) { const t = this.timers[addr]; if (t) { t.et = 0; t.q = false; } }
  }

  return { CATALOG, SLOTS, PC, defaultConfig, emptyConfig, cpuOf, validateConfig, checkAddr, ioAddresses,
    validateWiring, symbolTable, resolve, cycleTime, Memory, parseIP };
})();
