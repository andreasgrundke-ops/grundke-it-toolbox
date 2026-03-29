# =============================================================================
#   Titel       : Grundke IT Toolbox
#   Version     : 2.1.1
#   Autor       : Andreas Grundke | grundke-IT.de
#   Datum       : 2026-03-29
#   Lizenz      : MIT License - Copyright (c) 2026 Andreas Grundke, grundke-IT.de
#   GitHub      : https://github.com/andreasgrundke-ops/grundke-it-toolbox
#   Beschreibung: WinForms-Toolbox zur Installation und Verwaltung von Tools.
#                 - JSON-Katalog (lokal + optional remote wie Chris Titus WinUtil)
#                 - WinGet-basierte Installation / Deinstallation
#                 - Custom-Actions fuer spezielle Tools (F12-Diktieren etc.)
#                 - Windows-Tweaks als integrierte Skriptbloecke
#                 - PC-Aufbereitung: 12 MSP-Aufgaben fuer Rechner-Refresh
#   Aufruf      : irm https://grundke-it.de/toolbox | iex
#                 (alternativ: irm https://raw.githubusercontent.com/andreasgrundke-ops/grundke-it-toolbox/main/toolbox.ps1 | iex)
#   Aenderungen : 1.0.0 - Initiale Version (lokal, hartcodierte Tools)
#                 1.2.0 - SplitContainer Layout, Status-Badges
#                 2.0.0 - Catalog-JSON, WinGet-Integration, GIT-Tools Pfad
#                 2.1.0 - GitHub-Veroeffentlichung, Remote-Catalog-URL gesetzt,
#                         PC-Aufbereitung Kategorie (12 Tools), Copyright
#                 2.1.1 - Kurzaufruf-URL auf HTTPS korrigiert (IONOS HTTP-Redirect
#                         entfernt Pfad; grundke-it.de/toolbox → https:// notwendig)
# =============================================================================

#Requires -Version 5.1

