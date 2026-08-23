#requires -version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# WINDOWS SHOP SETUP
# install.ps1
# Version: 4.1.0
#
# Apps:
#   Google Chrome
#   Zalo
#   WinRAR
#   UniKey
#   Foxit PDF Reader
#   WPS Office
# ============================================================

$Version = "4.1.0"
$MaxRetries = 2

$Apps = @(
    @{
        Name   = "Google Chrome"
        Id     = "Google.Chrome"
        Detect = @("Google Chrome", "Chrome")
    },
    @{
        Name   = "Zalo"
        Id     = "VNGCorp.Zalo"
        Detect = @("Zalo")
    },
    @{
        Name   = "WinRAR"
        Id     = "RARLab.WinRAR"
        Detect = @("WinRAR")
    },
    @{
        Name   = "UniKey"
        Id     = "UniKey.UniKey"
        Detect = @("UniKey", "UniKeyNT")
    },
    @{
        Name   = "Foxit PDF Reader"
        Id     = "Foxit.FoxitReader"
        Detect = @("Foxit PDF Reader", "Foxit Reader", "Foxit")
    },
    @{
        Name   = "WPS Office"
        Id     = "Kingsoft.WPSOffice"
        Detect = @("WPS Office", "WPS")
    }
)

$TotalApps = $Apps.Count

$TempRoot = Join-Path `
    $env:TEMP `
    "WindowsShopSetup"

$LogRoot = Join-Path `
    $env:ProgramData `
    "WindowsShopSetup"

New-Item `
    -ItemType Directory `
    -Path $TempRoot `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $LogRoot `
    -Force | Out-Null

$LogFile = Join-Path `
    $LogRoot `
    "install-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"


# ============================================================
# LOG
# ============================================================

function Log {

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

    $Line = `
        "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"

    Add-Content `
        -Path $LogFile `
        -Value $Line `
        -Encoding UTF8

    switch ($Level) {

        "OK" {
            Write-Host `
                $Message `
                -ForegroundColor Green
        }

        "WARN" {
            Write-Host `
                $Message `
                -ForegroundColor Yellow
        }

        "ERROR" {
            Write-Host `
                $Message `
                -ForegroundColor Red
        }

        default {
            Write-Host `
                $Message `
                -ForegroundColor Gray
        }
    }
}


# ============================================================
# ADMINISTRATOR
# ============================================================

