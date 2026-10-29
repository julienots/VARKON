# ⚡ GRAFCET Ladder Lab

Application Android (et web) d'entraînement à l'automatisme pour le **BTS ATI** (Assistance Technique d'Ingénieur) :
GRAFCET, Ladder, configuration d'automate, câblage et mise en service, sur des **machines virtuelles** animées.

Tout est simulé : l'automate **VARKON VK-200** et ses cartes sont imaginaires, mais ils reprennent les principes
des vrais automates modulaires (rack, alimentation, CPU, cartes TOR, adressage `%I`/`%Q`/`%M`/`%T`/`%C`, réseau IP,
chien de garde). L'application fonctionne entièrement **hors ligne**.

## 📲 Installer l'APK

Le fichier `releases/grafcet-ladder-lab.apk` s'installe directement sur un téléphone Android (6.0 ou plus récent) :

1. Copie l'APK sur le téléphone (câble, Drive, mail…).
2. Ouvre-le. Android demande d'autoriser l'installation d'applications « de sources inconnues » pour l'appli qui l'ouvre (Fichiers, Chrome…) : accepte.
3. Lance **GRAFCET Ladder Lab**.

C'est un APK de test (signé avec la clé de débogage), pas une version du Play Store.

## Contenu

| Partie | Ce qu'on y trouve |
|---|---|
| 📚 **Cours** (9) | Démarrer, l'API et le cycle automate, adressage et mnémoniques, câblage (NO/NC, sécurité positive, PNP/NPN, relais/transistor, bilan de consommation), configuration du VK-200, Ladder, GRAFCET (règles d'évolution, actions, divergences), traduction GRAFCET → Ladder (Set/Reset), méthodologie BTS et dépannage |
| 🎯 **Tutoriels guidés** (9) | Étapes validées automatiquement, avec la solution à charger si besoin : premier Ladder, auto-maintien + AU, configuration complète de l'automate, perceuse en GRAFCET, cuve avec temporisation, feux de carrefour, tri de colis (aiguillage), GRAFCET → Ladder, chasse aux erreurs |
| 🔧 **Atelier** | Rack de 10 emplacements, réseau, tâche et chien de garde · tableau de câblage · éditeur GRAFCET (dessin automatique) · éditeur Ladder tactile (contacts, fronts, bobines, Set/Reset, TON/TOF, compteurs, branches parallèles) · transfert, RUN/STOP et visualisation en direct · diagnostic |
| 🏭 **Machines** (5) | Tapis roulant, perceuse automatique, cuve de mélange, tri de colis, feux de carrefour. Chacune a son cahier des charges, son pupitre, ses objectifs et des **défauts réalistes** (foret cassé, débordement, pompe à sec, accident, AU ignoré…) |
| 🩺 **Diagnostic** | Plus de 50 erreurs et avertissements, chacun avec **« Pourquoi ? »** et **« Comment corriger ? »** en langage simple (double bobine, entrée écrite par une bobine, IP hors réseau, carte transistor sur du 230 V, capteur NPN sur une carte PNP, réceptivité mal écrite, étape inatteignable…) |
| ❓ **Quiz** | 20 questions avec explications |
| 🆘 **Aide** | Glossaire, catalogue de toutes les erreurs, sauvegarde et import/export de projet |

## Développement

Application web sans framework (HTML/CSS/JS dans `www/`), empaquetée pour Android avec [Capacitor](https://capacitorjs.com).

```bash
cd grafcet-ladder-lab
npm install
npm run serve          # tester dans le navigateur : http://localhost:8080
npm run apk            # construire l'APK (Android SDK requis, ANDROID_HOME défini)
```

L'APK de debug est produit dans `android/app/build/outputs/apk/debug/app-debug.apk`.
Le workflow GitHub Actions `.github/workflows/grafcet-ladder-lab-apk.yml` le reconstruit à chaque modification
et le publie comme artefact téléchargeable.

### Organisation du code

| Fichier | Rôle |
|---|---|
| `www/js/expr.js` | Analyseur des réceptivités (`.` `+` `/` `↑` `↓` `t/X2/3s`), forme disjonctive pour la traduction en Ladder |
| `www/js/plc.js` | Catalogue matériel, vérification de la configuration, du réseau et du câblage, adressage, mémoire/tempos/compteurs |
| `www/js/ladder.js` | Modèle Ladder, flux de courant, vérification, exécution d'un cycle, éditeur tactile |
| `www/js/grafcet.js` | Vérification, évolution (franchissement simultané, stabilité), dessin SVG, éditeur, traduction Set/Reset |
| `www/js/machines.js` | Physique, dessin et défauts des 5 machines |
| `www/js/errors.js` | Catalogue des erreurs expliquées |
| `www/js/lessons.js` | Cours, tutoriels, quiz, glossaire |
| `www/js/app.js` | Navigation, atelier, boucle de simulation (lecture des entrées → programme → sorties → machine) |
| `tools/make_icons.py` | Génération des icônes Android |
