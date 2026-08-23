#requires -Version 5.1

# ============================================================
# WINDOWS SHOP INSTALLER
# Version: 5.1.0
#
# Apps:
#   Google Chrome
#   Zalo
#   WinRAR
#   UniKey
#   Foxit PDF Reader
#   WPS Office
#
# Designed for:
#   Windows 10 1809+
#   Windows 11
#   PowerShell 5.1
#
# Features:
#   - Works with irm | iex
#   - Automatic Administrator elevation
#   - Automatic WinGet detection
#   - Automatic WinGet registration/repair
#   - No winget source update
#   - No application upgrade
#   - Retry failed installations
#   - Continues if one application fails
#   - Desktop shortcut deduplication
#   - Log file
#   - No loading / spinner
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptVersion = "5.1.0"
$MaxRetries = 2


# ============================================================
# APPLICATIONS
# ============================================================

$Apps = @(
    [PSCustomObject]@{
        Name = "Google Chrome"
        Id = "Google.Chrome"
        Shortcut = "Google Chrome"
        Keywords = @("Google Chrome")
    },

    [PSCustomObject]@{
        Name = "Zalo"
        Id = "VNGCorp.Zalo"
        Shortcut = "Zalo"
        Keywords = @("Zalo")
    },

    [PSCustomObject]@{
        Name = "WinRAR"
        Id = "RARLab.WinRAR"
        Shortcut = "WinRAR"
        Keywords = @("WinRAR")
    },

    [PSCustomObject]@{
        Name = "UniKey"
        Id = "UniKey.UniKey"
        Shortcut = "UniKey"
        Keywords = @("UniKey", "UniKeyNT")
    },

    [PSCustomObject]@{
        Name = "Foxit PDF Reader"
        Id = "Foxit.FoxitReader"
        Shortcut = "Foxit PDF Reader"
        Keywords = @("Foxit PDF Reader", "Foxit Reader", "Foxit")
    },

    [PSCustomObject]@{
        Name = "WPS Office"
        Id = "Kingsoft.WPSOffice"
        Shortcut = "WPS Office"
        Keywords = @("WPS Office", "WPS")
    }
)


# ============================================================
# DIRECTORIES
# ============================================================

$LogRoot = Join-Path `
    $env:ProgramData `
    "WindowsShopInstaller"

New-Item `
    -Path $LogRoot `
    -ItemType Directory `
    -Force `
    -ErrorAction SilentlyContinue |
    Out-Null


$LogFile = Join-Path `
    $LogRoot `
    ("install-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")


# ============================================================
# LOG
# ============================================================

function Write-Log {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "OK", "WARN", "ERROR")]
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
            Write-Host `
                $Message `
                -ForegroundColor Gray
        }
    }
}


# ============================================================
# ADMIN
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
# SELF-ELEVATION
#
# Important:
# This works with:
#
# irm https://.../install.ps1 | iex
#
# because the script is reconstructed into a temporary .ps1
# before elevation.
# ============================================================

function Restart-AsAdministrator {

    Write-Host ""

    Write-Host `
        "Dang yeu cau quyen Administrator..." `
        -ForegroundColor Yellow


    $TempScript = Join-Path `
        $env:TEMP `
        ("WindowsShopInstaller-" + [guid]::NewGuid().ToString() + ".ps1")


    try {

        $CurrentScript = $null


        # ----------------------------------------------------
        # If executed normally from a .ps1 file
        # ----------------------------------------------------

        if (
            $MyInvocation `
            -and
            $MyInvocation.MyCommand `
            -and
            $MyInvocation.MyCommand.Path
        ) {

            $CurrentScript = `
                $MyInvocation.MyCommand.Path
        }


        # ----------------------------------------------------
        # If executed through irm | iex
        #
        # $script:sourceText is created below by the loader.
        # ----------------------------------------------------

        if (
            -not $CurrentScript `
            -and
            $script:SourceText
        ) {

            Set-Content `
                -Path $TempScript `
                -Value $script:SourceText `
                -Encoding UTF8

            $CurrentScript = $TempScript
        }


        if (-not $CurrentScript) {

            throw `
                "Khong xac dinh duoc script de nang quyen."
        }


        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$CurrentScript`""
            ) |
            Out-Null


        exit 0
    }
    catch {

        Write-Log `
            ("Khong the yeu cau Administrator: " + $_.Exception.Message) `
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
                "Windows nay qua cu. Can Windows 10 1809/build 17763 tro len." `
                "ERROR"

            return $false
        }


        return $true
    }
    catch {

        Write-Log `
            "Khong the kiem tra Windows version." `
            "WARN"

        return $true
    }
}


