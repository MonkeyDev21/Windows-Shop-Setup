#requires -version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# WINDOWS SHOP SETUP - PRODUCTION
# ============================================================

$Version = "4.0.0"
$MaxRetries = 2

$Apps = @(
    @{
        Name = "Google Chrome"
        Id   = "Google.Chrome"
        Detect = @(
            "Google Chrome"
            "Chrome"
        )
    },
    @{
        Name = "Zalo"
        Id   = "VNGCorp.Zalo"
        Detect = @(
            "Zalo"
        )
    },
    @{
        Name = "WinRAR"
        Id   = "RARLab.WinRAR"
        Detect = @(
            "WinRAR"
        )
    },
    @{
        Name = "UniKey"
        Id   = "UniKey.UniKey"
        Detect = @(
            "UniKey"
            "UniKeyNT"
        )
    },
    @{
        Name = "Foxit PDF Reader"
        Id   = "Foxit.FoxitReader"
        Detect = @(
            "Foxit PDF Reader"
            "Foxit Reader"
            "Foxit"
        )
    },
    @{
        Name = "WPS Office"
        Id   = "Kingsoft.WPSOffice"
        Detect = @(
            "WPS Office"
            "WPS"
        )
    }
)

$TotalApps = $Apps.Count

$BaseTemp = Join-Path $env:TEMP "WindowsShopSetup"
$LogRoot  = Join-Path $env:ProgramData "WindowsShopSetup"

New-Item -ItemType Directory -Path $BaseTemp -Force | Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null

$LogFile = Join-Path `
    $LogRoot `
    "install-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"


# ============================================================
# LOG
# ============================================================

function Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","OK","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $Line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"

    Add-Content `
        -Path $LogFile `
        -Value $Line `
        -Encoding UTF8

    switch ($Level) {
        "OK"    { Write-Host $Message -ForegroundColor Green }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message -ForegroundColor Gray }
    }
}


# ============================================================
# ADMIN
# ============================================================

function Is-Admin {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


function Restart-AsAdmin {

    Write-Host ""
    Write-Host "Yeu cau quyen Administrator..." `
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
# WINGET
# ============================================================

function Get-Winget {

    $Command = Get-Command `
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

        return ($LASTEXITCODE -eq 0)

    } catch {

        return $false
    }
}


function Install-Winget {

    Log "WinGet khong ton tai -> dang cai Microsoft App Installer."

    $File = Join-Path `
        $BaseTemp `
        "Microsoft.DesktopAppInstaller.msixbundle"

    $Url = `
        "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

    try {

        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $File `
            -UseBasicParsing `
            -TimeoutSec 180 `
            -ErrorAction Stop

        Log "Dang cai Microsoft App Installer..."

        Add-AppxPackage `
            -Path $File `
            -ForceApplicationShutdown `
            -ErrorAction Stop

    } catch {

        Log `
            "Khong cai duoc WinGet: $($_.Exception.Message)" `
            "ERROR"

        return $false
    }


    $WindowsApps = `
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"

    if ($env:PATH -notlike "*$WindowsApps*") {
        $env:PATH += ";$WindowsApps"
    }


    for ($i = 1; $i -le 20; $i++) {

        if (Has-Winget) {

            Log "WinGet da san sang." "OK"

            return $true
        }

        Start-Sleep -Milliseconds 500
    }


    Log "WinGet chua san sang sau khi cai." "ERROR"

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
    # Registry uninstall keys
    # --------------------------------------------------------

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    foreach ($Path in $RegistryPaths) {

        try {

            $Items = Get-ItemProperty `
                -Path $Path `
                -ErrorAction SilentlyContinue

            foreach ($Item in $Items) {

                $DisplayName = [string]$Item.DisplayName

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

        } catch {
        }
    }


    # --------------------------------------------------------
    # AppX packages
    # --------------------------------------------------------

    try {

        $Packages = Get-AppxPackage `
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

    } catch {
    }


    return $false
}


# ============================================================
# WINGET INSTALL
# ============================================================

