[CmdletBinding()]
param([string]$OutFile = '.verification/benchmark.txt', [switch]$Native)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
Push-Location $repoRoot
$previousNative = $env:PROMISE_BENCH_NATIVE
try {
    $env:PROMISE_BENCH_NATIVE = if ($Native) { '1' } else { '0' }
    $output = & "$PSScriptRoot/tests.ps1" -Spec 'tests/lune/promise.bench.luau' 2>&1
    $resultCode = $LASTEXITCODE
    $parent = Split-Path -Parent $OutFile
    if ($parent) { New-Item -ItemType Directory -Force $parent | Out-Null }
    $output | Set-Content -LiteralPath $OutFile -Encoding utf8
    $output | Write-Output
    exit $resultCode
} finally {
    $env:PROMISE_BENCH_NATIVE = $previousNative
    Pop-Location
}
