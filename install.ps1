#requires -version 5.1

# ============================================================
# WINDOWS SHOP SETUP
# install.ps1
#
# Apps:
#   Google Chrome
#   Zalo
#   WinRAR
#   UniKey
#   Adobe Acrobat Reader
#   WPS Office
#
# Designed for repeated deployment on shop PCs.
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# CONFIG
# ============================================================

$ScriptVersion = "2.0.0"
$MaxRetries    = 3

$Apps = @(
    @{
        Name = "Google Chrome"
        Id   = "Google.Chrome"
    },
    @{
        Name = "Zalo"
        Id   = "VNGCorp.Zalo"
    },
    @{
        Name = "WinRAR"
        Id   = "RARLab.WinRAR"
    },
    @{
        Name = "UniKey"
        Id   = "UniKey.UniKey"
    },
    @{
        Name = "Adobe Acrobat Reader"
        Id   = "Adobe.Acrobat.Reader.64-bit"
    },
    @{
        Name = "WPS Office"
        Id   = "Kingsoft.WPSOffice"
    }
)

$TempRoot = Join-Path `
    $env:TEMP `
    "WindowsShopSetup"

$LogRoot = Join-Path `
    $env:ProgramData `
    "WindowsShopSetup"

$LogFile = Join-Path `
    $LogRoot `
    "install-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"


# ============================================================
# LOG
# ============================================================

function Initialize-Log {

    if (-not (Test-Path $LogRoot)) {

        New-Item `
            -ItemType Directory `
            -Path $LogRoot `
            -Force | Out-Null
    }

    if (-not (Test-Path $TempRoot)) {

        New-Item `
            -ItemType Directory `
            -Path $TempRoot `
            -Force | Out-Null
    }
}


