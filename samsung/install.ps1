# Baut CleanHome sauber neu und installiert es auf dem Samsung-TV.
#   powershell -ExecutionPolicy Bypass -File samsung\install.ps1
# Voraussetzungen: Tizen Studio, ein Samsung-Zertifikatsprofil, TV im Entwicklermodus und
# einmal "Permit to install applications" im Device Manager.
param(
  [string]$Tv = "UE55NU7179",
  [string]$TvAddress = "192.168.178.57:26101",
  [string]$Profile = "samsung-certificate",
  [string]$TizenStudio = "C:\tizen-studio"
)
$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "CleanHome"
# Immer ein frischer Ordner: ein altes .wgt im Paket macht die Signatur ungültig.
$build = Join-Path $env:TEMP "CleanHome-build"
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory $build | Out-Null
Copy-Item (Join-Path $src "*") $build -Recurse

$tizen = Join-Path $TizenStudio "tools\ide\bin\tizen.bat"
$sdb = Join-Path $TizenStudio "tools\sdb.exe"
& $sdb connect $TvAddress
& $tizen package -t wgt -s $Profile -- $build
& $tizen install -n CleanHome.wgt -t $Tv -- $build
& $tizen run -p CleanHm001.CleanHome -t $Tv
