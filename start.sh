#!/bin/bash
# SCHNELLSTART – Einfaches Terminal-Schnellstartmenü für macOS
# Aufruf: start

CONFIG="$HOME/.config/schnellstart/config.json"
[[ -f "$CONFIG" ]] || CONFIG="$(cd "$(dirname "$0")" && pwd)/config.json"

if [[ ! -f "$CONFIG" ]]; then
    echo "Fehler: Konfigurationsdatei nicht gefunden."
    echo "Bitte zuerst install.sh ausführen."
    read -r -p "Taste zum Beenden drücken..."
    exit 1
fi

exec python3 -c "$(cat <<'PYTHON_ENDE'
import json, os, sys, select, tty, termios, subprocess

CONFIG = sys.argv[1]

with open(CONFIG) as f:
    eintraege = json.load(f).get("eintraege", [])

if not eintraege:
    print("Fehler: Keine Einträge in der Konfigurationsdatei gefunden.")
    input("Taste zum Beenden drücken...")
    sys.exit(1)

titel_liste = [e["titel"] for e in eintraege]
befehl_liste = [e["befehl"] for e in eintraege]
ANZAHL = len(titel_liste)

EINRUECK = "    "
TITEL = "SCHNELLSTART"

AUS = "\033[?25l"
AN = "\033[?25h"
LOESCHEN = "\033[2J\033[3J\033[H"

auswahl = 0


def ist_gui_befehl(befehl):
    return "open -a" in befehl or "osascript" in befehl


def zeichne_menue():
    # Statisches Menü: fester Abstand links, Überschrift oben.
    # Alles in einem Schreibvorgang -> kein Flackern.
    p = [LOESCHEN, "\n"]
    p.append(f"{EINRUECK}\033[1m{TITEL}\033[0m\n")
    p.append("\n")
    for i, titel in enumerate(titel_liste):
        if i == auswahl:
            p.append(f"{EINRUECK}\033[1m[{i + 1}] ▸ {titel}\033[0m\n")
        else:
            p.append(f"{EINRUECK}[{i + 1}]   {titel}\n")
    sys.stdout.write("".join(p))
    sys.stdout.flush()


def lies_taste(fd):
    ch = os.read(fd, 1)
    if ch == b"\x1b" and select.select([fd], [], [], 0.02)[0]:
        ch += os.read(fd, 2)
    return ch.decode("utf-8", "surrogateescape")


def beenden(fd, alt):
    sys.stdout.write(LOESCHEN + AN)
    sys.stdout.flush()
    if alt is not None:
        termios.tcsetattr(fd, termios.TCSADRAIN, alt)
    sys.exit(0)


def main():
    global auswahl
    fd = sys.stdin.fileno()
    try:
        alt = termios.tcgetattr(fd)
        tty.setcbreak(fd)
    except termios.error:
        alt = None

    sys.stdout.write(AUS)
    sys.stdout.flush()
    zeichne_menue()

    while True:
        taste = lies_taste(fd)
        if taste == "\x1b[A":
            auswahl = (auswahl - 1) % ANZAHL
            zeichne_menue()
        elif taste == "\x1b[B":
            auswahl = (auswahl + 1) % ANZAHL
            zeichne_menue()
        elif taste in ("\x1b", "q"):
            beenden(fd, alt)
        elif taste in ("", "\r", "\n"):
            break
        elif taste.isdigit() and 1 <= int(taste) <= ANZAHL:
            # Nummertaste: Eintrag direkt auswählen und starten
            auswahl = int(taste) - 1
            zeichne_menue()
            break

    befehl = befehl_liste[auswahl]
    sys.stdout.write(f"\n{EINRUECK}Starte: {titel_liste[auswahl]}...\n")
    sys.stdout.flush()
    if alt is not None:
        termios.tcsetattr(fd, termios.TCSADRAIN, alt)

    if ist_gui_befehl(befehl):
        # App entkoppelt starten (überlebt das Skript und das Terminal) ...
        subprocess.Popen(
            befehl, shell=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        if sys.platform == "darwin":
            # Fenster-Schließen zeitversetzt anstoßen und SOFORT beenden:
            # wenn der Helper zuschlägt, ist dieser Prozess schon weg,
            # Terminal sieht also keinen laufenden Prozess mehr und
            # schließt das Fenster ohne Nachfrage.
            subprocess.Popen(
                ["sh", "-c",
                 "sleep 0.2; "
                 "osascript -e 'tell application \"Terminal\" "
                 "to close front window' >/dev/null 2>&1"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
    else:
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()
        os.system(befehl)


main()
PYTHON_ENDE
)" "$CONFIG"
