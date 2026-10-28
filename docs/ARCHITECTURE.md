# Architecture technique — VARKON

## Choix techniques

- **Godot 4.4.1 / GDScript** : export Android natif (APK sans Gradle, AAB avec Gradle),
  3D complète, UI riche, licence MIT.
- **Renderer *Compatibility* (OpenGL ES 3.0)** : fonctionne sur la plus large gamme de téléphones
  Android (y compris sans Vulkan). Ombres, brouillard, glow et particules sont pilotés par les
  réglages de qualité.
- **Contenu 100 % procédural** : personnages, armes, armures, bâtiments, icônes de ressources,
  coffres, sons et musiques sont générés par le code (aucun asset commercial). Les seuls fichiers
  externes sont les logos fournis par le studio et trois polices sous licence libre.
- **Paysage** (`sensor_landscape`) pour tout le jeu ; résolution de base 1280×720,
  `canvas_items` + `expand` (s'adapte à 16:9, 18:9, 20:9…).

## Couches

```
           ┌────────────── UI (scripts/ui) ───────────────┐
 Router ── │ 17 écrans · widgets (CardView, TopBar, KingPreview, Glyph…) │
           └───────────────┬───────────────────────────────┘
                           │ appelle
 Game (autoload) ── systèmes scripts/core ── état persistant Game.state (Dictionary)
   Inventory · Collection · KingSystem · BaseSystem · LabSystem · ChestSystem
   ShopSystem · PassSystem · MissionSystem · CampaignSystem
                           │ lit
 DB (autoload) ── data/*.json (générés par tools/gen_content.py)
 SaveSys ── user://varkon_save.json (+ .bak, écriture atomique, checksum, migrations)
 Settings ── user://settings.cfg   Audio ── bus Master/Music/SFX/Voice   EventBus ── signaux
```

### Combat

```
CampaignSystem.mission_config()  ──►  cfg (Dictionary)
                                         │
BattleSim (RefCounted, 20 Hz, déterministe, sans rendu)  ◄── BotAI / WaveDirector
   entités BattleEnt · capacités · statuts · projectiles différés · boss · vagues
   └─ events[] ─────►  BattleView (Node3D) : modèles, interpolation, effets, barres de vie
                       BattleScreen (Control) : main de cartes, rage, King, pause
```

- La simulation n'a **aucune dépendance au rendu** : les tests font jouer des centaines de
  combats bot contre bot en headless, et un futur mode en ligne pourra exécuter la même logique
  côté serveur (entrées = cartes jouées / ordres du King).
- Les **bots** reçoivent `BattleSim.perceive(team)` : entités visibles (pas les furtifs non
  révélés), leur propre main et leur propre rage. Jamais la main, le deck ni la rage adverses.
- Les unités d'un même type partagent un **prototype fusionné** (`GoblinRig.merge_static` +
  `clone`) : peu de nœuds et d'appels de rendu par unité.

## Données

Tout le contenu est décrit par des **identifiants stables** dans `data/*.json` :

| Fichier | Contenu |
|---|---|
| `cards.json` | 76 cartes + invocations, familles, raretés, courbe d'amélioration, synergies |
| `items.json` | 13 emplacements, 87 objets, cosmétiques, matériaux |
| `king.json` | stats de base, plafonds, styles d'arme, 10 capacités, options d'apparence, mutations |
| `buildings.json` | 16 bâtiments, 7 zones, grille, base de départ |
| `lab.json` | conditions de déblocage, salles, recherche, 29 recettes, recyclage, reliques |
| `economy.json` | ressources, coffres, boutique, paramètres joueur/combat |
| `pass.json` | saison, 40 paliers gratuit/premium |
| `missions.json` | missions quotidiennes/hebdomadaires, 27 succès |
| `campaign.json` | 5 chapitres, 40 missions, 5 boss, raids, événements, structures |
| `legal.json` | documents légaux (depuis docs/legal) |

Ajouter une carte, un objet, un bâtiment ou une mission = ajouter une entrée dans
`tools/gen_content.py` puis régénérer ; aucune statistique n'est recopiée dans le code.
Les capacités de cartes sont des **types génériques paramétrés** (`on_hit_burn`, `aura_buff`,
`summon`…) : `test_data_loaded` vérifie que chaque type utilisé est implémenté.

## Sauvegarde et sécurité

- `SaveSys.write` : JSON → fichier temporaire → copie de l'ancienne sauvegarde en `.bak` →
  renommage. Une interruption ne laisse jamais un fichier à moitié écrit.
- Enveloppe `{checksum, body}` (SHA-256 + sel) : un fichier corrompu ou modifié est rejeté et
  la copie de secours est chargée (un message prévient le joueur).
- `SaveSys.migrate` : migrations de version (v1 → v2 incluse et testée).
- `Game._validate_state` : remplit les clés manquantes, borne les nombres, supprime les
  identifiants inconnus.
- `Game.claim_once(key)` : registre d'idempotence (récompenses de missions, pass, premières
  victoires, fabrications, rapports de combat) — aucune récompense ne peut être obtenue deux fois.
- `Game.spend` : vérification atomique de toutes les ressources avant tout débit.
- **Limite** : en hors ligne, l'utilisateur contrôle son appareil. La somme de contrôle détecte
  la corruption et les modifications simples, pas un attaquant déterminé ; l'horloge de
  l'appareil peut être modifiée (la production ignore les retours en arrière). Un mode en ligne
  devra valider côté serveur.

## Tests

`tests/` (exécutés par `tools/run_tests.sh`, qui échoue aussi sur toute erreur GDScript) :

- `test_core.gd` — économie, sauvegarde/altération/sauvegarde de secours, migration,
  collection, deck, King (équipement, stats, plafonds, configurations, verrous d'apparence),
  laboratoire (verrouillage, réparation, fabrication unique, annulation remboursée, mutations,
  recyclage, reliques), base (placement, chevauchement, zones, minuteries, production,
  horloge), coffres (probabilités observées = affichées), boutique (achat réel jamais simulé),
  pass, missions, succès, rapport de combat idempotent, montée de niveau.
- `test_combat.gd` — bots des 3 niveaux qui terminent leurs matchs, expert > facile, variété,
  perception sans informations cachées, règles de déploiement, capacités (brûlure, poison,
  ralentissement, zone, soins, boucliers, invocations, tourelles, murailles/saut, téléportation,
  furtivité, protection du King), King, 5 boss, défense, survie, chaque carte inflige des dégâts.
- `test_balance.gd` — le deck de départ gagne les premières missions ; les missions tardives ne
  sont pas triviales.
- `test_scripts.gd` — tous les scripts compilent.
- `test_ui_smoke.gd` — scène principale réelle : tous les écrans, onglets, popups, achats,
  construction, combats complets de 4 modes à travers la vue 3D, écran de résultats.
