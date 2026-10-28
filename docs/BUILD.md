# Compilation Android — VARKON

## Prérequis (versions vérifiées)

| Outil | Version | Rôle |
|---|---|---|
| Godot Engine | **4.4.1-stable** | moteur / exportation |
| Modèles d'export Godot | 4.4.1-stable | APK/AAB |
| Android SDK | platform-tools, **build-tools 34.0.0**, platforms;android-34 | signature, AAB |
| JDK | **17** (requis pour l'AAB : Gradle 8.2) ; JDK 21 suffit pour l'APK | apksigner / Gradle |

Dans l'éditeur : *Éditeur > Paramètres de l'éditeur > Export > Android* : chemin du SDK Android,
chemin du JDK, keystore de débogage.

## APK de test (sans Gradle)

```bash
godot --headless --import
godot --headless --export-debug "Android" build/VARKON-debug.apk
apksigner verify --verbose build/VARKON-debug.apk
```

Résultat vérifié dans l'environnement de développement :
`com.superessence.varkon`, versionCode 1, versionName 0.9.0, minSdk 21, targetSdk 34,
architectures arm64-v8a + armeabi-v7a, permission unique `VIBRATE`, signature v1+v2+v3 (clé de
**débogage**). Installation : `adb install -r build/VARKON-debug.apk` ou copie du fichier sur le
téléphone (autoriser les sources inconnues).

## AAB (Google Play)

L'AAB nécessite le *build Gradle* :

1. *Projet > Installer le modèle de compilation Android* (ou
   `godot --headless --install-android-build-template`).
2. Dupliquer le préréglage « Android » et activer `gradle_build/use_gradle_build`,
   `gradle_build/export_format = AAB`.
3. Exporter avec **JDK 17** (Gradle 8.2 ne fonctionne pas avec JDK 21).

Le préréglage **« Android AAB »** est déjà présent dans `export_presets.cfg` :

```bash
export JAVA_HOME=/chemin/vers/jdk-17
godot --headless --install-android-build-template --export-debug "Android AAB" build/VARKON-debug.aab
java -jar bundletool.jar validate --bundle=build/VARKON-debug.aab
```

Vérifié dans l'environnement de développement : AAB de 57 Mo, `bundletool validate` OK.
En cas d'erreurs HTTP 429 de Maven Central, un script `~/.gradle/init.d/mirror.gradle` peut
rediriger vers `https://maven-central.storage-download.googleapis.com/maven2/`.

## Publication (ce qui manque, à fournir par SuperEssence Studio)

- **Keystore de production** (upload key Play) : ne jamais le versionner. Renseigner
  `keystore/release`, `keystore/release_user`, `keystore/release_password` dans le préréglage
  ou via les variables `GODOT_ANDROID_KEYSTORE_RELEASE_*`.
- **Compte Google Play Console**, fiche du jeu, classification IARC.
- **targetSdk** : Google Play exige une API cible récente (35+ en 2025-2026) ; avec le build
  Gradle, régler `gradle_build/target_sdk` et installer la plateforme correspondante, puis
  retester.
- **Coordonnées de contact** dans la politique de confidentialité et les conditions (laissées
  « à compléter » : aucune coordonnée n'a été inventée).
- Si des achats réels sont ajoutés : Google Play Billing + validation serveur.

## Régénérer les contenus

```bash
python3 tools/gen_content.py     # data/*.json (cartes, objets, bâtiments, campagne…)
python3 tools/strings.py         # localization/strings.csv (+ vérification des clés)
python3 tools/build_legal.py     # data/legal.json depuis docs/legal/*.md
python3 tools/generate_audio.py  # assets/audio (sons et musiques synthétisés)
godot --headless --import        # réimporter
```

## Tests

```bash
tools/run_tests.sh               # tous les tests
tools/run_tests.sh --only=test_combat
```

Captures d'écran automatiques (Linux + Xvfb) :

```bash
xvfb-run -a godot --path . --resolution 1280x720 -- --screen=battle --param=mission:c1m8 \
  --param=autoplay:1 --screenshot=/tmp/boss.png@20
```
