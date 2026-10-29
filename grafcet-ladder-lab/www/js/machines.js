// Machines virtuelles (partie opérative simulée). Chaque machine décrit ses
// capteurs/actionneurs, sa physique, son dessin animé, ses défauts et ses objectifs.
const Machines = (() => {
  const S = U.svg;
  const btnIO = (sym, label, nc = false) => ({ sym, kind: 'DI', label, dev: nc ? 'Bouton NC' : 'Bouton NO', nc });
  const sensor = (sym, label, type = 'PNP') => ({ sym, kind: 'DI', label, dev: `Capteur ${type}`, sensor: type });
  const act = (sym, label, volt = '24VDC', dev = 'Actionneur') => ({ sym, kind: 'DO', label, dev, volt });

  function pressed(st, sym) { return !!(st.btn[sym] || (st.hold[sym] && st.hold[sym] > st.t)); }
  function base() { return { t: 0, btn: {}, hold: {}, fault: null, msgs: [], stats: {} }; }
  function fault(st, title, why) { if (!st.fault) st.fault = { title, why }; }
  function note(st, text) { st.msgs.push({ t: st.t, text }); if (st.msgs.length > 6) st.msgs.shift(); }

  // Éléments graphiques communs
  function lamp(x, y, color, label) {
    const g = S('g', {});
    const c = S('circle', { cx: x, cy: y, r: 9, fill: '#333', stroke: '#111', 'stroke-width': 2 });
    g.appendChild(c);
    if (label) g.appendChild(S('text', { x, y: y + 22, 'text-anchor': 'middle', class: 'm-label' }, label));
    return { g, set(on) { c.setAttribute('fill', on ? color : '#3a3a3a'); c.setAttribute('filter', on ? 'url(#glow)' : ''); } };
  }
  function sensorDot(x, y, label) {
    const g = S('g', {});
    const r = S('rect', { x: x - 6, y: y - 6, width: 12, height: 12, rx: 2, fill: '#555', stroke: '#222' });
    g.appendChild(r);
    if (label) g.appendChild(S('text', { x, y: y - 10, 'text-anchor': 'middle', class: 'm-label' }, label));
    return { g, set(on) { r.setAttribute('fill', on ? '#ffd23f' : '#555'); } };
  }
  function defs() {
    return S('defs', {}, S('filter', { id: 'glow', x: '-50%', y: '-50%', width: '200%', height: '200%' },
      S('feGaussianBlur', { stdDeviation: 3, result: 'b' }),
      S('feMerge', {}, S('feMergeNode', { in: 'b' }), S('feMergeNode', { in: 'SourceGraphic' }))),
    S('pattern', { id: 'belt', width: 20, height: 14, patternUnits: 'userSpaceOnUse' },
      S('rect', { width: 20, height: 14, fill: '#2b2b2b' }), S('rect', { width: 4, height: 14, fill: '#444' })));
  }
  function frame(h = 260) {
    const svg = S('svg', { viewBox: `0 0 400 ${h}`, class: 'machine-svg', role: 'img' });
    svg.appendChild(defs());
    svg.appendChild(S('rect', { x: 0, y: 0, width: 400, height: h, fill: '#1d2430' }));
    return svg;
  }

  // ======================================================== 1. Tapis roulant
  const convoyeur = {
    id: 'convoyeur', name: 'Tapis roulant', icon: '📦', level: 'Débutant',
    desc: 'Un tapis qui transporte des cartons jusqu\'à un bac. Idéal pour apprendre la marche/arrêt et l\'auto-maintien.',
    story: 'Un appui sur Marche (MA) démarre le moteur du tapis (KM1). Un appui sur Arrêt (AT) l\'arrête. Le voyant H1 est allumé quand le tapis tourne. L\'arrêt d\'urgence (AU) doit arrêter le tapis immédiatement. Le capteur FC détecte un carton en bout de tapis.',
    io: [btnIO('MA', 'Bouton Marche'), btnIO('AT', 'Bouton Arrêt (contact NC)', true), btnIO('AU', 'Arrêt d\'urgence (contact NC)', true),
      sensor('FC', 'Capteur fin de tapis'), act('KM1', 'Contacteur du moteur du tapis'), act('H1', 'Voyant vert « tapis en marche »')],
    defaultWiring: { MA: '%I2.0', AT: '%I2.1', AU: '%I2.2', FC: '%I2.3', KM1: '%Q3.0', H1: '%Q3.1' },
    controls: [{ sym: 'MA', label: 'Marche', kind: 'push', color: 'green' }, { sym: 'AT', label: 'Arrêt', kind: 'push', color: 'red' },
      { sym: 'AU', label: 'AU', kind: 'latch', color: 'au' }, { id: 'add', label: '+ Poser un carton', kind: 'action' }],
    create() { const st = base(); st.boxes = [{ x: 60 }]; st.belt = 0; st.delivered = 0; st.motor = false; return st; },
    action(st, id) { if (id === 'add') { if (st.boxes.some((b) => b.x < 100)) note(st, 'Il y a déjà un carton au début du tapis.'); else st.boxes.push({ x: 60 }); } },
    inputs(st) {
      return { MA: pressed(st, 'MA'), AT: !pressed(st, 'AT'), AU: !st.btn.AU, FC: st.boxes.some((b) => Math.abs(b.x - 320) < 16) };
    },
    step(st, o, dt) {
      const was = st.motor;
      st.motor = !!o.KM1;
      if (st.motor) {
        st.stats.ran = true;
        st.belt = (st.belt + dt * 0.06) % 20;
        for (const b of st.boxes) b.x += dt * 0.06;
        const before = st.boxes.length;
        st.boxes = st.boxes.filter((b) => b.x < 360);
        if (st.boxes.length < before) { st.delivered += before - st.boxes.length; note(st, `Carton livré (${st.delivered})`); }
      }
      if (was && !st.motor && pressed(st, 'AT')) st.stats.stopAT = true;
      if (st.btn.AU) {
        if (st.motor) { st.auTime = (st.auTime || 0) + dt; if (st.auTime > 400) fault(st, 'Arrêt d\'urgence non pris en compte !', 'Le bouton d\'arrêt d\'urgence est enfoncé mais le moteur continue de tourner. C\'est très dangereux : l\'AU doit couper le moteur dans TOUS les cas, même si Marche est appuyé. Place le contact AU en série dans la ligne du moteur.'); }
        else { if (was) st.stats.stopAU = true; st.auTime = 0; }
      } else st.auTime = 0;
    },
    view() {
      const svg = frame();
      svg.appendChild(S('rect', { x: 30, y: 150, width: 320, height: 18, rx: 9, fill: 'url(#belt)' }));
      svg.appendChild(S('circle', { cx: 40, cy: 159, r: 12, fill: '#777' }));
      svg.appendChild(S('circle', { cx: 340, cy: 159, r: 12, fill: '#777' }));
      const motorRect = S('rect', { x: 20, y: 175, width: 40, height: 30, rx: 4, fill: '#4a6' });
      svg.appendChild(motorRect);
      svg.appendChild(S('text', { x: 40, y: 195, 'text-anchor': 'middle', class: 'm-label dark' }, 'M'));
      svg.appendChild(S('text', { x: 40, y: 222, 'text-anchor': 'middle', class: 'm-label' }, 'Moteur (KM1)'));
      svg.appendChild(S('rect', { x: 355, y: 180, width: 40, height: 60, fill: '#5b4636', stroke: '#2a1f17' }));
      svg.appendChild(S('text', { x: 375, y: 252, 'text-anchor': 'middle', class: 'm-label' }, 'Bac'));
      const fc = sensorDot(320, 130, 'FC'); svg.appendChild(fc.g);
      const h1 = lamp(200, 40, '#3f3', 'H1'); svg.appendChild(h1.g);
      const boxesG = S('g', {}); svg.appendChild(boxesG);
      const counter = S('text', { x: 380, y: 30, 'text-anchor': 'end', class: 'm-big' }, '0');
      svg.appendChild(counter);
      svg.appendChild(S('text', { x: 380, y: 45, 'text-anchor': 'end', class: 'm-label' }, 'livrés'));
      return {
        node: svg,
        update(st, inp, out) {
          svg.querySelector('pattern#belt').setAttribute('x', st.belt);
          motorRect.setAttribute('fill', st.motor ? '#3c3' : '#4a6a55');
          fc.set(inp.FC); h1.set(out.H1);
          U.clear(boxesG);
          for (const b of st.boxes) boxesG.appendChild(S('rect', { x: b.x - 15, y: 120, width: 30, height: 30, fill: '#c8955a', stroke: '#7a5530', 'stroke-width': 2 }));
          counter.textContent = st.delivered;
        },
      };
    },
    goals: [
      { text: 'Démarrer le tapis avec Marche', done: (st) => st.stats.ran },
      { text: 'Arrêter le tapis avec le bouton Arrêt', done: (st) => st.stats.stopAT },
      { text: 'Livrer 3 cartons dans le bac', done: (st) => st.delivered >= 3 },
      { text: 'L\'arrêt d\'urgence arrête le tapis', done: (st) => st.stats.stopAU },
    ],
  };

  // ======================================================== 2. Perceuse
  const perceuse = {
    id: 'perceuse', name: 'Perceuse automatique', icon: '🛠️', level: 'Intermédiaire',
    desc: 'Le grand classique du GRAFCET : un vérin fait descendre une broche qui perce une pièce.',
    story: 'Quand une pièce est présente (S0), le vérin est en haut (S1) et que l\'opérateur appuie sur départ cycle (DCY) : le moteur de la broche démarre (KM1) et le vérin descend (Y1). Arrivé en bas (S2), le vérin remonte (Y2), la broche tourne toujours. Arrivé en haut (S1), le moteur s\'arrête : retour à l\'état initial. Le distributeur est BISTABLE : il garde sa position quand on coupe Y1/Y2. Attention : ne jamais commander Y1 et Y2 ensemble, et ne jamais descendre broche arrêtée.',
    io: [btnIO('DCY', 'Bouton départ cycle'), btnIO('AU', 'Arrêt d\'urgence (NC)', true), sensor('S0', 'Capteur pièce présente'),
      sensor('S1', 'Capteur vérin en haut'), sensor('S2', 'Capteur vérin en bas'),
      act('KM1', 'Contacteur moteur de broche (230 V)', '230VAC'), act('Y1', 'Électrovanne descente (14M1)'), act('Y2', 'Électrovanne montée (12M1)')],
    defaultWiring: { DCY: '%I2.0', AU: '%I2.1', S0: '%I2.2', S1: '%I2.3', S2: '%I2.4', KM1: '%Q3.0', Y1: '%Q3.1', Y2: '%Q3.2' },
    controls: [{ sym: 'DCY', label: 'Départ cycle', kind: 'push', color: 'green' }, { sym: 'AU', label: 'AU', kind: 'latch', color: 'au' },
      { id: 'put', label: '+ Poser pièce', kind: 'action' }, { id: 'take', label: '− Retirer pièce', kind: 'action' }],
    create() { const st = base(); st.pos = 0; st.dir = 0; st.piece = { drilled: false }; st.drilled = 0; st.angle = 0; st.km = false; return st; },
    action(st, id) {
      if (id === 'put') { if (st.piece) note(st, 'Il y a déjà une pièce.'); else if (st.pos > 0.2) note(st, 'Danger : attends que la broche soit remontée !'); else st.piece = { drilled: false }; }
      if (id === 'take') { if (!st.piece) note(st, 'Pas de pièce à retirer.'); else if (st.pos > 0.2) note(st, 'Danger : la broche est descendue !'); else { if (st.piece.drilled) st.stats.out = (st.stats.out || 0) + 1; st.piece = null; } }
    },
    inputs(st) { return { DCY: pressed(st, 'DCY'), AU: !st.btn.AU, S0: !!st.piece, S1: st.pos <= 0.02, S2: st.pos >= 0.98 }; },
    step(st, o, dt) {
      if (o.Y1 && o.Y2) { st.both = (st.both || 0) + dt; if (st.both > 60) fault(st, 'Distributeur commandé dans les deux sens', 'Y1 (descente) et Y2 (montée) sont commandées en même temps. Sur un distributeur bistable, c\'est un conflit : la tige ne sait pas où aller et le distributeur peut être endommagé. Dans ton GRAFCET, Y1 et Y2 ne doivent jamais être actives dans la même étape.'); }
      else st.both = 0;
      if (o.Y1 && !o.Y2) st.dir = 1;
      if (o.Y2 && !o.Y1) st.dir = -1;
      st.km = !!o.KM1;
      if (st.km) st.angle = (st.angle + dt * 1.2) % 360;
      st.pos = Math.max(0, Math.min(1, st.pos + st.dir * dt * 0.00045));
      if (st.pos > 0.55 && st.piece && !st.piece.drilled && !st.km) fault(st, 'Foret cassé !', 'La broche est descendue dans la pièce alors que le moteur ne tournait pas (KM1 = 0). Le moteur doit être démarré AVANT la descente et rester en marche pendant la remontée.');
      if (st.pos >= 0.98 && st.piece && !st.piece.drilled && st.km) { st.piece.drilled = true; st.drilled++; note(st, `Pièce percée (${st.drilled})`); }
      if (st.pos <= 0.02 && st.piece && st.piece.drilled && !st.km && st.dir <= 0) st.stats.clean = true;
      if (st.btn.AU && (st.km || st.dir === 1 && st.pos < 0.98 && o.Y1)) { st.au = (st.au || 0) + dt; if (st.au > 500) fault(st, 'Arrêt d\'urgence non pris en compte !', 'L\'arrêt d\'urgence est enfoncé mais la machine continue. Le contact AU doit bloquer toutes les évolutions et couper les actionneurs.'); }
      else st.au = 0;
    },
    view() {
      const svg = frame();
      svg.appendChild(S('rect', { x: 60, y: 20, width: 20, height: 220, fill: '#667' }));
      svg.appendChild(S('rect', { x: 40, y: 235, width: 300, height: 15, fill: '#556' }));
      const cyl = S('rect', { x: 150, y: 20, width: 60, height: 50, rx: 4, fill: '#8aa' });
      svg.appendChild(cyl);
      svg.appendChild(S('text', { x: 180, y: 50, 'text-anchor': 'middle', class: 'm-label dark' }, 'Vérin'));
      const head = S('g', {});
      head.appendChild(S('rect', { x: 172, y: 0, width: 16, height: 60, fill: '#bbb' }));
      head.appendChild(S('rect', { x: 150, y: 60, width: 60, height: 36, rx: 4, fill: '#4a6' }));
      const mtxt = S('text', { x: 180, y: 83, 'text-anchor': 'middle', class: 'm-label dark' }, 'M');
      head.appendChild(mtxt);
      const bit = S('g', {});
      bit.appendChild(S('rect', { x: 176, y: 96, width: 8, height: 40, fill: '#ddd' }));
      bit.appendChild(S('path', { d: 'M176 136 L180 146 L184 136 Z', fill: '#ddd' }));
      head.appendChild(bit);
      svg.appendChild(head);
      const piece = S('rect', { x: 140, y: 200, width: 80, height: 35, fill: '#b87333', stroke: '#6b4019', 'stroke-width': 2 });
      const hole = S('rect', { x: 176, y: 200, width: 8, height: 20, fill: '#222' });
      svg.appendChild(piece); svg.appendChild(hole);
      const s1 = sensorDot(240, 70, 'S1'), s2 = sensorDot(240, 160, 'S2'), s0 = sensorDot(110, 218, 'S0');
      [s1, s2, s0].forEach((x) => svg.appendChild(x.g));
      const cnt = S('text', { x: 380, y: 30, 'text-anchor': 'end', class: 'm-big' }, '0');
      svg.appendChild(cnt);
      svg.appendChild(S('text', { x: 380, y: 45, 'text-anchor': 'end', class: 'm-label' }, 'percées'));
      const y1 = lamp(300, 100, '#4af', 'Y1↓'), y2 = lamp(345, 100, '#4af', 'Y2↑');
      svg.appendChild(y1.g); svg.appendChild(y2.g);
      return {
        node: svg,
        update(st, inp, out) {
          const dy = st.pos * 90;
          head.setAttribute('transform', `translate(0 ${dy})`);
          head.children[1].setAttribute('fill', st.km ? '#3c3' : '#4a6a55');
          bit.setAttribute('transform', `rotate(${st.km ? (st.angle % 20) - 10 : 0} 180 120)`);
          piece.setAttribute('visibility', st.piece ? 'visible' : 'hidden');
          hole.setAttribute('visibility', st.piece && st.piece.drilled ? 'visible' : 'hidden');
          s1.set(inp.S1); s2.set(inp.S2); s0.set(inp.S0); y1.set(out.Y1); y2.set(out.Y2);
          cnt.textContent = st.drilled;
        },
      };
    },
    goals: [
      { text: 'Percer une pièce', done: (st) => st.drilled >= 1 },
      { text: 'Revenir en haut, moteur arrêté', done: (st) => st.stats.clean },
      { text: 'Percer 3 pièces (pose/retire les pièces)', done: (st) => st.drilled >= 3 },
    ],
  };

  // ======================================================== 3. Cuve de mélange
  const cuve = {
    id: 'cuve', name: 'Cuve de mélange', icon: '🧪', level: 'Intermédiaire',
    desc: 'Remplir une cuve, mélanger pendant un temps donné puis vider. Parfait pour les temporisations.',
    story: 'Appui sur DCY (cuve vide, NB = 0) : la vanne V1 s\'ouvre et remplit la cuve. Au niveau haut (NH) : V1 se ferme et le mélangeur MEL tourne pendant 5 secondes. Ensuite la pompe P1 vide la cuve jusqu\'à ce que le niveau bas (NB) ne détecte plus rien. Le mélangeur et la pompe sont en 230 V alternatif.',
    io: [btnIO('DCY', 'Bouton départ cycle'), btnIO('AU', 'Arrêt d\'urgence (NC)', true), sensor('NB', 'Capteur niveau bas (détecte du liquide)'), sensor('NH', 'Capteur niveau haut'),
      act('V1', 'Électrovanne de remplissage'), act('MEL', 'Moteur du mélangeur (230 V)', '230VAC'), act('P1', 'Pompe de vidange (230 V)', '230VAC')],
    defaultWiring: { DCY: '%I2.0', AU: '%I2.1', NB: '%I2.2', NH: '%I2.3', V1: '%Q3.0', MEL: '%Q3.1', P1: '%Q3.2' },
    controls: [{ sym: 'DCY', label: 'Départ cycle', kind: 'push', color: 'green' }, { sym: 'AU', label: 'AU', kind: 'latch', color: 'au' }],
    create() { const st = base(); st.level = 0; st.mix = 0; st.batches = 0; st.ang = 0; st.flags = {}; return st; },
    inputs(st) { return { DCY: pressed(st, 'DCY'), AU: !st.btn.AU, NB: st.level > 0.1, NH: st.level > 0.88 }; },
    step(st, o, dt) {
      const s = dt / 1000;
      if (o.V1) st.level += 0.11 * s;
      if (o.P1) st.level -= 0.14 * s;
      st.level = Math.max(0, st.level);
      if (st.level > 0.88) st.stats.full = true;
      if (o.MEL) { st.ang = (st.ang + dt * 0.5) % 360; if (st.level > 0.5) st.mix += dt; }
      if (st.mix >= 4800) st.stats.mixed = true;
      if (st.level >= 1.0) fault(st, 'La cuve déborde !', 'Le niveau haut NH est atteint mais la vanne V1 est restée ouverte. Le remplissage doit s\'arrêter dès que NH passe à 1 (c\'est la réceptivité de la transition).');
      if (o.P1 && st.level <= 0.001) { st.dry = (st.dry || 0) + dt; if (st.dry > 2500) fault(st, 'Pompe à sec !', 'La pompe P1 tourne alors que la cuve est vide. Une pompe qui tourne sans liquide chauffe et s\'abîme. Arrête la pompe quand le niveau bas ne détecte plus de liquide (/NB).'); }
      else st.dry = 0;
      if (st.level > 0.8) st.flags.wasFull = true;
      if (st.flags.wasFull && st.level <= 0.1) {
        st.flags.wasFull = false;
        if (st.mix >= 4500) { st.batches++; note(st, `Lot terminé (${st.batches})`); } else note(st, 'Lot raté : produit pas assez mélangé (5 s minimum) !');
        st.mix = 0;
      }
      if (st.btn.AU && (o.V1 || o.P1 || o.MEL)) { st.au = (st.au || 0) + dt; if (st.au > 500) fault(st, 'Arrêt d\'urgence non pris en compte !', 'L\'AU est enfoncé mais des actionneurs restent commandés. L\'AU doit tout arrêter.'); }
      else st.au = 0;
    },
    view() {
      const svg = frame();
      svg.appendChild(S('rect', { x: 20, y: 30, width: 140, height: 10, fill: '#889' }));
      const v1 = S('rect', { x: 150, y: 24, width: 20, height: 22, fill: '#a33' });
      svg.appendChild(v1);
      svg.appendChild(S('text', { x: 160, y: 18, 'text-anchor': 'middle', class: 'm-label' }, 'V1'));
      const flow = S('rect', { x: 166, y: 46, width: 8, height: 160, fill: '#39f', opacity: 0.7 });
      svg.appendChild(flow);
      svg.appendChild(S('rect', { x: 120, y: 60, width: 160, height: 160, fill: '#0b0f15', stroke: '#aab', 'stroke-width': 3 }));
      const liq = S('rect', { x: 122, y: 218, width: 156, height: 0, fill: '#39f', opacity: 0.85 });
      svg.appendChild(liq);
      const mixer = S('g', {});
      mixer.appendChild(S('rect', { x: 198, y: 40, width: 4, height: 150, fill: '#ccc' }));
      const blade = S('rect', { x: 180, y: 185, width: 40, height: 6, fill: '#ccc' });
      mixer.appendChild(blade);
      svg.appendChild(mixer);
      const mot = S('rect', { x: 185, y: 20, width: 30, height: 22, rx: 3, fill: '#4a6' });
      svg.appendChild(mot);
      svg.appendChild(S('text', { x: 200, y: 36, 'text-anchor': 'middle', class: 'm-label dark' }, 'MEL'));
      svg.appendChild(S('rect', { x: 280, y: 205, width: 60, height: 10, fill: '#889' }));
      const pump = S('circle', { cx: 350, cy: 210, r: 14, fill: '#4a6' });
      svg.appendChild(pump);
      svg.appendChild(S('text', { x: 350, y: 240, 'text-anchor': 'middle', class: 'm-label' }, 'P1'));
      const nh = sensorDot(290, 80, 'NH'), nb = sensorDot(290, 200, 'NB');
      svg.appendChild(nh.g); svg.appendChild(nb.g);
      const cnt = S('text', { x: 380, y: 30, 'text-anchor': 'end', class: 'm-big' }, '0');
      svg.appendChild(cnt);
      svg.appendChild(S('text', { x: 380, y: 45, 'text-anchor': 'end', class: 'm-label' }, 'lots'));
      const mixT = S('text', { x: 60, y: 120, 'text-anchor': 'middle', class: 'm-label' }, '');
      svg.appendChild(mixT);
      return {
        node: svg,
        update(st, inp, out) {
          const h = Math.min(1.05, st.level) * 156;
          liq.setAttribute('y', 218 - h); liq.setAttribute('height', h);
          flow.setAttribute('visibility', out.V1 ? 'visible' : 'hidden');
          v1.setAttribute('fill', out.V1 ? '#3c3' : '#a33');
          mot.setAttribute('fill', out.MEL ? '#3c3' : '#4a6a55');
          blade.setAttribute('width', out.MEL ? 10 + Math.abs(Math.cos(st.ang / 30)) * 30 : 40);
          blade.setAttribute('x', 200 - parseFloat(blade.getAttribute('width')) / 2);
          pump.setAttribute('fill', out.P1 ? '#3c3' : '#4a6a55');
          nh.set(inp.NH); nb.set(inp.NB);
          cnt.textContent = st.batches;
          mixT.textContent = st.mix > 0 ? `mélange : ${(st.mix / 1000).toFixed(1)} s` : '';
        },
      };
    },
    goals: [
      { text: 'Remplir jusqu\'au niveau haut sans déborder', done: (st) => st.stats.full },
      { text: 'Mélanger pendant 5 secondes', done: (st) => st.stats.mixed },
      { text: 'Réaliser 2 lots complets', done: (st) => st.batches >= 2 },
    ],
  };

  // ======================================================== 4. Tri de colis
  const tri = {
    id: 'tri', name: 'Tri de colis', icon: '🏭', level: 'Avancé',
    desc: 'Un tapis amène des petits et des grands colis. Les grands doivent être poussés dans le bac par un vérin.',
    story: 'Marche (MA) démarre le tapis (KM1) et allume H1. Arrêt (AT) l\'arrête. Les colis arrivent tout seuls. Devant le poussoir, le capteur SP détecte un colis et la barrière haute SG détecte s\'il est GRAND. Un grand colis doit être poussé dans le bac : arrêter le tapis, sortir le poussoir (Y1) jusqu\'à SS, puis le rentrer (ressort, Y1 = 0) jusqu\'à SR et repartir. Les petits colis continuent jusqu\'au bout. Le vérin est MONOSTABLE : il rentre tout seul quand Y1 = 0.',
    io: [btnIO('MA', 'Bouton Marche'), btnIO('AT', 'Bouton Arrêt (NC)', true), btnIO('AU', 'Arrêt d\'urgence (NC)', true),
      sensor('SP', 'Capteur présence colis devant le poussoir'), sensor('SG', 'Barrière « grand colis »'), sensor('SR', 'Capteur poussoir rentré'), sensor('SS', 'Capteur poussoir sorti'),
      act('KM1', 'Contacteur moteur du tapis'), act('Y1', 'Électrovanne du poussoir (monostable)'), act('H1', 'Voyant « en marche »')],
    defaultWiring: { MA: '%I2.0', AT: '%I2.1', AU: '%I2.2', SP: '%I2.3', SG: '%I2.4', SR: '%I2.5', SS: '%I2.6', KM1: '%Q3.0', Y1: '%Q3.1', H1: '%Q3.2' },
    controls: [{ sym: 'MA', label: 'Marche', kind: 'push', color: 'green' }, { sym: 'AT', label: 'Arrêt', kind: 'push', color: 'red' },
      { sym: 'AU', label: 'AU', kind: 'latch', color: 'au' }, { id: 'add', label: '+ Colis', kind: 'action' }],
    create() { const st = base(); st.boxes = []; st.p = 0; st.belt = 0; st.good = 0; st.bad = 0; st.big = 0; st.small = 0; st.spawn = 1500; st.seq = 0; return st; },
    action(st, id) { if (id === 'add') spawnBox(st); },
    inputs(st) {
      const at = st.boxes.find((b) => !b.out && Math.abs(b.x - 220) < 14);
      return { MA: pressed(st, 'MA'), AT: !pressed(st, 'AT'), AU: !st.btn.AU, SP: !!at, SG: !!(at && at.big), SR: st.p <= 0.02, SS: st.p >= 0.98 };
    },
    step(st, o, dt) {
      if (o.KM1) {
        st.belt = (st.belt + dt * 0.05) % 20;
        st.spawn -= dt;
        if (st.spawn <= 0) { spawnBox(st); st.spawn = 2600 + ((st.seq * 7919) % 1800); }
        for (const b of st.boxes) if (!b.out) b.x += dt * 0.05;
      }
      st.p = Math.max(0, Math.min(1, st.p + (o.Y1 ? 1 : -0.8) * dt * 0.0025));
      for (const b of st.boxes) {
        if (!b.out && st.p > 0.35 && Math.abs(b.x - 220) < 22) {
          if (Math.abs(b.x - 220) > 14) { fault(st, 'Colis coincé contre le poussoir !', 'Le poussoir est sorti alors que le colis n\'était pas bien en face (le capteur SP ne le détectait pas encore). Il faut attendre SP = 1 et arrêter le tapis avant de pousser.'); }
          b.out = true;
          if (b.big) { st.good++; st.big++; note(st, 'Grand colis trié ✔'); } else { st.bad++; note(st, 'Erreur : petit colis poussé dans le bac ✘'); }
        }
        if (b.out) b.y = Math.min(60, (b.y || 0) + dt * 0.12);
      }
      st.boxes = st.boxes.filter((b) => {
        if (b.out) return b.y < 60;
        if (b.x >= 375) { if (b.big) { st.bad++; note(st, 'Erreur : grand colis non trié ✘'); } else { st.good++; st.small++; } return false; }
        return true;
      });
      if (st.btn.AU && (o.KM1 || o.Y1)) { st.au = (st.au || 0) + dt; if (st.au > 500) fault(st, 'Arrêt d\'urgence non pris en compte !', 'L\'AU est enfoncé mais le tapis ou le poussoir sont encore commandés.'); }
      else st.au = 0;
    },
    view() {
      const svg = frame();
      svg.appendChild(S('rect', { x: 20, y: 110, width: 360, height: 18, rx: 9, fill: 'url(#belt)' }));
      svg.appendChild(S('rect', { x: 196, y: 140, width: 48, height: 60, fill: '#5b4636', stroke: '#2a1f17' }));
      svg.appendChild(S('text', { x: 220, y: 215, 'text-anchor': 'middle', class: 'm-label' }, 'Bac grands'));
      svg.appendChild(S('text', { x: 370, y: 150, 'text-anchor': 'end', class: 'm-label' }, 'petits →'));
      svg.appendChild(S('rect', { x: 200, y: 20, width: 40, height: 30, fill: '#8aa' }));
      const rod = S('rect', { x: 215, y: 50, width: 10, height: 10, fill: '#bbb' });
      const pad = S('rect', { x: 200, y: 58, width: 40, height: 6, fill: '#ddd' });
      svg.appendChild(rod); svg.appendChild(pad);
      const sp = sensorDot(175, 140, 'SP'), sg = sensorDot(175, 60, 'SG'), sr = sensorDot(260, 30, 'SR'), ss = sensorDot(260, 70, 'SS');
      [sp, sg, sr, ss].forEach((x) => svg.appendChild(x.g));
      const h1 = lamp(40, 40, '#3f3', 'H1'); svg.appendChild(h1.g);
      const boxesG = S('g', {}); svg.appendChild(boxesG);
      const score = S('text', { x: 390, y: 30, 'text-anchor': 'end', class: 'm-big' }, '');
      svg.appendChild(score);
      svg.appendChild(S('text', { x: 390, y: 45, 'text-anchor': 'end', class: 'm-label' }, 'bons / erreurs'));
      return {
        node: svg,
        update(st, inp, out) {
          svg.querySelector('pattern#belt').setAttribute('x', st.belt);
          const ext = st.p * 42;
          rod.setAttribute('height', 10 + ext); pad.setAttribute('y', 58 + ext);
          sp.set(inp.SP); sg.set(inp.SG); sr.set(inp.SR); ss.set(inp.SS); h1.set(out.H1);
          U.clear(boxesG);
          for (const b of st.boxes) {
            const h = b.big ? 46 : 24;
            boxesG.appendChild(S('rect', { x: b.x - 14, y: 110 - h + (b.y || 0) * 1.6, width: 28, height: h, fill: b.big ? '#d08a4a' : '#e8c27a', stroke: '#7a5530', 'stroke-width': 2, opacity: b.out ? 0.8 : 1 }));
          }
          score.textContent = `${st.good} / ${st.bad}`;
        },
      };
    },
    goals: [
      { text: 'Trier 3 grands colis', done: (st) => st.big >= 3 },
      { text: 'Laisser passer 3 petits colis', done: (st) => st.small >= 3 },
      { text: '10 bons colis sans aucune erreur', done: (st) => st.good >= 10 && st.bad === 0 },
    ],
  };
  function spawnBox(st) {
    if (st.boxes.some((b) => !b.out && b.x < 70)) return;
    st.seq++;
    const big = [1, 0, 0, 1, 0, 1, 1, 0, 0, 1][st.seq % 10] === 1;
    st.boxes.push({ x: 30, big });
  }

  // ======================================================== 5. Feux de carrefour
  const feux = {
    id: 'feux', name: 'Feux de carrefour', icon: '🚦', level: 'Intermédiaire',
    desc: 'Deux feux tricolores à synchroniser avec des temporisations. Une seule voie au vert à la fois !',
    story: 'Après un appui sur MA, le cycle démarre : Voie 1 au vert 6 s (voie 2 au rouge), puis orange 2 s, puis rouge partout 1 s (sécurité), puis Voie 2 au vert 6 s, orange 2 s, rouge partout 1 s, et on recommence. Un appui sur AT arrête le cycle à la fin et éteint tout (ou fait clignoter les oranges avec CLIGNO, en bonus).',
    io: [btnIO('MA', 'Bouton Marche'), btnIO('AT', 'Bouton Arrêt (NC)', true),
      act('R1', 'Feu rouge voie 1'), act('O1', 'Feu orange voie 1'), act('V1', 'Feu vert voie 1'),
      act('R2', 'Feu rouge voie 2'), act('O2', 'Feu orange voie 2'), act('V2', 'Feu vert voie 2')],
    defaultWiring: { MA: '%I2.0', AT: '%I2.1', R1: '%Q3.0', O1: '%Q3.1', V1: '%Q3.2', R2: '%Q3.3', O2: '%Q3.4', V2: '%Q3.5' },
    controls: [{ sym: 'MA', label: 'Marche', kind: 'push', color: 'green' }, { sym: 'AT', label: 'Arrêt', kind: 'push', color: 'red' }],
    create() { const st = base(); st.cars1 = [0.1, 0.55]; st.cars2 = [0.3, 0.8]; st.phase1 = ''; st.cycles = 0; st.o1 = 0; st.allRed = 0; st.seq = []; return st; },
    inputs(st) { return { MA: pressed(st, 'MA'), AT: !pressed(st, 'AT') }; },
    step(st, o, dt) {
      if ([o.R1, o.O1, o.V1].filter(Boolean).length > 1) fault(st, 'Feu 1 : plusieurs couleurs allumées', 'Un feu tricolore ne doit afficher qu\'une seule couleur à la fois, sinon les conducteurs ne savent pas quoi faire. Vérifie qu\'une sortie s\'éteint quand la suivante s\'allume.');
      if ([o.R2, o.O2, o.V2].filter(Boolean).length > 1) fault(st, 'Feu 2 : plusieurs couleurs allumées', 'Un feu tricolore ne doit afficher qu\'une seule couleur à la fois.');
      if ((o.V1 || o.O1) && (o.V2 || o.O2)) fault(st, 'Accident ! Les deux voies peuvent passer', 'Les deux feux sont au vert (ou à l\'orange) en même temps : les voitures se croisent. Quand une voie est au vert ou à l\'orange, l\'autre doit être au ROUGE.');
      const ph = o.V1 ? 'V' : o.O1 ? 'O' : o.R1 ? 'R' : '';
      if (ph !== st.phase1) { st.seq.push(ph); if (st.seq.length > 6) st.seq.shift(); st.phase1 = ph; if (st.seq.slice(-3).join('') === 'VOR') { st.cycles++; note(st, `Cycle voie 1 complet (${st.cycles})`); } }
      if (o.O1) st.o1 += dt; else { if (st.o1 >= 1900) st.stats.orange = true; st.o1 = 0; }
      if (o.R1 && o.R2) st.allRed += dt; else { if (st.allRed >= 900) st.stats.allred = true; st.allRed = 0; }
      const mv = (cars, go) => cars.map((c) => {
        const stopLine = 0.38;
        const nc = c + dt * 0.00012;
        if (!go && c < stopLine && nc >= stopLine) return c;
        return nc > 1 ? nc - 1 : nc;
      });
      st.cars1 = mv(st.cars1, o.V1 || o.O1);
      st.cars2 = mv(st.cars2, o.V2 || o.O2);
    },
    view() {
      const svg = frame();
      svg.appendChild(S('rect', { x: 0, y: 105, width: 400, height: 50, fill: '#444' }));
      svg.appendChild(S('rect', { x: 175, y: 0, width: 50, height: 260, fill: '#444' }));
      svg.appendChild(S('line', { x1: 0, y1: 130, x2: 400, y2: 130, stroke: '#ddd', 'stroke-dasharray': '10 10' }));
      svg.appendChild(S('line', { x1: 200, y1: 0, x2: 200, y2: 260, stroke: '#ddd', 'stroke-dasharray': '10 10' }));
      const mkFeu = (x, y, n) => {
        svg.appendChild(S('rect', { x: x - 13, y, width: 26, height: 72, rx: 5, fill: '#111' }));
        const r = lamp(x, y + 13, '#f33'), o = lamp(x, y + 36, '#fa0'), v = lamp(x, y + 59, '#3f3');
        [r, o, v].forEach((l) => svg.appendChild(l.g));
        svg.appendChild(S('text', { x, y: y + 86, 'text-anchor': 'middle', class: 'm-label' }, `Feu ${n}`));
        return { r, o, v };
      };
      const f1 = mkFeu(140, 20, 1), f2 = mkFeu(260, 160, 2);
      const carsG = S('g', {}); svg.appendChild(carsG);
      const cnt = S('text', { x: 390, y: 30, 'text-anchor': 'end', class: 'm-big' }, '0');
      svg.appendChild(cnt);
      svg.appendChild(S('text', { x: 390, y: 45, 'text-anchor': 'end', class: 'm-label' }, 'cycles'));
      return {
        node: svg,
        update(st, inp, out) {
          f1.r.set(out.R1); f1.o.set(out.O1); f1.v.set(out.V1);
          f2.r.set(out.R2); f2.o.set(out.O2); f2.v.set(out.V2);
          U.clear(carsG);
          for (const c of st.cars1) carsG.appendChild(S('rect', { x: c * 400 - 15, y: 135, width: 30, height: 14, rx: 4, fill: '#4af' }));
          for (const c of st.cars2) carsG.appendChild(S('rect', { x: 205, y: c * 260 - 15, width: 14, height: 30, rx: 4, fill: '#f6a' }));
          cnt.textContent = st.cycles;
        },
      };
    },
    goals: [
      { text: 'Faire un cycle vert → orange → rouge sur la voie 1', done: (st) => st.cycles >= 1 },
      { text: 'Orange allumé au moins 2 s', done: (st) => st.stats.orange },
      { text: 'Rouge partout au moins 1 s (sécurité)', done: (st) => st.stats.allred },
      { text: 'Enchaîner 3 cycles', done: (st) => st.cycles >= 3 },
    ],
  };

  const list = [convoyeur, perceuse, cuve, tri, feux];
  const byId = Object.fromEntries(list.map((m) => [m.id, m]));
  return { list, byId, pressed };
})();
