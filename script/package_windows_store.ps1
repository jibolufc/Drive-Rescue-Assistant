param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,

    [string]$Version = "0.3.0.0",

    [string]$OutputDirectory = "dist-store"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $ExecutablePath)) {
    $ExecutablePath = Join-Path $root $ExecutablePath
}
$ExecutablePath = (Resolve-Path $ExecutablePath).Path
$manifestTemplate = Join-Path $root "windows/store/AppxManifest.xml"
$outputRoot = Join-Path $root $OutputDirectory
$packageRoot = Join-Path $outputRoot "package"
$assetsRoot = Join-Path $packageRoot "Assets"
$msixPath = Join-Path $outputRoot "DriveRescueAssistant_$($Version)_x64.msix"
$uploadPath = Join-Path $outputRoot "DriveRescueAssistant_$($Version)_x64.msixupload"
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "MSIX version must contain four numeric parts, for example 0.3.1.0."
}

Remove-Item $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item $assetsRoot -ItemType Directory -Force | Out-Null
Copy-Item $ExecutablePath (Join-Path $packageRoot "DriveRescueAssistant.exe")

[xml]$manifest = Get-Content $manifestTemplate
$manifest.Package.Identity.SetAttribute("Version", $Version)
$manifest.Save((Join-Path $packageRoot "AppxManifest.xml"))

Add-Type -AssemblyName System.Drawing

function New-DriveRescueAsset {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height
    )

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 32, 34))

    $size = [Math]::Min($Width, $Height)
    $margin = [Math]::Max(4, [int]($size * 0.18))
    $stroke = [Math]::Max(2, [int]($size * 0.07))
    $driveWidth = $size - (2 * $margin)
    $driveHeight = [int]($driveWidth * 0.62)
    $left = [int](($Width - $driveWidth) / 2)
    $top = [int](($Height - $driveHeight) / 2)

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 73, 196, 122), $stroke)
    $graphics.DrawRectangle($pen, $left, $top, $driveWidth, $driveHeight)

    $indicatorSize = [Math]::Max(3, [int]($size * 0.10))
    $indicator = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 73, 196, 122))
    $graphics.FillEllipse(
        $indicator,
        $left + $driveWidth - $indicatorSize - $stroke,
        $top + $driveHeight - $indicatorSize - $stroke,
        $indicatorSize,
        $indicatorSize
    )

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $indicator.Dispose()
    $pen.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

New-DriveRescueAsset (Join-Path $assetsRoot "StoreLogo.png") 50 50
New-DriveRescueAsset (Join-Path $assetsRoot "Square44x44Logo.png") 44 44
New-DriveRescueAsset (Join-Path $assetsRoot "Square71x71Logo.png") 71 71
New-DriveRescueAsset (Join-Path $assetsRoot "Square150x150Logo.png") 150 150
New-DriveRescueAsset (Join-Path $assetsRoot "Wide310x150Logo.png") 310 150
New-DriveRescueAsset (Join-Path $assetsRoot "Square310x310Logo.png") 310 310

$sdkBinRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin"
$sdkVersion = Get-ChildItem $sdkBinRoot -Directory |
    Sort-Object Name -Descending |
    Where-Object { Test-Path (Join-Path $_.FullName "x64/makeappx.exe") } |
    Select-Object -First 1

if (-not $sdkVersion) {
    throw "Windows SDK MakeAppx.exe was not found."
}

$makeAppx = Join-Path $sdkVersion.FullName "x64/makeappx.exe"
Write-Output "Packing MSIX with MakeAppx..."
& $makeAppx pack /d $packageRoot /p $msixPath /o
if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed with exit code $LASTEXITCODE."
}

# Partner Center signs accepted MSIX packages. Store uploads do not need a
# developer certificate, so the CI runner never creates or handles a private key.
$uploadStaging = Join-Path $outputRoot "upload"
New-Item $uploadStaging -ItemType Directory -Force | Out-Null
Copy-Item $msixPath $uploadStaging
$temporaryZip = Join-Path $outputRoot "DriveRescueAssistant_$($Version)_x64.zip"
Write-Output "Creating Microsoft Store upload archive..."
Compress-Archive -Path (Join-Path $uploadStaging "*") -DestinationPath $temporaryZip
Move-Item $temporaryZip $uploadPath

Write-Output $uploadPath
