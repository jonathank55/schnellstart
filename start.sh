#!/bin/bash
# SCHNELLSTART – Einfaches Terminal-Schnellstartmenü für macOS

CONFIG="$HOME/.config/schnellstart/config.json"

cursor_aus() { printf '\033[?25l'; }
cursor_an()  { printf '\033[?25h'; }
aufraeumen() { cursor_an; }
trap aufraeumen EXIT

# Menü sauber vom Bildschirm entfernen und Cursor wiederherstellen
beenden() {
    printf '\033[2J\033[3J\033[H'
    cursor_an
    exit 0
}

ist_gui_befehl() {
    case "$1" in
        *open\ -a*|*osascript*) return 0 ;;
    esac
    return 1
}

if [[ ! -f "$CONFIG" ]]; then
    CONFIG="$(cd "$(dirname "$0")" && pwd)/config.json"
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "Fehler: Konfigurationsdatei nicht gefunden."
    echo "Bitte zuerst install.sh ausführen."
    read -r -p "Taste zum Beenden drücken..."
    exit 1
fi

titel_liste=()
befehl_liste=()

while IFS=$'\t' read -r titel befehl; do
    titel_liste+=("$titel")
    befehl_liste+=("$befehl")
done < <(python3 -c "
import json
with open('$CONFIG') as f:
    daten = json.load(f)
for eintrag in daten.get('eintraege', []):
    print(f\"{eintrag['titel']}\t{eintrag['befehl']}\")
")

anzahl=${#titel_liste[@]}
if (( anzahl == 0 )); then
    echo "Fehler: Keine Einträge in der Konfigurationsdatei gefunden."
    read -r -p "Taste zum Beenden drücken..."
    exit 1
fi

auswahl=0

zeichne_menue() {
    local zeilen spalten
    if ! read -r zeilen spalten < <(stty size 2>/dev/null); then
        zeilen=24; spalten=80
    fi
    [[ -z "$zeilen" || -z "$spalten" ]] && { zeilen=24; spalten=80; }

    local hoehe=$(( anzahl + 3 ))
    local start_zeile=1
    (( zeilen > hoehe )) && (( start_zeile = (zeilen - hoehe) / 2 + 1 ))

    local breite=$EINRUECK_TITEL
    local i l
    for i in "${!titel_liste[@]}"; do
        l=$(( ${#EINRUECK} + 2 + ${#titel_liste[$i]} ))
        (( l > breite )) && breite=$l
    done
    local start_spalte=1
    (( spalten > breite )) && (( start_spalte = (spalten - breite) / 2 + 1 ))

    # Absolut positioniertes Zeichnen; \033[3J leert den Scrollback.
    local puffer zeile
    puffer=$(
        printf '\033[2J\033[3J\033[H'
        zeile=$start_zeile
        printf '\033[%s;%sH\033[K' "$zeile" "$start_spalte"; (( zeile++ ))
        printf '\033[%s;%sH\033[1mSCHNELLSTART\033[0m\033[K' "$zeile" "$start_spalte"; (( zeile++ ))
        printf '\033[%s;%sH\033[K' "$zeile" "$start_spalte"; (( zeile++ ))
        for i in "${!titel_liste[@]}"; do
            if (( i == auswahl )); then
                printf '\033[%s;%sH▸ \033[1m%s\033[0m\033[K' "$zeile" "$start_spalte" "${titel_liste[$i]}"
            else
                printf '\033[%s;%sH  %s\033[K' "$zeile" "$start_spalte" "${titel_liste[$i]}"
            fi
            (( zeile++ ))
        done
        printf '\033[%s;1H' "$start_zeile"
    )
    printf '%s' "$puffer"
}

ausfuehren() {
    local befehl="${befehl_liste[$auswahl]}"
    local zeilen spalten zeile
    if ! read -r zeilen spalten < <(stty size 2>/dev/null); then
        zeilen=24; spalten=80
    fi
    [[ -z "$zeilen" || -z "$spalten" ]] && { zeilen=24; spalten=80; }
    zeile=$(( zeilen / 2 + anzahl / 2 + 3 ))
    (( zeile > zeilen )) && zeile=$zeilen
    printf '\033[%s;1H\033[K' "$zeile"
    printf 'Starte: %s...\n' "${titel_liste[$auswahl]}"
    if ist_gui_befehl "$befehl"; then
        ( eval "$befehl" >/dev/null 2>&1 & )
        fenster_schliessen
    else
        cursor_an
        clear
        eval "$befehl"
    fi
}

fenster_schliessen() {
    if [[ "$OSTYPE" == darwin* ]]; then
        osascript -e 'tell application "Terminal" to close front window' >/dev/null 2>&1 &
    fi
    exit 0
}

EINRUECK="  "
EINRUECK_TITEL=$(( ${#EINRUECK} + 11 ))

# Bei Fenstergrößenänderung (Resize) sofort neu zeichnen
trap 'zeichne_menue' WINCH

cursor_aus
zeichne_menue
while true; do
    IFS= read -rsn1 taste
    case "$taste" in
        $'\x1b')
            # Escape kann Pfeiltasten einleiten: kurz auf Folgebytes warten.
            # Wichtig: ganzzahlige Zeit (macOS-bash 3.2 kann keine Dezimal-Timeouts).
            if read -rsn2 -t 1 rest 2>/dev/null; then
                case "$rest" in
                    '[A')
                        (( auswahl-- ))
                        (( auswahl < 0 )) && (( auswahl = anzahl - 1 ))
                        ;;
                    '[B') (( auswahl = (auswahl + 1) % anzahl )) ;;
                esac
            else
                # ESC allein gedrückt → Menü schließen
                beenden
            fi
            ;;
        "") ausfuehren; exit 0 ;;
        q)  beenden ;;
    esac
    zeichne_menue
done
