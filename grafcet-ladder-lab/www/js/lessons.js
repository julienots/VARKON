// Contenu pédagogique : cours, tutoriels guidés, quiz et glossaire.
const Content = (() => {
  // Petit langage pour écrire des lignes Ladder dans les tutoriels :
  // 'NO:MA NC:AT - - - - - C:KM1'  ('-' = fil, '.' = vide, TON:T0:5000)
  function rung(comment, rows, vlinks = []) {
    const r = { comment, rows: rows.length, cells: {}, v: vlinks.slice() };
    rows.forEach((line, ri) => {
      line.trim().split(/\s+/).forEach((tok, c) => {
        if (tok === '.' || !tok) return;
        if (tok === '-') { r.cells[`${ri},${c}`] = { t: 'H' }; return; }
        const [t, v, p] = tok.split(':');
        r.cells[`${ri},${c}`] = { t, v, p: p ? +p : undefined };
      });
      // la bobine est toujours en colonne 7
      const toks = line.trim().split(/\s+/);
      const last = toks[toks.length - 1];
      if (toks.length < 8 && last && /^(C|CN|S|R|TON|TOF|CTU):/.test(last)) {
        delete r.cells[`${ri},${toks.length - 1}`];
        for (let c = toks.length - 1; c < 7; c++) r.cells[`${ri},${c}`] = { t: 'H' };
        const [t, v, p] = last.split(':');
        r.cells[`${ri},7`] = { t, v, p: p ? +p : undefined };
      }
    });
    return r;
  }
  const step = (id, actions = [], initial = false, comment = '') => ({ id, initial, comment, actions: actions.map((a) => (typeof a === 'string' ? { type: 'N', v: a, cond: '' } : a)) });
  const tr = (id, from, to, cond) => ({ id, from: [].concat(from), to: [].concat(to), cond });

  // ================================================================ COURS
  const courses = [
    { id: 'demarrer', title: 'Bien démarrer avec l\'application', icon: '🚀', html: `
<p>Cette application est un <b>atelier d'automatisme virtuel</b>. Tout y est simulé : l'automate (le <b>VARKON VK-200</b>, un modèle inventé pour l'entraînement), le câblage et les machines. Tu peux donc tout essayer, tout casser et recommencer sans risque.</p>
<h4>La démarche, comme en vrai</h4>
<ol>
<li><b>Lire le cahier des charges</b> de la machine (onglet <i>Machine</i>).</li>
<li><b>Configurer l'automate</b> : alimentation, CPU, cartes d'entrées/sorties, adresse IP (onglet <i>Automate</i>).</li>
<li><b>Câbler</b> : relier chaque capteur et chaque actionneur à une voie de carte (onglet <i>Câblage</i>). C'est le <i>tableau d'affectation des entrées/sorties</i>.</li>
<li><b>Programmer</b> en GRAFCET et/ou en Ladder.</li>
<li><b>Vérifier</b> (onglet <i>Diagnostic</i>) : chaque erreur est expliquée simplement avec la solution.</li>
<li><b>Transférer</b> le programme dans l'automate, passer en <b>RUN</b> et <b>tester</b> sur la machine.</li>
</ol>
<div class="tip">💡 Commence par les <b>tutoriels guidés</b> dans l'ordre : ils te prennent par la main étape par étape.</div>` },

    { id: 'api', title: 'L\'automate programmable (API)', icon: '🧠', html: `
<p>Un <b>automate programmable industriel</b> (API, ou PLC en anglais) est un ordinateur robuste qui commande une machine. Il <b>lit</b> des capteurs, <b>réfléchit</b> grâce à ton programme, et <b>commande</b> des actionneurs.</p>
<h4>Les parties d'un automate modulaire</h4>
<table><tr><th>Élément</th><th>Rôle</th></tr>
<tr><td>Alimentation</td><td>Transforme le 230 V AC en 24 V DC pour les cartes.</td></tr>
<tr><td>CPU (processeur)</td><td>Exécute le programme, contient la mémoire, le port réseau.</td></tr>
<tr><td>Cartes d'entrées (DI)</td><td>Reçoivent les signaux des capteurs et boutons.</td></tr>
<tr><td>Cartes de sorties (DO)</td><td>Envoient les ordres aux actionneurs (contacteurs, électrovannes, voyants).</td></tr>
<tr><td>Rack</td><td>Le support (fond de panier) qui relie toutes les cartes.</td></tr></table>
<h4>Le cycle automate (à connaître par cœur !)</h4>
<pre>  ┌────────────────────────────────┐
  │ 1. LECTURE des entrées (%I)    │  photo de tous les capteurs
  │ 2. TRAITEMENT du programme     │  ligne par ligne, de haut en bas
  │ 3. ÉCRITURE des sorties (%Q)   │  envoi de tous les ordres
  └──────────────┬─────────────────┘
                 └─── et on recommence (quelques ms)</pre>
<p>Conséquence importante : pendant le traitement, l'automate travaille sur la <b>photo</b> des entrées prise au début du cycle. Et les sorties ne changent réellement qu'à la fin du cycle.</p>
<h4>Les modes</h4>
<ul><li><b>STOP</b> : le programme ne tourne pas, toutes les sorties sont à 0.</li>
<li><b>RUN</b> : le cycle tourne en permanence.</li></ul>
<h4>Le chien de garde (watchdog)</h4>
<p>C'est un minuteur de sécurité : si un cycle dure plus longtemps que prévu (programme bloqué), le CPU passe en défaut et coupe les sorties.</p>` },

    { id: 'adressage', title: 'Adressage et mnémoniques', icon: '🏷️', html: `
<p>Chaque information de l'automate a une <b>adresse</b>. Sur le VK-200 (comme sur beaucoup d'automates réels) :</p>
<table><tr><th>Adresse</th><th>Signification</th><th>Exemple</th></tr>
<tr><td>%I<i>e</i>.<i>v</i></td><td>Entrée de l'emplacement <i>e</i>, voie <i>v</i></td><td>%I2.0 = 1<sup>re</sup> entrée de la carte en emplacement 2</td></tr>
<tr><td>%Q<i>e</i>.<i>v</i></td><td>Sortie de l'emplacement <i>e</i>, voie <i>v</i></td><td>%Q3.1 = 2<sup>e</sup> sortie de la carte en emplacement 3</td></tr>
<tr><td>%M<i>n</i></td><td>Bit interne (mémoire), ne sort pas de l'automate</td><td>%M10</td></tr>
<tr><td>%T<i>n</i></td><td>Temporisation</td><td>%T0</td></tr>
<tr><td>%C<i>n</i></td><td>Compteur</td><td>%C0</td></tr>
<tr><td>%S<i>n</i></td><td>Bit système</td><td>%S1 = premier cycle (INIT), %S6 = clignotant 1 Hz (CLIGNO)</td></tr></table>
<p>Les voies commencent à <b>0</b> : une carte 8 voies va de .0 à .7.</p>
<h4>Les mnémoniques</h4>
<p>Écrire %I2.3 partout est illisible. On donne donc un <b>nom</b> (mnémonique) à chaque adresse : <code>dcy</code>, <code>S1</code>, <code>KM1</code>… L'onglet <i>Câblage</i> crée automatiquement les mnémoniques de la machine. Tu peux aussi déclarer tes propres noms pour les %M.</p>
<div class="tip">💡 Dans l'appli, tu peux écrire indifféremment le nom (<code>KM1</code>) ou l'adresse (<code>%Q3.0</code>).</div>` },

    { id: 'cablage', title: 'Câblage : capteurs, boutons, sorties', icon: '🔌', html: `
<h4>Contact NO et contact NC</h4>
<ul><li><b>NO</b> (normalement ouvert, « à fermeture ») : le courant passe quand on appuie. Ex : bouton Marche.</li>
<li><b>NC</b> (normalement fermé, « à ouverture ») : le courant passe quand on N'appuie PAS. Ex : bouton Arrêt, arrêt d'urgence.</li></ul>
<h4>Pourquoi l'arrêt est câblé en NC ? (sécurité positive)</h4>
<p>Si un fil est coupé ou débranché, une entrée câblée en NC passe à 0 <b>comme si on avait appuyé sur Arrêt</b> : la machine s'arrête. Avec un contact NO, un fil coupé empêcherait d'arrêter la machine. C'est le principe de <b>sécurité positive</b>.</p>
<div class="warn">⚠ Conséquence dans le programme : l'entrée AT vaut <b>1 au repos</b> et <b>0 quand on appuie</b>. Dans le Ladder, on utilise donc un contact <b>NO</b> sur AT pour « laisser passer tant qu'on n'appuie pas ». C'est l'erreur n°1 des débutants !</div>
<h4>Capteurs PNP et NPN</h4>
<ul><li><b>PNP</b> (logique positive) : le capteur envoie du +24 V quand il détecte. La carte d'entrée doit être en logique PNP (« sink »).</li>
<li><b>NPN</b> (logique négative) : le capteur relie l'entrée au 0 V quand il détecte. La carte doit être en logique NPN (« source »).</li></ul>
<p>Si les deux ne sont pas réglés pareil, l'entrée ne bouge jamais. Dans l'appli, la logique se règle sur chaque carte DI.</p>
<h4>Sorties relais ou transistor ?</h4>
<table><tr><th></th><th>Relais (DO8-REL)</th><th>Transistor (DO8-TRA)</th></tr>
<tr><td>Tension</td><td>24 V DC <b>ou 230 V AC</b></td><td>24 V DC seulement</td></tr>
<tr><td>Vitesse</td><td>Lente (usure mécanique)</td><td>Rapide, sans usure</td></tr>
<tr><td>Usage</td><td>Contacteurs 230 V, moteurs…</td><td>Électrovannes 24 V, voyants…</td></tr></table>
<h4>Bilan de consommation</h4>
<p>Additionne la consommation de chaque carte : le total doit rester inférieur à ce que l'alimentation peut fournir. L'appli fait le calcul sous le rack.</p>` },

    { id: 'config', title: 'Configurer l\'automate VK-200', icon: '⚙️', html: `
<h4>1. Le rack</h4>
<ul><li>Emplacement <b>0</b> : alimentation (ALIM-24/3A ou /5A).</li>
<li>Emplacement <b>1</b> : CPU (VK-210 : 4 cartes max, VK-220 : 8 cartes max).</li>
<li>Emplacements <b>2 à 9</b> : cartes d'E/S. L'adresse dépend de l'emplacement : une carte de sorties en 3 donne %Q3.0 à %Q3.7.</li></ul>
<h4>2. Les paramètres des cartes</h4>
<p>Cartes d'entrées : logique PNP ou NPN (selon les capteurs).</p>
<h4>3. Le réseau</h4>
<p>Pour transférer le programme, le PC et l'automate doivent être sur le <b>même sous-réseau</b>. Le PC de l'atelier virtuel est en <code>192.168.1.10</code> masque <code>255.255.255.0</code>.</p>
<p>Avec le masque 255.255.255.0, les <b>3 premiers nombres</b> doivent être identiques et le dernier différent (entre 1 et 254). Exemple valable pour l'automate : <code>192.168.1.20</code>.</p>
<h4>4. La tâche et le chien de garde</h4>
<ul><li><b>Cyclique</b> : un cycle recommence dès que le précédent est fini.</li>
<li><b>Périodique</b> : un cycle démarre toutes les X ms (il faut que X soit plus grand que la durée d'un cycle).</li>
<li><b>Chien de garde</b> : durée max d'un cycle avant défaut (150 ms par défaut).</li></ul>
<h4>5. Transférer et passer en RUN</h4>
<p>Le bouton <b>Transférer</b> vérifie tout, puis envoie configuration + programme. Ensuite <b>RUN</b>. Si tu modifies quelque chose, il faut transférer à nouveau : l'automate garde l'ancienne version tant que tu ne l'as pas fait.</p>` },

    { id: 'ladder', title: 'Le langage Ladder (à contacts)', icon: '🪜', html: `
<p>Le Ladder ressemble à un schéma électrique : le courant part du <b>rail de gauche</b>, traverse des <b>contacts</b> (conditions) et arrive à une <b>bobine</b> (action) sur la droite.</p>
<h4>Les éléments de base</h4>
<table><tr><th>Symbole</th><th>Nom</th><th>Laisse passer si…</th></tr>
<tr><td><code>┤ ├</code></td><td>Contact NO</td><td>la variable vaut 1</td></tr>
<tr><td><code>┤/├</code></td><td>Contact NC</td><td>la variable vaut 0</td></tr>
<tr><td><code>┤P├</code></td><td>Front montant</td><td>la variable vient de passer de 0 à 1 (1 seul cycle)</td></tr>
<tr><td><code>( )</code></td><td>Bobine</td><td>variable = 1 tant que la ligne est alimentée</td></tr>
<tr><td><code>(S)</code> / <code>(R)</code></td><td>Set / Reset</td><td>met à 1 / à 0 et <b>mémorise</b></td></tr></table>
<h4>ET et OU</h4>
<pre>Série = ET :      ──┤ a ├──┤ b ├──( Y )     Y = a . b

Parallèle = OU :  ──┬─┤ a ├─┬──( Y )        Y = a + b
                    └─┤ b ├─┘</pre>
<p>Dans l'éditeur, une branche parallèle se fait avec une 2<sup>e</sup> rangée et des <b>liaisons verticales │</b>.</p>
<h4>L'auto-maintien (montage incontournable)</h4>
<pre>──┬─┤ MA ├──┬──┤ AT ├──┤ AU ├──( KM1 )
  └─┤ KM1├──┘</pre>
<p>On appuie sur MA : KM1 passe à 1. Le contact KM1 en parallèle « maintient » la bobine quand on relâche MA. Un appui sur AT (câblé NC, donc AT passe à 0) coupe la ligne. Ici l'arrêt est <b>prioritaire</b> (il est en série après le OU).</p>
<h4>Temporisations</h4>
<ul><li><b>TON</b> (retard à l'enclenchement) : la sortie %T passe à 1 quand l'entrée est restée à 1 pendant la durée PT.</li>
<li><b>TOF</b> (retard au déclenchement) : la sortie reste à 1 pendant PT après que l'entrée retombe à 0.</li></ul>
<p>On utilise ensuite un contact <code>┤ %T0 ├</code> dans une autre ligne.</p>
<h4>Compteurs</h4>
<p><b>CTU</b> : +1 à chaque front montant de son entrée. La sortie %C passe à 1 quand la valeur atteint la présélection PV. Une bobine <code>(R)</code> sur %C0 remet le compteur à zéro.</p>
<div class="warn">⚠ Le piège de la <b>double bobine</b> : si la même sortie est écrite par deux bobines dans deux lignes, seule la DERNIÈRE compte (les lignes s'exécutent de haut en bas). Regroupe les conditions avec un OU dans une seule ligne.</div>` },

    { id: 'grafcet', title: 'Le GRAFCET', icon: '🔀', html: `
<p>Le <b>GRAFCET</b> (norme NF EN 60848) décrit le fonctionnement d'un système <b>séquentiel</b> : une succession d'étapes séparées par des transitions.</p>
<h4>Les éléments</h4>
<table><tr><th>Élément</th><th>Dessin</th><th>Rôle</th></tr>
<tr><td>Étape</td><td>carré numéroté</td><td>Une situation stable du système. Active ou inactive. Variable Xn.</td></tr>
<tr><td>Étape initiale</td><td>double carré</td><td>Active au démarrage.</td></tr>
<tr><td>Action</td><td>rectangle à droite de l'étape</td><td>Ce qu'on fait quand l'étape est active.</td></tr>
<tr><td>Transition</td><td>petit trait horizontal</td><td>Le passage d'une étape à la suivante.</td></tr>
<tr><td>Réceptivité</td><td>texte à droite de la transition</td><td>La condition pour franchir la transition.</td></tr></table>
<h4>Les 5 règles d'évolution</h4>
<ol><li><b>Situation initiale</b> : au départ, seules les étapes initiales sont actives.</li>
<li><b>Franchissement</b> : une transition est franchie si elle est <i>validée</i> (toutes les étapes d'avant sont actives) ET que sa réceptivité est vraie.</li>
<li><b>Évolution</b> : franchir une transition active les étapes d'après et désactive les étapes d'avant.</li>
<li><b>Simultanéité</b> : plusieurs transitions franchissables en même temps sont franchies en même temps.</li>
<li><b>Priorité à l'activation</b> : si une étape doit être activée et désactivée en même temps, elle reste active.</li></ol>
<h4>Écrire une réceptivité</h4>
<table><tr><th>Écriture</th><th>Sens</th></tr>
<tr><td><code>a . b</code></td><td>a ET b</td></tr><tr><td><code>a + b</code></td><td>a OU b</td></tr>
<tr><td><code>/a</code></td><td>NON a (a barre)</td></tr><tr><td><code>↑a</code></td><td>front montant de a</td></tr>
<tr><td><code>t/X2/5s</code></td><td>5 s après l'activation de l'étape 2</td></tr>
<tr><td><code>X3</code></td><td>l'étape 3 est active</td></tr><tr><td><code>1</code></td><td>toujours vrai</td></tr></table>
<h4>Les types d'actions</h4>
<ul><li><b>Continue</b> : la sortie est à 1 tant que l'étape est active (le plus courant).</li>
<li><b>Conditionnelle</b> : continue, mais seulement si une condition est vraie.</li>
<li><b>Mémorisée</b> : <code>Y := 1</code> à l'activation, et elle reste à 1 jusqu'à un <code>Y := 0</code> dans une autre étape.</li></ul>
<h4>Divergences et convergences</h4>
<pre>  OU (aiguillage) :            ET (parallélisme) :
       [1]                          [1]
     ──┴──┬──                        ┼ a
   a ┼    ┼ b                   ═════╪═════
    [2]  [3]                    [2]       [3]
  une seule branche          les deux branches en même temps</pre>
<p>Pour un OU, les réceptivités doivent être <b>exclusives</b> (jamais vraies en même temps), sinon les deux branches s'activent.</p>
<h4>Points de vue</h4>
<p><b>Système</b> (on décrit ce que fait le produit), <b>partie opérative</b> (on nomme les actionneurs : « descendre ») et <b>partie commande</b> (on utilise les variables de l'automate : Y1, S2…). Dans l'appli, on écrit le GRAFCET du point de vue <b>partie commande</b>.</p>` },

    { id: 'conversion', title: 'Du GRAFCET au Ladder', icon: '🔁', html: `
<p>Beaucoup d'automates ne lisent pas le GRAFCET directement : il faut le <b>traduire en Ladder</b>. La méthode la plus utilisée en BTS est la méthode <b>SET / RESET</b>.</p>
<h4>1. Une variable par étape</h4>
<p>Chaque étape n devient un bit interne : X0 → %M0, X1 → %M1…</p>
<h4>2. L'initialisation</h4>
<pre>──┤ INIT ├────────────┬──(S X0)    INIT = %S1, vrai au 1er cycle
                      ├──(R X1)
                      └──(R X2)</pre>
<h4>3. Les transitions</h4>
<p>Une transition est franchissable si : étape(s) d'avant active(s) <b>ET</b> réceptivité vraie. Pour chaque transition :</p>
<pre>──┤ X0 ├──┤ dcy ├──┤ S1 ├───( FT0 )</pre>
<h4>4. L'évolution</h4>
<pre>──┤ FT0 ├───(R X0)        désactiver l'étape d'avant
──┤ FT0 ├───(S X1)        activer l'étape d'après</pre>
<p>On fait toutes les désactivations puis toutes les activations : la règle 5 (priorité à l'activation) est ainsi respectée.</p>
<h4>5. Les actions</h4>
<p>Pour une action continue, on fait le <b>OU</b> de toutes les étapes où elle apparaît, dans <b>une seule</b> ligne (pas de double bobine !) :</p>
<pre>──┬─┤ X1 ├─┬───( KM1 )
  └─┤ X2 ├─┘</pre>
<h4>6. Les temporisations</h4>
<pre>──┤ X2 ├───[TON %T0 5s]       puis t/X2/5s devient ┤ %T0 ├</pre>
<div class="tip">💡 Dans l'onglet GRAFCET, le bouton « Générer le Ladder équivalent » applique exactement cette méthode. Utilise-le pour vérifier ta traduction faite à la main.</div>` },

    { id: 'methodo', title: 'Méthodologie BTS : de l\'étude au dépannage', icon: '📋', html: `
<h4>Analyser</h4>
<ul><li>Lis le cahier des charges et repère : les <b>entrées</b> (capteurs, boutons) et les <b>sorties</b> (actionneurs, voyants).</li>
<li>Dresse le <b>tableau d'affectation des E/S</b> : mnémonique, adresse, description, type (NO/NC, PNP/NPN, 24 V/230 V).</li></ul>
<h4>Concevoir</h4>
<ul><li>Écris le GRAFCET point de vue système, puis partie commande.</li>
<li>Vérifie l'alternance étape / transition / étape, les reprises de séquence et l'exclusivité des aiguillages.</li></ul>
<h4>Réaliser</h4>
<ul><li>Choisis et configure le matériel (alimentation, CPU, cartes, bilan de consommation, réseau).</li>
<li>Programme, compile, corrige les erreurs.</li></ul>
<h4>Mettre en service</h4>
<ol><li>Vérifier le câblage <b>hors tension</b>, puis en STOP : chaque capteur fait-il bien bouger son entrée ? (onglet Machine : la liste des E/S montre l'état en direct)</li>
<li>Tester chaque sortie.</li>
<li>Passer en RUN et tester le cycle normal, puis les cas anormaux (arrêt, AU, capteur absent…).</li></ol>
<h4>Dépanner : les bons réflexes</h4>
<ul><li>Regarder l'état des entrées : le capteur est-il vu par l'automate ?</li>
<li>Regarder l'état des étapes (GRAFCET) : où le cycle est-il bloqué ? Quelle réceptivité n'est pas vraie ?</li>
<li>Regarder la ligne de Ladder en direct : quel contact ne laisse pas passer ?</li>
<li>Penser aux pièges : contact NC/NO inversé, double bobine, programme pas transféré, mauvaise logique PNP/NPN.</li></ul>` },
  ];

  // ================================================================ TUTORIELS
  const sol = {
    autoMaintien: () => ({ rungs: [
      rung('Auto-maintien : MA démarre, KM1 se maintient. AT et AU (câblés NC) coupent.', ['NO:MA NO:AT NO:AU - - - - C:KM1', 'NO:KM1'], ['0,0']),
      rung('Voyant de marche', ['NO:KM1 - - - - - - C:H1']),
    ] }),
    perceuse: () => ({ steps: [step(0, [], true, 'attente'), step(1, ['KM1', 'Y1'], false, 'descente'), step(2, ['KM1', 'Y2'], false, 'remontée')],
      transitions: [tr(0, 0, 1, 'DCY . S0 . S1 . AU'), tr(1, 1, 2, 'S2'), tr(2, 2, 0, 'S1')] }),
    cuve: () => ({ steps: [step(0, [], true, 'attente'), step(1, ['V1'], false, 'remplissage'), step(2, ['MEL'], false, 'mélange'), step(3, ['P1'], false, 'vidange')],
      transitions: [tr(0, 0, 1, 'DCY . /NB . AU'), tr(1, 1, 2, 'NH'), tr(2, 2, 3, 't/X2/5s'), tr(3, 3, 0, '/NB')] }),
    feux: () => ({ steps: [step(0, [], true, 'éteint'), step(1, ['V1', 'R2'], false, 'voie 1 passe'), step(2, ['O1', 'R2']), step(3, ['R1', 'R2'], false, 'sécurité'),
      step(4, ['R1', 'V2'], false, 'voie 2 passe'), step(5, ['R1', 'O2']), step(6, ['R1', 'R2'], false, 'sécurité')],
      transitions: [tr(0, 0, 1, 'MA'), tr(1, 1, 2, 't/X1/6s'), tr(2, 2, 3, 't/X2/2s'), tr(3, 3, 4, 't/X3/1s'), tr(4, 4, 5, 't/X4/6s'), tr(5, 5, 6, 't/X5/2s'),
        tr(6, 6, 1, 't/X6/1s . AT'), tr(7, 6, 0, 't/X6/1s . /AT')] }),
    tri: () => ({ steps: [step(0, [], true, 'arrêt'), step(1, ['KM1', 'H1'], false, 'tapis'), step(2, ['Y1', 'H1'], false, 'pousser'), step(3, ['H1'], false, 'retour')],
      transitions: [tr(0, 0, 1, 'MA . AU'), tr(1, 1, 2, 'SP . SG'), tr(2, 2, 3, 'SS'), tr(3, 3, 1, 'SR'), tr(4, 1, 0, '(/AT + /AU) . /SP')] }),
  };

  const findCell = (p, t, v) => p.ladder.rungs.some((r) => Object.values(r.cells).some((c) => c.t === t && c.v && c.v.toUpperCase() === v));
  const noErr = (diags, prefix) => !diags.some((d) => d.level === 'error' && (!prefix || d.code.startsWith(prefix)));

  const tutorials = [
    { id: 't1', title: 'Ton premier programme Ladder', machine: 'convoyeur', mode: 'ladder', level: 1,
      intro: 'On va faire tourner le tapis roulant quand on appuie sur le bouton Marche.',
      setup: (p) => { p.ladder = { rungs: [] }; },
      steps: [
        { title: 'Découvre la machine', text: 'Ouvre l\'onglet <b>Machine</b>. Lis le cahier des charges. Repère le bouton Marche (MA) et le moteur du tapis (KM1). Clique « Étape suivante » quand c\'est fait.' },
        { title: 'Regarde le câblage', text: 'Onglet <b>Câblage</b> : MA est relié à l\'entrée <code>%I2.0</code> et KM1 à la sortie <code>%Q3.0</code>. Ces noms (MA, KM1) sont des <b>mnémoniques</b> : tu peux les utiliser dans ton programme.' },
        { title: 'Ajoute une ligne', text: 'Onglet <b>Ladder</b> : touche <b>+ Ligne</b>. Choisis l\'outil <b>Contact NO</b> puis touche la 1<sup>re</sup> case et choisis <code>MA</code>.',
          check: (c) => findCell(c.project, 'NO', 'MA') },
        { title: 'Ajoute la bobine', text: 'Choisis l\'outil <b>Bobine</b> et touche la DERNIÈRE case de la ligne (à droite). Choisis <code>KM1</code>. Puis remplis les cases vides entre les deux avec l\'outil <b>Fil</b> ───.',
          check: (c) => findCell(c.project, 'C', 'KM1') && noErr(c.diags, 'LAD') },
        { title: 'Transfère et lance', text: 'Clique sur <b>Transférer</b> (barre du haut), puis sur <b>RUN</b>. Si une erreur s\'affiche, lis l\'explication dans l\'onglet <b>Diagnostic</b>.', check: (c) => c.running },
        { title: 'Teste !', text: 'Onglet <b>Machine</b> : maintiens le bouton <b>Marche</b> appuyé. Le tapis tourne… mais s\'arrête dès que tu lâches ! Normal : KM1 = MA. Pour garder le moteur en marche, il faut un <b>auto-maintien</b> : c\'est le tutoriel suivant.', check: (c) => c.mstate && c.mstate.stats.ran },
      ] },
    { id: 't2', title: 'Auto-maintien et arrêt d\'urgence', machine: 'convoyeur', mode: 'ladder', level: 1,
      intro: 'Le tapis doit rester en marche après un appui sur Marche, et s\'arrêter avec Arrêt ou l\'arrêt d\'urgence.',
      setup: (p) => { p.ladder = { rungs: [rung('', ['NO:MA - - - - - - C:KM1'])] }; },
      solution: (p) => { p.ladder = sol.autoMaintien(); },
      steps: [
        { title: 'Le principe', text: 'On part du programme du tutoriel 1. Pour que KM1 reste à 1 quand on relâche MA, on met un contact <b>KM1</b> en <b>parallèle</b> de MA (= OU). Lis le cours « Le langage Ladder » si besoin.' },
        { title: 'Crée la branche parallèle', text: 'Sur la ligne L1, touche <b>+⎸</b> pour ajouter une rangée. Place un <b>Contact NO KM1</b> sous MA (rangée 2, colonne 1). Puis outil <b>Liaison ↓</b> et touche la case MA : cela relie la sortie de MA et celle de KM1.',
          check: (c) => c.project.ladder.rungs.some((r) => r.rows > 1 && r.v.length && Object.values(r.cells).some((x) => x.t === 'NO' && x.v === 'KM1')) },
        { title: 'Ajoute Arrêt et AU', text: 'Remplace deux fils de la rangée 1 (après MA) par des <b>Contacts NO</b> sur <code>AT</code> puis <code>AU</code>.<br><br>⚠ Pourquoi NO et pas NC ? Les boutons Arrêt et AU sont câblés en <b>NC</b> : au repos, l\'entrée vaut 1. Un contact NO laisse donc passer tant qu\'on n\'appuie pas, et coupe quand on appuie. C\'est la <b>sécurité positive</b> (voir le cours Câblage).',
          check: (c) => findCell(c.project, 'NO', 'AT') && findCell(c.project, 'NO', 'AU') },
        { title: 'Ajoute le voyant', text: 'Nouvelle ligne : contact NO <code>KM1</code> → bobine <code>H1</code>. ⚠ Ne remets pas une 2<sup>e</sup> bobine KM1 dans une autre ligne : c\'est le piège de la double bobine.',
          check: (c) => findCell(c.project, 'C', 'H1') && noErr(c.diags) },
        { title: 'Teste tout', text: 'Transfère, RUN, puis dans l\'onglet Machine : Marche → le tapis tourne et H1 s\'allume. Arrêt → il s\'arrête. Relance et teste l\'AU (bouton rouge coup de poing). Réalise tous les objectifs de la machine.',
          check: (c) => c.mstate && c.mstate.stats.stopAT && c.mstate.stats.stopAU },
      ] },
    { id: 't3', title: 'Configurer l\'automate de A à Z', machine: 'convoyeur', mode: 'ladder', level: 2,
      intro: 'Le programme est prêt, mais l\'automate est vide ! Tu vas choisir le matériel, régler le réseau et câbler.',
      setup: (p) => { p.config = PLC.emptyConfig(); p.wiring = {}; p.ladder = sol.autoMaintien(); },
      steps: [
        { title: 'Alimentation et CPU', text: 'Onglet <b>Automate</b>. Touche l\'emplacement 0 et choisis une <b>alimentation ALIM-24/3A</b>. Touche l\'emplacement 1 et choisis le <b>CPU VK-210</b>.',
          check: (c) => !c.cfgDiags.some((d) => d.code === 'CFG-01' || d.code === 'CFG-02') },
        { title: 'Les cartes d\'E/S', text: 'La machine a 4 entrées (MA, AT, AU, FC) et 2 sorties (KM1, H1). Ajoute une carte <b>DI8-24DC</b> en emplacement 2 et une carte <b>DO8-REL</b> ou <b>DO8-TRA</b> en emplacement 3. Les capteurs sont PNP : laisse la carte DI en logique PNP.',
          check: (c) => !c.cfgDiags.some((d) => d.code === 'CFG-13' || d.code === 'CFG-05') },
        { title: 'Le réseau', text: 'Le PC de l\'atelier a l\'adresse <code>192.168.1.10</code>, masque <code>255.255.255.0</code>. Donne à l\'automate une adresse dans le même réseau, par exemple <code>192.168.1.20</code>. Que se passe-t-il si tu mets 192.168.2.20 ? Essaie et lis l\'explication !',
          check: (c) => noErr(c.cfgDiags, 'CFG') },
        { title: 'Le câblage', text: 'Onglet <b>Câblage</b> : pour chaque appareil choisis une voie. Les boutons et capteurs sur des <code>%I2.x</code>, les actionneurs sur des <code>%Q3.x</code>. Une voie ne peut recevoir qu\'un seul appareil.',
          check: (c) => noErr(c.wireDiags) && !c.wireDiags.some((d) => d.code === 'CAB-06') },
        { title: 'Transfère et teste', text: 'Transfère, passe en RUN et livre 3 cartons. Tu viens de faire une mise en service complète ! 🎉', check: (c) => c.mstate && c.mstate.delivered >= 3 },
      ] },
    { id: 't4', title: 'Premier GRAFCET : la perceuse', machine: 'perceuse', mode: 'grafcet', level: 2,
      intro: 'On décrit le cycle de perçage en GRAFCET : attente → descente → remontée.',
      setup: (p) => { p.grafcet = { steps: [step(0, [], true, 'attente')], transitions: [] }; },
      solution: (p) => { p.grafcet = sol.perceuse(); },
      steps: [
        { title: 'Lis le cahier des charges', text: 'Onglet <b>Machine</b>. Le cycle : DCY + pièce + vérin en haut → broche (KM1) + descente (Y1) → en bas (S2) → broche + montée (Y2) → en haut (S1) → fin.' },
        { title: 'Les étapes', text: 'Onglet <b>GRAFCET</b>. L\'étape 0 (initiale) existe déjà. Ajoute l\'étape <b>1</b> avec les actions <code>KM1</code> et <code>Y1</code>, puis l\'étape <b>2</b> avec <code>KM1</code> et <code>Y2</code>.',
          check: (c) => c.project.grafcet.steps.length >= 3 },
        { title: 'Les transitions', text: 'Ajoute 3 transitions :<br>• de 0 vers 1 : <code>DCY . S0 . S1 . AU</code><br>• de 1 vers 2 : <code>S2</code><br>• de 2 vers 0 : <code>S1</code><br>Le dessin se fait tout seul en haut. Remarque la flèche de retour vers l\'étape 0.',
          check: (c) => c.project.grafcet.transitions.length >= 3 && noErr(c.diags, 'GRA') },
        { title: 'Teste', text: 'Transfère, RUN. Dans l\'onglet Machine, appuie sur Départ cycle. Observe les étapes actives (en vert) dans l\'onglet GRAFCET. Pose et retire des pièces pour en percer 3.', check: (c) => c.mstate && c.mstate.drilled >= 1 },
        { title: 'Pour aller plus loin', text: 'Essaie de mettre <code>KM1</code> seulement dans l\'étape 2 : que se passe-t-il ? (lis bien le message de défaut). Et si tu mets <code>1</code> comme réceptivité de la transition 0 ?' },
      ] },
    { id: 't5', title: 'Temporisation : la cuve de mélange', machine: 'cuve', mode: 'grafcet', level: 2,
      intro: 'Remplir, mélanger 5 secondes, vider : on découvre la temporisation t/Xn/durée.',
      setup: (p) => { p.grafcet = { steps: [step(0, [], true, 'attente')], transitions: [] }; },
      solution: (p) => { p.grafcet = sol.cuve(); },
      steps: [
        { title: 'Structure', text: 'Crée les étapes 1 (action <code>V1</code>), 2 (action <code>MEL</code>) et 3 (action <code>P1</code>).', check: (c) => c.project.grafcet.steps.length >= 4 },
        { title: 'Transitions', text: '• 0 → 1 : <code>DCY . /NB . AU</code> (la cuve doit être vide)<br>• 1 → 2 : <code>NH</code><br>• 2 → 3 : <code>t/X2/5s</code> → vraie 5 s après l\'activation de l\'étape 2<br>• 3 → 0 : <code>/NB</code> (plus de liquide)',
          check: (c) => c.project.grafcet.transitions.some((t) => /t\s*\/\s*X\d+/i.test(t.cond)) && noErr(c.diags, 'GRA') },
        { title: 'Teste', text: 'Transfère et lance. Réalise 2 lots. Essaie aussi de retirer la transition NH : la cuve déborde et le défaut t\'explique pourquoi.', check: (c) => c.mstate && c.mstate.batches >= 1 },
        { title: 'Câblage piège', text: 'Va dans l\'onglet Automate et remplace la carte de sorties par une <b>DO8-TRA</b> (transistor). Regarde le Diagnostic : le mélangeur et la pompe sont en 230 V ! Remets ensuite une DO8-REL.' },
      ] },
    { id: 't6', title: 'Feux de carrefour (enchaîner les tempos)', machine: 'feux', mode: 'grafcet', level: 2,
      intro: 'Un cycle de 7 étapes avec temporisations et une divergence en OU pour l\'arrêt.',
      setup: (p) => { p.grafcet = { steps: [step(0, [], true, 'éteint')], transitions: [] }; },
      solution: (p) => { p.grafcet = sol.feux(); },
      steps: [
        { title: 'Le cycle', text: 'Étape 1 : <code>V1</code> + <code>R2</code> (6 s). Étape 2 : <code>O1</code> + <code>R2</code> (2 s). Étape 3 : <code>R1</code> + <code>R2</code> (1 s, sécurité). Puis la même chose pour la voie 2 dans les étapes 4, 5, 6.', check: (c) => c.project.grafcet.steps.length >= 7 },
        { title: 'Les transitions', text: '0 → 1 : <code>MA</code>. Puis chaque étape n part vers n+1 avec <code>t/Xn/durée</code>, par exemple <code>t/X1/6s</code>.' },
        { title: 'Boucler ou s\'arrêter : divergence en OU', text: 'Après l\'étape 6, deux transitions : vers 1 avec <code>t/X6/1s . AT</code> (on continue), et vers 0 avec <code>t/X6/1s . /AT</code> (Arrêt appuyé, câblé NC). Les deux réceptivités sont <b>exclusives</b> grâce à AT et /AT.',
          check: (c) => noErr(c.diags, 'GRA') && c.project.grafcet.transitions.length >= 8 },
        { title: 'Teste', text: 'Lance et observe les voitures. Valide tous les objectifs. Bonus : que se passe-t-il si tu oublies <code>R2</code> dans l\'étape 1 ?', check: (c) => c.mstate && c.mstate.cycles >= 2 },
      ] },
    { id: 't7', title: 'Aiguillage : le tri de colis', machine: 'tri', mode: 'grafcet', level: 3,
      intro: 'Une boucle de production avec un choix : pousser le colis s\'il est grand, sinon le laisser passer.',
      setup: (p) => { p.grafcet = { steps: [step(0, [], true, 'arrêt')], transitions: [] }; },
      solution: (p) => { p.grafcet = sol.tri(); },
      steps: [
        { title: 'Les étapes', text: 'Étape 1 : tapis (<code>KM1</code>, <code>H1</code>). Étape 2 : pousser (<code>Y1</code>, <code>H1</code>). Étape 3 : retour du poussoir (<code>H1</code>, Y1 = 0 donc le ressort le rentre).', check: (c) => c.project.grafcet.steps.length >= 4 },
        { title: 'La boucle', text: '0 → 1 : <code>MA . AU</code>. 1 → 2 : <code>SP . SG</code> (un grand colis est devant). 2 → 3 : <code>SS</code>. 3 → 1 : <code>SR</code>. Les petits colis passent car le tapis tourne à l\'étape 1.' },
        { title: 'L\'arrêt (divergence en OU)', text: 'Ajoute 1 → 0 : <code>(/AT + /AU) . /SP</code>. On s\'arrête si on appuie sur Arrêt ou sur l\'AU, mais pas pendant qu\'un colis est devant le poussoir : les deux sorties de l\'étape 1 sont exclusives.',
          check: (c) => noErr(c.diags, 'GRA') && c.project.grafcet.transitions.length >= 5 },
        { title: 'Teste', text: 'Trie 10 colis sans erreur ! Si un colis se coince, lis le défaut : il faut que le tapis soit arrêté avant de pousser.', check: (c) => c.mstate && c.mstate.big >= 3 },
      ] },
    { id: 't8', title: 'Traduire un GRAFCET en Ladder', machine: 'perceuse', mode: 'grafcet', level: 3,
      intro: 'On part du GRAFCET de la perceuse et on le traduit en Ladder avec la méthode Set/Reset.',
      setup: (p) => { p.grafcet = sol.perceuse(); p.ladder = { rungs: [] }; },
      steps: [
        { title: 'Relis le cours', text: 'Ouvre le cours <b>Du GRAFCET au Ladder</b>. Retiens : 1 bit par étape, initialisation avec INIT, une ligne par transition, puis R des étapes d\'avant et S des étapes d\'après, puis les actions.' },
        { title: 'Génère', text: 'Onglet GRAFCET, en bas : <b>Générer le Ladder équivalent</b>. Le programme passe en mode Ladder.', check: (c) => c.project.mode === 'ladder' && c.project.ladder.rungs.length > 5 },
        { title: 'Analyse', text: 'Onglet Ladder : lis les commentaires de chaque ligne. Repère la ligne de KM1 : c\'est un OU de X1 et X2, dans UNE seule bobine. Les bits X0, X1… sont des %M (voir Câblage > Mnémoniques).' },
        { title: 'Teste', text: 'Transfère et lance : le comportement est identique au GRAFCET. Regarde les lignes s\'allumer en vert en direct pendant le cycle.', check: (c) => c.running && c.mstate && c.mstate.drilled >= 1 },
      ] },
    { id: 't9', title: 'Chasse aux erreurs', machine: 'convoyeur', mode: 'ladder', level: 2,
      intro: 'Un collègue a laissé un projet plein d\'erreurs. Utilise le Diagnostic pour tout réparer.',
      setup: (p) => {
        p.config.ip = '192.168.0.20';
        p.config.rack[0] = null;
        p.wiring.H1 = '%I2.5';
        p.ladder = { rungs: [
          rung('Marche', ['NO:MA - - - - - - C:KM1']),
          rung('Maintien', ['NO:KM1 NC:AT - - - - - C:KM1']),
          rung('Voyant', ['NO:KM1 - . - - - - C:H1']),
          rung('Arrêt d\'urgence', ['NO:AU - - - - - - C:%I2.2']),
        ] };
      },
      solution: (p) => { p.config = PLC.defaultConfig(); p.wiring = Object.assign({}, Machines.byId.convoyeur.defaultWiring); p.ladder = sol.autoMaintien(); },
      steps: [
        { title: 'Ouvre le Diagnostic', text: 'Onglet <b>Diagnostic</b> : chaque erreur rouge bloque le transfert. Touche une erreur pour aller directement à l\'endroit concerné. Lis le « Pourquoi » et le « Comment corriger ».' },
        { title: 'Le matériel', text: 'Il manque quelque chose dans le rack, et l\'adresse IP n\'est pas dans le bon réseau.', check: (c) => noErr(c.cfgDiags) },
        { title: 'Le câblage', text: 'Un actionneur est câblé sur une entrée…', check: (c) => noErr(c.wireDiags) },
        { title: 'Le programme', text: 'Il y a une coupure dans une ligne, une écriture dans une entrée, une double bobine et un contact NC sur AT (qui est déjà câblé NC !). Corrige tout jusqu\'à ce que le diagnostic soit vert (les avertissements orange doivent aussi disparaître).',
          check: (c) => noErr(c.diags) && !c.diags.some((d) => d.code === 'LAD-08') },
        { title: 'Valide', text: 'Transfère et vérifie que Marche, Arrêt et AU fonctionnent.', check: (c) => c.mstate && c.mstate.stats.stopAT && c.mstate.stats.stopAU },
      ] },
  ];

  // ================================================================ QUIZ
  const quiz = [
    { q: 'Dans quel ordre se déroule un cycle automate ?', a: ['Lecture des entrées → traitement → écriture des sorties', 'Traitement → lecture → écriture', 'Écriture des sorties → lecture → traitement'], ok: 0, why: 'L\'automate prend une « photo » des entrées, exécute le programme puis met à jour toutes les sorties en même temps.' },
    { q: 'Que signifie l\'adresse %Q3.2 ?', a: ['Entrée n°2 de la carte 3', 'Sortie n°2 de la carte en emplacement 3', 'Bit interne n°32'], ok: 1, why: 'Q = sortie (output), 3 = emplacement, 2 = voie (la 3e, car on commence à 0).' },
    { q: 'Pourquoi câble-t-on le bouton d\'arrêt d\'urgence en NC ?', a: ['C\'est moins cher', 'Pour qu\'un fil coupé arrête la machine (sécurité positive)', 'Parce que l\'automate ne lit que les NC'], ok: 1, why: 'Avec un NC, une coupure de fil donne la même chose qu\'un appui : la machine s\'arrête. C\'est la sécurité positive.' },
    { q: 'Le bouton AT est câblé NC. Dans le Ladder, pour que la ligne soit coupée quand on appuie, on utilise…', a: ['un contact NO sur AT', 'un contact NC sur AT', 'une bobine AT'], ok: 0, why: 'Au repos l\'entrée AT vaut 1 : un contact NO laisse passer. Quand on appuie, AT = 0 : le contact NO coupe.' },
    { q: 'Deux contacts en série correspondent à…', a: ['un OU', 'un ET', 'un NON'], ok: 1, why: 'Le courant doit traverser les deux contacts : il faut a ET b.' },
    { q: 'Deux contacts en parallèle correspondent à…', a: ['un OU', 'un ET', 'un front montant'], ok: 0, why: 'Le courant peut passer par l\'un OU l\'autre chemin.' },
    { q: 'La même sortie est écrite par une bobine à la ligne 2 et à la ligne 5. Que se passe-t-il ?', a: ['La sortie est à 1 si l\'une des deux lignes est vraie', 'C\'est la ligne 5 (la dernière) qui impose la valeur', 'L\'automate se met en défaut'], ok: 1, why: 'Les lignes s\'exécutent dans l\'ordre et la dernière écriture gagne : c\'est le piège de la double bobine.' },
    { q: 'Une transition GRAFCET est franchie quand…', a: ['sa réceptivité est vraie', 'elle est validée (étapes d\'avant actives) ET sa réceptivité est vraie', 'l\'étape suivante est active'], ok: 1, why: 'Règle 2 : il faut les DEUX conditions.' },
    { q: 'Que signifie t/X4/3s ?', a: ['Une attente de 3 s dans l\'étape 4', 'Vrai 3 s après l\'activation de l\'étape 4', 'L\'étape 4 dure au maximum 3 s'], ok: 1, why: 'C\'est une variable qui devient vraie quand l\'étape 4 est active depuis 3 secondes.' },
    { q: 'Comment représente-t-on une étape initiale ?', a: ['Par un double carré', 'Par un cercle', 'Par un carré en pointillés'], ok: 0, why: 'L\'étape initiale (active au démarrage) a un double carré.' },
    { q: 'Dans une divergence en OU, les réceptivités doivent être…', a: ['identiques', 'exclusives', 'toujours vraies'], ok: 1, why: 'Sinon les deux branches peuvent s\'activer en même temps, ce qui n\'est pas voulu dans un aiguillage.' },
    { q: 'Une étape doit être activée et désactivée en même temps. Elle…', a: ['est désactivée', 'reste active', 'provoque une erreur'], ok: 1, why: 'Règle 5 : priorité à l\'activation.' },
    { q: 'Un moteur en 230 V AC doit être commandé par…', a: ['une sortie transistor', 'une sortie relais', 'une entrée'], ok: 1, why: 'Les sorties transistor ne commutent que du 24 V DC. Un relais (contact sec) peut commuter du 230 V AC.' },
    { q: 'Le PC est en 192.168.1.10/24. Quelle adresse peut prendre l\'automate ?', a: ['192.168.2.10', '192.168.1.10', '192.168.1.25'], ok: 2, why: 'Même réseau (192.168.1.x) et adresse différente de celle du PC.' },
    { q: 'Un capteur NPN branché sur une carte réglée en PNP…', a: ['fonctionne normalement', 'n\'est jamais vu par l\'automate', 'grille la carte'], ok: 1, why: 'Les logiques ne correspondent pas : l\'entrée ne voit pas le signal.' },
    { q: 'À quoi sert le chien de garde (watchdog) ?', a: ['À compter les pièces', 'À détecter un cycle trop long et mettre l\'automate en sécurité', 'À protéger contre les surtensions'], ok: 1, why: 'Si le cycle dépasse le temps du watchdog, le CPU passe en défaut et coupe les sorties.' },
    { q: 'Que fait une bobine (S) ?', a: ['Met la variable à 1 et la laisse à 1', 'Met la variable à 1 seulement pendant que la ligne est vraie', 'Met la variable à 0'], ok: 0, why: 'SET mémorise : la variable reste à 1 jusqu\'à un RESET.' },
    { q: 'Une temporisation TON de 5 s : sa sortie passe à 1…', a: ['tout de suite puis retombe après 5 s', 'quand son entrée est restée à 1 pendant 5 s', 'toutes les 5 s'], ok: 1, why: 'TON = retard à l\'enclenchement.' },
    { q: 'Dans la méthode Set/Reset, l\'action continue KM1 présente dans les étapes 1 et 2 s\'écrit…', a: ['Deux lignes : X1 → (KM1) et X2 → (KM1)', 'Une ligne : (X1 OU X2) → (KM1)', 'X1 → (S KM1)'], ok: 1, why: 'Une seule bobine par sortie, avec un OU des étapes.' },
    { q: 'Le bit INIT (%S1) est vrai…', a: ['tout le temps', 'pendant le premier cycle après le passage en RUN', 'quand on appuie sur AU'], ok: 1, why: 'Il sert à initialiser le programme (activer les étapes initiales).' },
  ];

  // ================================================================ GLOSSAIRE
  const glossary = [
    ['API', 'Automate Programmable Industriel. En anglais : PLC.'],
    ['AU', 'Arrêt d\'Urgence : bouton coup de poing rouge sur fond jaune, câblé NC, qui doit tout arrêter.'],
    ['Action', 'Ce qui est fait quand une étape GRAFCET est active.'],
    ['Actionneur', 'Organe qui agit sur la machine : moteur, vérin, résistance…'],
    ['Auto-maintien', 'Montage où une sortie se maintient elle-même grâce à son propre contact en parallèle du bouton Marche.'],
    ['Bistable', 'Distributeur qui garde sa position quand on coupe la commande. Il faut un ordre pour chaque sens.'],
    ['Bobine', 'En Ladder, élément de droite qui écrit une variable.'],
    ['Chien de garde', 'Watchdog : surveille la durée du cycle automate.'],
    ['Contact NO / NC', 'Normalement Ouvert / Normalement Fermé.'],
    ['Contacteur', 'Interrupteur commandé électriquement (KM) qui alimente un moteur.'],
    ['CPU', 'Processeur de l\'automate : exécute le programme.'],
    ['Cycle automate', 'Lecture des entrées, traitement, écriture des sorties, en boucle.'],
    ['DCY', 'Départ CYcle.'],
    ['Distributeur', 'Composant pneumatique qui oriente l\'air vers une chambre du vérin. Commandé par des électrovannes.'],
    ['Divergence', 'Point où un GRAFCET se sépare en plusieurs branches (OU = choix, ET = simultané).'],
    ['Étape', 'Situation stable d\'un GRAFCET. Variable Xn = 1 si active.'],
    ['Front montant', 'Passage d\'une variable de 0 à 1. Noté ↑a.'],
    ['GRAFCET', 'GRAphe Fonctionnel de Commande Étape-Transition (norme NF EN 60848).'],
    ['Ladder', 'Langage graphique à contacts, proche d\'un schéma électrique. Norme IEC 61131-3 (LD).'],
    ['Mnémonique', 'Nom lisible donné à une adresse (ex : KM1 = %Q3.0).'],
    ['Monostable', 'Distributeur qui revient en position de repos (ressort) quand on coupe la commande.'],
    ['Partie commande', 'L\'automate et son programme : le « cerveau ».'],
    ['Partie opérative', 'La machine : capteurs et actionneurs, les « muscles ».'],
    ['PNP / NPN', 'Type de sortie d\'un capteur : PNP envoie +24 V, NPN relie au 0 V.'],
    ['Préactionneur', 'Organe qui distribue l\'énergie à l\'actionneur : contacteur, distributeur.'],
    ['Rack', 'Fond de panier qui reçoit les cartes de l\'automate.'],
    ['Réceptivité', 'Condition associée à une transition GRAFCET.'],
    ['RUN / STOP', 'Modes de l\'automate : programme en marche ou à l\'arrêt.'],
    ['Sécurité positive', 'Principe : une panne (fil coupé, coupure de courant) doit mettre la machine en sécurité.'],
    ['Sous-réseau', 'Groupe d\'adresses IP qui communiquent directement, défini par le masque.'],
    ['TON / TOF', 'Temporisations à l\'enclenchement / au déclenchement.'],
    ['Transition', 'Barrière entre deux étapes, franchie quand elle est validée et que la réceptivité est vraie.'],
    ['TOR', 'Tout Ou Rien : signal qui ne vaut que 0 ou 1.'],
  ];

  return { courses, tutorials, quiz, glossary, rung, step, tr, sol };
})();
