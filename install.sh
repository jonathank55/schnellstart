#!/bin/bash
set -e
QUELLE="$(cd "$(dirname "$0")" && pwd)"
ZIEL_KONFIG="$HOME/.config/schnellstart"
ZIEL_SKRIPT="$ZIEL_KONFIG/start.sh"

if ! grep -q 'SCHNELLSTART' "$QUELLE/start.sh"; then
    echo "Fehler: start.sh im Quellordner unvollständig."
    exit 1
fi

mkdir -p "$ZIEL_KONFIG"

if [[ ! -f "$ZIEL_KONFIG/config.json" ]]; then
    cp "$QUELLE/config.json" "$ZIEL_KONFIG/config.json"
else
    echo "Vorhandene Konfiguration beibehalten."
fi

cp "$QUELLE/start.sh" "$ZIEL_SKRIPT"
chmod +x "$ZIEL_SKRIPT"

mkdir -p "$HOME/bin"
printf '#!/bin/bash\nexec "%s"\n' "$ZIEL_SKRIPT" > "$HOME/bin/start"
chmod +x "$HOME/bin/start"

if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bash_profile"
fi

if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
fi

echo "Installation abgeschlossen! Neues Terminal-Fenster öffnen und 'start' eingeben."
