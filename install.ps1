# ============================================================
# WINDOWS SHOP INSTALLER
# VERSION 5.5.0
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Version = "5.5.0"


# ============================================================
# ADMIN
# ============================================================

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)


if (-not $IsAdmin) {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host " CAN CHAY POWERSHELL BANG ADMINISTRATOR" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Chuột phải PowerShell -> Run as Administrator." -ForegroundColor White
    Write-Host ""

    Read-Host "Nhan Enter de thoat"

    exit 1
}


# ============================================================
# LOG
# ============================================================

$LogDirectory = Join-Path `
    $env:ProgramData `
    "WindowsShopInstaller"


New-Item `
    -Path $LogDirectory `
    -ItemType Directory `
    -Force `
    -ErrorAction SilentlyContinue |
    Out-Null


$LogFile = Join-Path `
    $LogDirectory `
    (
        "install-" +
        (Get-Date -Format "yyyyMMdd-HHmmss") +
        ".log"
    )


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

    $Line = "[{0}] [{1}] {2}" -f `
        $Time,
        $Level,
        $Message


    try {

        Add-Content `
            -Path $LogFile `
            -Value $Line `
            -Encoding UTF8 `
            -ErrorAction SilentlyContinue
    }
    catch {
    }


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
            Write-Host $Message
        }
    }
}


# ============================================================
# INTERNET CHECK
# ============================================================

function Test-Internet {

    try {

        $Request = [System.Net.HttpWebRequest]::Create(
            "https://www.microsoft.com"
        )

        $Request.Method = "HEAD"

        $Request.Timeout = 5000

        $Request.AllowAutoRedirect = $true

        $Response = $Request.GetResponse()

        $Response.Close()

        return $true
    }
    catch {

        return $false
    }
}


# ============================================================
# WINGET PATH
# ============================================================

function Get-Winget {

    try {

        $Command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue


        if ($Command) {

            return $Command.Source
        }
    }
    catch {
    }


    $PossiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe"
    )


    foreach ($Path in $PossiblePaths) {

        try {

            $Found = Get-Item `
                $Path `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1


            if ($Found) {

                return $Found.FullName
            }
        }
        catch {
        }
    }


    return $null
}


# ============================================================
# TEST WINGET
# ============================================================

function Test-Winget {

    $Winget = Get-Winget


    if (-not $Winget) {

        return $false
    }


    try {

        $null = & $Winget --version 2>$null

        return (
            $LASTEXITCODE -eq 0
        )
    }
    catch {

        return $false
    }
}


# ============================================================
# REPAIR / INITIALIZE WINGET
# ============================================================

function Repair-Winget {

    Write-Log `
        "WinGet chua san sang. Dang thu khoi phuc..." `
        "WARN"


    # --------------------------------------------------------
    # Try App Installer registration
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
    # TLS
    # --------------------------------------------------------

    try {

        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor
            [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }


    # --------------------------------------------------------
    # NuGet
    # --------------------------------------------------------

    try {

        $NuGet = Get-PackageProvider `
            -Name NuGet `
            -ErrorAction SilentlyContinue


        if (-not $NuGet) {

            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Force `
                -Scope AllUsers `
                -ErrorAction Stop |
                Out-Null
        }
    }
    catch {

        Write-Log `
            "Khong the cai NuGet." `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # WinGet Client
    # --------------------------------------------------------

    try {

        $Module = Get-Module `
            -ListAvailable `
            -Name Microsoft.WinGet.Client |
            Sort-Object Version -Descending |
            Select-Object -First 1


        if (-not $Module) {

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
    }
    catch {

        Write-Log `
            (
                "Microsoft.WinGet.Client loi: " +
                $_.Exception.Message
            ) `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Repair
    # --------------------------------------------------------

    try {

        Repair-WinGetPackageManager `
            -Force `
            -Latest `
            -ErrorAction Stop


        Start-Sleep -Seconds 3
    }
    catch {

        Write-Log `
            "Repair WinGet khong hoan tat." `
            "WARN"
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

        ShortcutNames = @(
            "Google Chrome"
            "Chrome"
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

        ShortcutNames = @(
            "Zalo"
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

        ShortcutNames = @(
            "WinRAR"
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

        ShortcutNames = @(
            "UniKey"
            "UniKeyNT"
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

        ShortcutNames = @(
            "Foxit PDF Reader"
            "Foxit Reader"
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

        ShortcutNames = @(
            "WPS Office"
            "WPS"
        )
    }
)


# ============================================================
# CHECK KNOWN EXE PATHS
# ============================================================

function Test-AppPath {

    param(
        $App
    )


    foreach ($Path in $App.Paths) {

        if (
            $Path `
            -and
            (Test-Path $Path -PathType Leaf)
        ) {

            return $true
        }
    }


    return $false
}


# ============================================================
# CHECK REGISTRY
# ============================================================

function Test-AppRegistry {

    param(
        $App
    )


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


    return $false
}


# ============================================================
# CHECK WINGET
# ============================================================

function Test-AppWinget {

    param(
        $App
    )


    $Winget = Get-Winget


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
            $Text `
            -match [regex]::Escape($App.Id)
        ) {

            return $true
        }
    }
    catch {
    }


    return $false
}


# ============================================================
# FINAL APP DETECTION
# ============================================================

function Test-AppInstalled {

    param(
        $App
    )


    # FASTEST
    if (Test-AppPath $App) {

        return $true
    }


    # REGISTRY
    if (Test-AppRegistry $App) {

        return $true
    }


    # WINGET
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
    # WINGET
    # --------------------------------------------------------

    $Winget = Get-Winget


    if (-not $Winget) {

        Write-Log `
            "Khong tim thay WinGet." `
            "ERROR"

        return "FAIL"
    }


    Write-Log `
        "$($App.Name) chua co -> dang cai..."


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


        $ExitCode = [int]$LASTEXITCODE


        Start-Sleep `
            -Milliseconds 1000


        # ----------------------------------------------------
        # VERIFY
        # ----------------------------------------------------

        if (Test-AppInstalled $App) {

            Write-Log `
                "$($App.Name) cai thanh cong." `
                "OK"

            return "OK"
        }


        Write-Log `
            (
                "$($App.Name) cai xong nhung khong verify duoc. " +
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

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "        WINDOWS SHOP INSTALLER v$Version" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # --------------------------------------------------------
    # ADMIN
    # --------------------------------------------------------

    if (-not $IsAdmin) {

        Write-Log `
            "Can chay bang Administrator." `
            "ERROR"

        Read-Host "Nhan Enter de thoat"

        exit 1
    }


    Write-Log `
        "Administrator: OK" `
        "OK"


    # --------------------------------------------------------
    # INTERNET
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra Internet..."


    if (-not (Test-Internet)) {

        Write-Log `
            "Khong co Internet." `
            "ERROR"

        Read-Host "Nhan Enter de thoat"

        exit 1
    }


    Write-Log `
        "Internet: OK" `
        "OK"


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
                "Khong the khoi phuc WinGet." `
                "ERROR"

            Read-Host "Nhan Enter de thoat"

            exit 1
        }
    }


    # --------------------------------------------------------
    # INSTALL APPS
    # --------------------------------------------------------

    Write-Host ""

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                 CHECK & INSTALL" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan


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

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                    KET QUA" `
        -ForegroundColor Cyan

    Write-Host `
        "==================================================" `
        -ForegroundColor Cyan


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


    $OK = @(
        $Results |
        Where-Object {
            $_.Status -eq "OK"
        }
    ).Count


    $SKIP = @(
        $Results |
        Where-Object {
            $_.Status -eq "SKIP"
        }
    ).Count


    $FAIL = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
    ).Count


    Write-Host ""

    Write-Host "Cai moi : $OK" -ForegroundColor Green
    Write-Host "Da co   : $SKIP" -ForegroundColor Yellow
    Write-Host "Loi     : $FAIL" -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Gray

    Write-Host ""


    if ($FAIL -eq 0) {

        Write-Host `
            "CAI DAT HOAN TAT." `
            -ForegroundColor Green
    }
    else {

        Write-Host `
            "CO APP BI LOI - KIEM TRA LOG." `
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

    Write-Host ""

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Yellow

    Write-Host ""

    Read-Host "Nhan Enter de dong"
}
