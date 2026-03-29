# Grundke IT Toolbox

> **Lokales MSP-Werkzeug für Windows** — Tools installieren, PC aufbereiten, System-Tweaks anwenden.  
> Entwickelt von [Andreas Grundke | grundke-IT.de](https://grundke-it.de)

---

## Schnellstart (Admin-PowerShell)

```powershell
irm https://raw.githubusercontent.com/andreasgrundke-ops/grundke-it-toolbox/main/toolbox.ps1 | iex
```

Oder kurz über grundke-it.de (HTTPS erforderlich):

```powershell
irm https://grundke-it.de/toolbox | iex
```

---

## Was ist die Grundke IT Toolbox?

Eine PowerShell WinForms-Anwendung im Stil von [Chris Titus WinUtil](https://github.com/ChrisTitusTech/winutil) —
angepasst auf den Alltag eines IT-Dienstleisters / MSPs.

**Kernfunktionen:**

- **WinGet-Katalog** — 40+ Tools direkt installieren/deinstallieren (Browser, Remote, Dev, Security, ...)
- **Status-Erkennung** — Toolbox prüft automatisch was installiert ist (grün/rot)
- **PC-Aufbereitung** — 12 MSP-Aufgaben für Rechner-Refresh auf Knopfdruck
- **Remote-Catalog** — Katalog wird automatisch von GitHub geladen (immer aktuell)
- **Custom-Actions** — Web-Tools öffnen, PowerShell-Befehle ausführen, F12-Diktieren installieren

---

## Kategorien

| Kategorie | Inhalt |
|---|---|
| Grundke IT Tools | F12-Diktieren, eigene Tools |
| Browser | Chrome, Firefox, Edge, Brave, Tor |
| Kommunikation | Teams, Slack, Zoom, Signal, Telegram |
| Entwicklung | VS Code, Git, Python, Node.js, Docker, ... |
| Remote & Admin | TeamViewer, AnyDesk, RustDesk, mRemoteNG, ... |
| Sicherheit | ESET, Bitwarden, Malwarebytes, ... |
| Utilities | 7-Zip, Notepad++, Everything, WinDirStat, ... |
| Medien | VLC, Audacity, OBS, ... |
| Diagnose & Analyse | CrystalDiskInfo, HWiNFO, Wireshark, ... |
| Web & Downloads | Ninite, Chris Titus WinUtil, grundke-it.de |
| **PC-Aufbereitung** | WinGet, Updates, Energie, RDP, Taskleiste, ... |

---

## PC-Aufbereitung (MSP-Workflow)

Spezialkategorie für den schnellen Rechner-Refresh beim Kunden:

- WinGet installieren (falls fehlend)
- Alle Apps aktualisieren (`winget upgrade --all`)
- Windows Update Cache zurücksetzen
- Windows Update via PSWindowsUpdate starten
- Taskleiste bereinigen (News/Wetter/Suchfeld ausblenden)
- Energieplan: Ausbalanciert setzen
- Laptop am Netz: Kein Sleep, kein Bildschirmschoner
- Laptop Akku: 30 Min Bildschirm, 45 Min Sleep
- Desktop-PC: Kein Sleep, kein Timeout (immer per RDP erreichbar)
- Bildschirmschoner deaktivieren
- RDP aktivieren + Firewall + IP anzeigen

---

## Voraussetzungen

- Windows 10 / 11
- PowerShell 5.1+
- WinGet (Windows Package Manager)
- Admin-Rechte empfohlen (für Installation und PC-Aufbereitung)

---

## Lokale Installation

```powershell
git clone https://github.com/andreasgrundke-ops/grundke-it-toolbox.git
cd grundke-it-toolbox
.\start_toolbox.bat
```

---

## Eigenen Katalog verwenden

Die `catalog.json` kann lokal angepasst oder per Remote-URL bereitgestellt werden.  
Format: siehe [catalog.json](catalog.json)

```powershell
# In toolbox.ps1 anpassen:
$REMOTE_CATALOG_URL = "https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/catalog.json"
```

---

## Lizenz

MIT License — Copyright (c) 2026 Andreas Grundke, [grundke-IT.de](https://grundke-it.de)  
Siehe [LICENSE](LICENSE)

---

## Autor

**Andreas Grundke**  
IT-Dienstleister & MSP | Raum München, Bayern  
🌐 [grundke-it.de](https://grundke-it.de) · ✉️ info@grundke-it.de