# ---------------------------------------------------------------------------
# Admin-Selbstelevation
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList (
        "-ExecutionPolicy Bypass -File `"$PSCommandPath`"") -WindowStyle Normal
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------------------
# CI-Farben (grundke-IT.de Corporate Identity)
# ---------------------------------------------------------------------------
$CI_BLUE      = [System.Drawing.Color]::FromArgb(12,  77,  162)
$CI_BLUE_DARK = [System.Drawing.Color]::FromArgb(8,   50,  110)
$CI_CYAN      = [System.Drawing.Color]::FromArgb(38, 189, 239)
$CI_WHITE     = [System.Drawing.Color]::White
$CI_LIGHT     = [System.Drawing.Color]::FromArgb(244, 247, 252)
$CI_DARK      = [System.Drawing.Color]::FromArgb(17,  17,  17)
$CI_GRAY      = [System.Drawing.Color]::FromArgb(104, 104, 104)
$CI_BORDER    = [System.Drawing.Color]::FromArgb(208, 218, 234)
$CI_OK_BG     = [System.Drawing.Color]::FromArgb(230, 248, 240)
$CI_OK_FG     = [System.Drawing.Color]::FromArgb(26,  122,  94)
$CI_WARN_FG   = [System.Drawing.Color]::FromArgb(180,  90,   0)
$CI_LOG_BG    = [System.Drawing.Color]::FromArgb(15,  20,  35)

# Schriften
$FT = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$FB = New-Object System.Drawing.Font("Segoe UI",  9, [System.Drawing.FontStyle]::Bold)
$FN = New-Object System.Drawing.Font("Segoe UI",  9)
$FS = New-Object System.Drawing.Font("Segoe UI",  8)
$FM = New-Object System.Drawing.Font("Consolas",  9)
$FI = New-Object System.Drawing.Font("Segoe UI",  7)  # WinGet-ID klein

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
$GIT_TOOLS_BASE = "C:\GIT-Tools"
# Remote-Catalog-URL (GitHub raw) - wird automatisch geladen wenn erreichbar
$REMOTE_CATALOG_URL = "https://raw.githubusercontent.com/andreasgrundke-ops/grundke-it-toolbox/main/catalog.json"
$CATALOG_PATH = Join-Path $PSScriptRoot "catalog.json"

# ---------------------------------------------------------------------------
# Catalog laden: 1. Remote  2. Lokale JSON  3. Interner Fallback
# ---------------------------------------------------------------------------
$script:CatalogSource = "intern"
$catalogTools = @()

# Versuch: Remote-Catalog laden
if ($REMOTE_CATALOG_URL -ne "") {
    try {
        $web = Invoke-WebRequest -Uri $REMOTE_CATALOG_URL -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $remote = $web.Content | ConvertFrom-Json
        $catalogTools = $remote.tools
        $script:CatalogSource = "remote v$($remote.version)"
    } catch { }
}

# Versuch: Lokale catalog.json
if ($catalogTools.Count -eq 0 -and (Test-Path $CATALOG_PATH)) {
    try {
        $local = Get-Content $CATALOG_PATH -Raw | ConvertFrom-Json
        $catalogTools = $local.tools
        $script:CatalogSource = "lokal v$($local.version)"
    } catch { }
}

# ---------------------------------------------------------------------------
# WinGet-Cache: einmalig alle installierten Pakete laden (schnelle Checks)
# ---------------------------------------------------------------------------
$script:WingetLines = @()
$script:WingetAvailable = $false
try {
    $wgTest = & winget --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $script:WingetLines = & winget list --accept-source-agreements 2>&1
        $script:WingetAvailable = $true
    }
} catch { }

function Test-WingetInstalled {
    param([string]$id)
    if (-not $script:WingetAvailable) { return $false }
    $escaped = [regex]::Escape($id)
    return ($script:WingetLines | Where-Object { $_ -match $escaped }) -ne $null
}

function Update-WingetCache {
    if (-not $script:WingetAvailable) { return }
    $script:WingetLines = & winget list --accept-source-agreements 2>&1
}

# ---------------------------------------------------------------------------
# Tool-Status pruefen (unabhaengig von WinGet-Cache)
# ---------------------------------------------------------------------------
function Get-ToolStatus {
    param($tool)
    try {
        switch ($tool['checkType']) {
            "winget"  { return Test-WingetInstalled $tool['checkValue'] }
            "path"    { return Test-Path $tool['checkValue'] }
            "process" { return (Get-Process $tool['checkValue'] -EA SilentlyContinue) -ne $null }
            "tweak"   { return (& $tool['Check']) }
            default   { return $false }
        }
    } catch { return $false }
}

# ---------------------------------------------------------------------------
# WinGet-Installation / Deinstallation
# ---------------------------------------------------------------------------
function Install-ViaPM {
    param($tool)
    $name = $tool['Name']
    $wid  = $tool['wingetId']

    # WinGet-Installation
    if ($wid) {
        Write-Log "Installiere via WinGet: $name ($wid) ..."
        $out = & winget install --id $wid --silent --accept-package-agreements --accept-source-agreements 2>&1
        $out | ForEach-Object { Write-Log "  $_" }
        if ($LASTEXITCODE -eq 0) { Write-Log "$name erfolgreich installiert." "OK" }
        else { Write-Log "$name - WinGet Exitcode: $LASTEXITCODE" "WARN" }
        Update-WingetCache
        return
    }

    # URL im Browser oeffnen (Ninite, TeamViewer, grundke-it.de, ...)
    if ($tool['customAction'] -eq 'open-url') {
        $url = [string]$tool['customData']
        Write-Log "Oeffne im Browser: $url"
        Start-Process $url
        Write-Log "$name - Browser wird geoeffnet." "OK"
        return
    }

    # PowerShell-Befehl in neuem Admin-Fenster starten (Chris Titus WinUtil, ...)
    if ($tool['customAction'] -eq 'run-ps') {
        $cmd     = [string]$tool['customData']
        $bytes   = [System.Text.Encoding]::Unicode.GetBytes($cmd)
        $encoded = [Convert]::ToBase64String($bytes)
        Write-Log "Starte in Admin-PS: $cmd"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-EncodedCommand $encoded"
        Write-Log "$name - Admin-Fenster geoeffnet." "OK"
        return
    }

    # Sonstiger Custom-Scriptblock (z.B. F12-Diktieren, Tweaks)
    $action = $tool['Action']
    if ($action) { & $action }
    else { Write-Log "Kein Install-Mechanismus fuer: $name" "WARN" }
}

function Uninstall-ViaPM {
    param($tool)
    $name = $tool['Name']
    $wid  = $tool['wingetId']
    if ($wid) {
        Write-Log "Deinstalliere via WinGet: $name ($wid) ..."
        $out = & winget uninstall --id $wid --silent --accept-source-agreements 2>&1
        $out | ForEach-Object { Write-Log "  $_" }
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$name erfolgreich deinstalliert." "OK"
        } else {
            Write-Log "$name - WinGet Exitcode: $LASTEXITCODE" "WARN"
        }
        Update-WingetCache
        return
    }
    Write-Log "Deinstallation nur via WinGet moeglich. Kein WinGet-ID fuer: $name" "WARN"
}

# ---------------------------------------------------------------------------
# Catalog-Tools in $TOOLS-Hashtable umwandeln
# ---------------------------------------------------------------------------
$TOOLS = @()

foreach ($t in $catalogTools) {
    $entry = @{
        Category     = $t.category
        Name         = $t.name
        Desc         = $t.desc
        wingetId     = $t.wingetId
        checkType    = $t.checkType
        checkValue   = $t.checkValue
        customAction = $t.customAction
        customData   = $t.customData   # URL oder PS-Befehl fuer open-url / run-ps
    }
    # Fuer Custom-Actions: Action-Scriptblock zur Laufzeit erzeugen
    if ($t.customAction -eq "f12-install") {
        $entry['Action'] = {
            $insSource   = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\F12-Diktieren\installer.ps1"))
            $insFallback = "$GIT_TOOLS_BASE\F12-Diktieren\installer.ps1"
            $ins = if (Test-Path $insSource) { $insSource } elseif (Test-Path $insFallback) { $insFallback } else { $null }
            if ($ins) {
                Write-Log "Starte F12-Diktieren Installer: $ins"
                Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ins`"" -Wait
                Update-WingetCache
                Write-Log "F12-Diktieren Installer abgeschlossen." "OK"
            } else {
                Write-Log "installer.ps1 nicht gefunden!" "ERR"
                Write-Log "Erwartet: $insSource" "WARN"
            }
        }
    }
    # open-url und run-ps werden direkt in Install-ViaPM behandelt (kein Scriptblock noetig)
    $TOOLS += $entry
}

# ---------------------------------------------------------------------------
# Windows-Tweaks und System-Tools als integrierte PS-Entries
# ---------------------------------------------------------------------------
$TOOLS += @{
    Category   = "Windows Tweaks"
    Name       = "Klassisches Kontextmenue (Win11)"
    Desc       = "Stellt das vollstaendige Rechtsklick-Menue in Windows 11 wieder her."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { Test-Path "HKCU:\SOFTWARE\CLASSES\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" }
    Action     = {
        $rp = "HKCU:\SOFTWARE\CLASSES\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        New-Item $rp -Force | Out-Null
        Set-ItemProperty $rp "(Default)" "" -Force
        Stop-Process -Name explorer -Force -EA SilentlyContinue
        Write-Log "Klassisches Kontextmenue aktiv." "OK"
    }
}
$TOOLS += @{
    Category   = "Windows Tweaks"
    Name       = "Taskleiste aufraemen (Win11)"
    Desc       = "Entfernt Aufgaben-Ansicht, Widgets und Chat-Icon aus der Taskleiste."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = {
        $v = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -EA SilentlyContinue).ShowTaskViewButton
        $v -eq 0
    }
    Action     = {
        $rp = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty $rp "ShowTaskViewButton" 0 -Type DWord -Force
        Set-ItemProperty $rp "TaskbarDa" 0 -Type DWord -Force -EA SilentlyContinue
        Set-ItemProperty $rp "TaskbarMn" 0 -Type DWord -Force -EA SilentlyContinue
        Stop-Process -Name explorer -Force -EA SilentlyContinue
        Write-Log "Taskleiste bereinigt." "OK"
    }
}

