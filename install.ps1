# ============================================================
# WINDOWS SHOP INSTALLER
# VERSION 6.0.0
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Version = "6.0.0"


# ============================================================
# ADMIN CHECK
# ============================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    $CurrentIdentity
)

$IsAdmin = $CurrentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host " SCRIPT CAN CHAY BANG ADMINISTRATOR" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mo PowerShell bang Run as Administrator roi chay lai." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Nhan Enter de thoat"

    exit 1
}


# ============================================================
# LOG
# ============================================================

$LogFolder = Join-Path `
    $env:ProgramData `
    "WindowsShopInstaller"

New-Item `
    -Path $LogFolder `
    -ItemType Directory `
    -Force `
    -ErrorAction SilentlyContinue |
    Out-Null

$LogFile = Join-Path `
    $LogFolder `
    "install.log"


function Write-Log {

    param(
        [string]$Message,

        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "HH:mm:ss"

    $Line = "[$Time] [$Level] $Message"

    Add-Content `
        -Path $LogFile `
        -Value $Line `
        -Encoding UTF8 `
        -ErrorAction SilentlyContinue

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
            Write-Host $Message
        }
    }
}


# ============================================================
# WINGET
# ============================================================

function Get-WingetPath {

    $Command = Get-Command `
        winget.exe `
        -ErrorAction SilentlyContinue

    if ($Command) {

        return $Command.Source
    }


    $Path = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"

    if (Test-Path $Path) {

        return $Path
    }


    return $null
}


function Test-Winget {

    $Winget = Get-WingetPath

    if (-not $Winget) {

        return $false
    }


    try {

        $Version = & $Winget --version 2>$null

        if ($LASTEXITCODE -eq 0 -and $Version) {

            return $true
        }
    }
    catch {
    }


    return $false
}


# ============================================================
# TRY REPAIR WINGET
# ============================================================

function Repair-Winget {

    Write-Log `
        "WinGet chua san sang. Dang thu khoi phuc..." `
        "WARN"


    # --------------------------------------------------------
    # Try registering App Installer
    # --------------------------------------------------------

    try {

        Add-AppxPackage `
            -RegisterByFamilyName `
            -MainPackage `
            "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop

        Start-Sleep -Seconds 2


        if (Test-Winget) {

            Write-Log `
                "WinGet da san sang." `
                "OK"

            return $true
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # Try WinGet Client
    # --------------------------------------------------------

    try {

        if (-not (
            Get-PackageProvider `
                -Name NuGet `
                -ErrorAction SilentlyContinue
        )) {

            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Force `
                -Scope CurrentUser `
                -ErrorAction Stop |
                Out-Null
        }


        if (-not (
            Get-Module `
                -ListAvailable `
                -Name Microsoft.WinGet.Client `
                -ErrorAction SilentlyContinue
        )) {

            Install-Module `
                -Name Microsoft.WinGet.Client `
                -Repository PSGallery `
                -Scope CurrentUser `
                -Force `
                -AllowClobber `
                -ErrorAction Stop
        }


        Import-Module `
            Microsoft.WinGet.Client `
            -Force `
            -ErrorAction Stop


        Repair-WinGetPackageManager `
            -Force `
            -Latest `
            -ErrorAction Stop


        Start-Sleep -Seconds 3
    }
    catch {

        Write-Log `
            (
                "Khong the repair WinGet: " +
                $_.Exception.Message
            ) `
            "ERROR"

        return $false
    }


    if (Test-Winget) {

        Write-Log `
            "WinGet da san sang." `
            "OK"

        return $true
    }


    return $false
}


# ============================================================
# APPLICATION LIST
# ============================================================

