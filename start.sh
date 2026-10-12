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

RESIZE = [False]
AUSWAHL = [0]

AUS = "\033[?25l"
AN = "\033[?25h"
LOESCHEN = "\033[2J\033[3J\033[H"


def fenstergroesse():
    # get_terminal_size liefert (columns, lines) – Spalten zuerst!
    try:
        spalten, zeilen = os.get_terminal_size(0)
    except Exception:
        try:
            spalten, zeilen = os.get_terminal_size(1)
        except Exception:
            spalten, zeilen = 80, 24
    return zeilen, spalten


def ist_gui_befehl(befehl):
    return "open -a" in befehl or "osascript" in befehl


def zeichne_menue(auswahl):
    zeilen, spalten = fenstergroesse()
    start_zeile = 1   # Menü beginnt oben

    breite = max(
        len(TITEL) + len(EINRUECK),
        max(len(t) + len(EINRUECK) + 2 for t in titel_liste),
    )
    start_spalte = (spalten - breite) // 2 + 1 if spalten > breite else 1

    p = [LOESCHEN]
    z = start_zeile
    p.append(f"\033[{z};{start_spalte}H\033[K")
    z += 1
    p.append(f"\033[{z};{start_spalte}H{EINRUECK}\033[1m{TITEL}\033[0m\033[K")
    z += 1
    p.append(f"\033[{z};{start_spalte}H\033[K")
    z += 1
    for i, titel in enumerate(titel_liste):
        if i == auswahl:
            p.append(f"\033[{z};{start_spalte}H{EINRUECK}▸ \033[1m{titel}\033[0m\033[K")
        else:
            p.append(f"\033[{z};{start_spalte}H{EINRUECK}  {titel}\033[K")
        z += 1
    p.append(f"\033[{start_zeile};1H")
    sys.stdout.write("".join(p))
    sys.stdout.flush()


def lies_taste(fd):
    # Auf Eingabe warten und nebenbei auf Fenstergrößenänderung reagieren:
    # Select wacht alle 0,1 s auf, prüft dann das RESIZE-Flag und zeichnet neu.
    while True:
        r, _, _ = select.select([fd], [], [], 0.1)
        if RESIZE[0]:
            RESIZE[0] = False
            zeichne_menue(AUSWAHL[0])
        if r:
            break
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
    fd = sys.stdin.fileno()
    try:
        alt = termios.tcgetattr(fd)
        tty.setcbreak(fd)
    except termios.error:
        alt = None

    import signal

    def bei_resize(sig, frame):
        RESIZE[0] = True

    signal.signal(signal.SIGWINCH, bei_resize)
    AUSWAHL[0] = 0

    sys.stdout.write(AUS)
    sys.stdout.flush()
    zeichne_menue(0)

    while True:
        taste = lies_taste(fd)
        if taste == "\x1b[A":
            AUSWAHL[0] = (AUSWAHL[0] - 1) % ANZAHL
            zeichne_menue(AUSWAHL[0])
        elif taste == "\x1b[B":
            AUSWAHL[0] = (AUSWAHL[0] + 1) % ANZAHL
            zeichne_menue(AUSWAHL[0])
        elif taste in ("\x1b", "q"):
            beenden(fd, alt)
        elif taste in ("", "\r", "\n"):
            break

    befehl = befehl_liste[AUSWAHL[0]]
    zeilen, spalten = fenstergroesse()
    zeile = min(zeilen, ANZAHL + 5)
    sys.stdout.write(f"\033[{zeile};1H\033[KStarte: {titel_liste[AUSWAHL[0]]}...\n")
    sys.stdout.flush()
    if alt is not None:
        termios.tcsetattr(fd, termios.TCSADRAIN, alt)

    if ist_gui_befehl(befehl):
        # GUI-Programm entkoppelt starten (überlebt das Skript) ...
        subprocess.Popen(
            befehl, shell=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        # ... und Terminalfenster sofort schließen
        if sys.platform == "darwin":
            subprocess.run(
                ["osascript", "-e",
                 'tell application "Terminal" to close front window'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
    else:
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()
        os.system(befehl)


main()
PYTHON_ENDE
)" "$CONFIG"