$TOOLS += @{
    Category   = "MSP / Netzwerk"
    Name       = "WinGet - Alle Apps aktualisieren"
    Desc       = "Aktualisiert alle installierten Apps via WinGet (silent)."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { (Get-Command winget -EA SilentlyContinue) -ne $null }
    Action     = {
        Write-Log "WinGet-Update laeuft (kann einige Minuten dauern) ..."
        & winget upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1 |
            ForEach-Object { Write-Log "  $_" }
        Update-WingetCache
        Write-Log "WinGet-Update abgeschlossen." "OK"
    }
}
$TOOLS += @{
    Category   = "MSP / Netzwerk"
    Name       = "Chocolatey installieren"
    Desc       = "Installiert den Chocolatey Package Manager (alternative zu WinGet)."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { (Get-Command choco -EA SilentlyContinue) -ne $null }
    Action     = {
        if (Get-Command choco -EA SilentlyContinue) { Write-Log "Chocolatey bereits installiert." "OK"; return }
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installiert." "OK"
    }
}
$TOOLS += @{
    Category   = "MSP / Netzwerk"
    Name       = "Netzwerk-Info anzeigen"
    Desc       = "Zeigt IP, Gateway und DNS aller aktiven Netzwerkadapter."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        Get-NetIPConfiguration | Where-Object { $_.IPv4Address } | ForEach-Object {
            Write-Log "Adapter : $($_.InterfaceAlias)"
            Write-Log "  IPv4  : $($_.IPv4Address.IPAddress)"
            Write-Log "  GW    : $($_.IPv4DefaultGateway.NextHop)"
            Write-Log "  DNS   : $($_.DNSServer.ServerAddresses -join ', ')"
        }
        Write-Log "--- Ende ---" "OK"
    }
}
$TOOLS += @{
    Category   = "System Info"
    Name       = "System-Zusammenfassung"
    Desc       = "Zeigt OS, CPU, RAM, Festplatten und Aktivierungsstatus."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        $os  = Get-CimInstance Win32_OperatingSystem
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
        Write-Log "OS    : $($os.Caption) ($($os.OSArchitecture))"
        Write-Log "Build : $($os.BuildNumber)"
        Write-Log "CPU   : $cpu"
        Write-Log "RAM   : $([math]::Round($os.TotalVisibleMemorySize/1MB,1)) GB"
        Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used } | ForEach-Object {
            Write-Log "Disk $($_.Name): $([math]::Round($_.Free/1GB,1)) GB frei / $([math]::Round(($_.Used+$_.Free)/1GB,1)) GB"
        }
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%' AND LicenseStatus=1" -EA SilentlyContinue
        if ($lic) { Write-Log "Lizenz: Aktiviert" "OK" } else { Write-Log "Lizenz: NICHT aktiviert" "WARN" }
    }
}
$TOOLS += @{
    Category   = "System Info"
    Name       = "GPU-Check (CUDA)"
    Desc       = "Prueft ob NVIDIA-GPU mit CUDA vorhanden ist (relevant fuer F12-Diktieren)."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        Get-CimInstance Win32_VideoController | ForEach-Object {
            Write-Log "GPU: $($_.Name) | VRAM: $([math]::Round($_.AdapterRAM/1GB,1)) GB"
        }
        $null = & nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Log "CUDA verfuegbar -> Modell-Empfehlung: medium" "OK" }
        else { Write-Log "Kein CUDA -> Modell: small (CPU-Betrieb genuegt)" "WARN" }
    }
}

