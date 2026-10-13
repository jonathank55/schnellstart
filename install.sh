#!/usr/bin/env bash
# ==============================================================================
# Schnellstart — Terminal-Schnellstartmenü für macOS
# Installationsskript
#
# Zwei Installationswege:
#   1. Aus dem geklonten Repository:  ./install.sh
#   2. Einzeilig ohne Klon (macOS, curl vorhanden):
#      curl -fsSL https://raw.githubusercontent.com/jonathank55/schnellstart/main/install.sh | bash
# ==============================================================================

set -e

echo "=== Installation von Schnellstart ==="

RAW_BASE="https://raw.githubusercontent.com/jonathank55/schnellstart/main"
PROGRAMM_DATEIEN=("start.sh" "config.json")

# ---------------------------------------------------------------- Quelle ermitteln
# Wurde das Skript aus einem vorhandenen Repository ausgeführt, liegt dieses
# Verzeichnis dort, wo die Programmdateien bereits lokal vorliegen. Wurde es
# per curl direkt in eine Shell gepipt, fehlen diese Dateien und werden
# vorübergehend in ein Arbeitsverzeichnis heruntergeladen.
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if [ -f "$SCRIPT_PATH" ] && [ -f "$(dirname "$SCRIPT_PATH")/start.sh" ]; then
    SRC_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    CLEANUP_DIR=""
    echo "Installiere aus vorhandenem Verzeichnis: $SRC_DIR"
else
    command -v curl >/dev/null 2>&1 || { echo "Fehler: curl wird benötigt, um die Dateien herunterzuladen."; exit 1; }
    CLEANUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/schnellstart-install.XXXXXX")"
    SRC_DIR="$CLEANUP_DIR"
    echo "Lade Programmdateien von GitHub nach $SRC_DIR ..."
    for DATEI in "${PROGRAMM_DATEIEN[@]}"; do
        curl -fsSL "$RAW_BASE/$DATEI" -o "$SRC_DIR/$DATEI"
    done
    trap 'rm -rf "$CLEANUP_DIR"' EXIT
fi

CONFIG_DIR="$HOME/.config/schnellstart"

# 1. Zielverzeichnis im PATH ermitteln
INSTALL_DIR=""
if [ -d "$HOME/bin" ] && [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
    INSTALL_DIR="$HOME/bin"
elif [ -w /usr/local/bin ]; then
    INSTALL_DIR="/usr/local/bin"
else
    mkdir -p "$HOME/bin"
    INSTALL_DIR="$HOME/bin"
    echo "Hinweis: Bitte stellen Sie sicher, dass $HOME/bin in Ihrem PATH liegt."
fi

# 2. Konfigurationsverzeichnis vorbereiten und Programmdateien installieren
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.json" ]; then
    echo "Erstelle Standard-Konfiguration in $CONFIG_DIR/config.json..."
    cp "$SRC_DIR/config.json" "$CONFIG_DIR/config.json"
else
    echo "Bestehende Konfiguration in $CONFIG_DIR/config.json bleibt unberührt."
fi

cp "$SRC_DIR/start.sh" "$CONFIG_DIR/start.sh"
chmod +x "$CONFIG_DIR/start.sh"

# 3. Ausführbaren Befehl verlinken
ln -sf "$CONFIG_DIR/start.sh" "$INSTALL_DIR/start"

echo "=============================================================================="
echo "ERFOLG: Schnellstart wurde erfolgreich installiert!"
echo "Befehl:  start"
echo "=============================================================================="
