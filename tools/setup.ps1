# Link the Godot Motion Kit into addons\ (a directory junction: no admin
# rights or Developer Mode needed). The puppets use its 2D cutout rig.
#   .\tools\setup.ps1                        # kit from the vendor\ submodule
#   .\tools\setup.ps1 -KitsDir C:\dev        # kit from a sibling checkout
param([string]$KitsDir = "")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if ($KitsDir -ne "") {
    $mk = Join-Path $KitsDir "godot-motion-kit"
} else {
    git submodule update --init --depth 1
    $mk = Join-Path $PWD "vendor\godot-motion-kit"
}

New-Item -ItemType Directory -Force -Path addons | Out-Null
$src = (Resolve-Path (Join-Path $mk "addons\motion_kit")).Path
$dst = Join-Path $PWD "addons\motion_kit"
if (Test-Path $dst) { (Get-Item $dst).Delete() }   # removes the junction, not its target
New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
Write-Host "addons\motion_kit -> $src"