# ===========================================================================
# PC-AUFBEREITUNG – Kategorie fuer Rechner-Refresh, Neueinrichtung, MSP-Setup
# ===========================================================================
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "WinGet installieren"
    Desc       = "Installiert WinGet (App Installer) falls nicht vorhanden. Voraussetzung fuer alle WinGet-Tools."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { (Get-Command winget -EA SilentlyContinue) -ne $null }
    Action     = {
        if (Get-Command winget -EA SilentlyContinue) { Write-Log "WinGet ist bereits installiert." "OK"; return }
        Write-Log "Versuche App Installer zu registrieren..."
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -EA Stop
            Write-Log "WinGet registriert. Toolbox neu starten!" "OK"
        } catch {
            Write-Log "App Installer nicht gefunden - lade von GitHub..." "WARN"
            $rel = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
            $url = ($rel.assets | Where-Object { $_.name -match "msixbundle" } | Select-Object -First 1).browser_download_url
            $tmp = "$env:TEMP\winget.msixbundle"
            Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
            Add-AppxPackage $tmp
            Write-Log "WinGet installiert. Bitte Toolbox neu starten." "OK"
        }
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Alle Apps aktualisieren (WinGet)"
    Desc       = "Aktualisiert ALLE installierten Anwendungen via WinGet - silent, ohne Rueckfragen."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        if (-not (Get-Command winget -EA SilentlyContinue)) { Write-Log "WinGet nicht gefunden!" "ERR"; return }
        Write-Log "WinGet-Upgrade --all laeuft (kann Minuten dauern)..."
        & winget upgrade --all --silent --accept-source-agreements --accept-package-agreements --include-unknown 2>&1 |
            ForEach-Object { Write-Log "  $_" }
        Update-WingetCache
        Write-Log "Alle Apps aktualisiert." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Windows Update Cache zuruecksetzen"
    Desc       = "Behebt defekte Windows Updates: stoppt Dienste, benennt SoftwareDistribution + catroot2 um, startet neu."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        Write-Log "Stoppe Windows Update Dienste..."
        Stop-Service wuauserv, bits, cryptsvc, msiserver -Force -EA SilentlyContinue
        $ts  = Get-Date -Format 'yyyyMMdd-HHmm'
        $sd  = "C:\Windows\SoftwareDistribution"
        $cr2 = "C:\Windows\System32\catroot2"
        if (Test-Path $sd)  { Rename-Item $sd  "$sd.bak.$ts"  -Force -EA SilentlyContinue; Write-Log "SoftwareDistribution umbenannt." "OK" }
        if (Test-Path $cr2) { Rename-Item $cr2 "$cr2.bak.$ts" -Force -EA SilentlyContinue; Write-Log "catroot2 umbenannt." "OK" }
        Start-Service wuauserv, bits, cryptsvc, msiserver -EA SilentlyContinue
        Write-Log "Cache zurueckgesetzt. Windows Update jetzt erneut starten." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Windows Update - Alle Updates installieren"
    Desc       = "Startet PSWindowsUpdate (Modul wird auto-installiert) in neuem Admin-Fenster. Zeigt alle Updates an."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        $cmd = 'Write-Host "=== Windows Update ===" -ForegroundColor Cyan; ' +
               'if (-not (Get-Module -ListAvailable PSWindowsUpdate -EA SilentlyContinue)) { ' +
               '  Write-Host "Installiere PSWindowsUpdate..." -ForegroundColor Yellow; ' +
               '  Install-Module PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber }; ' +
               'Import-Module PSWindowsUpdate -Force; ' +
               'Write-Host "Suche nach Updates..." -ForegroundColor Cyan; ' +
               'Get-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose; ' +
               'Write-Host "Fertig! Bitte neu starten wenn noetig." -ForegroundColor Green; pause'
        $bytes   = [System.Text.Encoding]::Unicode.GetBytes($cmd)
        $encoded = [Convert]::ToBase64String($bytes)
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-EncodedCommand $encoded"
        Write-Log "Windows Update Fenster geoeffnet - Admin-Bestaetigung noetig." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Taskleiste: News, Wetter + Suche ausblenden"
    Desc       = "Blendet Nachrichten/Wetter und Suchfeld aus der Taskleiste aus (Win10/11). Explorer wird neu gestartet."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = {
        $s = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -EA SilentlyContinue).SearchboxTaskbarMode
        $s -eq 0 -or $s -eq 1
    }
    Action     = {
        # News + Interessen (Win10)
        $fp = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds"
        if (-not (Test-Path $fp)) { New-Item $fp -Force | Out-Null }
        Set-ItemProperty $fp "ShellFeedsTaskbarViewMode" 2 -Type DWord -Force
        # Suchfeld -> nur Icon (1) oder ausgeblendet (0)
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1 -Type DWord -Force
        # Taskansicht ausblenden
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 -Type DWord -Force
        # Widgets (Win11)
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0 -Type DWord -Force -EA SilentlyContinue
        Stop-Process -Name explorer -Force -EA SilentlyContinue
        Write-Log "Taskleiste bereinigt. Explorer neu gestartet." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Energieplan: Ausbalanciert aktivieren"
    Desc       = "Setzt den Windows-Energieplan auf 'Ausbalanciert' (empfohlen fuer die meisten Geraete)."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = {
        $active = & powercfg /getactivescheme 2>&1
        $active -match "381b4222-f694-41f0-9685-ff5bb260df2e"
    }
    Action     = {
        & powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
        $plan = & powercfg /getactivescheme 2>&1
        Write-Log "Energieplan: $plan" "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Zuklappen-Einstellungen oeffnen"
    Desc       = "Oeffnet die Systemsteuerung fuer Deckel/Netzschalter-Aktionen. Dort manuell einstellen."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        Start-Process "control.exe" -ArgumentList "/name Microsoft.PowerOptions /page pageGlobalSettings"
        Write-Log "Zuklappen-Einstellungen geoeffnet." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Laptop am Netz: Immer an (kein Sleep, kein Schirm-Aus)"
    Desc       = "Netz-Profil: Bildschirm/Sleep/Hibernate niemals. Zuklappen = nichts tun. Ideal fuer Fernwartung."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        # Bildschirm, Ruhezustand, Hibernate - niemals (AC)
        & powercfg /change monitor-timeout-ac 0
        & powercfg /change standby-timeout-ac 0
        & powercfg /change hibernate-timeout-ac 0
        # Zuklappen (AC) = 0 = Nichts tun
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
        & powercfg /SETACTIVE SCHEME_CURRENT
        Write-Log "Laptop (Netz): Bildschirm/Sleep/Zuklappen auf Niemals gesetzt." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Laptop Akku (mobil): 30 Min Schirm / 45 Min Sleep"
    Desc       = "Akku-Profil: Bildschirm nach 30 Min aus, Ruhezustand nach 45 Min. Schont den Akku unterwegs."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        & powercfg /change monitor-timeout-dc 30
        & powercfg /change standby-timeout-dc 45
        & powercfg /change hibernate-timeout-dc 60
        & powercfg /SETACTIVE SCHEME_CURRENT
        Write-Log "Laptop (Akku): Bildschirm 30 Min, Sleep 45 Min, Hibernate 60 Min." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Desktop-PC: Immer erreichbar (kein Sleep, kein Schirm-Aus)"
    Desc       = "Desktop-Profil: Bildschirm/Sleep/Hibernate fuer Netz UND Akku niemals. Ideal fuer Server-PCs."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = { $false }
    Action     = {
        foreach ($mode in @("ac","dc")) {
            & powercfg /change "monitor-timeout-$mode" 0
            & powercfg /change "standby-timeout-$mode" 0
            & powercfg /change "hibernate-timeout-$mode" 0
        }
        & powercfg /SETACTIVE SCHEME_CURRENT
        Write-Log "Desktop-PC: Bildschirm/Sleep vollstaendig deaktiviert." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "Bildschirmschoner deaktivieren"
    Desc       = "Deaktiviert den Bildschirmschoner komplett via Registry fuer den aktuellen Benutzer."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = {
        $v = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -EA SilentlyContinue).ScreenSaveActive
        $v -eq "0" -or $v -eq 0
    }
    Action     = {
        $rp = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty $rp "ScreenSaveActive"    "0" -Type String -Force
        Set-ItemProperty $rp "ScreenSaverIsSecure" "0" -Type String -Force
        Set-ItemProperty $rp "SCRNSAVE.EXE"         "" -Type String -Force -EA SilentlyContinue
        Write-Log "Bildschirmschoner deaktiviert." "OK"
    }
}
$TOOLS += @{
    Category   = "PC-Aufbereitung"
    Name       = "RDP Fernzugriff aktivieren"
    Desc       = "Aktiviert Remote Desktop (RDP) und oeffnet die Firewall. Rechner dann per IP/Name erreichbar."
    wingetId   = $null
    checkType  = "tweak"
    checkValue = $null
    Check      = {
        $v = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -EA SilentlyContinue).fDenyTSConnections
        $v -eq 0
    }
    Action     = {
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -Type DWord -Force
        Enable-NetFirewallRule -DisplayGroup "Remotedesktop" -EA SilentlyContinue
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
        Write-Log "RDP aktiviert. IP-Adresse: $ip" "OK"
        Write-Log "Verbinden: mstsc /v:$ip" "OK"
    }
}

