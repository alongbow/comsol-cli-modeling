param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
  [string]$ClassName,

  [Parameter(Mandatory = $true)]
  [string]$Destination,

  [string]$ComsolBin = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) {
  $existing = @(Get-ChildItem -LiteralPath $destinationPath -Force)
  if ($existing.Count -gt 0) {
    throw "Destination must be absent or empty: $destinationPath"
  }
} else {
  New-Item -ItemType Directory -Path $destinationPath | Out-Null
}

$skillRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $skillRoot 'assets'
$encoding = New-Object Text.UTF8Encoding($false)
$modelFilename = "$ClassName.mph"
$escapedComsolBin = $ComsolBin.Replace("'", "''")

function Expand-Template([string]$TemplatePath, [string]$OutputPath) {
  $content = [IO.File]::ReadAllText($TemplatePath)
  $content = $content.Replace('__CLASS_NAME__', $ClassName)
  $content = $content.Replace('__MODEL_FILENAME__', $modelFilename)
  $content = $content.Replace('__COMSOL_BIN__', $escapedComsolBin)
  [IO.File]::WriteAllText($OutputPath, $content, $encoding)
}

New-Item -ItemType Directory -Force -Path `
  (Join-Path $destinationPath 'results'), `
  (Join-Path $destinationPath 'figures'), `
  (Join-Path $destinationPath '.comsol-cli-prefs') | Out-Null

Expand-Template `
  (Join-Path $assets 'ComsolModel.java.template') `
  (Join-Path $destinationPath "$ClassName.java")
Expand-Template `
  (Join-Path $assets 'run_comsol.ps1.template') `
  (Join-Path $destinationPath 'run_comsol.ps1')
Copy-Item -LiteralPath (Join-Path $assets 'comsol.prefs.template') `
  -Destination (Join-Path $destinationPath '.comsol-cli-prefs\comsol.prefs')

Write-Host "Created COMSOL CLI project: $destinationPath"
Write-Host "Java source: $ClassName.java"
Write-Host 'Next: replace buildModel(), then run .\run_comsol.ps1'
