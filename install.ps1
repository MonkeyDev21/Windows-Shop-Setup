# ============================================================
# WINDOWS SHOP INSTALLER
# VERSION 6.1.0
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Version = "6.1.0"


# ============================================================
# ADMIN CHECK
# ============================================================

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal(
    $Identity
)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host " CAN CHAY BANG ADMINISTRATOR" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mo PowerShell bang Run as Administrator." -ForegroundColor Yellow
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

        [ValidateSet(
            "INFO",
            "OK",
            "WARN",
            "ERROR"
        )]
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


        return (
            $LASTEXITCODE -eq 0 -and
            $Version
        )
    }
    catch {

        return $false
    }
}


# ============================================================
# REPAIR WINGET
# ============================================================

function Repair-Winget {

    Write-Log `
        "WinGet chua co. Dang thu khoi phuc..." `
        "WARN"


    # --------------------------------------------------------
    # App Installer registration
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
    # Microsoft.WinGet.Client
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


        Start-Sleep -Seconds 2
    }
    catch {

        Write-Log `
            (
                "Khong the khoi phuc WinGet: " +
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
# APPLICATIONS
# ============================================================

$Apps = @(

    [PSCustomObject]@{
        Name = "Google Chrome"
        Id = "Google.Chrome"

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
        Id = "VNGCorp.Zalo"

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
        Id = "RARLab.WinRAR"

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
        Id = "UniKey.UniKey"

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
        Id = "Foxit.FoxitReader"

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
        Id = "Kingsoft.WPSOffice"

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
# FAST FILE CHECK
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
# REGISTRY CHECK
# ============================================================

function Test-AppRegistry {

    param(
        $App
    )


    $Locations = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($Location in $Locations) {

        try {

            $Items = Get-ItemProperty `
                -Path $Location `
                -ErrorAction SilentlyContinue


            foreach ($Item in $Items) {

                if (-not $Item.DisplayName) {

                    continue
                }


                foreach ($Name in $App.RegistryNames) {

                    if (
                        $Item.DisplayName `
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
# APP CHECK
# ============================================================

function Test-AppInstalled {

    param(
        $App
    )


    # --------------------------------------------------------
    # FIRST: File
    # --------------------------------------------------------

    if (Test-AppFile $App) {

        return $true
    }


    # --------------------------------------------------------
    # SECOND: Registry
    # --------------------------------------------------------

    if (Test-AppRegistry $App) {

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
    # CHECK BEFORE INSTALL
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
    # GET WINGET
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


        # ----------------------------------------------------
        # VERIFY
        # ----------------------------------------------------

        Start-Sleep -Milliseconds 700


        if (Test-AppInstalled $App) {

            Write-Log `
                "$($App.Name) da san sang." `
                "OK"

            return "OK"
        }


        # ----------------------------------------------------
        # Winget sometimes reports already installed
        # ----------------------------------------------------

        if ($ExitCode -eq -1978335189) {

            Write-Log `
                "$($App.Name) da duoc cai tu truoc nhung chua tim thay executable." `
                "WARN"


            Start-Sleep -Seconds 2


            if (Test-AppInstalled $App) {

                Write-Log `
                    "$($App.Name) da san sang." `
                    "OK"

                return "OK"
            }
        }


        Write-Log `
            (
                "$($App.Name) khong xac nhan duoc. " +
                "ExitCode=$ExitCode"
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
        "Installer started."


    # --------------------------------------------------------
    # WINGET
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra WinGet..."


    if (Test-Winget) {

        Write-Log `
            "WinGet da co san -> SKIP." `
            "OK"
    }
    else {

        if (-not (Repair-Winget)) {

            Write-Log `
                "Khong the su dung WinGet." `
                "ERROR"

            Write-Host ""

            Write-Host `
                "Kiem tra Microsoft App Installer / Windows Update." `
                -ForegroundColor Yellow

            Write-Host ""

            Read-Host "Nhan Enter de thoat"

            exit 1
        }
    }


    # --------------------------------------------------------
    # INSTALL APPS
    # --------------------------------------------------------

    Write-Host ""

    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "                 CHECK & INSTALL" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan


    $Results = @()


    foreach ($App in $Apps) {

        $Status = Install-App $App


        $Results += [PSCustomObject]@{
            Name = $App.Name
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


    $NewCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "OK"
        }
    ).Count


    $SkipCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "SKIP"
        }
    ).Count


    $FailCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
    ).Count


    Write-Host ""

    Write-Host `
        "Cai moi : $NewCount" `
        -ForegroundColor Green

    Write-Host `
        "Da co   : $SkipCount" `
        -ForegroundColor Yellow

    Write-Host `
        "Loi     : $FailCount" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Gray

    Write-Host ""


    if ($FailCount -eq 0) {

        Write-Host `
            "CAI DAT HOAN TAT." `
            -ForegroundColor Green
    }
    else {

        Write-Host `
            "CO APP BI LOI. KIEM TRA LOG." `
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