$CATEGORIES = $TOOLS | ForEach-Object { $_['Category'] } | Sort-Object -Unique

# ---------------------------------------------------------------------------
# GUI: Hauptfenster
# ---------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Grundke IT Toolbox v2.0.0"
$form.Size          = New-Object System.Drawing.Size(1100, 740)
$form.MinimumSize   = New-Object System.Drawing.Size(800, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor     = $CI_WHITE
$form.Font          = $FN

# ---- Header (Dock=Top) ---------------------------------------------------
$pnlHdr = New-Object System.Windows.Forms.Panel
$pnlHdr.Dock = "Top"; $pnlHdr.Height = 60; $pnlHdr.BackColor = $CI_BLUE

$lbTitle = New-Object System.Windows.Forms.Label
$lbTitle.Text = "  Grundke IT Toolbox"; $lbTitle.Font = $FT
$lbTitle.ForeColor = $CI_WHITE; $lbTitle.AutoSize = $false
$lbTitle.Size = New-Object System.Drawing.Size(600, 36)
$lbTitle.Location = New-Object System.Drawing.Point(0, 4); $lbTitle.TextAlign = "MiddleLeft"

$lbSub = New-Object System.Windows.Forms.Label
$lbSub.Text = "  v2.0  |  grundke-it.de  |  Catalog: wird geladen..."
$lbSub.Font = $FS; $lbSub.ForeColor = [System.Drawing.Color]::FromArgb(180, 210, 240)
$lbSub.AutoSize = $false; $lbSub.Size = New-Object System.Drawing.Size(800, 18)
$lbSub.Location = New-Object System.Drawing.Point(0, 42)
$pnlHdr.Controls.AddRange(@($lbTitle, $lbSub))

$pnlAccent = New-Object System.Windows.Forms.Panel
$pnlAccent.Dock = "Top"; $pnlAccent.Height = 3; $pnlAccent.BackColor = $CI_CYAN

# ---- Button-Leiste (Dock=Bottom) -----------------------------------------
$pnlBtn = New-Object System.Windows.Forms.Panel
$pnlBtn.Dock = "Bottom"; $pnlBtn.Height = 50
$pnlBtn.BackColor = $CI_LIGHT; $pnlBtn.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Ausgewaehlt installieren"; $btnInstall.Font = $FN
$btnInstall.BackColor = $CI_BLUE; $btnInstall.ForeColor = $CI_WHITE
$btnInstall.FlatStyle = "Flat"; $btnInstall.FlatAppearance.BorderSize = 0
$btnInstall.Size = New-Object System.Drawing.Size(190, 32); $btnInstall.Location = New-Object System.Drawing.Point(10, 9); $btnInstall.Cursor = "Hand"

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Ausgewaehlt deinstall."; $btnUninstall.Font = $FN
$btnUninstall.BackColor = [System.Drawing.Color]::FromArgb(160, 50, 20); $btnUninstall.ForeColor = $CI_WHITE
$btnUninstall.FlatStyle = "Flat"; $btnUninstall.FlatAppearance.BorderSize = 0
$btnUninstall.Size = New-Object System.Drawing.Size(170, 32); $btnUninstall.Location = New-Object System.Drawing.Point(208, 9); $btnUninstall.Cursor = "Hand"

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Status aktualisieren"; $btnCheck.Font = $FN
$btnCheck.BackColor = $CI_LIGHT; $btnCheck.ForeColor = $CI_DARK
$btnCheck.FlatStyle = "Flat"; $btnCheck.FlatAppearance.BorderColor = $CI_BORDER
$btnCheck.Size = New-Object System.Drawing.Size(160, 32); $btnCheck.Location = New-Object System.Drawing.Point(386, 9); $btnCheck.Cursor = "Hand"

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Log leeren"; $btnClear.Font = $FN
$btnClear.BackColor = $CI_LIGHT; $btnClear.ForeColor = $CI_DARK
$btnClear.FlatStyle = "Flat"; $btnClear.FlatAppearance.BorderColor = $CI_BORDER
$btnClear.Size = New-Object System.Drawing.Size(100, 32); $btnClear.Location = New-Object System.Drawing.Point(554, 9); $btnClear.Cursor = "Hand"

$lbSel = New-Object System.Windows.Forms.Label
$lbSel.Text = "0 ausgewaehlt"; $lbSel.Font = $FS; $lbSel.ForeColor = $CI_GRAY
$lbSel.AutoSize = $true; $lbSel.Location = New-Object System.Drawing.Point(665, 18)
$pnlBtn.Controls.AddRange(@($btnInstall, $btnUninstall, $btnCheck, $btnClear, $lbSel))

# ---- Outer SplitContainer (Horizontal: oben=Kategorien+Tools, unten=Log) -
$splitOuter = New-Object System.Windows.Forms.SplitContainer
$splitOuter.Dock              = "Fill"
$splitOuter.Orientation       = [System.Windows.Forms.Orientation]::Horizontal
$splitOuter.SplitterWidth     = 4
$splitOuter.BackColor         = $CI_BORDER
$splitOuter.Panel1.BackColor  = $CI_WHITE
$splitOuter.Panel2.BackColor  = $CI_LOG_BG

# ---- Log-Bereich (Panel2 des Outer-Splits) --------------------------------
$lbLogHdr = New-Object System.Windows.Forms.Label
$lbLogHdr.Text = "  Ausgabe / Log"; $lbLogHdr.Font = $FB
$lbLogHdr.ForeColor = $CI_WHITE; $lbLogHdr.BackColor = $CI_BLUE_DARK
$lbLogHdr.Dock = "Top"; $lbLogHdr.Height = 24; $lbLogHdr.TextAlign = "MiddleLeft"

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Dock = "Fill"; $txtLog.ReadOnly = $true
$txtLog.BackColor = $CI_LOG_BG
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 245)
$txtLog.Font = $FM; $txtLog.BorderStyle = "None"; $txtLog.ScrollBars = "Vertical"
$splitOuter.Panel2.Controls.Add($txtLog)
$splitOuter.Panel2.Controls.Add($lbLogHdr)
$script:LogBox = $txtLog

