# ============================================================
# WINDOWS SHOP INSTALLER
# VERSION 5.4.0
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Version = "5.4.0"

# ============================================================
# ADMIN CHECK
# ============================================================

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host " SCRIPT CAN QUYEN ADMINISTRATOR" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Hay mo PowerShell bang Run as Administrator." -ForegroundColor White
    Write-Host ""

    Read-Host "Nhan Enter de thoat"

    return
}


# ============================================================
# LOG
# ============================================================

$LogDirectory = "$env:ProgramData\WindowsShopInstaller"

New-Item `
    -Path $LogDirectory `
    -ItemType Directory `
    -Force `
    -ErrorAction SilentlyContinue |
    Out-Null

$LogFile = Join-Path `
    $LogDirectory `
    ("install-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")


function Log {

    param(
        [string]$Text,
        [string]$Type = "INFO"
    )

    $Time = Get-Date -Format "HH:mm:ss"

    $Line = "[$Time] [$Type] $Text"

    Add-Content `
        -Path $LogFile `
        -Value $Line `
        -Encoding UTF8 `
        -ErrorAction SilentlyContinue

    switch ($Type) {

        "OK" {
            Write-Host $Text -ForegroundColor Green
        }

        "WARN" {
            Write-Host $Text -ForegroundColor Yellow
        }

        "ERROR" {
            Write-Host $Text -ForegroundColor Red
        }

        default {
            Write-Host $Text
        }
    }
}


# ============================================================
# WINGET
# ============================================================

function Get-Winget {

    $Command = Get-Command winget.exe -ErrorAction SilentlyContinue

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

    $Winget = Get-Winget

    if (-not $Winget) {
        return $false
    }

    try {

        & $Winget --version 2>$null | Out-Null

        return ($LASTEXITCODE -eq 0)

    }
    catch {

        return $false
    }
}


