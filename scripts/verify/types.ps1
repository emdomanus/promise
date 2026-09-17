[CmdletBinding()]
param([string]$Project = "dev.project.json")
$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")
Push-Location $repoRoot
try {
    $positive = & "$PSScriptRoot/analyze.ps1" -Project $Project -Paths src, tests/typechecks 2>&1
    $positiveErrors = @($positive | Where-Object { $_ -match 'TypeError:|SyntaxError:' })
    if ($positiveErrors.Count -ne 0) { $positiveErrors; throw "Accepted type surface failed." }
    $probeDir = Join-Path $repoRoot '.verification/typechecks'
    New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
    $probePath = Join-Path $probeDir 'rejected.luau'
    Copy-Item -LiteralPath 'tests/typechecks/rejected.luau.txt' -Destination $probePath -Force
    $negative = & "$PSScriptRoot/analyze.ps1" -Project $Project -Paths .verification/typechecks/rejected.luau 2>&1
    $negative | Set-Content -LiteralPath (Join-Path $probeDir 'diagnostics.txt')
    $errors = @($negative | Where-Object { $_ -match 'rejected\.luau.*\(\d+,\d+\): TypeError:' })
    if ($errors.Count -ne 4) { $negative; throw "Expected 4 rejected type uses; found $($errors.Count)." }
    Write-Host 'PASS: typed promise API; rejects wrong resolution, await, observer, and private-state access.'
    exit 0
} finally { Pop-Location }
