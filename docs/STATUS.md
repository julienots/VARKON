# État du projet — VARKON 0.9.0 (version de test)

Ce document distingue ce qui est **opérationnel et testé**, ce qui est **incomplet**, et les
**problèmes connus**. Rien n'est présenté comme terminé sans l'être.

## Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| Suite de tests headless `tools/run_tests.sh` | **53 tests, 0 échec**, aucune erreur GDScript |
| Parcours UI automatisé (tous les écrans, onglets, popups, achats, construction, 4 combats via la vue 3D) | OK (`test_ui_smoke.gd`) |
| Bots facile/normal/expert : matchs bot contre bot menés à terme | OK |
| Équilibrage (deck de départ, joueur simulé « normal ») | c1m1 100 %, c1m2 75 %, c1m3 75 %, c1m4 (raid) 100 %, c1m5 100 %, c1m8 (boss) 100 % |
| Rendu réel (Linux, Xvfb, Mesa llvmpipe, renderer Compatibility) | captures de tous les écrans dans `docs/screenshots` |
| Export APK `godot --export-debug "Android"` | **APK généré**, 57 Mo, `apksigner verify` OK (v1+v2+v3), arm64-v8a + armeabi-v7a |
| Export AAB (Gradle) | voir section « AAB » ci-dessous |
| Exécution sur un vrai téléphone Android | **non réalisée** (aucun appareil ni émulateur disponible dans l'environnement) |
| Mesure de fréquence d'images sur appareil | **non réalisée** — aucune valeur de FPS n'est revendiquée |

## Fonctionnalités terminées (opérationnelles)

- Lancement SuperEssence Studio → VARKON → chargement réel → menu (passable après la 1re fois).
- Menu principal 3D vivant (King animé, réactions), barre de profil/monnaies, notifications.
- King Gobelin unique : apparence (21 options, verrous de progression), 13 emplacements,
  aperçu 3D avant équipement, comparaison, recalcul et plafonds des statistiques,
  10 capacités, 7 mutations visibles, configurations, emotes/animations de victoire/défaite.
- 76 cartes jouables (12 familles, 6 raretés), améliorations (copies, fragments, or),
  deck de 8, 12 synergies, portraits générés depuis les modèles 3D.
- Combat : déploiement par glisser-déposer ou toucher, King contrôlable, 43 types de capacités,
  statuts, projectiles, synergies, rage double, 7 modes, 5 boss à phases.
- Bots 3 niveaux sans triche d'information ni de statistiques ; directeur de vagues.
- Base 3D : 16 bâtiments, placement/rotation/déplacement validés, améliorations temporisées,
  2 bâtisseurs, accélération, production plafonnée, 7 zones, laboratoire en ruine puis réparé.
- Laboratoire : fabrication en file (29 recettes, annulation remboursée), mutation,
  expérimentation, recherche, recyclage, reliques.
- Coffres (8 types, probabilités affichées exactes), boutique (offres du jour, aperçu, limites),
  pass 40 paliers gratuit/premium, missions quotidiennes/hebdomadaires, 27 succès,
  événements hebdomadaires locaux, inventaire filtrable.
- Sauvegarde versionnée (atomique, checksum, secours, migration, validation, idempotence).
- Paramètres : graphismes, audio par bus, vibrations, taille des boutons, mode gaucher,
  accessibilité (texte, contraste, flashs, secousses, animations, indicateurs sonores),
  FR/EN, tutoriels, nombres de dégâts, portée, confirmations, notifications in-game, compte.
- Documents : confidentialité, conditions, achats, code de conduite, mineurs, crédits (FR/EN).

## Fonctionnalités incomplètes ou volontairement absentes

| Élément | État |
|---|---|
| Multijoueur en ligne | **absent** (aucune infrastructure réseau). La simulation déterministe et séparée du rendu est prête pour un serveur. L'onglet l'indique clairement. |
| Achats avec argent réel | **non configurés** : affichés indisponibles, jamais simulés. Nécessite Google Play Billing + serveur de validation. |
| Notifications système Android | non implémentées (aucune autorisation demandée) ; seules les notifications in-game existent. |
| Sauvegarde cloud / compte | absente ; sauvegarde locale uniquement. |
| Événements en ligne | absents ; défis locaux hebdomadaires selon l'horloge de l'appareil, présentés comme tels. |
| Traduction anglaise du contenu | l'interface est entièrement traduite ; les noms/descriptions des cartes, objets et missions sont en français (champs `name_en` prévus par la structure). |
| Modèles 3D | personnages et bâtiments **procéduraux low-poly** (formes primitives assemblées, matériaux PBR, silhouettes variées par rôle/famille). Ce ne sont pas des modèles sculptés haute définition ; pas de squelette ni d'animation faciale (animations procédurales des membres, tête, ailes, armes). |
| Audio | sons et musiques originaux **synthétisés** (qualité fonctionnelle, pas de production musicale professionnelle ni de voix enregistrées). |
| Équilibrage | vérifié par simulation sur le chapitre 1 ; les chapitres 2 à 5 n'ont pas été équilibrés finement. |
| Keystore de production, fiche Play, contacts légaux | à fournir par le studio (voir `docs/BUILD.md`). |
| targetSdk 35+ exigé par Google Play | l'APK de test cible l'API 34 (modèle par défaut de Godot 4.4.1) ; à régler avec le build Gradle. |

## Problèmes connus

- Performances sur téléphone non mesurées. Mesures de réduction déjà en place : renderer
  Compatibility, prototypes de modèles fusionnés et clonés, détails réduits sur le terrain,
  qualité basse/économie d'énergie (30 FPS, sans ombres ni particules).
- Les dates (missions, offres, pass) dépendent de l'horloge de l'appareil ; la production des
  bâtiments ignore les retours en arrière mais une avance d'horloge n'est pas détectable hors ligne.
- La protection de la sauvegarde (somme de contrôle) détecte la corruption et les modifications
  simples, pas une triche déterminée sur un appareil maîtrisé par l'utilisateur.
- Les emojis/symboles non présents dans les polices ont été remplacés par des icônes vectorielles ;
  un texte saisi par le joueur contenant des emojis peut s'afficher sans glyphe.

## AAB

Résultat de la tentative de build Gradle dans l'environnement de développement : voir la
section ajoutée en fin de document.

## Prochaines étapes recommandées

1. Tester l'APK sur 2-3 téléphones de référence (entrée de gamme, milieu, haut de gamme) et
   mesurer les FPS en combat chargé ; ajuster `BattleView.VIS`, les détails et les particules.
2. Équilibrer les chapitres 2-5 avec `test_balance.gd` étendu et des sessions de jeu réelles.
3. Remplacer progressivement les modèles procéduraux par des modèles 3D artistiques (les points
   d'attache et l'API `GoblinRig` restent valables).
4. Traduire le contenu (cartes/objets/missions) en anglais via les champs `*_en`.
5. Préparer la publication : keystore, targetSdk récent, fiche Play, classification IARC,
   coordonnées légales.
6. Si souhaité : serveur (sauvegarde cloud, validation des achats, multijoueur basé sur
   `BattleSim`).
