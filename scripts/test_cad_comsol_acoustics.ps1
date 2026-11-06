param(
 [Parameter(Mandatory=$true)][string]$ProjectRoot,
 [string]$ComsolBin='',
 [string]$UvExe=(Join-Path $env:USERPROFILE '.local\bin\uvx.exe'),
 [string]$PythonInstallDir=(Join-Path $env:USERPROFILE '.local\share\uv\python'),
 [string]$CadgenVersion='0.7.15',
 [ValidateSet('standard','native-approved')][string]$ExecutionContextTag='standard',
 [ValidateRange(0,168)][double]$CacheMaxAgeHours=24,
 [switch]$Force
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'resolve_comsol.ps1')
$ComsolBin=Resolve-ComsolBin -ComsolBin $ComsolBin
$root=(Resolve-Path -LiteralPath $ProjectRoot).Path
$compile=Join-Path $ComsolBin 'comsolcompile.exe'
$batch=Join-Path $ComsolBin 'comsolbatch.exe'
foreach($file in @($compile,$batch,$UvExe)){if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw "Missing executable: $file"}}
$template=Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\CadComsolPreflight.java.template'
$runtimeArgs=@('--no-config','--managed-python','--python','3.13','--from',"cadgen==$CadgenVersion")
$env:UV_PYTHON_INSTALL_DIR=$PythonInstallDir
$state=Join-Path $root '.cad-comsol-preflight'
New-Item -ItemType Directory -Force -Path $state | Out-Null
$fingerprint=[ordered]@{
 script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
 resolver=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'resolve_comsol.ps1') -Algorithm SHA256).Hash
 template=(Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash
 comsol_bin=(Resolve-Path -LiteralPath $ComsolBin).Path
 batch_size=(Get-Item -LiteralPath $batch).Length
 batch_modified=(Get-Item -LiteralPath $batch).LastWriteTimeUtc.ToString('o')
 uvx=(Get-FileHash -LiteralPath $UvExe -Algorithm SHA256).Hash
 python_install_dir=$PythonInstallDir
 cadgen_version=$CadgenVersion
 execution_context=$ExecutionContextTag
}
$key=$fingerprint | ConvertTo-Json -Compress
$cache=Join-Path $state 'passed.json'
if(!$Force -and (Test-Path -LiteralPath $cache)){
 $prior=Get-Content -LiteralPath $cache -Raw | ConvertFrom-Json
 $fresh=([DateTime]::Now-[DateTime]::Parse($prior.verified_at)).TotalHours -lt $CacheMaxAgeHours
 if($fresh -and $prior.fingerprint -eq $key -and (Test-Path -LiteralPath $prior.csv) -and (Test-Path -LiteralPath $prior.marker)){
  if((Get-FileHash -LiteralPath $prior.csv -Algorithm SHA256).Hash -eq $prior.csv_sha256){
   Write-Output "PASS (cached): CAD runtime, STEP import, 200 Hz solve and CSV export. Report: $cache"
   return
  }
 }
}
$probe=Join-Path $state ('run-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $probe | Out-Null
$encoding=[Text.UTF8Encoding]::new($false)
$javaRoot=$probe.Replace('\','/').Replace('"','\"')
$java=[IO.File]::ReadAllText($template).Replace('__PROBE_ROOT__',$javaRoot)
[IO.File]::WriteAllText((Join-Path $probe 'CadComsolPreflight.java'),$java,$encoding)
$python=@'
from cadgen import build123d as bd, step
@step
def preflight_duct():
    return bd.Solid.make_cylinder(5,30,bd.Plane(origin=(-15,0,0),z_dir=(1,0,0)))
if __name__=='__main__':
    preflight_duct()
'@
[IO.File]::WriteAllText((Join-Path $probe 'preflight_duct.py'),$python,$encoding)
$prefs=Join-Path $probe 'prefs'
New-Item -ItemType Directory -Path $prefs | Out-Null
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\comsol.prefs.template') -Destination (Join-Path $prefs 'comsol.prefs')
Push-Location $probe
try {
 & $UvExe @runtimeArgs python preflight_duct.py *> 'cad.log'
 if($LASTEXITCODE -ne 0){throw 'CAD runtime failed; inspect cad.log'}
 & $compile CadComsolPreflight.java *> 'compile.log'
 # comsolcompile can return 0 after a failed compile, so require the artifact.
 if(($LASTEXITCODE -ne 0) -or -not(Test-Path -LiteralPath 'CadComsolPreflight.class')){throw 'Java compilation failed; inspect compile.log'}
 & $batch -prefsdir $prefs -inputfile CadComsolPreflight.class -nosave -batchlogout -batchlog (Join-Path $probe 'batch.log') *> 'stdout.log'
 if(!(Test-Path -LiteralPath 'passed.marker')){throw 'Native STEP/acoustic/export check failed; inspect batch.log and stdout.log. Do not launch the full solve.'}
 $csv=Join-Path $probe 'probe.csv'
 $rows=@(Get-Content -LiteralPath $csv | Where-Object { $_.Trim() -and $_ -notmatch '^%' })
 if($rows.Count -ne 1){throw 'Expected one exported frequency row'}
 $record=[ordered]@{fingerprint=$key;verified_at=[DateTime]::Now.ToString('o');csv=$csv;csv_sha256=(Get-FileHash -LiteralPath $csv -Algorithm SHA256).Hash;marker=(Join-Path $probe 'passed.marker');metrics=(Get-Content -LiteralPath 'passed.marker' -Raw).Trim()}
 [IO.File]::WriteAllText($cache,($record | ConvertTo-Json -Depth 4),$encoding)
 Write-Output "PASS: $($record.metrics)"
 Write-Output "Environment report: $cache"
} catch {
 Write-Output "FAIL: $($_.Exception.Message)"
 Write-Output "Retained logs: $probe"
 throw
} finally {Pop-Location}