# ---- Inner SplitContainer (Vertical: links=Kategorien, rechts=Tools) -----
$splitInner = New-Object System.Windows.Forms.SplitContainer
$splitInner.Dock              = "Fill"
$splitInner.Orientation       = [System.Windows.Forms.Orientation]::Vertical
$splitInner.SplitterWidth     = 4
$splitInner.BackColor         = $CI_BORDER
$splitInner.Panel1.BackColor  = $CI_LIGHT
$splitInner.Panel1MinSize     = 140
# Panel2MinSize bewusst nicht gesetzt - Default (25px) genuegt, kein Exception beim Init

# ---- Kategorie-Liste (links) ---------------------------------------------
$lbCatHdr = New-Object System.Windows.Forms.Label
$lbCatHdr.Text = "  Kategorien"; $lbCatHdr.Font = $FB
$lbCatHdr.ForeColor = $CI_WHITE; $lbCatHdr.BackColor = $CI_BLUE
$lbCatHdr.Dock = "Top"; $lbCatHdr.Height = 28; $lbCatHdr.TextAlign = "MiddleLeft"

$lstCat = New-Object System.Windows.Forms.ListBox
$lstCat.Dock = "Fill"; $lstCat.Font = $FN
$lstCat.BackColor = $CI_LIGHT; $lstCat.ForeColor = $CI_DARK
$lstCat.BorderStyle = "None"; $lstCat.ItemHeight = 30
foreach ($c in $CATEGORIES) { [void]$lstCat.Items.Add($c) }
$lstCat.SelectedIndex = 0
$splitInner.Panel1.Controls.Add($lstCat)
$splitInner.Panel1.Controls.Add($lbCatHdr)

# ---- Tool-Panel (rechts) -------------------------------------------------
$lbToolHdr = New-Object System.Windows.Forms.Label
$lbToolHdr.Text = "  Tools"; $lbToolHdr.Font = $FB
$lbToolHdr.ForeColor = $CI_WHITE; $lbToolHdr.BackColor = $CI_BLUE
$lbToolHdr.Dock = "Top"; $lbToolHdr.Height = 28; $lbToolHdr.TextAlign = "MiddleLeft"

$pnlTools = New-Object System.Windows.Forms.Panel
$pnlTools.Dock = "Fill"; $pnlTools.AutoScroll = $true; $pnlTools.BackColor = $CI_WHITE
$splitInner.Panel2.Controls.Add($pnlTools)
$splitInner.Panel2.Controls.Add($lbToolHdr)

$splitOuter.Panel1.Controls.Add($splitInner)

# Form zusammenbauen
$form.SuspendLayout()
$form.Controls.Add($splitOuter)
$form.Controls.Add($pnlBtn)
$form.Controls.Add($pnlAccent)
$form.Controls.Add($pnlHdr)
$form.ResumeLayout()

# ---------------------------------------------------------------------------
# Log-Funktion (Farb-codiert)
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$msg, [string]$level = "INFO")
    $ts  = Get-Date -Format "HH:mm:ss"
    $line = "[$ts]  $msg"
    $color = switch ($level) {
        "OK"   { [System.Drawing.Color]::FromArgb(80,  200, 140) }
        "WARN" { [System.Drawing.Color]::FromArgb(240, 160,  40) }
        "ERR"  { [System.Drawing.Color]::FromArgb(220,  80,  60) }
        default{ [System.Drawing.Color]::FromArgb(200, 220, 245) }
    }
    $box = $script:LogBox
    $box.SelectionStart  = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionColor  = $color
    $box.AppendText("$line`n")
    $box.ScrollToCaret()
}

# ---------------------------------------------------------------------------
# Checkbox-Verwaltung
# ---------------------------------------------------------------------------
$script:AllChecks  = @{}
$script:CurrentCat = ""

function Update-SelCount {
    $n = ($script:AllChecks.Values | Where-Object { $_.Checked }).Count
    $lbSel.Text = if ($n -gt 0) { "$n ausgewaehlt" } else { "" }
}