$Apps = @(

    [PSCustomObject]@{
        Name = "Google Chrome"
        Id   = "Google.Chrome"

        Paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )

        RegistryNames = @(
            "Google Chrome"
            "Chrome"
        )
    }


    [PSCustomObject]@{
        Name = "Zalo"
        Id   = "VNGCorp.Zalo"

        Paths = @(
            "$env:LOCALAPPDATA\Programs\Zalo\Zalo.exe"
            "$env:APPDATA\Zalo\Zalo.exe"
            "$env:ProgramFiles\Zalo\Zalo.exe"
            "${env:ProgramFiles(x86)}\Zalo\Zalo.exe"
        )

        RegistryNames = @(
            "Zalo"
        )
    }


    [PSCustomObject]@{
        Name = "WinRAR"
        Id   = "RARLab.WinRAR"

        Paths = @(
            "$env:ProgramFiles\WinRAR\WinRAR.exe"
            "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
        )

        RegistryNames = @(
            "WinRAR"
            "WinRAR archiver"
        )
    }


    [PSCustomObject]@{
        Name = "UniKey"
        Id   = "UniKey.UniKey"

        Paths = @(
            "$env:ProgramFiles\UniKey\UniKeyNT.exe"
            "${env:ProgramFiles(x86)}\UniKey\UniKeyNT.exe"
            "$env:LOCALAPPDATA\Programs\UniKey\UniKeyNT.exe"
            "$env:APPDATA\UniKey\UniKeyNT.exe"
        )

        RegistryNames = @(
            "UniKey"
            "UniKeyNT"
        )
    }


    [PSCustomObject]@{
        Name = "Foxit PDF Reader"
        Id   = "Foxit.FoxitReader"

        Paths = @(
            "$env:ProgramFiles\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe"
            "${env:ProgramFiles(x86)}\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe"
            "$env:ProgramFiles\Foxit Software\Foxit Reader\FoxitReader.exe"
            "${env:ProgramFiles(x86)}\Foxit Software\Foxit Reader\FoxitReader.exe"
        )

        RegistryNames = @(
            "Foxit PDF Reader"
            "Foxit Reader"
        )
    }


    [PSCustomObject]@{
        Name = "WPS Office"
        Id   = "Kingsoft.WPSOffice"

        Paths = @(
            "$env:ProgramFiles\WPS Office\ksolaunch.exe"
            "${env:ProgramFiles(x86)}\WPS Office\ksolaunch.exe"
            "$env:ProgramFiles\Kingsoft\WPS Office\ksolaunch.exe"
            "${env:ProgramFiles(x86)}\Kingsoft\WPS Office\ksolaunch.exe"
            "$env:LOCALAPPDATA\Kingsoft\WPS Office\ksolaunch.exe"
        )

        RegistryNames = @(
            "WPS Office"
            "WPS Office System"
        )
    }
)


# ============================================================
# CHECK BY FILE
# ============================================================

function Test-AppFile {

    param(
        $App
    )

    foreach ($Path in $App.Paths) {

        if (
            $Path -and
            (Test-Path $Path -PathType Leaf)
        ) {

            return $true
        }
    }


    return $false
}


# ============================================================
# CHECK BY REGISTRY
# ============================================================

