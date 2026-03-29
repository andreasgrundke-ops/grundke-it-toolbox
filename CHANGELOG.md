# Changelog — Grundke IT Toolbox

Alle wesentlichen Änderungen werden in dieser Datei dokumentiert.  
Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/).

---

## [2.1.0] — 2026-03-29

### Neu
- GitHub-Veröffentlichung (öffentliches Repository)
- Remote-Catalog-URL standardmäßig auf GitHub-Raw gesetzt
- PC-Aufbereitung: neue Kategorie mit 12 MSP-Aufgaben
  - WinGet installieren / alle Apps aktualisieren
  - Windows Update Cache zurücksetzen
  - Windows Update via PSWindowsUpdate
  - Taskleiste bereinigen (News/Wetter/Suchfeld)
  - Energieplan: Ausbalanciert
  - Laptop-Einstellungen (Netz / Akku)
  - Desktop-PC: kein Sleep/Timeout
  - Bildschirmschoner deaktivieren
  - RDP aktivieren + IP anzeigen
- Copyright-Header in toolbox.ps1
- README.md und CHANGELOG.md hinzugefügt
- MIT-Lizenz hinzugefügt

### Geändert
- Versionsnummer auf 2.1.0 erhöht
- Datum auf 2026-03-29 aktualisiert

---

## [2.0.0] — 2026-03-23

### Neu
- JSON-Katalog (catalog.json) mit 40+ Tools
- WinGet-basierte Installation / Deinstallation
- Remote-Catalog-URL Unterstützung (GitHub raw)
- Chris-Titus-Style: kompakte Karten, automatischer Status-Check
- Per-Card Buttons: Installieren / Deinstallieren / Öffnen
- Web-Tools: nur "Öffnen"-Button, kein Checkbox
- WinGet-Cache beim Start (schnelle Statusprüfung)
- Kategorien: Browser, Kommunikation, Entwicklung, Remote & Admin,
  Sicherheit, Utilities, Medien, Diagnose & Analyse, Web & Downloads
- Chris Titus WinUtil direkt aufrufbar
- Ninite, TeamViewer-Download, grundke-it.de als Web-Shortcuts
- Pfad von C:\Tools auf C:\GIT-Tools umgestellt

### Geändert
- F12-Diktieren Installer-Pfad angepasst
- SplitterDistance-Bug beim Start behoben

---

## [1.2.0] — 2026-03-10

### Neu
- SplitContainer-Layout (Sidebar + Content)
- Status-Badges (farbige Punkte pro Tool)
- Horizontale + vertikale SplitContainer-Verschachtelung

---

## [1.0.0] — 2026-03-01

### Neu
- Initiale Version
- Lokale hartcodierte Tool-Liste
- Grundlegendes WinForms-Fenster
- Manuelle Statusprüfung per Knopf
