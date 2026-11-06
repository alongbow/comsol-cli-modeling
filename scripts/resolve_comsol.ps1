function Test-ComsolBin([string]$Path) {
  return ((Test-Path -LiteralPath (Join-Path $Path 'comsolcompile.exe') -PathType Leaf) -and
          (Test-Path -LiteralPath (Join-Path $Path 'comsolbatch.exe') -PathType Leaf))
}

function Resolve-ComsolBin {
  param([string]$ComsolBin = '', [string]$ConfiguredComsolBin = '')
  # Never silently fall back to a different release after an explicit choice.
  foreach ($choice in @($ComsolBin, $env:COMSOL_BIN, $ConfiguredComsolBin)) {
    if ([string]::IsNullOrWhiteSpace($choice)) { continue }
    if (-not (Test-ComsolBin $choice)) {
      throw "COMSOL bin is invalid: $choice. Both comsolcompile.exe and comsolbatch.exe are required. Pass -ComsolBin with the installed bin\win64 directory."
    }
    return (Resolve-Path -LiteralPath $choice).Path
  }
  $candidates = New-Object 'System.Collections.Generic.List[string]'
  $command = Get-Command comsolcompile.exe -CommandType Application -ErrorAction SilentlyContinue
  if ($command) { $candidates.Add((Split-Path -Parent $command.Source)) }
  foreach ($registryRoot in @('HKLM:\SOFTWARE\COMSOL', 'HKLM:\SOFTWARE\WOW6432Node\COMSOL')) {
    foreach ($key in @(Get-ChildItem -LiteralPath $registryRoot -ErrorAction SilentlyContinue)) {
      $installation = Get-ItemProperty -LiteralPath $key.PSPath -Name COMSOLROOT -ErrorAction SilentlyContinue
      if ($installation -and $installation.COMSOLROOT) {
        $candidates.Add((Join-Path $installation.COMSOLROOT 'bin\win64'))
        $candidates.Add((Join-Path $installation.COMSOLROOT 'Multiphysics\bin\win64'))
      }
    }
  }
  # Enumerate levels explicitly: wildcard traversal can miss junction paths.
  $parents = @('C:\Program Files\COMSOL', 'D:\comsol', 'E:\comsol')
  if ($env:ProgramFiles) { $parents += (Join-Path $env:ProgramFiles 'COMSOL') }
  foreach ($parent in ($parents | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { continue }
    foreach ($directory in @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue)) {
      if ($directory.Name -like 'COMSOL*') {
        $candidates.Add((Join-Path $directory.FullName 'Multiphysics\bin\win64'))
      }
    }
  }
  $valid = @($candidates | Where-Object { Test-ComsolBin $_ } |
    ForEach-Object { (Resolve-Path -LiteralPath $_).Path } | Select-Object -Unique)
  if ($valid.Count -eq 1) { return $valid[0] }
  if ($valid.Count -gt 1) {
    throw ("Multiple COMSOL installations found. Select one with -ComsolBin or COMSOL_BIN:`n" + ($valid -join "`n"))
  }
  throw 'COMSOL was not found. Pass -ComsolBin or set COMSOL_BIN to the installed Multiphysics\bin\win64 directory.'
}
