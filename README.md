# Aero 4G Cam - Android Screen Recording Automation

Automatisation GitHub pour enregistrement d'écran Android UBox et upload sur Cloudflare R2.

## 📋 Objectif

- Lance un émulateur Android
- Installe l'application UBox
- Ouvre la première caméra dans l'app
- Déclenche un screen recording Android **en format paysage (landscape)**
- Upload la vidéo sur Cloudflare R2 (S3 API) sous le nom `terrain.mp4`
- Se déclenche à la demande via workflow_dispatch sur GitHub Actions

## 🛠️ Stack Technique

- **Runtime**: Node.js + Yarn
- **Automatisation**: Appium + WebdriverIO
- **Driver**: UiAutomator2 (Android)
- **Stockage**: Cloudflare R2 (S3 API)
- **CI/CD**: GitHub Actions
- **Git**: Git LFS pour l'APK (100MB+)
- **Orientation**: Mode paysage (LANDSCAPE) forcé pour l'enregistrement

## 📁 Structure du Projet

```
aero-4g-cam/
├── .github/
│   └── workflows/
│       └── record-camera.yml          # GitHub Actions workflow
├── src/
│   ├── automation/
│   │   ├── appium-config.js           # Configuration Appium
│   │   ├── camera-recorder.js         # Script principal d'enregistrement
│   │   └── ubox-navigation.js         # Navigation dans UBox
│   ├── upload/
│   │   └── r2-uploader.js             # Upload sur Cloudflare R2
│   └── utils/
│       ├── env-validator.js           # Validation de l'environnement
│       ├── logger.js                  # Système de logs
│       └── retry-manager.js           # Gestion des retries
├── scripts/
│   ├── dev.sh                         # Script de développement
│   └── start.sh                       # Script de production
├── .gitattributes                     # Git LFS config
├── package.json                       # Dépendances Node.js
├── .env.example                       # Template variables d'environnement
└── UBox.xapk                          # XAPK UBox (extracted to UBox.apk during setup)
```

## 🚀 Installation

### Prérequis

- **Node.js** 18+ et Yarn
- **Android Studio** (pour SDK et emulator)
- **Appium** (sera installé via yarn)
- **Compte Cloudflare R2** avec credentials

### Étape 1: Clone et Setup

```bash
git clone https://github.com/yourusername/aero-4g-cam.git
cd aero-4g-cam

# Installer Git LFS et télécharger l'XAPK
git lfs install
git lfs pull

# Run setup (extracts XAPK to APK + OBB files, installs dependencies)
./setup.sh
```

**Note:** The setup script automatically:

- Extracts `UBox.xapk` to `UBox.apk`
- Preserves OBB files (if any) in `./obb/` directory
- Installs all Node.js dependencies
- Configures Android SDK and emulator

### Étape 2: Configuration .env

Créer un fichier `.env` à la racine du projet (ne sera pas commité):

```env
# Cloudflare R2
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=your_bucket_name
R2_ENDPOINT=https://your_account_id.r2.cloudflarestorage.com

# Android (Optional - these have defaults)
RECORDING_DURATION=30000
SCREEN_ORIENTATION=LANDSCAPE
```

### Étape 3: C'est tout! 🎉

The setup script handles everything:

- ✅ XAPK extraction (APK + OBB files)
- ✅ Appium drivers installation
- ✅ Android SDK configuration
- ✅ Emulator setup

**OBB Files:** If UBox.xapk contains OBB files (expansion packs), they are automatically:

- Extracted to `./obb/` during setup
- Pushed to device at `/sdcard/Android/obb/{package_name}/` before each run

## 💻 Utilisation Locale

### ⚡ Lancement Simple (Un Seul Commande!)

```bash
# Mode développement - Avec affichage de l'écran de l'émulateur (verbose par défaut)
yarn dev

# Mode production - Headless (sans affichage, logs minimaux)
yarn start
```

**C'est tout!** Ces commandes font TOUT automatiquement:

- ✅ Démarrent le serveur Appium
- ✅ Créent l'AVD si nécessaire
- ✅ Lancent l'émulateur (avec/sans affichage selon le mode)
- ✅ Attendent que tout soit prêt
- ✅ Exécutent l'automation
- ✅ Nettoient tout à la fin

**Différences entre les modes:**

- `yarn dev` → Émulateur **visible** + **logs verbeux** (pour le debugging et voir ce qui se passe)
- `yarn start` → Émulateur **headless** + **logs minimaux** (erreurs uniquement, plus propre)

### 📋 Gestion des Logs

**Suivant les bonnes pratiques Linux**, les logs sont maintenant optimisés:

```bash
# Mode production - Sortie silencieuse (recommandé)
yarn start

# Mode verbose - Affiche tous les logs détaillés
VERBOSE=true yarn start

# Mode développement - Verbose par défaut
yarn dev

# Mode développement silencieux (rare)
VERBOSE=false yarn dev
```

**Comportement des logs:**

- **Console**: En mode production, **sortie totalement silencieuse** sauf en cas d'erreur
- **Fichiers**: Tous les logs (INFO, WARN, ERROR) sont **toujours sauvegardés** dans `.logs/run-*.log`
- **Dev mode**: Verbose activé par défaut pour faciliter le debugging
- **Fin d'exécution**: Le chemin du fichier de log est toujours affiché

**Exemples:**

```bash
# Production silencieuse (défaut)
yarn start
# Sortie:
# 📋 Full log available at: .logs/run-1704153600000.log

# Production avec tous les détails
VERBOSE=true yarn start     # Tous les logs visibles

# Développement normal
yarn dev                    # Verbose par défaut

# Vérifier les logs après exécution
cat .logs/run-*.log         # Tous les détails sont toujours là
```