function Is-Admin {

    $Identity = `
        [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = `
        New-Object Security.Principal.WindowsPrincipal(
            $Identity
        )

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


function Restart-AsAdmin {

    Write-Host ""

    Write-Host `
        "Dang yeu cau quyen Administrator..." `
        -ForegroundColor Yellow

    Start-Process `
        -FilePath (Get-Process -Id $PID).Path `
        -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$PSCommandPath`""
        ) `
        -Verb RunAs

    exit
}


# ============================================================
# INTERNET
# ============================================================

function Test-Internet {

    try {

        Invoke-WebRequest `
            -Uri "https://cdn.winget.microsoft.com" `
            -Method Head `
            -UseBasicParsing `
            -TimeoutSec 8 `
            -ErrorAction Stop | Out-Null

        return $true
    }
    catch {

        return $false
    }
}


# ============================================================
# WINGET
# ============================================================

function Get-Winget {

    $Command = `
        Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

    if ($Command) {

        return $Command.Source
    }


    $Path = `
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"


    if (Test-Path $Path) {

        return $Path
    }


    return $null
}


function Has-Winget {

    $Winget = Get-Winget

    if (-not $Winget) {

        return $false
    }


    try {

        & $Winget --version `
            > $null `
            2>&1

        return (
            $LASTEXITCODE -eq 0
        )
    }
    catch {

        return $false
    }
}


# ============================================================
# INSTALL WINGET
# ============================================================

function Install-Winget {

    Log `
        "WinGet khong ton tai -> dang cai Microsoft App Installer."


    $File = Join-Path `
        $TempRoot `
        "Microsoft.DesktopAppInstaller.msixbundle"


    $Url = `
        "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"


    try {

        Log `
            "Dang tai Microsoft App Installer..."


        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $File `
            -UseBasicParsing `
            -TimeoutSec 180 `
            -ErrorAction Stop


        Log `
            "Dang cai Microsoft App Installer..."


        Add-AppxPackage `
            -Path $File `
            -ForceApplicationShutdown `
            -ErrorAction Stop
    }
    catch {

        Log `
            "Khong cai duoc WinGet: $($_.Exception.Message)" `
            "ERROR"

        return $false
    }


    # Refresh PATH

    $WindowsApps = `
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"


    if ($env:PATH -notlike "*$WindowsApps*") {

        $env:PATH += ";$WindowsApps"
    }


    # Wait for WinGet

    for ($i = 1; $i -le 20; $i++) {

        if (Has-Winget) {

            Log `
                "WinGet da san sang." `
                "OK"

            return $true
        }


        Start-Sleep `
            -Milliseconds 500
    }


    Log `
        "WinGet chua san sang sau khi cai." `
        "ERROR"

    return $false
}


# ============================================================
# APP DETECTION
# ============================================================

function Test-App {

    param(
        [hashtable]$App
    )


    # --------------------------------------------------------
    # Registry
    # --------------------------------------------------------

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($Path in $RegistryPaths) {

        try {

            $Items = `
                Get-ItemProperty `
                    -Path $Path `
                    -ErrorAction SilentlyContinue


            foreach ($Item in $Items) {

                $DisplayName = `
                    [string]$Item.DisplayName


                if (-not $DisplayName) {
                    continue
                }


                foreach ($Keyword in $App.Detect) {

                    if (
                        $DisplayName `
                        -like "*$Keyword*"
                    ) {

                        return $true
                    }
                }
            }
        }
        catch {
        }
    }


    # --------------------------------------------------------
    # AppX
    # --------------------------------------------------------

    try {

        $Packages = `
            Get-AppxPackage `
                -AllUsers `
                -ErrorAction SilentlyContinue


        foreach ($Package in $Packages) {

            $PackageText = `
                "$($Package.Name) $($Package.PackageFullName)"


            foreach ($Keyword in $App.Detect) {

                if (
                    $PackageText `
                    -like "*$Keyword*"
                ) {

                    return $true
                }
            }
        }
    }
    catch {
    }


    return $false
}


# ============================================================
# INSTALL WITH WINGET
# ============================================================

function Install-With-Winget {

    param(
        [string]$Name,

        [string]$Id
    )


    $Winget = Get-Winget


    if (-not $Winget) {

        throw "Khong tim thay winget.exe."
    }


    for (
        $Attempt = 1;
        $Attempt -le $MaxRetries;
        $Attempt++
    ) {

        Log `
            "Dang cai $Name - lan $Attempt/$MaxRetries..."


        $Arguments = @(
            "install"
            "--id"
            $Id
            "--exact"
            "--source"
            "winget"
            "--silent"
            "--no-upgrade"
            "--accept-package-agreements"
            "--accept-source-agreements"
            "--disable-interactivity"
        )


        try {

            & $Winget @Arguments 2>&1 |
                ForEach-Object {

                    if ($_ -and $_.Trim()) {

                        Write-Host $_
                    }
                }


            $ExitCode = `
                [int]$LASTEXITCODE


            # ------------------------------------------------
            # Success
            # ------------------------------------------------

            if ($ExitCode -eq 0) {

                Log `
                    "$Name cai thanh cong." `
                    "OK"

                return "OK"
            }


            # ------------------------------------------------
            # Check whether it installed anyway
            # ------------------------------------------------

            Start-Sleep `
                -Milliseconds 500


            if (
                Test-App `
                    -App @{
                        Detect = @($Name)
                    }
            ) {

                Log `
                    "$Name da duoc cai thanh cong." `
                    "OK"

                return "OK"
            }


            Log `
                "$Name that bai - ExitCode=$ExitCode" `
                "WARN"
        }
        catch {

            Log `
                "$Name loi: $($_.Exception.Message)" `
                "WARN"
        }


        if ($Attempt -lt $MaxRetries) {

            Start-Sleep `
                -Seconds 2
        }
    }


    Log `
        "$Name FAIL sau $MaxRetries lan." `
        "ERROR"


    return "FAIL"
}


# ============================================================
# USER DESKTOP
# ============================================================

function Get-UserDesktop {

    # --------------------------------------------------------
    # Ưu tiên Desktop của user đang đăng nhập.
    # Không dùng Desktop của Administrator.
    # --------------------------------------------------------

    $User = `
        Get-CimInstance `
            Win32_ComputerSystem |
            Select-Object -ExpandProperty UserName


    if (-not $User) {

        return `
            [Environment]::GetFolderPath(
                "Desktop"
            )
    }


    $Username = `
        $User.Split("\")[-1]


    $Profile = `
        Get-CimInstance `
            Win32_UserProfile |
            Where-Object {

                $_.LocalPath -like "*\$Username" -and
                $_.Loaded
            } |
            Select-Object -First 1


    if ($Profile) {

        return `
            Join-Path `
                $Profile.LocalPath `
                "Desktop"
    }


    return `
        [Environment]::GetFolderPath(
            "Desktop"
        )
}


# ============================================================
# SHORTCUT
# ============================================================

function Create-OneShortcut {

    param(
        [string]$Name,

        [string[]]$Keywords
    )


    $Desktop = `
        Get-UserDesktop


    if (-not (Test-Path $Desktop)) {

        Log `
            "Khong tim thay Desktop user cho $Name." `
            "WARN"

        return
    }


    $Destination = `
        Join-Path `
            $Desktop `
            "$Name.lnk"


    # --------------------------------------------------------
    # Exact shortcut already exists
    # --------------------------------------------------------

    if (Test-Path $Destination) {

        Log `
            "Shortcut $Name da ton tai -> SKIP." `
            "OK"

        return
    }


    # --------------------------------------------------------
    # Find source shortcut
    # --------------------------------------------------------

    $StartMenus = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )


    $Source = $null


    foreach ($Menu in $StartMenus) {

        if (-not (Test-Path $Menu)) {
            continue
        }


        $Files = `
            Get-ChildItem `
                -Path $Menu `
                -Filter "*.lnk" `
                -Recurse `
                -ErrorAction SilentlyContinue


        foreach ($File in $Files) {

            foreach ($Keyword in $Keywords) {

                if (
                    $File.BaseName `
                    -like "*$Keyword*"
                ) {

                    $Source = $File

                    break
                }
            }


            if ($Source) {
                break
            }
        }


        if ($Source) {
            break
        }
    }


    if (-not $Source) {

        Log `
            "Khong tim thay shortcut $Name trong Start Menu." `
            "WARN"

        return
    }


    try {

        $Shell = `
            New-Object `
                -ComObject WScript.Shell


        $SourceObject = `
            $Shell.CreateShortcut(
                $Source.FullName
            )


        $SourceTarget = `
            $SourceObject.TargetPath


        # ----------------------------------------------------
        # Check duplicate target
        # ----------------------------------------------------

        $ExistingShortcuts = `
            Get-ChildItem `
                -Path $Desktop `
                -Filter "*.lnk" `
                -ErrorAction SilentlyContinue


        foreach ($Existing in $ExistingShortcuts) {

            try {

                $ExistingObject = `
                    $Shell.CreateShortcut(
                        $Existing.FullName
                    )


                if (
                    $ExistingObject.TargetPath `
                    -and
                    $SourceTarget `
                    -and
                    (
                        $ExistingObject.TargetPath `
                        -ieq `
                        $SourceTarget
                    )
                ) {

                    Log `
                        "$Name da co shortcut tuong duong -> SKIP." `
                        "OK"

                    return
                }
            }
            catch {
            }
        }


        # ----------------------------------------------------
        # Create shortcut
        # ----------------------------------------------------

        $NewShortcut = `
            $Shell.CreateShortcut(
                $Destination
            )


        $NewShortcut.TargetPath = `
            $SourceTarget


        if ($SourceObject.Arguments) {

            $NewShortcut.Arguments = `
                $SourceObject.Arguments
        }


        if ($SourceObject.WorkingDirectory) {

            $NewShortcut.WorkingDirectory = `
                $SourceObject.WorkingDirectory
        }


        if ($SourceObject.IconLocation) {

            $NewShortcut.IconLocation = `
                $SourceObject.IconLocation
        }


        $NewShortcut.Save()


        Log `
            "Da tao shortcut: $Name" `
            "OK"
    }
    catch {

        Log `
            "Tao shortcut $Name loi: $($_.Exception.Message)" `
            "WARN"
    }
}


# ============================================================
# MAIN
# ============================================================

try {

    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "              WINDOWS SHOP SETUP v$Version" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # --------------------------------------------------------
    # Administrator
    # --------------------------------------------------------

    if (-not (Is-Admin)) {

        Restart-AsAdmin
    }


    Log `
        "Bat dau cai dat."


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra Internet..." `
        -ForegroundColor Gray


    if (-not (Test-Internet)) {

        Log `
            "Khong ket noi duoc Internet." `
            "ERROR"

        exit 1
    }


    Log `
        "Internet OK." `
        "OK"


    # --------------------------------------------------------
    # WinGet
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra WinGet..." `
        -ForegroundColor Gray


    if (-not (Has-Winget)) {

        if (-not (Install-Winget)) {

            exit 1
        }
    }
    else {

        Log `
            "WinGet da co san -> SKIP." `
            "OK"
    }


    $Winget = Get-Winget


    $WingetVersion = `
        & $Winget --version 2>&1


    Log `
        "WinGet: $($WingetVersion -join ' ')" `
        "OK"


    # --------------------------------------------------------
    # IMPORTANT:
    # Khong update source.
    # --------------------------------------------------------


    $Results = @()


    # --------------------------------------------------------
    # INSTALL APPS
    # --------------------------------------------------------

    for (
        $i = 0;
        $i -lt $Apps.Count;
        $i++
    ) {

        $App = $Apps[$i]

        $Index = $i + 1


        Write-Host ""

        Write-Host `
            "[$Index/$TotalApps] $($App.Name)" `
            -ForegroundColor Cyan


        # ----------------------------------------------------
        # Fast detection
        # ----------------------------------------------------

        if (Test-App -App $App) {

            Log `
                "$($App.Name) da co san -> SKIP." `
                "OK"


            $Results += [PSCustomObject]@{
                Name   = $App.Name
                Status = "SKIP"
            }


            continue
        }


        # ----------------------------------------------------
        # Install
        # ----------------------------------------------------

        try {

            $Status = `
                Install-With-Winget `
                    -Name $App.Name `
                    -Id $App.Id
        }
        catch {

            Log `
                "$($App.Name) loi: $($_.Exception.Message)" `
                "ERROR"

            $Status = "FAIL"
        }


        $Results += [PSCustomObject]@{
            Name   = $App.Name
            Status = $Status
        }
    }


    # ========================================================
    # SHORTCUTS
    # ========================================================

    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                 TAO SHORTCUT DESKTOP" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan


    Create-OneShortcut `
        -Name "Google Chrome" `
        -Keywords @(
            "Google Chrome"
        )


    Create-OneShortcut `
        -Name "Zalo" `
        -Keywords @(
            "Zalo"
        )


    Create-OneShortcut `
        -Name "WinRAR" `
        -Keywords @(
            "WinRAR"
        )


    Create-OneShortcut `
        -Name "UniKey" `
        -Keywords @(
            "UniKey"
            "UniKeyNT"
        )


    Create-OneShortcut `
        -Name "Foxit PDF Reader" `
        -Keywords @(
            "Foxit PDF Reader"
            "Foxit Reader"
            "Foxit"
        )


    Create-OneShortcut `
        -Name "WPS Office" `
        -Keywords @(
            "WPS Office"
            "WPS"
        )


    # ========================================================
    # SUMMARY
    # ========================================================

    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                       KET QUA" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    $Failed = 0


    foreach ($Result in $Results) {

        switch ($Result.Status) {

            "OK" {

                Write-Host `
                    "[OK]   $($Result.Name)" `
                    -ForegroundColor Green
            }

            "SKIP" {

                Write-Host `
                    "[SKIP] $($Result.Name) - da co san" `
                    -ForegroundColor Yellow
            }

            "FAIL" {

                Write-Host `
                    "[FAIL] $($Result.Name)" `
                    -ForegroundColor Red

                $Failed++
            }
        }
    }


    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Gray

    Write-Host ""


    if ($Failed -eq 0) {

        Write-Host `
            "============================================================" `
            -ForegroundColor Green

        Write-Host `
            "                 CAI DAT THANH CONG" `
            -ForegroundColor Green

        Write-Host `
            "============================================================" `
            -ForegroundColor Green

        exit 0
    }
    else {

        Write-Host `
            "============================================================" `
            -ForegroundColor Red

        Write-Host `
            "       CO $Failed UNG DUNG CAI THAT BAI" `
            -ForegroundColor Red

        Write-Host `
            "============================================================" `
            -ForegroundColor Red

        exit 2
    }
}
catch {

    Log `
        "FATAL ERROR: $($_.Exception.Message)" `
        "ERROR"


    Write-Host ""

    Write-Host `
        "Installer gap loi. Xem log:" `
        -ForegroundColor Red

    Write-Host `
        $LogFile `
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
