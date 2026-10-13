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

EINRUECK = "    "
AUS = "\033[?25l"
AN = "\033[?25h"
LOESCHEN = "\033[2J\033[3J\033[H"


def ist_gui_befehl(befehl):
    return "open -a" in befehl or "osascript" in befehl


def zeichne_menue(titel, liste, auswahl):
    p = [LOESCHEN, "\n"]
    p.append(f"{EINRUECK}\033[1m{titel}\033[0m\n")
    p.append("\n")
    for i, e in enumerate(liste):
        if i == auswahl:
            p.append(f"{EINRUECK}\033[1m[{i + 1}] ▸ {e['titel']}\033[0m\n")
        else:
            p.append(f"{EINRUECK}[{i + 1}]   {e['titel']}\n")
    sys.stdout.write("".join(p))
    sys.stdout.flush()


def lies_taste(fd):
    ch = os.read(fd, 1)
    if ch == b"\x1b" and select.select([fd], [], [], 0.02)[0]:
        ch += os.read(fd, 2)
    return ch.decode("utf-8", "surrogateescape")


def auswaehlen(fd, alt, titel, liste):
    # Lässt den Benutzer in einer Liste navigieren; gibt Index zurück.
    # Esc/q: None (zurück bzw. beenden).
    auswahl = 0
    anzahl = len(liste)
    zeichne_menue(titel, liste, auswahl)
    while True:
        taste = lies_taste(fd)
        if taste == "\x1b[A":
            auswahl = (auswahl - 1) % anzahl
            zeichne_menue(titel, liste, auswahl)
        elif taste == "\x1b[B":
            auswahl = (auswahl + 1) % anzahl
            zeichne_menue(titel, liste, auswahl)
        elif taste in ("\x1b", "q"):
            return None
        elif taste in ("", "\r", "\n"):
            return auswahl
        elif taste.isdigit() and 1 <= int(taste) <= anzahl:
            auswahl = int(taste) - 1
            zeichne_menue(titel, liste, auswahl)
            return auswahl


def beenden(fd, alt):
    sys.stdout.write(LOESCHEN + AN)
    sys.stdout.flush()
    if alt is not None:
        termios.tcsetattr(fd, termios.TCSADRAIN, alt)
    sys.exit(0)


def starte_befehl(titel, befehl, fd, alt):
    sys.stdout.write(f"\n{EINRUECK}Starte: {titel}...\n")
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


def main():
    fd = sys.stdin.fileno()
    try:
        alt = termios.tcgetattr(fd)
        tty.setcbreak(fd)
    except termios.error:
        alt = None

    sys.stdout.write(AUS)
    sys.stdout.flush()

    liste = eintraege
    while True:
        index = auswaehlen(fd, alt, "SCHNELLSTART", liste)
        if index is None:
            beenden(fd, alt)
        eintrag = liste[index]
        if "untermenu" in eintrag:
            # Untermenü anzeigen; Esc/q im Untermenü -> zurück zum Hauptmenü
            sub_liste = eintrag["untermenu"]
            while True:
                sub_index = auswaehlen(fd, alt, eintrag["titel"].upper(), sub_liste)
                if sub_index is None:
                    break
                starte_befehl(sub_liste[sub_index]["titel"],
                              sub_liste[sub_index]["befehl"], fd, alt)
                beenden(fd, alt)
            continue
        starte_befehl(eintrag["titel"], eintrag["befehl"], fd, alt)
        beenden(fd, alt)


main()
PYTHON_ENDE
)" "$CONFIG"
