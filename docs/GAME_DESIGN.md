# Règles de jeu — VARKON

## Combat

- **Terrain** : 32 × 18. Joueur à gauche, ennemi à droite. Chaque camp possède un **Trône**
  (4200 PV) et deux **tours** (2400 PV) en duel. Les niveaux de *Tour de garde* (base) et la
  recherche *Fortification* renforcent les vôtres.
- **Rage** : départ 5 (+ bonus King/recherche), +1 toutes les 2,8 s, max 10. Rage ×2 pendant la
  dernière minute d'un duel.
- **Cartes** : deck de 8, main de 4 + carte suivante. Une carte jouée retourne en fin de file.
  Déploiement uniquement sur sa moitié de terrain (zone réduite en raid).
- **King Gobelin** : héros déplacé en touchant le sol ; attaque automatiquement ce qui est
  proche ; capacité active, défensive (recharges) et ultime (jauge 0-100 % remplie avec le temps
  et les dégâts). Réapparition 12 s après sa chute, tant que le Trône tient.
- **Victoire** : destruction du Trône adverse ; sinon, à la fin du temps, le camp qui a détruit
  le plus de structures (puis le plus de PV restants) ; sinon égalité.
- **Étoiles** : ★ victoire, ★★ Trône à 50 % ou plus, ★★★ toutes les structures adverses détruites
  (raid : 75 s restantes et toutes les tours ; défense/boss : aucune structure perdue).
- **Dégâts** : `dégâts × bonus × 100 / (100 + armure)` ; bouclier absorbé en premier ;
  résistance du King contre capacités et dégâts sur la durée.

### Modes

| Mode | Règles particulières |
|---|---|
| Duel / Campagne | bot ennemi + son chef (King rival) |
| Raid | forteresse ennemie (murailles qui bloquent les unités terrestres, pièges, tours) ; l'attaquant démarre avec 80 % de rage, le défenseur se régénère moins vite ; 3 min |
| Défense | vagues ; le *WaveDirector* choisit la voie la plus faible ; murailles et pièges construits dans la base |
| Survie | vagues infinies croissantes ; victoire à partir de 5 vagues |
| Boss | boss à phases, attaques télégraphiées (cercles/lignes rouges), armure destructible, épuisement (+50 % de dégâts subis) |
| Défis | règles : familles imposées, rage double, sans King, coût max, tours renforcées |
| Entraînement | mannequins ou bots, sans récompense |

## Bots

Score tactique par couple (carte, position) : valeur défensive (menaces sur sa moitié, contres :
anti-air, zone contre nuées, dégâts contre tanks), valeur offensive (réserve de rage, tank à
l'arrière, poussée quand le King adverse est vulnérable), soutien et synergies (expert),
efficacité du coût, pénalité de répétition, bruit selon la difficulté.

| | Facile | Normal | Expert |
|---|---|---|---|
| Réflexion | 2,2 s | 1,2 s | 0,6 s |
| Bruit | ±45 % | ±18 % | ±5 % |
| Poids des contres | 0,4 | 1,0 | 1,3 |
| Synergies / exploitation des recharges | non | non | oui |
| Réserve de rage | 0 | 1 | 2 |

Anti-blocage : si la rage reste pleine plus de 3 s, le meilleur coup est joué.

## Progression et économie

- **Cartes** : niveaux 1-10 (+10 % PV/dégâts par niveau), copies + or ; les copies manquantes
  peuvent être remplacées par des fragments. Niveau max = Salle des cartes + 2.
- **Bâtiments** : coût × croissance^niveau, durée = base × (niveau+1)^1,6 (max 4 h), 2 bâtisseurs,
  accélération en cristaux. Les autres bâtiments ne dépassent pas le niveau de la Forteresse ;
  la Forteresse demande un niveau de joueur.
- **Production** : mines (or, plafond = Trésorerie), atelier (composants), cristallerie
  (cristaux), enclos mutant (essence).
- **Laboratoire** : verrouillé jusqu'à Forteresse 4 + chapitre 2 + réparation (800 or, 60
  composants).
- **Coffres** : chaque carte/objet est tiré indépendamment selon les poids de rareté ; si aucune
  carte d'une rareté n'est disponible au niveau du joueur, le tirage passe à la rareté inférieure
  (les pourcentages affichés en tiennent compte).
- **Pass** : 40 paliers × 100 XP ; XP par combat (30/10), mission quotidienne (50), hebdomadaire
  (150). Voie premium : 650 cristaux (gagnables).
- **Sans argent réel** : toute la campagne, tous les bâtiments et le pass gratuit sont
  accessibles ; les cristaux s'obtiennent par niveaux, missions, succès, premières victoires,
  pass, coffres et Cristallerie.