# ============================================================
# INTERNET
# ============================================================

function Test-Internet {

    $Urls = @(
        "https://www.microsoft.com"
        "https://cdn.winget.microsoft.com"
        "https://www.powershellgallery.com"
    )


    foreach ($Url in $Urls) {

        try {

            $Request = `
                [System.Net.WebRequest]::Create($Url)

            $Request.Method = "HEAD"
            $Request.Timeout = 7000

            $Response = `
                $Request.GetResponse()

            $Response.Close()

            return $true
        }
        catch {
        }
    }


    return $false
}


# ============================================================
# FIND WINGET
# ============================================================

function Get-Winget {

    $Command = `
        Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue


    if ($Command) {

        return $Command.Source
    }


    $Paths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )


    foreach ($Path in $Paths) {

        if (Test-Path $Path) {

            return $Path
        }
    }


    # --------------------------------------------------------
    # Search WindowsApps only when necessary
    # --------------------------------------------------------

    try {

        $WindowsApps = `
            "$env:ProgramFiles\WindowsApps"


        if (Test-Path $WindowsApps) {

            $Winget = `
                Get-ChildItem `
                    -Path $WindowsApps `
                    -Filter "winget.exe" `
                    -Recurse `
                    -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1


            if ($Winget) {

                return $Winget.FullName
            }
        }
    }
    catch {
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
# REGISTER EXISTING APP INSTALLER
# ============================================================

function Register-Winget {

    Write-Log `
        "Thu dang ky lai Windows Package Manager..."


    try {

        Add-AppxPackage `
            -RegisterByFamilyName `
            -MainPackage `
            "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop


        Start-Sleep `
            -Seconds 2


        if (Test-Winget) {

            Write-Log `
                "WinGet da duoc dang ky thanh cong." `
                "OK"

            return $true
        }
    }
    catch {

        Write-Log `
            "Khong the dang ky App Installer." `
            "WARN"
    }


    return $false
}


# ============================================================
# BOOTSTRAP WINGET
#
# Uses Microsoft's documented Microsoft.WinGet.Client
# repair/bootstrap method.
# ============================================================

function Install-Or-Repair-Winget {

    Write-Host ""

    Write-Host `
        "WinGet chua san sang - dang tu sua/cai..." `
        -ForegroundColor Yellow


    # --------------------------------------------------------
    # First: existing App Installer registration
    # --------------------------------------------------------

    if (Register-Winget) {

        return $true
    }


    # --------------------------------------------------------
    # TLS 1.2 for PowerShell Gallery
    # --------------------------------------------------------

    try {

        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol `
            -bor `
            [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }


    # --------------------------------------------------------
    # NuGet provider
    # --------------------------------------------------------

    try {

        Write-Log `
            "Kiem tra NuGet Package Provider..."


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


        Write-Log `
            "NuGet OK." `
            "OK"
    }
    catch {

        Write-Log `
            ("Khong cai duoc NuGet: " + $_.Exception.Message) `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Microsoft.WinGet.Client
    # --------------------------------------------------------

    try {

        Write-Log `
            "Dang cai/nap Microsoft.WinGet.Client..."


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
                -Force `
                -AllowClobber `
                -Scope AllUsers `
                -ErrorAction Stop
        }


        Import-Module `
            Microsoft.WinGet.Client `
            -Force `
            -ErrorAction Stop


        Write-Log `
            "Microsoft.WinGet.Client OK." `
            "OK"
    }
    catch {

        Write-Log `
            ("Khong cai duoc Microsoft.WinGet.Client: " + $_.Exception.Message) `
            "ERROR"

        return $false
    }


    # --------------------------------------------------------
    # Repair / bootstrap WinGet
    # --------------------------------------------------------

    try {

        Write-Log `
            "Dang Repair-WinGetPackageManager..."


        Repair-WinGetPackageManager `
            -Force `
            -Latest `
            -ErrorAction Stop


        Start-Sleep `
            -Seconds 3
    }
    catch {

        Write-Log `
            ("Repair-WinGetPackageManager loi: " + $_.Exception.Message) `
            "WARN"
    }


    # --------------------------------------------------------
    # Re-register after repair
    # --------------------------------------------------------

    if (Test-Winget) {

        Write-Log `
            "WinGet da san sang." `
            "OK"

        return $true
    }


    Register-Winget | Out-Null


    if (Test-Winget) {

        Write-Log `
            "WinGet da san sang sau khi dang ky lai." `
            "OK"

        return $true
    }


    # --------------------------------------------------------
    # Final attempt: refresh PATH
    # --------------------------------------------------------

    $WindowsApps = `
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"


    if (
        $env:PATH `
        -notlike "*$WindowsApps*"
    ) {

        $env:PATH += ";$WindowsApps"
    }


    Start-Sleep `
        -Seconds 2


    if (Test-Winget) {

        Write-Log `
            "WinGet da san sang." `
            "OK"

        return $true
    }


    Write-Log `
        "Khong the khoi phuc WinGet tu dong." `
        "ERROR"


    return $false
}


# ============================================================
# WINGET PACKAGE STATE
#
# Uses WinGet itself instead of guessing from registry names.
# ============================================================

function Get-PackageState {

    param(
        [string]$Id
    )


    $Winget = Get-Winget


    if (-not $Winget) {

        return "UNKNOWN"
    }


    try {

        $Output = `
            & $Winget list `
                --id `
                $Id `
                --exact `
                --source winget `
                2>&1


        $ExitCode = `
            [int]$LASTEXITCODE


        $Text = `
            ($Output -join "`n")


        # ----------------------------------------------------
        # Package found
        # ----------------------------------------------------

        if (
            $Text `
            -match [regex]::Escape($Id)
        ) {

            return "INSTALLED"
        }


        # ----------------------------------------------------
        # WinGet's "No installed package found" is normal.
        # ----------------------------------------------------

        if (
            $Text `
            -match "No installed package found"
        ) {

            return "NOT_INSTALLED"
        }


        if (
            $Text `
            -match "No installed package"
        ) {

            return "NOT_INSTALLED"
        }


        # Exit 0 with no package text generally means no match
        if (
            $ExitCode -eq 0 `
            -and
            $Text `
            -notmatch [regex]::Escape($Id)
        ) {

            return "NOT_INSTALLED"
        }


        return "UNKNOWN"
    }
    catch {

        return "UNKNOWN"
    }
}


# ============================================================
# INSTALL ONE PACKAGE
# ============================================================

function Install-App {

    param(
        [Parameter(Mandatory = $true)]
        $App
    )


    Write-Host ""

    Write-Host `
        "[$($App.Name)]" `
        -ForegroundColor Cyan


    # --------------------------------------------------------
    # Check first
    # --------------------------------------------------------

    $State = `
        Get-PackageState `
            -Id $App.Id


    if ($State -eq "INSTALLED") {

        Write-Log `
            "$($App.Name) da co -> SKIP, khong upgrade." `
            "OK"

        return "SKIP"
    }


    # --------------------------------------------------------
    # Install
    # --------------------------------------------------------

    $Winget = Get-Winget


    if (-not $Winget) {

        Write-Log `
            "Khong tim thay winget.exe." `
            "ERROR"

        return "FAIL"
    }


    for (
        $Attempt = 1;
        $Attempt -le $MaxRetries;
        $Attempt++
    ) {

        Write-Log `
            "Dang cai $($App.Name) - lan $Attempt/$MaxRetries..."


        $Arguments = @(
            "install"
            "--id"
            $App.Id
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

            & $Winget @Arguments


            $ExitCode = `
                [int]$LASTEXITCODE


            # ------------------------------------------------
            # WinGet success
            # ------------------------------------------------

            if ($ExitCode -eq 0) {

                Write-Log `
                    "$($App.Name) cai thanh cong." `
                    "OK"

                return "OK"
            }


            # ------------------------------------------------
            # IMPORTANT:
            #
            # Some installers return non-zero even though the
            # application is now installed.
            #
            # Check again before declaring failure.
            # ------------------------------------------------

            Start-Sleep `
                -Milliseconds 800


            $AfterState = `
                Get-PackageState `
                    -Id $App.Id


            if ($AfterState -eq "INSTALLED") {

                Write-Log `
                    "$($App.Name) da duoc cai thanh cong." `
                    "OK"

                return "OK"
            }


            Write-Log `
                "$($App.Name) that bai - ExitCode=$ExitCode" `
                "WARN"


            if ($Attempt -lt $MaxRetries) {

                Start-Sleep `
                    -Seconds 2
            }
        }
        catch {

            Write-Log `
                "$($App.Name) loi: $($_.Exception.Message)" `
                "WARN"


            if ($Attempt -lt $MaxRetries) {

                Start-Sleep `
                    -Seconds 2
            }
        }
    }


    Write-Log `
        "$($App.Name) FAIL sau $MaxRetries lan." `
        "ERROR"


    return "FAIL"
}


# ============================================================
# CURRENT USER DESKTOP
# ============================================================

function Get-CurrentUserDesktop {

    try {

        $Computer = `
            Get-CimInstance `
                Win32_ComputerSystem


        $User = `
            $Computer.UserName


        if ($User) {

            $UserName = `
                $User.Split("\")[-1]


            $Profile = `
                Get-CimInstance `
                    Win32_UserProfile `
                    -ErrorAction SilentlyContinue |
                Where-Object {

                    $_.Loaded -eq $true `
                    -and
                    $_.LocalPath -like "*\$UserName"
                } |
                Select-Object -First 1


            if ($Profile) {

                $Desktop = `
                    Join-Path `
                        $Profile.LocalPath `
                        "Desktop"


                if (Test-Path $Desktop) {

                    return $Desktop
                }
            }
        }
    }
    catch {
    }


    # Fallback

    try {

        return `
            [Environment]::GetFolderPath(
                "Desktop"
            )
    }
    catch {

        return $null
    }
}


# ============================================================
# FIND START MENU SHORTCUT
# ============================================================

function Find-Shortcut {

    param(
        [string[]]$Keywords
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

            $Shortcuts = `
                Get-ChildItem `
                    -Path $Location `
                    -Filter "*.lnk" `
                    -Recurse `
                    -ErrorAction SilentlyContinue


            foreach ($Shortcut in $Shortcuts) {

                foreach ($Keyword in $Keywords) {

                    if (
                        $Shortcut.BaseName `
                        -like "*$Keyword*"
                    ) {

                        return $Shortcut
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
# CREATE DESKTOP SHORTCUT
# ============================================================

function Ensure-Shortcut {

    param(
        [string]$Name,

        [string[]]$Keywords
    )


    $Desktop = `
        Get-CurrentUserDesktop


    if (-not $Desktop) {

        Write-Log `
            "Khong tim thay Desktop user cho $Name." `
            "WARN"

        return
    }


    $Destination = `
        Join-Path `
            $Desktop `
            ($Name + ".lnk")


    # --------------------------------------------------------
    # Exact shortcut already exists
    # --------------------------------------------------------

    if (Test-Path $Destination) {

        Write-Log `
            "Shortcut $Name da co -> SKIP." `
            "OK"

        return
    }


    # --------------------------------------------------------
    # Find Start Menu shortcut
    # --------------------------------------------------------

    $Source = `
        Find-Shortcut `
            -Keywords $Keywords


    if (-not $Source) {

        Write-Log `
            "Khong tim thay shortcut Start Menu cho $Name." `
            "WARN"

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
        # Prevent duplicate shortcut pointing to same EXE
        # ----------------------------------------------------

        $ExistingShortcuts = `
            Get-ChildItem `
                -Path $Desktop `
                -Filter "*.lnk" `
                -ErrorAction SilentlyContinue


        foreach ($Existing in $ExistingShortcuts) {

            try {

                $ExistingLink = `
                    $Shell.CreateShortcut(
                        $Existing.FullName
                    )


                if (
                    $ExistingLink.TargetPath `
                    -and
                    $Target `
                    -and
                    (
                        $ExistingLink.TargetPath `
                        -ieq `
                        $Target
                    )
                ) {

                    Write-Log `
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

        $NewLink = `
            $Shell.CreateShortcut(
                $Destination
            )


        $NewLink.TargetPath = `
            $Target


        if ($SourceLink.Arguments) {

            $NewLink.Arguments = `
                $SourceLink.Arguments
        }


        if ($SourceLink.WorkingDirectory) {

            $NewLink.WorkingDirectory = `
                $SourceLink.WorkingDirectory
        }


        if ($SourceLink.IconLocation) {

            $NewLink.IconLocation = `
                $SourceLink.IconLocation
        }


        $NewLink.Save()


        Write-Log `
            "Da tao shortcut $Name." `
            "OK"
    }
    catch {

        Write-Log `
            ("Tao shortcut $Name loi: " + $_.Exception.Message) `
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
        "             WINDOWS SHOP INSTALLER v$ScriptVersion" `
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
    # Administrator
    # --------------------------------------------------------

    if (-not (Test-IsAdmin)) {

        Restart-AsAdministrator
    }


    Write-Log `
        "Administrator: OK" `
        "OK"


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra Internet..." `
        -ForegroundColor Gray


    if (-not (Test-Internet)) {

        Write-Log `
            "Khong co ket noi Internet." `
            "ERROR"

        exit 1
    }


    Write-Log `
        "Internet: OK" `
        "OK"


    # --------------------------------------------------------
    # WinGet
    # --------------------------------------------------------

    Write-Host `
        "Kiem tra WinGet..." `
        -ForegroundColor Gray


    if (-not (Test-Winget)) {

        if (-not (Install-Or-Repair-Winget)) {

            Write-Host ""

            Write-Log `
                "Khong the khoi tao WinGet. Dung installer." `
                "ERROR"

            exit 1
        }
    }
    else {

        Write-Log `
            "WinGet da san sang -> SKIP." `
            "OK"
    }


    $Winget = Get-Winget


    if (-not $Winget) {

        Write-Log `
            "WinGet van khong ton tai sau bootstrap." `
            "ERROR"

        exit 1
    }


    $WingetVersion = `
        & $Winget --version `
        2>$null


    Write-Log `
        ("WinGet " + ($WingetVersion -join " ") + ": OK") `
        "OK"


    # --------------------------------------------------------
    # NO SOURCE UPDATE
    # --------------------------------------------------------

    Write-Log `
        "Bo qua winget source update de tang toc." `
        "INFO"


    # ========================================================
    # INSTALL APPS
    # ========================================================

    Write-Host ""

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "                    CAI UNG DUNG" `
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
        "                 TAO SHORTCUT DESKTOP" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan


    foreach ($App in $Apps) {

        Ensure-Shortcut `
            -Name $App.Shortcut `
            -Keywords $App.Keywords
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
        "             CO UNG DUNG CAI THAT BAI" `
        -ForegroundColor Red

    Write-Host `
        "============================================================" `
        -ForegroundColor Red

    exit 2
}
catch {

    Write-Log `
        ("FATAL ERROR: " + $_.Exception.Message) `
        "ERROR"


    Write-Host ""

    Write-Host `
        "Installer gap loi nghiem trong." `
        -ForegroundColor Red

    Write-Host `
        ("Log: " + $LogFile) `
        -ForegroundColor Yellow

    exit 1
}