function Install-With-Winget {

    param(
        [string]$Name,
        [string]$Id,
        [int]$Index
    )


    $Winget = Get-Winget

    if (-not $Winget) {
        throw "Khong tim thay winget.exe."
    }


    $Spinner = @(
        "|"
        "/"
        "-"
        "\"
    )


    for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {

        Log "Dang cai $Name - lan $Attempt/$MaxRetries..."


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


        $Process = Start-Process `
            -FilePath $Winget `
            -ArgumentList $Arguments `
            -PassThru `
            -NoNewWindow


        $Spin = 0


        while (-not $Process.HasExited) {

            $Percent = `
                [int](
                    (($Index - 1) / $TotalApps) * 100
                )


            Write-Progress `
                -Id 1 `
                -Activity "Windows Shop Setup" `
                -Status `
                "[$Index/$TotalApps] $Name $($Spinner[$Spin % 4])" `
                -PercentComplete $Percent


            Start-Sleep -Milliseconds 200

            $Spin++

            $Process.Refresh()
        }


        Write-Progress `
            -Id 1 `
            -Activity "Windows Shop Setup" `
            -Status `
            "[$Index/$TotalApps] $Name - hoan tat" `
            -PercentComplete `
            ([int](($Index / $TotalApps) * 100))


        $ExitCode = $Process.ExitCode


        # ----------------------------------------------------
        # ExitCode 0
        # ----------------------------------------------------

        if ($ExitCode -eq 0) {

            Log "$Name cai thanh cong." "OK"

            return "OK"
        }


        # ----------------------------------------------------
        # Check again in case installer returned non-zero
        # after successfully installing.
        # ----------------------------------------------------

        Start-Sleep -Milliseconds 500


        if (
            Test-App `
                -App @{
                    Detect = @($Name)
                }
        ) {

            Log "$Name da duoc cai thanh cong." "OK"

            return "OK"
        }


        Log `
            "$Name that bai - ExitCode=$ExitCode" `
            "WARN"


        if ($Attempt -lt $MaxRetries) {

            Start-Sleep -Seconds 2
        }
    }


    return "FAIL"
}


# ============================================================
# DESKTOP SHORTCUT
# ============================================================

function Get-UserDesktop {

    # Quan trong:
    # Lay Desktop cua user dang dang nhap,
    # khong lay Desktop cua Administrator.

    $User = Get-CimInstance `
        Win32_ComputerSystem |
        Select-Object -ExpandProperty UserName


    if (-not $User) {

        return [Environment]::GetFolderPath("Desktop")
    }


    $Username = `
        $User.Split("\")[-1]


    $Profile = `
        Get-CimInstance Win32_UserProfile |
        Where-Object {
            $_.LocalPath -like "*\$Username" -and
            $_.Loaded
        } |
        Select-Object -First 1


    if ($Profile) {

        return Join-Path `
            $Profile.LocalPath `
            "Desktop"
    }


    return [Environment]::GetFolderPath("Desktop")
}


function Create-OneShortcut {

    param(
        [string]$Name,
        [string[]]$Keywords
    )


    $Desktop = Get-UserDesktop


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


    # Da co dung ten
    if (Test-Path $Destination) {

        Log `
            "Shortcut $Name da ton tai -> SKIP." `
            "OK"

        return
    }


    $StartMenus = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )


    $Source = $null


    foreach ($Menu in $StartMenus) {

        if (-not (Test-Path $Menu)) {
            continue
        }


        $Files = Get-ChildItem `
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

        $Shell = New-Object -ComObject WScript.Shell


        # ----------------------------------------------------
        # Chống shortcut trùng target
        # ----------------------------------------------------

        $SourceObject = `
            $Shell.CreateShortcut(
                $Source.FullName
            )


        $SourceTarget = `
            $SourceObject.TargetPath


        $Existing = `
            Get-ChildItem `
                -Path $Desktop `
                -Filter "*.lnk" `
                -ErrorAction SilentlyContinue


        foreach ($Shortcut in $Existing) {

            try {

                $Object = `
                    $Shell.CreateShortcut(
                        $Shortcut.FullName
                    )


                if (
                    $Object.TargetPath `
                    -and
                    $SourceTarget `
                    -and
                    (
                        $Object.TargetPath `
                        -ieq `
                        $SourceTarget
                    )
                ) {

                    Log `
                        "$Name da co shortcut tuong duong -> SKIP." `
                        "OK"

                    return
                }

            } catch {
            }
        }


        # ----------------------------------------------------
        # Create
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


        $NewShortcut.WorkingDirectory = `
            $SourceObject.WorkingDirectory


        $NewShortcut.IconLocation = `
            $SourceObject.IconLocation


        $NewShortcut.Save()


        Log `
            "Da tao shortcut: $Name" `
            "OK"

    } catch {

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
    # Admin
    # --------------------------------------------------------

    if (-not (Is-Admin)) {

        Restart-AsAdmin
    }


    Log "Bat dau cai dat."


    # --------------------------------------------------------
    # Internet
    # --------------------------------------------------------

    try {

        Invoke-WebRequest `
            -Uri "https://cdn.winget.microsoft.com" `
            -Method Head `
            -UseBasicParsing `
            -TimeoutSec 8 `
            -ErrorAction Stop | Out-Null

    } catch {

        Log `
            "Khong ket noi duoc Internet." `
            "ERROR"

        exit 1
    }


    # --------------------------------------------------------
    # WinGet
    # --------------------------------------------------------

    if (-not (Has-Winget)) {

        if (-not (Install-Winget)) {

            exit 1
        }
    }
    else {

        Log "WinGet da co san -> SKIP." "OK"
    }


    $Winget = Get-Winget


    $VersionOutput = `
        & $Winget --version 2>&1


    Log `
        "WinGet $($VersionOutput -join ' ')" `
        "OK"


    # --------------------------------------------------------
    # KHONG source update
    # --------------------------------------------------------
    #
    # Khong goi:
    # winget source update
    #
    # De tiet kiem thoi gian tren tung may.
    #
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


        Write-Progress `
            -Id 1 `
            -Activity "Windows Shop Setup" `
            -Status `
            "[$Index/$TotalApps] Kiem tra $($App.Name)..." `
            -PercentComplete `
            ([int](($i / $TotalApps) * 100))


        # ----------------------------------------------------
        # Fast detection
        # ----------------------------------------------------

        if (Test-App -App $App) {

            Log `
                "$($App.Name) da co san -> SKIP." `
                "OK"

            $Results += [PSCustomObject]@{
                Name = $App.Name
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
                    -Id $App.Id `
                    -Index $Index

        } catch {

            Log `
                "$($App.Name) loi: $($_.Exception.Message)" `
                "ERROR"

            $Status = "FAIL"
        }


        $Results += [PSCustomObject]@{
            Name = $App.Name
            Status = $Status
        }
    }


    Write-Progress `
        -Id 1 `
        -Activity "Windows Shop Setup" `
        -Status "Hoan tat cai dat" `
        -PercentComplete 100


    Start-Sleep -Milliseconds 500


    Write-Progress `
        -Id 1 `
        -Activity "Windows Shop Setup" `
        -Completed


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
                    "[SKIP] $($Result.Name)" `
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

        if (Test-Path $BaseTemp) {

            Remove-Item `
                $BaseTemp `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

    } catch {
    }
}