# ---------------------------------------------------------------------------
# Show-Category: Kompakte Cards (Chris-Titus-Stil)
#   Web-Tools    -> nur blauer "Oeffnen"-Button, kein Checkbox
#   Install-Tools -> Checkbox + "Installieren" / "Deinstall." je nach Status
#   Tweak-Tools  -> Checkbox + "Aktivieren" Button
#   Status wird pro Card automatisch gecheckt (WinGet-Cache)
# ---------------------------------------------------------------------------
function Show-Category {
    param([string]$Cat)
    $script:CurrentCat = $Cat
    $lbToolHdr.Text    = "  $Cat"
    $pnlTools.SuspendLayout()
    $pnlTools.Controls.Clear()

    $w     = [Math]::Max($pnlTools.ClientSize.Width - 16, 380)
    $y     = 4
    $cardH = 46

    foreach ($tool in ($TOOLS | Where-Object { $_['Category'] -eq $Cat })) {
        $tName = $tool['Name']
        $tDesc = $tool['Desc']
        $isOK  = Get-ToolStatus $tool
        $isWeb = ($tool['checkType'] -eq 'none')
        $isTwk = ($tool['checkType'] -eq 'tweak')

        $bgColor = if ($isWeb)    { [System.Drawing.Color]::FromArgb(238, 244, 255) }
                   elseif ($isOK) { $CI_OK_BG }
                   else           { $CI_LIGHT }

        # -- Card ----------------------------------------------------------
        $card = New-Object System.Windows.Forms.Panel
        $card.Size        = New-Object System.Drawing.Size($w, $cardH)
        $card.Location    = New-Object System.Drawing.Point(4, $y)
        $card.BackColor   = $bgColor
        $card.BorderStyle = "FixedSingle"
        $card.Anchor      = ([System.Windows.Forms.AnchorStyles]::Top  -bor
                             [System.Windows.Forms.AnchorStyles]::Left -bor
                             [System.Windows.Forms.AnchorStyles]::Right)

        # -- Aktions-Button (rechts) ---------------------------------------
        if ($isWeb) {
            $btnText  = "Oeffnen"
            $btnColor = $CI_BLUE
            $btnW     = 84
        } elseif ($isOK) {
            $btnText  = "Deinstall."
            $btnColor = [System.Drawing.Color]::FromArgb(160, 50, 20)
            $btnW     = 88
        } elseif ($isTwk) {
            $btnText  = "Aktivieren"
            $btnColor = [System.Drawing.Color]::FromArgb(0, 110, 80)
            $btnW     = 88
        } else {
            $btnText  = "Installieren"
            $btnColor = $CI_BLUE
            $btnW     = 88
        }

        $btnAct = New-Object System.Windows.Forms.Button
        $btnAct.Text      = $btnText
        $btnAct.Font      = $FS
        $btnAct.BackColor = $btnColor
        $btnAct.ForeColor = $CI_WHITE
        $btnAct.FlatStyle = "Flat"
        $btnAct.FlatAppearance.BorderSize = 0
        $btnAct.Size      = New-Object System.Drawing.Size($btnW, 34)
        $btnAct.Location  = New-Object System.Drawing.Point(($w - $btnW - 6), 5)
        $btnAct.Cursor    = "Hand"
        $btnAct.Tag       = $tName
        $btnAct.Anchor    = ([System.Windows.Forms.AnchorStyles]::Top -bor
                             [System.Windows.Forms.AnchorStyles]::Right)
        $btnAct.Add_Click({
            $t = $TOOLS | Where-Object { $_['Name'] -eq $this.Tag } | Select-Object -First 1
            if (-not $t) { return }
            if ($t['checkType'] -eq 'none') {
                Install-ViaPM $t
            } elseif (Get-ToolStatus $t) {
                Uninstall-ViaPM $t
                Show-Category $script:CurrentCat
            } else {
                Install-ViaPM $t
                Show-Category $script:CurrentCat
            }
        })
        $card.Controls.Add($btnAct)

        # -- Status-Punkt (kleiner Indikator links vom Button) -------------
        if (-not $isWeb) {
            $dot = New-Object System.Windows.Forms.Label
            $dot.Size      = New-Object System.Drawing.Size(10, 10)
            $dot.Location  = New-Object System.Drawing.Point(($w - $btnW - 20), 18)
            $dot.BackColor = if ($isOK) { $CI_OK_FG } else { $CI_WARN_FG }
            $dot.Anchor    = ([System.Windows.Forms.AnchorStyles]::Top -bor
                              [System.Windows.Forms.AnchorStyles]::Right)
            $dot.Add_Paint({
                param($s, $e)
                $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $br = New-Object System.Drawing.SolidBrush($s.BackColor)
                $e.Graphics.FillEllipse($br, 0, 0, 9, 9)
                $br.Dispose()
            })
            $card.Controls.Add($dot)
        }

        # -- Checkbox (nur fuer Nicht-Web-Tools) ---------------------------
        $xOff = 6
        if (-not $isWeb) {
            $chk = New-Object System.Windows.Forms.CheckBox
            $chk.Size      = New-Object System.Drawing.Size(16, 16)
            $chk.Location  = New-Object System.Drawing.Point(6, 15)
            $chk.BackColor = $bgColor
            $chk.Tag       = $tName
            if ($script:AllChecks.ContainsKey($tName)) { $chk.Checked = $script:AllChecks[$tName].Checked }
            $script:AllChecks[$tName] = $chk
            $chk.Add_CheckedChanged({ Update-SelCount })
            $card.Controls.Add($chk)
            $xOff = 26
        }

        # -- Name ----------------------------------------------------------
        $availW = $w - $xOff - $btnW - 32
        $lN = New-Object System.Windows.Forms.Label
        $lN.Text      = $tName
        $lN.Font      = $FB
        $lN.ForeColor = if ($isWeb) { $CI_BLUE } else { $CI_DARK }
        $lN.AutoSize  = $false
        $lN.Size      = New-Object System.Drawing.Size($availW, 18)
        $lN.Location  = New-Object System.Drawing.Point($xOff, 5)
        $lN.Anchor    = ([System.Windows.Forms.AnchorStyles]::Top  -bor
                         [System.Windows.Forms.AnchorStyles]::Left -bor
                         [System.Windows.Forms.AnchorStyles]::Right)

        # -- Beschreibung --------------------------------------------------
        $lD = New-Object System.Windows.Forms.Label
        $lD.Text      = $tDesc
        $lD.Font      = $FS
        $lD.ForeColor = $CI_GRAY
        $lD.AutoSize  = $false
        $lD.Size      = New-Object System.Drawing.Size($availW, 16)
        $lD.Location  = New-Object System.Drawing.Point($xOff, 25)
        $lD.Anchor    = ([System.Windows.Forms.AnchorStyles]::Top  -bor
                         [System.Windows.Forms.AnchorStyles]::Left -bor
                         [System.Windows.Forms.AnchorStyles]::Right)

        $card.Controls.AddRange(@($lN, $lD))
        $pnlTools.Controls.Add($card)
        $y += ($cardH + 3)
    }
    $pnlTools.ResumeLayout()
}