**Sources de logs optimisées:**

- ✅ Emulateur Android (silencieux)
- ✅ Installation APK (silencieuse)
- ✅ Validation environnement (silencieuse)
- ✅ WebDriver/Appium (logLevel: "error")
- ✅ Logger applicatif (respect VERBOSE)
- ✅ Scripts shell (respect VERBOSE)

Seules les **erreurs critiques** apparaissent en mode production, tout le reste est dans les fichiers de log.

### Appium Inspector (Debug UI) - Optionnel

Si vous avez besoin de débugger les sélecteurs UBox:

```bash
# Lancer Appium manuellement
appium --allow-cors

# Ouvrir Appium Inspector dans votre navigateur
# URL: http://localhost:4723

# Identifier les sélecteurs de l'app UBox et mettre à jour ubox-navigation.js
```

## 🔧 Commandes

```bash
# Les 3 seules commandes dont vous avez besoin:
yarn install          # 1. Installer les dépendances (une seule fois)
yarn dev              # 2. Mode dev: démarre TOUT avec affichage de l'écran
yarn start            # 3. Mode prod: démarre TOUT en headless (sans écran)
```

### Commandes Android (optionnelles)

```bash
# Debug Android via adb
adb devices                           # Lister les devices
adb logcat                            # Voir les logs Android
adb shell pm list packages | grep ubox  # Vérifier si l'app est installée
adb shell screenrecord /sdcard/test.mp4 # Enregistrement manuel
adb pull /sdcard/test.mp4             # Récupérer une vidéo
```

## 🚀 GitHub Actions

### Quick Setup

1. **Configure Secrets** (Settings → Secrets and variables → Actions):

   - `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
   - `R2_BUCKET_NAME`, `R2_ENDPOINT`
   - `UBOX_EMAIL`, `UBOX_PASSWORD`

2. **Run Workflow**:

   - Go to **Actions** → **Generate Video**
   - Click **Run workflow**
   - (Optional) Adjust recording duration
   - View logs and download artifacts

3. **Automated Runs**:
   - Workflow runs daily at 2:00 AM UTC (configurable)
   - Videos uploaded to Cloudflare R2
   - Artifacts available for 7 days

### Architecture Note

The GitHub Action uses **x86_64 architecture** (not ARM) because:

- GitHub-hosted runners are x86_64
- Better Android emulator support with KVM acceleration
- More stable and faster in CI environments

For detailed setup, troubleshooting, and configuration options, see **[GITHUB_ACTIONS.md](./GITHUB_ACTIONS.md)**.

## 📝 Fichiers Clés

### `src/automation/camera-recorder.js`

Script principal qui:

1. Crée une session Appium
2. Lance la navigation UBox
3. Force l'orientation paysage
4. Enregistre l'écran (1280x720)
5. Sauvegarde localement
6. Upload sur R2
7. Nettoie les fichiers temporaires

### `src/automation/ubox-navigation.js`

Classe pour naviguer dans l'app UBox:

- `waitAndClick()` - Attend et clique sur un élément
- `navigateToFirstCamera()` - Ouvre la première caméra

⚠️ **À personnaliser** avec les bons sélecteurs UBox (via Appium Inspector)

### `src/upload/r2-uploader.js`

Upload sur Cloudflare R2 avec AWS SDK S3:

- Configure le client S3 avec credentials
- Upload le fichier MP4
- Retourne l'URL d'accès

### `.github/workflows/record-camera.yml`

Workflow complet:

- Setup Node.js, Android SDK, Appium
- Cache de l'AVD pour plus de rapidité
- Lancement de l'émulateur
- Exécution du script
- Backup de la vidéo en artifact

## 🐛 Debugging

### L'émulateur ne démarre pas

```bash
# Vérifier les AVD disponibles
emulator -list-avds

# Nettoyer et recréer
avdmanager delete avd -n test_emulator
./scripts/setup-android.sh
```

### Appium ne trouve pas l'app

```bash
# Vérifier que l'APK est installé
adb shell pm list packages | grep ubox

# Réinstaller
adb install UBox.apk
```

### Les sélecteurs UI ne fonctionnent pas

1. Lancer Appium: `appium --allow-cors`
2. Ouvrir Appium Inspector
3. Connecter à l'émulateur
4. Inspecter et identifier les bons sélecteurs
5. Mettre à jour `src/automation/ubox-navigation.js`

### Upload R2 échoue

```bash
# Vérifier les credentials
cat .env

# Tester avec AWS CLI
aws s3 ls --endpoint-url=https://your_account.r2.cloudflarestorage.com
```

### La vidéo n'est pas en mode paysage

```javascript
// Vérifier dans camera-recorder.js que:
// 1. driver.setOrientation("LANDSCAPE") est appelé
// 2. videoSize: "1280x720" (largeur > hauteur)
// 3. L'orientation Appium est configurée
```

## 📚 Ressources

- [Appium Documentation](https://appium.io/docs/en/latest/)
- [WebDriverIO Docs](https://webdriver.io/)
- [Cloudflare R2 S3 API](https://developers.cloudflare.com/r2/api/s3/)
- [GitHub Actions Android](https://github.com/ReactiveCircus/android-emulator-runner)
- [Git LFS](https://git-lfs.github.com/)

## 📄 License

MIT

## 🤝 Contribution

Les pulls requests sont bienvenues!