function Test-AppRegistry {

    param(
        $App
    )


    $RegistryLocations = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($Location in $RegistryLocations) {

        try {

            $InstalledApps = Get-ItemProperty `
                -Path $Location `
                -ErrorAction SilentlyContinue


            foreach ($Installed in $InstalledApps) {

                if (-not $Installed.DisplayName) {

                    continue
                }


                foreach ($Name in $App.RegistryNames) {

                    if (
                        $Installed.DisplayName `
                        -like "*$Name*"
                    ) {

                        return $true
                    }
                }
            }
        }
        catch {
        }
    }


    return $false
}


# ============================================================
# CHECK BY WINGET
# ============================================================

function Test-AppWinget {

    param(
        $App
    )


    $Winget = Get-WingetPath

    if (-not $Winget) {

        return $false
    }


    try {

        $Output = & $Winget list `
            --id $App.Id `
            --exact `
            --disable-interactivity `
            2>&1


        $Text = $Output -join "`n"


        if (
            $Text -match [regex]::Escape($App.Id)
        ) {

            return $true
        }
    }
    catch {
    }


    return $false
}


# ============================================================
# CHECK APP
# ============================================================

function Test-AppInstalled {

    param(
        $App
    )


    # 1. File check
    if (Test-AppFile $App) {

        return $true
    }


    # 2. Registry check
    if (Test-AppRegistry $App) {

        return $true
    }


    # 3. WinGet check
    if (Test-AppWinget $App) {

        return $true
    }


    return $false
}


# ============================================================
# INSTALL APP
# ============================================================

function Install-App {

    param(
        $App
    )


    Write-Host ""

    Write-Host `
        "[$($App.Name)]" `
        -ForegroundColor Cyan


    # --------------------------------------------------------
    # CHECK FIRST
    # --------------------------------------------------------

    Write-Log `
        "Kiem tra $($App.Name)..."


    if (Test-AppInstalled $App) {

        Write-Log `
            "$($App.Name) da co san -> SKIP." `
            "OK"

        return "SKIP"
    }


    # --------------------------------------------------------
    # WINGET
    # --------------------------------------------------------

    $Winget = Get-WingetPath


    if (-not $Winget) {

        Write-Log `
            "Khong tim thay WinGet." `
            "ERROR"

        return "FAIL"
    }


    # --------------------------------------------------------
    # INSTALL
    # --------------------------------------------------------

    Write-Log `
        "Dang cai $($App.Name)..."


    try {

        & $Winget install `
            --id $App.Id `
            --exact `
            --source winget `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity


        $ExitCode = $LASTEXITCODE


        Start-Sleep -Seconds 1


        # ----------------------------------------------------
        # IMPORTANT:
        # Don't rely only on ExitCode.
        # Winget may return non-zero when app is already installed.
        # ----------------------------------------------------

        if (Test-AppInstalled $App) {

            Write-Log `
                "$($App.Name) da san sang." `
                "OK"

            return "OK"
        }


        Write-Log `
            (
                "$($App.Name) chua xac nhan duoc. " +
                "WinGet ExitCode=$ExitCode"
            ) `
            "ERROR"


        return "FAIL"
    }
    catch {

        Write-Log `
            (
                "$($App.Name) loi: " +
                $_.Exception.Message
            ) `
            "ERROR"

        return "FAIL"
    }
}


# ============================================================
# MAIN
# ============================================================

try {

    Clear-Host


    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "        WINDOWS SHOP INSTALLER v$Version" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""


    Write-Log `
        "Bat dau installer." `
        "INFO"


    # --------------------------------------------------------
    # WINGET
    # --------------------------------------------------------

    Write-Host "Kiem tra WinGet..."


    if (Test-Winget) {

        Write-Log `
            "WinGet da co san -> SKIP." `
            "OK"
    }
    else {

        $WingetReady = Repair-Winget


        if (-not $WingetReady) {

            Write-Log `
                "Khong the su dung WinGet tren may nay." `
                "ERROR"

            Write-Host ""

            Write-Host `
                "Hay kiem tra Microsoft App Installer / Windows Update." `
                -ForegroundColor Yellow

            Write-Host ""

            Read-Host "Nhan Enter de thoat"

            exit 1
        }
    }


    # --------------------------------------------------------
    # APPS
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "                 CHECK & INSTALL" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan


    $Results = @()


    foreach ($App in $Apps) {

        $Status = Install-App $App


        $Results += [PSCustomObject]@{
            Name   = $App.Name
            Status = $Status
        }
    }


    # --------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "                    KET QUA" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""


    foreach ($Result in $Results) {

        switch ($Result.Status) {

            "OK" {

                Write-Host `
                    "[OK]   $($Result.Name)" `
                    -ForegroundColor Green
            }

            "SKIP" {

                Write-Host `
                    "[SKIP] $($Result.Name)" `
                    -ForegroundColor Yellow
            }

            "FAIL" {

                Write-Host `
                    "[FAIL] $($Result.Name)" `
                    -ForegroundColor Red
            }
        }
    }


    $InstalledCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "OK"
        }
    ).Count


    $SkippedCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "SKIP"
        }
    ).Count


    $FailedCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
    ).Count


    Write-Host ""

    Write-Host `
        "Cai moi : $InstalledCount" `
        -ForegroundColor Green

    Write-Host `
        "Da co   : $SkippedCount" `
        -ForegroundColor Yellow

    Write-Host `
        "Loi     : $FailedCount" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Gray

    Write-Host ""


    if ($FailedCount -eq 0) {

        Write-Host `
            "CAI DAT HOAN TAT." `
            -ForegroundColor Green
    }
    else {

        Write-Host `
            "CO APP CHUA CAI DUOC. XEM LOG DE KIEM TRA." `
            -ForegroundColor Red
    }


    Write-Host ""

    Read-Host "Nhan Enter de dong"
}
catch {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "FATAL ERROR" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Yellow

    Write-Host ""

    Read-Host "Nhan Enter de dong"
}