# Resize -> Cards neu zeichnen
$pnlTools.Add_Resize({ if ($script:CurrentCat -ne "") { Show-Category $script:CurrentCat } })

# ---------------------------------------------------------------------------
# Events: Kategorie-Auswahl
# ---------------------------------------------------------------------------
$lstCat.Add_SelectedIndexChanged({
    if ($lstCat.SelectedItem) { Show-Category $lstCat.SelectedItem }
})

# ---------------------------------------------------------------------------
# Events: Installieren (alle angeklickten Tools)
# ---------------------------------------------------------------------------
$btnInstall.Add_Click({
    $sel = $script:AllChecks.GetEnumerator() | Where-Object { $_.Value.Checked }
    if (-not $sel) { Write-Log "Keine Tools ausgewaehlt!" "WARN"; return }

    $btnInstall.Enabled = $false; $btnInstall.Text = "Laeuft..."
    $count = 0
    foreach ($item in $sel) {
        $tName = $item.Key
        $tool  = $TOOLS | Where-Object { $_['Name'] -eq $tName } | Select-Object -First 1
        if (-not $tool) { continue }
        Write-Log "=============================="
        Write-Log "Starte: $tName"
        try {
            Install-ViaPM $tool
            $count++
        } catch {
            Write-Log "Fehler bei $tName`: $_" "ERR"
        }
    }
    Write-Log "=============================="
    Write-Log "$count Tool(s) verarbeitet." "OK"
    $btnInstall.Enabled = $true; $btnInstall.Text = "Ausgewaehlt installieren"
    if ($script:CurrentCat -ne "") { Show-Category $script:CurrentCat }
})

# ---------------------------------------------------------------------------
# Events: Deinstallieren (alle angeklickten Tools)
# ---------------------------------------------------------------------------
$btnUninstall.Add_Click({
    $sel = $script:AllChecks.GetEnumerator() | Where-Object { $_.Value.Checked }
    if (-not $sel) { Write-Log "Keine Tools ausgewaehlt!" "WARN"; return }

    $names = ($sel | ForEach-Object { $_.Key }) -join ", "
    $dlg = [System.Windows.Forms.MessageBox]::Show(
        "Folgende Tools deinstallieren?`n`n$names",
        "Deinstallation bestaetigen",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($dlg -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnUninstall.Enabled = $false; $btnUninstall.Text = "Laeuft..."
    foreach ($item in $sel) {
        $tName = $item.Key
        $tool  = $TOOLS | Where-Object { $_['Name'] -eq $tName } | Select-Object -First 1
        if (-not $tool) { continue }
        Write-Log "=============================="
        Write-Log "Deinstalliere: $tName"
        try { Uninstall-ViaPM $tool }
        catch { Write-Log "Fehler bei $tName`: $_" "ERR" }
    }
    Write-Log "=============================="
    Write-Log "Deinstallation abgeschlossen." "OK"
    $btnUninstall.Enabled = $true; $btnUninstall.Text = "Ausgewaehlt deinstall."
    if ($script:CurrentCat -ne "") { Show-Category $script:CurrentCat }
})

# ---------------------------------------------------------------------------
# Events: Status pruefen + WinGet-Cache aktualisieren
# ---------------------------------------------------------------------------
$btnCheck.Add_Click({
    Write-Log "--- WinGet-Cache wird aktualisiert ..."
    Update-WingetCache
    Write-Log "--- Status-Check aller Tools ---"
    foreach ($tool in $TOOLS) {
        $ok = Get-ToolStatus $tool
        $n  = $tool['Name']
        if ($ok) { Write-Log "  [OK]   $n" "OK" }
        else      { Write-Log "  [--]   $n" "WARN" }
    }
    Write-Log "--- Ende ---" "OK"
    if ($script:CurrentCat -ne "") { Show-Category $script:CurrentCat }
})

$btnClear.Add_Click({ $txtLog.Clear() })

# ---------------------------------------------------------------------------
# Form.Shown: Proportionen setzen, erste Kategorie laden, Startup-Log
# ---------------------------------------------------------------------------
$form.Add_Shown({
    # Outer: 2/3 oben (Tools), 1/3 unten (Log)
    $splitOuter.SplitterDistance = [Math]::Max(60, [int]($splitOuter.Height * 0.65))
    # Inner: ~220px Kategorien links
    $splitInner.SplitterDistance = 220

    # Catalog-Quelle im Header anzeigen
    $lbSub.Text = "  v2.0  |  grundke-it.de  |  Catalog: $($script:CatalogSource)  |  $($TOOLS.Count) Tools"

    Show-Category $CATEGORIES[0]

    Write-Log "Grundke IT Toolbox v2.0.0 gestartet."
    Write-Log "Benutzer : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Log "Catalog  : $($script:CatalogSource)  |  $($TOOLS.Count) Tools in $($CATEGORIES.Count) Kategorien"
    if ($script:WingetAvailable) {
        Write-Log "WinGet   : verfuegbar  |  Cache geladen" "OK"
    } else {
        Write-Log "WinGet   : NICHT verfuegbar - winget installieren!" "WARN"
    }
    Write-Log "GIT-Tools: $GIT_TOOLS_BASE"
    Write-Log "---"
    Write-Log "Tipp: Tools auswaehlen, dann [Installieren] oder [Deinstallieren] klicken."
    Write-Log "[Status pruefen] aktualisiert den WinGet-Cache und zeigt Installationsstatus."
})

[void]$form.ShowDialog()

