#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Project = 'dev.project.json',
    [string]$Definitions = '',
    [string]$OutDir = ''
)
. (Join-Path $PSScriptRoot 'tools.ps1')
. (Join-Path $PSScriptRoot 'type-diagnostics.ps1')
$repoRoot = Get-PackageRoot
if (-not $OutDir) { $OutDir = '.verification/typechecks/' + [guid]::NewGuid().ToString('N') }
$evidence = [IO.Path]::GetFullPath($OutDir, $repoRoot)
if (Test-Path -LiteralPath $evidence) { throw "Use a fresh -OutDir; '$evidence' already exists." }
New-Item -ItemType Directory -Path $evidence | Out-Null
$pwsh = (Get-Process -Id $PID).Path
$arguments = @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'analyze.ps1'), '-Project', $Project)
if ($Definitions) { $arguments += @('-Definitions', $Definitions) }
$positiveDir = Join-Path $evidence 'accepted'
$positive = Invoke-PackageTool $pwsh ($arguments + @('-OutDir', $positiveDir))
if ($positive.ExitCode -ne 0 -or $positive.Output -match 'TypeError:|SyntaxError:|\[ERROR\]') {
    throw "Accepted type surface failed: $($positive.Output)"
}
$probePath = Join-Path $evidence 'rejected.luau'
Copy-Item -LiteralPath (Join-Path $repoRoot 'tests/typechecks/rejected.luau.txt') -Destination $probePath
$expected = Get-ContractExpectations @($probePath) $repoRoot
$negativeDir = Join-Path $evidence 'rejected'
$relativeProbe = [IO.Path]::GetRelativePath($repoRoot, $probePath)
$negative = Invoke-PackageTool $pwsh ($arguments + @('-Paths', $relativeProbe, '-OutDir', $negativeDir))
$summaryPath = Join-Path $negativeDir 'summary.json'
if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) { throw "Analyzer failed before capture: $($negative.Output)" }
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
if (-not $summary.captureValid -or $summary.exitCode -ne $negative.ExitCode) { throw 'Invalid analyzer capture or wrapper/native exit mismatch.' }
$raw = [IO.File]::ReadAllText((Join-Path $negativeDir 'raw.txt'))
$count = Test-ContractDiagnostics $raw $negative.ExitCode $expected $repoRoot
@{ passed = $true; rejectedExpressions = $count; expectedLocations = @($expected.Keys | Sort-Object) } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $negativeDir 'expectations.json')
Write-Output "PASS: accepted promise API and $count rejected expressions, no unexpected diagnostics; $evidence"
