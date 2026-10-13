# schnellstart

Terminal-Schnellstartmenü für macOS.

## Installation

Einzeilig ohne Klon:

```bash
curl -fsSL https://raw.githubusercontent.com/jonathank55/schnellstart/main/install.sh | bash
```

Oder aus dem geklonten Repository:

```bash
git clone https://github.com/jonathank55/schnellstart.git
cd schnellstart && ./install.sh
```

## Benutzung

Neues Terminal-Fenster öffnen und eingeben:

```
start
```

Menü bedienen:

- `↑` / `↓` — Eintrag auswählen
- `1`–`9` — Eintrag direkt per Nummer starten
- `Enter` — ausgewählten Eintrag starten
- `q` oder `Esc` — beenden

## Konfiguration

Die Einträge liegen in `~/.config/schnellstart/config.json`:

```json
{
  "eintraege": [
    { "titel": "Safari", "befehl": "open -a Safari" },
    { "titel": "Windscribe", "befehl": "windscribe-cli" }
  ]
}
```

- `titel`: Anzeigename im Menü
- `befehl`: beliebiger Shell-Befehl; GUI-Programme (`open -a …`) werden entkoppelt gestartet und das Terminal-Fenster schließt sich automatisch

Eine bei der Installation vorhandene Konfiguration wird nicht überschrieben.
