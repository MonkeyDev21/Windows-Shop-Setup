#requires -Version 5.1

# ============================================================
# WINDOWS SHOP INSTALLER
# VERSION 5.3.0 - PRODUCTION
#
# Apps:
#   Google Chrome
#   Zalo
#   WinRAR
#   UniKey
#   Foxit PDF Reader
#   WPS Office
#
# Design:
#   1. Check app locally FIRST
#   2. If installed -> SKIP
#   3. Only use WinGet when missing
#   4. Verify after installation
#   5. No unnecessary upgrade
#   6. No source update
#   7. No recursive Program Files scan
#   8. No duplicate Desktop shortcuts
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Version = "5.3.0"
$MaxRetries = 2


# ============================================================
# APP CONFIG
# ============================================================

$Apps = @(

    [PSCustomObject]@{
        Name = "Google Chrome"
        Id = "Google.Chrome"

        DetectNames = @(
            "Google Chrome"
            "Chrome"
        )

        DetectPaths = @(
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

        DetectNames = @(
            "Zalo"
        )

        DetectPaths = @(
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

        DetectNames = @(
            "WinRAR"
            "WinRAR archiver"
        )

        DetectPaths = @(
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

        DetectNames = @(
            "UniKey"
            "UniKeyNT"
        )

        DetectPaths = @(
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

        DetectNames = @(
            "Foxit PDF Reader"
            "Foxit Reader"
        )

        DetectPaths = @(
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

        DetectNames = @(
            "WPS Office"
            "WPS Office System"
        )

        DetectPaths = @(
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
    ("install-" +
    (Get-Date -Format "yyyyMMdd-HHmmss") +
    ".log")


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
# ADMIN CHECK
# ============================================================

function Test-IsAdmin {

    $Identity = `
        [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = `
        New-Object `
        Security.Principal.WindowsPrincipal(
            $Identity
        )

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


# ============================================================
# ELEVATION
# ============================================================

function Invoke-Elevation {

    Write-Host ""

    Write-Host `
        "Dang yeu cau quyen Administrator..." `
        -ForegroundColor Yellow


    # --------------------------------------------------------
    # Normal .ps1 execution
    # --------------------------------------------------------

    $ScriptPath = $null

    try {

        if (
            $MyInvocation `
            -and
            $MyInvocation.ScriptName `
            -and
            (Test-Path $MyInvocation.ScriptName)
        ) {

            $ScriptPath = `
                $MyInvocation.ScriptName
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # Fallback for irm | iex
    #
    # In IEX mode, Definition normally contains the script
    # body. Recreate it as a temporary file.
    # --------------------------------------------------------

    if (-not $ScriptPath) {

        try {

            $Definition = `
                $script:SourceText

            if (
                -not $Definition `
                -and
                $MyInvocation.MyCommand.Definition
            ) {

                $Definition = `
                    $MyInvocation.MyCommand.Definition
            }


            if ($Definition) {

                $TempPath = Join-Path `
                    $env:TEMP `
                    (
                        "WindowsShopInstaller-" +
                        [guid]::NewGuid().ToString() +
                        ".ps1"
                    )


                Set-Content `
                    -Path $TempPath `
                    -Value $Definition `
                    -Encoding UTF8 `
                    -Force


                $ScriptPath = $TempPath
            }
        }
        catch {
        }
    }


    if (-not $ScriptPath) {

        Write-Log `
            "Khong the tao lai script de nang quyen." `
            "ERROR"

        exit 1
    }


    try {

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$ScriptPath`""
            ) |
            Out-Null

        exit 0
    }
    catch {

        Write-Log `
            (
                "Khong the yeu cau UAC: " +
                $_.Exception.Message
            ) `
            "ERROR"

        exit 1
    }
}


# ============================================================
# WINDOWS VERSION
# ============================================================

function Test-WindowsVersion {

    try {

        $Build = `
            [Environment]::OSVersion.Version.Build

        if ($Build -lt 17763) {

            Write-Log `
                "Windows qua cu. Can Windows 10 1809 tro len." `
                "ERROR"

            return $false
        }

        return $true
    }
    catch {

        return $true
    }
}


# ============================================================
# INTERNET
# ============================================================

function Test-Internet {

    try {

        $Request = `
            [System.Net.WebRequest]::Create(
                "https://www.microsoft.com"
            )

        $Request.Method = "HEAD"
        $Request.Timeout = 5000

        $Response = `
            $Request.GetResponse()

        $Response.Close()

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


function Test-Winget {

    $Winget = Get-Winget

    if (-not $Winget) {

        return $false
    }


    try {

        & $Winget --version `
            2>$null |
            Out-Null

        return (
            $LASTEXITCODE -eq 0
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
        "WinGet chua san sang. Dang thu khoi phuc..."


    # --------------------------------------------------------
    # Try existing App Installer registration first
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
                "WinGet da duoc khoi phuc." `
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

        $NuGet = `
            Get-PackageProvider `
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
            "Khong cai duoc NuGet." `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Microsoft.WinGet.Client
    # --------------------------------------------------------

    try {

        $Module = `
            Get-Module `
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
            "Repair-WinGetPackageManager khong hoan tat." `
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
# REGISTRY DETECTION
# ============================================================

function Test-RegistryApp {

    param(
        [Parameter(Mandatory)]
        $App
    )


    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($Path in $Paths) {

        try {

            $Items = `
                Get-ItemProperty `
                    -Path $Path `
                    -ErrorAction SilentlyContinue


            foreach ($Item in $Items) {

                if (-not $Item.DisplayName) {
                    continue
                }


                foreach ($Name in $App.DetectNames) {

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
# FAST FILE DETECTION
# ============================================================

function Test-AppPath {

    param(
        [Parameter(Mandatory)]
        $App
    )


    foreach ($Path in $App.DetectPaths) {

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
# WINGET DETECTION
#
# Only called after local detection fails.
# ============================================================

function Test-WingetInstalled {

    param(
        [string]$Id
    )


    $Winget = Get-Winget

    if (-not $Winget) {

        return $false
    }


    try {

        $Output = `
            & $Winget list `
                --id $Id `
                --exact `
                --disable-interactivity `
                2>&1


        $Text = `
            $Output -join "`n"


        return (
            $Text -match [regex]::Escape($Id)
        )
    }
    catch {

        return $false
    }
}


# ============================================================
# APP DETECTION
#
# FASTEST -> SLOWEST
#
# 1. Known executable path
# 2. Registry
# 3. WinGet
# ============================================================

function Test-AppInstalled {

    param(
        [Parameter(Mandatory)]
        $App
    )


    # --------------------------------------------------------
    # 1. FAST PATH
    # --------------------------------------------------------

    if (
        Test-AppPath `
            -App $App
    ) {

        return $true
    }


    # --------------------------------------------------------
    # 2. REGISTRY
    # --------------------------------------------------------

    if (
        Test-RegistryApp `
            -App $App
    ) {

        return $true
    }


    # --------------------------------------------------------
    # 3. WINGET
    # --------------------------------------------------------

    if (
        Test-WingetInstalled `
            -Id $App.Id
    ) {

        return $true
    }


    return $false
}


# ============================================================
# INSTALL ONE APP
# ============================================================

function Install-App {

    param(
        [Parameter(Mandatory)]
        $App
    )


    Write-Host ""

    Write-Host `
        "[$($App.Name)]" `
        -ForegroundColor Cyan


    # ========================================================
    # CHECK FIRST
    # ========================================================

    Write-Log `
        "Kiem tra $($App.Name)..."


    if (
        Test-AppInstalled `
            -App $App
    ) {

        Write-Log `
            "$($App.Name) da co san -> SKIP." `
            "OK"

        return "SKIP"
    }


    # ========================================================
    # APP NOT FOUND
    # ========================================================

    Write-Log `
        "$($App.Name) chua co -> bat dau cai."


    $Winget = Get-Winget


    if (-not $Winget) {

        Write-Log `
            "Khong tim thay WinGet." `
            "ERROR"

        return "FAIL"
    }


    # ========================================================
    # INSTALL
    # ========================================================

    for (
        $Attempt = 1;
        $Attempt -le $MaxRetries;
        $Attempt++
    ) {

        Write-Log `
            "Cai $($App.Name) - lan $Attempt/$MaxRetries..."


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


            $ExitCode = `
                [int]$LASTEXITCODE


            # ------------------------------------------------
            # Verify regardless of ExitCode
            # ------------------------------------------------

            Start-Sleep `
                -Milliseconds 800


            if (
                Test-AppInstalled `
                    -App $App
            ) {

                Write-Log `
                    "$($App.Name) cai thanh cong." `
                    "OK"

                return "OK"
            }


            # ------------------------------------------------
            # Don't retry if WinGet says package already exists
            # ------------------------------------------------

            if ($ExitCode -eq -1978335189) {

                Write-Log `
                    "$($App.Name) WinGet bao package da ton tai nhung detection khong tim thay." `
                    "WARN"

                break
            }


            Write-Log `
                (
                    "$($App.Name) that bai. " +
                    "ExitCode=$ExitCode"
                ) `
                "WARN"


            if ($Attempt -lt $MaxRetries) {

                Start-Sleep -Seconds 2
            }
        }
        catch {

            Write-Log `
                (
                    "$($App.Name) loi: " +
                    $_.Exception.Message
                ) `
                "WARN"


            if ($Attempt -lt $MaxRetries) {

                Start-Sleep -Seconds 2
            }
        }
    }


    # ========================================================
    # FINAL CHECK
    # ========================================================

    if (
        Test-AppInstalled `
            -App $App
    ) {

        Write-Log `
            "$($App.Name) da ton tai sau khi verify." `
            "OK"

        return "OK"
    }


    Write-Log `
        "$($App.Name) FAIL." `
        "ERROR"

    return "FAIL"
}


# ============================================================
# DESKTOP
# ============================================================

function Get-DesktopPath {

    try {

        $Path = `
            [Environment]::GetFolderPath(
                [Environment+SpecialFolder]::Desktop
            )


        if (
            $Path `
            -and
            (Test-Path $Path)
        ) {

            return $Path
        }
    }
    catch {
    }


    return `
        (Join-Path `
            $env:USERPROFILE `
            "Desktop")
}


# ============================================================
# FIND START MENU SHORTCUT
# ============================================================

function Find-Shortcut {

    param(
        [string[]]$Names
    )


    $Locations = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )


    foreach ($Location in $Locations) {

        if (-not (Test-Path $Location)) {
            continue
        }


        try {

            $Files = `
                Get-ChildItem `
                    -Path $Location `
                    -Filter "*.lnk" `
                    -Recurse `
                    -ErrorAction SilentlyContinue


            foreach ($File in $Files) {

                foreach ($Name in $Names) {

                    if (
                        $File.BaseName `
                        -like "*$Name*"
                    ) {

                        return $File
                    }
                }
            }
        }
        catch {
        }
    }


    return $null
}


# ============================================================
# DESKTOP SHORTCUT
# ============================================================

function Ensure-DesktopShortcut {

    param(
        [Parameter(Mandatory)]
        $App
    )


    $Desktop = Get-DesktopPath


    if (-not $Desktop) {
        return
    }


    # --------------------------------------------------------
    # Find source shortcut
    # --------------------------------------------------------

    $Source = `
        Find-Shortcut `
            -Names $App.ShortcutNames


    if (-not $Source) {

        Write-Log `
            "Khong tim thay shortcut $($App.Name)." `
            "WARN"

        return
    }


    $Destination = `
        Join-Path `
            $Desktop `
            ($App.Name + ".lnk")


    # --------------------------------------------------------
    # Exact shortcut already exists
    # --------------------------------------------------------

    if (Test-Path $Destination) {

        Write-Log `
            "Shortcut $($App.Name) da co -> SKIP." `
            "OK"

        return
    }


    try {

        $Shell = `
            New-Object `
                -ComObject WScript.Shell


        $SourceLink = `
            $Shell.CreateShortcut(
                $Source.FullName
            )


        $Target = `
            $SourceLink.TargetPath


        # ----------------------------------------------------
        # Check ALL existing shortcuts
        # ----------------------------------------------------

        $Existing = `
            Get-ChildItem `
                -Path $Desktop `
                -Filter "*.lnk" `
                -ErrorAction SilentlyContinue


        foreach ($File in $Existing) {

            try {

                $Link = `
                    $Shell.CreateShortcut(
                        $File.FullName
                    )


                if (
                    $Target `
                    -and
                    $Link.TargetPath `
                    -and
                    $Link.TargetPath -ieq $Target
                ) {

                    Write-Log `
                        "Shortcut $($App.Name) da ton tai -> SKIP." `
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
            $SourceLink.TargetPath


        if ($SourceLink.Arguments) {

            $NewShortcut.Arguments = `
                $SourceLink.Arguments
        }


        if ($SourceLink.WorkingDirectory) {

            $NewShortcut.WorkingDirectory = `
                $SourceLink.WorkingDirectory
        }


        if ($SourceLink.IconLocation) {

            $NewShortcut.IconLocation = `
                $SourceLink.IconLocation
        }


        $NewShortcut.Save()


        Write-Log `
            "Da tao shortcut $($App.Name)." `
            "OK"
    }
    catch {

        Write-Log `
            (
                "Tao shortcut $($App.Name) loi: " +
                $_.Exception.Message
            ) `
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
        "           WINDOWS SHOP INSTALLER v$Version" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # --------------------------------------------------------
    # Windows
    # --------------------------------------------------------

    if (-not (Test-WindowsVersion)) {

        exit 1
    }


    # --------------------------------------------------------
    # Admin
    # --------------------------------------------------------

    if (-not (Test-IsAdmin)) {

        Invoke-Elevation
    }


    Write-Log `
        "Administrator: OK" `
        "OK"


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    if (-not (Test-Internet)) {

        Write-Log `
            "Khong co Internet." `
            "ERROR"

        exit 1
    }


    Write-Log `
        "Internet: OK" `
        "OK"


    # --------------------------------------------------------
    # WinGet
    #
    # IMPORTANT:
    # WinGet is initialized before app detection only because
    # it is also used as the final detection layer.
    # --------------------------------------------------------

    if (-not (Test-Winget)) {

        if (-not (Repair-Winget)) {

            Write-Log `
                "Khong the khoi phuc WinGet." `
                "ERROR"

            exit 1
        }
    }
    else {

        Write-Log `
            "WinGet da san sang -> SKIP." `
            "OK"
    }


    # ========================================================
    # INSTALL
    # ========================================================

    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                  CHECK & INSTALL APPS" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan


    $Results = @()


    foreach ($App in $Apps) {

        $Status = `
            Install-App `
                -App $App


        $Results += `
            [PSCustomObject]@{
                Name = $App.Name
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
        "                    DESKTOP SHORTCUT" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan


    foreach ($Result in $Results) {

        if (
            $Result.Status -eq "OK" `
            -or
            $Result.Status -eq "SKIP"
        ) {

            $App = `
                $Apps |
                Where-Object {
                    $_.Name -eq $Result.Name
                } |
                Select-Object -First 1


            if ($App) {

                Ensure-DesktopShortcut `
                    -App $App
            }
        }
    }


    # ========================================================
    # SUMMARY
    # ========================================================

    $Installed = @(
        $Results |
        Where-Object {
            $_.Status -eq "OK"
        }
    ).Count


    $Skipped = @(
        $Results |
        Where-Object {
            $_.Status -eq "SKIP"
        }
    ).Count


    $Failed = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
    ).Count


    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                         KET QUA" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
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


    Write-Host ""

    Write-Host `
        "Da cai : $Installed" `
        -ForegroundColor Green

    Write-Host `
        "Bo qua: $Skipped" `
        -ForegroundColor Yellow

    Write-Host `
        "Loi   : $Failed" `
        -ForegroundColor Red

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
            "                 CAI DAT HOAN TAT" `
            -ForegroundColor Green

        Write-Host `
            "============================================================" `
            -ForegroundColor Green

        Write-Host ""

        exit 0
    }


    Write-Host `
        "============================================================" `
        -ForegroundColor Red

    Write-Host `
        "              CO APP CAI THAT BAI" `
        -ForegroundColor Red

    Write-Host `
        "============================================================" `
        -ForegroundColor Red

    exit 2
}
catch {

    Write-Log `
        (
            "FATAL ERROR: " +
            $_.Exception.Message
        ) `
        "ERROR"


    Write-Host ""

    Write-Host `
        "Installer gap loi nghiem trong." `
        -ForegroundColor Red

    Write-Host `
        "Log: $LogFile" `
        -ForegroundColor Yellow

    exit 1
}
