# Script de lancement Flutter sur émulateur Android
# Usage : lancé automatiquement par VS Code via Terminal > Run Task

$ADB      = "C:\Users\matis\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$EMULATOR = "C:\Users\matis\AppData\Local\Android\Sdk\emulator\emulator.exe"
$AVD_NAME = "Pixel_8_API_35"
$AVD_INI  = "C:\Users\matis\.android\avd\Pixel_8_API_35.avd\emulator-user.ini"
$FLUTTER  = "C:\Cours\Master\Mobile\Appli\flutter_sdk\bin\flutter.bat"
$PROJECT  = "C:\Cours\Master\Mobile\Appli\flutter_application_1"

# ── Étape 1 : vérifier si l'émulateur est déjà lancé ──────────────────────────
Write-Host "Vérification de l'émulateur en cours..."

$devices = & $ADB devices 2>&1
$running = $devices | Where-Object { $_ -match "^emulator-\d+\s+device$" }

if ($running) {
    $deviceId = ($running -split "\s+")[0]
    Write-Host "Emulateur déjà lancé : $deviceId"
} else {
    # ── Étape 2 : fixer la position avant de lancer ───────────────────────────
    # On écrit la position ici car l'émulateur écrase ce fichier à chaque fermeture
    @"
window.x = 950
window.y = 20
window.scale = 0.350000
resizable.config.id = -1
posture = 0
"@ | Set-Content $AVD_INI -Encoding UTF8

    # ── Étape 3 : lancer l'émulateur ──────────────────────────────────────────
    Write-Host "Lancement de l'émulateur $AVD_NAME..."
    # -no-snapshot-load : démarrage propre (évite les états gelés)
    # -scale 0.35       : taille fixe pour tenir dans l'écran
    Start-Process -FilePath $EMULATOR `
        -ArgumentList "-avd", $AVD_NAME, "-no-snapshot-load", "-scale", "0.35" `
        -WindowStyle Normal

    # ── Étape 4 : attendre que l'émulateur soit complètement démarré ──────────
    Write-Host "Attente du démarrage (peut prendre 30-60 secondes)..."
    $booted = $false
    $attempts = 0
    while (-not $booted -and $attempts -lt 60) {
        Start-Sleep -Seconds 3
        $attempts++

        $devices = & $ADB devices 2>&1
        $running = $devices | Where-Object { $_ -match "^emulator-\d+\s+device$" }

        if ($running) {
            $deviceId = ($running -split "\s+")[0]
            $bootDone = & $ADB -s $deviceId shell getprop sys.boot_completed 2>&1
            if ($bootDone -match "1") { $booted = $true }
        }

        Write-Host "  ... tentative $attempts/60"
    }

    if (-not $booted) {
        Write-Host "ERREUR : l'émulateur n'a pas démarré dans les temps. Relance le script."
        exit 1
    }

    Write-Host "Emulateur prêt : $deviceId"
}

# ── Étape 5 : lancer l'application Flutter ────────────────────────────────────
Write-Host ""
Write-Host "Lancement de l'application Flutter sur $deviceId..."
Write-Host "(appuie sur 'r' pour Hot Reload, 'R' pour Hot Restart, 'q' pour quitter)"
Write-Host ""

Set-Location $PROJECT
# --no-enable-impeller : évite l'écran blanc sur émulateurs x86
& $FLUTTER run -d $deviceId --no-enable-impeller
