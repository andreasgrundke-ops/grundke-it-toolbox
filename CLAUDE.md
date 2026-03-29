# CLAUDE.md – Grundke IT Toolbox

## Projektübersicht

Lokale Windows-Toolbox mit WinForms-GUI, ähnlich wie Chris Titus WinUtil.
Start per Doppelklick auf `start_toolbox.bat` (oder später per PowerShell-Einzeiler).

Geplanter Online-Aufruf:
```powershell
irm "https://grundke-it.de/toolbox.ps1" | iex
```

## Dateien

| Datei | Beschreibung |
|---|---|
| `toolbox.ps1` | Hauptskript – WinForms GUI, alle Tool-Definitionen |
| `start_toolbox.bat` | Launcher – startet PS1 mit Admin-Rechten |

## Tools im Menue (Stand v1.1.0)

### Diktieren & KI
- F12-Diktieren installieren / starten / stoppen

### Windows Optimierung
- ExecutionPolicy setzen
- Telemetrie deaktivieren
- Klassisches Kontextmenue (Win11)
- Taskleiste aufraumen (Win11)

### MSP / Netzwerk
- WinGet alle Apps aktualisieren
- Chocolatey installieren
- Netzwerk-Info anzeigen

### System Info
- System-Zusammenfassung
- GPU-Check (CUDA fuer F12-Diktieren)

## Neues Tool hinzufügen

In `toolbox.ps1` im `$TOOLS`-Array einen neuen Eintrag ergänzen:

```powershell
@{
    Category = "Kategoriename"
    Name     = "Tool-Name"
    Desc     = "Kurzbeschreibung (erscheint unter dem Namen)"
    Check    = { Test-Path "C:\..." }   # $true = gruen (installiert)
    Action   = {
        Write-Log "Mache etwas..."
        # PowerShell-Code hier
        Write-Log "Fertig." "OK"
    }
}
```

## Änderungshistorie

| Version | Datum | Änderung |
|---|---|---|
| 1.0.0 | 2026-03-23 | Initiale Version |
| 1.1.0 | 2026-03-23 | Bugfix Hashtable-Properties, Status-Check je Tool, Cards nach Form.Shown rendern |