function Repair-Winget {

    Log "WinGet chua co. Dang thu khoi phuc..." "WARN"

    # --------------------------------------------------------
    # Try existing App Installer
    # --------------------------------------------------------

    try {

        Add-AppxPackage `
            -RegisterByFamilyName `
            -MainPackage `
            "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop

        Start-Sleep -Seconds 2

        if (Test-Winget) {

            Log "WinGet da san sang." "OK"

            return $true
        }

    }
    catch {
    }


    # --------------------------------------------------------
    # Microsoft.WinGet.Client
    # --------------------------------------------------------

    try {

        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12


        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {

            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Force `
                -Scope AllUsers `
                -ErrorAction Stop |
                Out-Null
        }


        if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {

            Install-Module `
                -Name Microsoft.WinGet.Client `
                -Repository PSGallery `
                -Scope AllUsers `
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

        Log "Khong the tu khoi phuc WinGet." "ERROR"

        return $false
    }


    if (Test-Winget) {

        Log "WinGet da san sang." "OK"

        return $true
    }


    return $false
}


# ============================================================
# APP CONFIG
# ============================================================

$Apps = @(

    [PSCustomObject]@{
        Name = "Google Chrome"
        Id = "Google.Chrome"

        Names = @(
            "Google Chrome"
            "Chrome"
        )

        Paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
    }

    [PSCustomObject]@{
        Name = "Zalo"
        Id = "VNGCorp.Zalo"

        Names = @(
            "Zalo"
        )

        Paths = @(
            "$env:LOCALAPPDATA\Programs\Zalo\Zalo.exe"
            "$env:APPDATA\Zalo\Zalo.exe"
            "$env:ProgramFiles\Zalo\Zalo.exe"
            "${env:ProgramFiles(x86)}\Zalo\Zalo.exe"
        )
    }

    [PSCustomObject]@{
        Name = "WinRAR"
        Id = "RARLab.WinRAR"

        Names = @(
            "WinRAR"
            "WinRAR archiver"
        )

        Paths = @(
            "$env:ProgramFiles\WinRAR\WinRAR.exe"
            "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
        )
    }

    [PSCustomObject]@{
        Name = "UniKey"
        Id = "UniKey.UniKey"

        Names = @(
            "UniKey"
            "UniKeyNT"
        )

        Paths = @(
            "$env:ProgramFiles\UniKey\UniKeyNT.exe"
            "${env:ProgramFiles(x86)}\UniKey\UniKeyNT.exe"
            "$env:LOCALAPPDATA\Programs\UniKey\UniKeyNT.exe"
            "$env:APPDATA\UniKey\UniKeyNT.exe"
        )
    }

    [PSCustomObject]@{
        Name = "Foxit PDF Reader"
        Id = "Foxit.FoxitReader"

        Names = @(
            "Foxit PDF Reader"
            "Foxit Reader"
        )

        Paths = @(
            "$env:ProgramFiles\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe"
            "${env:ProgramFiles(x86)}\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe"
            "$env:ProgramFiles\Foxit Software\Foxit Reader\FoxitReader.exe"
            "${env:ProgramFiles(x86)}\Foxit Software\Foxit Reader\FoxitReader.exe"
        )
    }

    [PSCustomObject]@{
        Name = "WPS Office"
        Id = "Kingsoft.WPSOffice"

        Names = @(
            "WPS Office"
            "WPS Office System"
        )

        Paths = @(
            "$env:ProgramFiles\WPS Office\ksolaunch.exe"
            "${env:ProgramFiles(x86)}\WPS Office\ksolaunch.exe"
            "$env:ProgramFiles\Kingsoft\WPS Office\ksolaunch.exe"
            "${env:ProgramFiles(x86)}\Kingsoft\WPS Office\ksolaunch.exe"
            "$env:LOCALAPPDATA\Kingsoft\WPS Office\ksolaunch.exe"
        )
    }
)


# ============================================================
# FAST APP DETECTION
# ============================================================

function Test-App {

    param(
        $App
    )


    # --------------------------------------------------------
    # 1. Known executable path
    # --------------------------------------------------------

    foreach ($Path in $App.Paths) {

        if (
            $Path `
            -and
            (Test-Path $Path -PathType Leaf)
        ) {

            return $true
        }
    }


    # --------------------------------------------------------
    # 2. Registry
    # --------------------------------------------------------

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($RegistryPath in $RegistryPaths) {

        try {

            $Items = Get-ItemProperty `
                -Path $RegistryPath `
                -ErrorAction SilentlyContinue


            foreach ($Item in $Items) {

                if (-not $Item.DisplayName) {
                    continue
                }


                foreach ($Name in $App.Names) {

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


    # --------------------------------------------------------
    # 3. WinGet
    # --------------------------------------------------------

    $Winget = Get-Winget

    if ($Winget) {

        try {

            $Result = `
                & $Winget list `
                    --id $App.Id `
                    --exact `
                    --disable-interactivity `
                    2>&1


            $Text = `
                $Result -join "`n"


            if (
                $Text `
                -match [regex]::Escape($App.Id)
            ) {

                return $true
            }

        }
        catch {
        }
    }


    return $false
}


# ============================================================
# INSTALL
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

    Log `
        "Dang kiem tra $($App.Name)..."


    if (Test-App $App) {

        Log `
            "$($App.Name) da co san -> SKIP." `
            "OK"

        return "SKIP"
    }


    # --------------------------------------------------------
    # INSTALL
    # --------------------------------------------------------

    $Winget = Get-Winget


    if (-not $Winget) {

        Log `
            "Khong tim thay WinGet." `
            "ERROR"

        return "FAIL"
    }


    Log `
        "Chua co $($App.Name) -> dang cai..."


    try {

        & $Winget install `
            --id $App.Id `
            --exact `
            --source winget `
            --silent `
            --no-upgrade `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity


        $ExitCode = $LASTEXITCODE


        Start-Sleep `
            -Milliseconds 800


        # ----------------------------------------------------
        # VERIFY
        # ----------------------------------------------------

        if (Test-App $App) {

            Log `
                "$($App.Name) cai thanh cong." `
                "OK"

            return "OK"
        }


        Log `
            "$($App.Name) chua xac nhan duoc sau khi cai. ExitCode=$ExitCode" `
            "ERROR"


        return "FAIL"

    }
    catch {

        Log `
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

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "       WINDOWS SHOP INSTALLER v$Version" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # --------------------------------------------------------
    # Admin
    # --------------------------------------------------------

    if (-not $IsAdmin) {

        # IMPORTANT:
        # irm | iex cannot safely self-elevate without knowing
        # the original URL. Therefore we stop cleanly.
        Write-Host `
            "Can chay PowerShell bang Run as Administrator." `
            -ForegroundColor Yellow

        Read-Host "Nhan Enter de thoat"

        return
    }


    Log `
        "Administrator: OK" `
        "OK"


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    if (-not (Test-Internet)) {

        Log `
            "Khong co ket noi Internet." `
            "ERROR"

        Read-Host "Nhan Enter de thoat"

        return
    }


    Log `
        "Internet: OK" `
        "OK"


    # --------------------------------------------------------
    # WinGet
    # --------------------------------------------------------

    if (Test-Winget) {

        Log `
            "WinGet da co san -> SKIP." `
            "OK"
    }
    else {

        if (-not (Repair-Winget)) {

            Log `
                "Khong the khoi phuc WinGet." `
                "ERROR"

            Read-Host "Nhan Enter de thoat"

            return
        }
    }


    # --------------------------------------------------------
    # Apps
    # --------------------------------------------------------

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "              CHECK & INSTALL" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan


    $Results = @()


    foreach ($App in $Apps) {

        $Status = `
            Install-App `
                $App


        $Results += `
            [PSCustomObject]@{
                Name = $App.Name
                Status = $Status
            }
    }


    # --------------------------------------------------------
    # RESULT
    # --------------------------------------------------------

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                    KET QUA" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan


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


    $FailCount = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
    ).Count


    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Gray

    Write-Host ""


    if ($FailCount -eq 0) {

        Write-Host `
            "HOAN TAT." `
            -ForegroundColor Green

    }
    else {

        Write-Host `
            "CO APP CAI THAT BAI. XEM LOG O TREN." `
            -ForegroundColor Red
    }


    Write-Host ""

    Read-Host "Nhan Enter de dong"

}
catch {

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Red

    Write-Host `
        "FATAL ERROR" `
        -ForegroundColor Red

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Yellow

    Write-Host ""

    Read-Host "Nhan Enter de dong"
}