function Write-Log {

    param(
        [string]$Message,

        [ValidateSet(
            "INFO",
            "OK",
            "WARN",
            "ERROR"
        )]
        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Line = "[$Time] [$Level] $Message"

    Add-Content `
        -Path $LogFile `
        -Value $Line `
        -Encoding UTF8

    switch ($Level) {

        "OK" {
            Write-Host $Message -ForegroundColor Green
        }

        "WARN" {
            Write-Host $Message -ForegroundColor Yellow
        }

        "ERROR" {
            Write-Host $Message -ForegroundColor Red
        }

        default {
            Write-Host $Message -ForegroundColor Gray
        }
    }
}


# ============================================================
# ADMIN
# ============================================================

function Test-Administrator {

    $Identity = `
        [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = `
        New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


function Relaunch-Administrator {

    Write-Host ""
    Write-Host "Dang yeu cau quyen Administrator..." `
        -ForegroundColor Yellow

    $PowerShellPath = `
        (Get-Process -Id $PID).Path

    Start-Process `
        -FilePath $PowerShellPath `
        -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$PSCommandPath`""
        ) `
        -Verb RunAs

    exit 0
}


# ============================================================
# WINDOWS CHECK
# ============================================================

function Test-Windows {

    $Version = [Environment]::OSVersion.Version

    Write-Log `
        "Windows version: $Version"

    # Windows 10 1809 / build 17763+
    if ($Version.Build -lt 17763) {

        Write-Log `
            "Windows qua cu. Yeu cau Windows 10 1809+ hoac Windows 11." `
            "ERROR"

        return $false
    }

    return $true
}


# ============================================================
# INTERNET CHECK
# ============================================================

function Test-Internet {

    $Urls = @(
        "https://github.com"
        "https://api.github.com"
        "https://cdn.winget.microsoft.com"
    )

    foreach ($Url in $Urls) {

        try {

            Invoke-WebRequest `
                -Uri $Url `
                -Method Head `
                -UseBasicParsing `
                -TimeoutSec 10 `
                -ErrorAction Stop | Out-Null

            return $true
        }
        catch {
        }
    }

    return $false
}


# ============================================================
# WINGET PATH
# ============================================================

function Get-WingetPath {

    $Command = `
        Get-Command winget.exe `
        -ErrorAction SilentlyContinue

    if ($Command) {

        return $Command.Source
    }


    $Candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )

    foreach ($Path in $Candidates) {

        if (Test-Path $Path) {

            return $Path
        }
    }


    # App Installer location
    $WindowsApps = `
        "$env:ProgramFiles\WindowsApps"

    if (Test-Path $WindowsApps) {

        $Found = Get-ChildItem `
            -Path $WindowsApps `
            -Filter "winget.exe" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($Found) {

            return $Found.FullName
        }
    }

    return $null
}


function Test-Winget {

    $Winget = Get-WingetPath

    if (-not $Winget) {

        return $false
    }

    try {

        & $Winget --version `
            > $null `
            2>&1

        return ($LASTEXITCODE -eq 0)
    }
    catch {

        return $false
    }
}


# ============================================================
# INSTALL WINGET / APP INSTALLER
# ============================================================

function Install-Winget {

    Write-Log `
        "WinGet chua co. Bat dau cai Microsoft App Installer."

    $Directory = `
        Join-Path `
        $TempRoot `
        "WinGet"

    if (Test-Path $Directory) {

        Remove-Item `
            $Directory `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    New-Item `
        -ItemType Directory `
        -Path $Directory `
        -Force | Out-Null


    # --------------------------------------------------------
    # Latest official WinGet release
    # --------------------------------------------------------

    $Api = `
        "https://api.github.com/repos/microsoft/winget-cli/releases/latest"

    try {

        $Release = Invoke-RestMethod `
            -Uri $Api `
            -Headers @{
                "User-Agent" = "Windows-Shop-Setup"
            } `
            -TimeoutSec 30 `
            -ErrorAction Stop
    }
    catch {

        Write-Log `
            "Khong lay duoc WinGet release: $($_.Exception.Message)" `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Find MSIXBundle
    # --------------------------------------------------------

    $Bundle = $Release.assets |
        Where-Object {
            $_.name -match `
            "Microsoft\.DesktopAppInstaller.*\.msixbundle$"
        } |
        Select-Object -First 1


    if (-not $Bundle) {

        Write-Log `
            "Khong tim thay App Installer MSIXBundle." `
            "ERROR"

        return $false
    }


    $BundlePath = `
        Join-Path `
        $Directory `
        $Bundle.name


    # --------------------------------------------------------
    # Download
    # --------------------------------------------------------

    Write-Log `
        "Dang tai Microsoft App Installer..."

    try {

        Invoke-WebRequest `
            -Uri $Bundle.browser_download_url `
            -OutFile $BundlePath `
            -UseBasicParsing `
            -TimeoutSec 180 `
            -ErrorAction Stop
    }
    catch {

        Write-Log `
            "Tai App Installer that bai: $($_.Exception.Message)" `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Install
    # --------------------------------------------------------

    Write-Log `
        "Dang cai Microsoft App Installer..."

    try {

        Add-AppxPackage `
            -Path $BundlePath `
            -ForceApplicationShutdown `
            -ErrorAction Stop
    }
    catch {

        Write-Log `
            "Add-AppxPackage loi: $($_.Exception.Message)" `
            "WARN"
    }


    # Refresh PATH
    $WindowsApps = `
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"

    if ($env:PATH -notlike "*$WindowsApps*") {

        $env:PATH += ";$WindowsApps"
    }


    # --------------------------------------------------------
    # Wait
    # --------------------------------------------------------

    Write-Log `
        "Dang cho WinGet khoi dong..."

    for ($i = 1; $i -le 30; $i++) {

        Start-Sleep -Seconds 2

        if (Test-Winget) {

            Write-Log `
                "WinGet da san sang." `
                "OK"

            return $true
        }
    }


    # --------------------------------------------------------
    # Re-register App Installer
    # --------------------------------------------------------

    Write-Log `
        "WinGet chua san sang. Thu dang ky lai App Installer..." `
        "WARN"

    try {

        $Package = `
            Get-AppxPackage `
                -Name "Microsoft.DesktopAppInstaller" `
                -ErrorAction SilentlyContinue

        if ($Package) {

            Add-AppxPackage `
                -Register `
                "$($Package.InstallLocation)\AppxManifest.xml" `
                -DisableDevelopmentMode `
                -ErrorAction Stop
        }
    }
    catch {

        Write-Log `
            "Re-register that bai: $($_.Exception.Message)" `
            "WARN"
    }


    Start-Sleep -Seconds 5


    if (Test-Winget) {

        Write-Log `
            "WinGet da san sang." `
            "OK"

        return $true
    }


    Write-Log `
        "Khong the khoi dong WinGet." `
        "ERROR"

    return $false
}


# ============================================================
# RUN WINGET
# ============================================================

function Invoke-Winget {

    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $Winget = Get-WingetPath

    if (-not $Winget) {

        throw "Khong tim thay winget.exe."
    }

    & $Winget @Arguments

    return $LASTEXITCODE
}


# ============================================================
# CHECK APP
# ============================================================

function Test-AppInstalled {

    param(
        [string]$Id
    )

    try {

        $Output = `
            Invoke-Winget @(
                "list"
                "--id"
                $Id
                "--exact"
                "--source"
                "winget"
                "--disable-interactivity"
            ) 2>&1

        if ($LASTEXITCODE -eq 0) {

            $Text = $Output -join "`n"

            if (
                $Text -match [regex]::Escape($Id)
            ) {

                return $true
            }
        }
    }
    catch {
    }

    return $false
}


# ============================================================
# INSTALL APP
# ============================================================

function Install-App {

    param(
        [string]$Name,
        [string]$Id
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------" `
        -ForegroundColor DarkGray

    Write-Log `
        "[$Name]"

    # Already installed
    if (Test-AppInstalled -Id $Id) {

        Write-Log `
            "$Name da co san -> SKIP" `
            "OK"

        return "SKIP"
    }


    # Install
    for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {

        Write-Log `
            "Dang cai $Name - lan $Attempt/$MaxRetries..."

        try {

            $Code = Invoke-Winget @(
                "install"
                "--id"
                $Id
                "--exact"
                "--source"
                "winget"
                "--silent"
                "--accept-package-agreements"
                "--accept-source-agreements"
                "--disable-interactivity"
            )


            if ($Code -eq 0) {

                Start-Sleep -Seconds 2

                if (Test-AppInstalled -Id $Id) {

                    Write-Log `
                        "$Name cai thanh cong." `
                        "OK"

                    return "OK"
                }
            }


            Write-Log `
                "$Name that bai - ExitCode=$Code" `
                "WARN"
        }
        catch {

            Write-Log `
                "$Name loi: $($_.Exception.Message)" `
                "WARN"
        }


        if ($Attempt -lt $MaxRetries) {

            Start-Sleep -Seconds 3
        }
    }


    Write-Log `
        "$Name FAIL sau $MaxRetries lan." `
        "ERROR"

    return "FAIL"
}


# ============================================================
# DESKTOP SHORTCUT
# ============================================================

function Create-Shortcut {

    param(
        [string]$Name,
        [string[]]$Keywords
    )

    $Desktop = `
        [Environment]::GetFolderPath("Desktop")

    $Destination = `
        Join-Path `
        $Desktop `
        "$Name.lnk"


    if (Test-Path $Destination) {

        Write-Log `
            "Shortcut $Name da ton tai."

        return
    }


    $Locations = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )


    $Shortcuts = @()


    foreach ($Location in $Locations) {

        if (Test-Path $Location) {

            $Shortcuts += `
                Get-ChildItem `
                    -Path $Location `
                    -Filter "*.lnk" `
                    -Recurse `
                    -ErrorAction SilentlyContinue
        }
    }


    $Match = $null


    foreach ($Shortcut in $Shortcuts) {

        $ShortcutName = `
            [System.IO.Path]::GetFileNameWithoutExtension(
                $Shortcut.Name
            )


        foreach ($Keyword in $Keywords) {

            if (
                $ShortcutName `
                -like "*$Keyword*"
            ) {

                $Match = $Shortcut
                break
            }
        }


        if ($Match) {
            break
        }
    }


    if (-not $Match) {

        Write-Log `
            "Khong tim thay shortcut Start Menu cho $Name." `
            "WARN"

        return
    }


    try {

        $Shell = `
            New-Object -ComObject WScript.Shell

        $ShortcutObject = `
            $Shell.CreateShortcut($Destination)

        $ShortcutObject.TargetPath = `
            $Match.FullName

        $ShortcutObject.WorkingDirectory = `
            $Match.DirectoryName

        $ShortcutObject.Save()


        Write-Log `
            "Da tao shortcut Desktop: $Name" `
            "OK"
    }
    catch {

        Write-Log `
            "Khong tao duoc shortcut $Name." `
            "WARN"
    }
}


# ============================================================
# MAIN
# ============================================================

$Results = @()

try {

    Initialize-Log


    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host "               WINDOWS SHOP SETUP" `
        -ForegroundColor Cyan

    Write-Host "                    v$ScriptVersion" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # --------------------------------------------------------
    # Administrator
    # --------------------------------------------------------

    if (-not (Test-Administrator)) {

        Relaunch-Administrator
    }


    Write-Log `
        "Installer started."


    # --------------------------------------------------------
    # Windows
    # --------------------------------------------------------

    if (-not (Test-Windows)) {

        exit 1
    }


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    Write-Log `
        "Kiem tra Internet..."

    if (-not (Test-Internet)) {

        Write-Log `
            "Khong co Internet." `
            "ERROR"

        exit 1
    }

    Write-Log `
        "Internet OK." `
        "OK"


    # --------------------------------------------------------
    # WinGet
    # --------------------------------------------------------

    Write-Log `
        "Kiem tra WinGet..."

    if (-not (Test-Winget)) {

        if (-not (Install-Winget)) {

            Write-Log `
                "Khong the cai WinGet." `
                "ERROR"

            exit 1
        }
    }


    $WingetVersion = `
        (Invoke-Winget @("--version") 2>&1) -join " "

    Write-Log `
        "WinGet: $WingetVersion" `
        "OK"


    # --------------------------------------------------------
    # Source
    # --------------------------------------------------------

    Write-Log `
        "Cap nhat WinGet source..."

    try {

        Invoke-Winget @(
            "source"
            "update"
            "--disable-interactivity"
        ) | Out-Null

        Write-Log `
            "Source update OK." `
            "OK"
    }
    catch {

        Write-Log `
            "Source update khong thanh cong. Tiep tuc." `
            "WARN"
    }


    # --------------------------------------------------------
    # Install applications
    # --------------------------------------------------------

    foreach ($App in $Apps) {

        $Status = Install-App `
            -Name $App.Name `
            -Id $App.Id

        $Results += [PSCustomObject]@{
            Name   = $App.Name
            Id     = $App.Id
            Status = $Status
        }
    }


    # --------------------------------------------------------
    # Desktop shortcuts
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host "                 DESKTOP SHORTCUTS" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan


    Create-Shortcut `
        -Name "Google Chrome" `
        -Keywords @(
            "Google Chrome"
        )


    Create-Shortcut `
        -Name "Zalo" `
        -Keywords @(
            "Zalo"
        )


    Create-Shortcut `
        -Name "WinRAR" `
        -Keywords @(
            "WinRAR"
        )


    Create-Shortcut `
        -Name "UniKey" `
        -Keywords @(
            "UniKey"
            "UniKeyNT"
        )


    Create-Shortcut `
        -Name "Adobe Acrobat Reader" `
        -Keywords @(
            "Adobe Acrobat"
            "Acrobat Reader"
            "Adobe Reader"
        )


    Create-Shortcut `
        -Name "WPS Office" `
        -Keywords @(
            "WPS Office"
            "WPS"
        )


    # --------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------

    Write-Host ""
    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host "                     KET QUA" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    $Failed = 0


    foreach ($Result in $Results) {

        if ($Result.Status -eq "OK") {

            Write-Host `
                "[OK]   $($Result.Name)" `
                -ForegroundColor Green
        }
        elseif ($Result.Status -eq "SKIP") {

            Write-Host `
                "[SKIP] $($Result.Name)" `
                -ForegroundColor Yellow
        }
        else {

            Write-Host `
                "[FAIL] $($Result.Name)" `
                -ForegroundColor Red

            $Failed++
        }
    }


    Write-Host ""
    Write-Host "Log:" `
        -ForegroundColor Cyan

    Write-Host $LogFile `
        -ForegroundColor Gray

    Write-Host ""


    if ($Failed -eq 0) {

        Write-Host "============================================================" `
            -ForegroundColor Green

        Write-Host "              TAT CA - THANH CONG" `
            -ForegroundColor Green

        Write-Host "============================================================" `
            -ForegroundColor Green

        exit 0
    }
    else {

        Write-Host "============================================================" `
            -ForegroundColor Red

        Write-Host "       HOAN TAT NHUNG CO $Failed APP BI LOI" `
            -ForegroundColor Red

        Write-Host "============================================================" `
            -ForegroundColor Red

        exit 2
    }
}
catch {

    try {

        Write-Log `
            "FATAL ERROR: $($_.Exception.Message)" `
            "ERROR"
    }
    catch {
    }

    Write-Host ""
    Write-Host "INSTALLER GAP LOI NGHIEM TRONG." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Log: $LogFile" `
        -ForegroundColor Yellow

    exit 1
}
finally {

    try {

        if (Test-Path $TempRoot) {

            Remove-Item `
                $TempRoot `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
    catch {
    }
}
