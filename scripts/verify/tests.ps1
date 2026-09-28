[CmdletBinding()]
param(
	[string[]]$Spec = @("tests\lune\promise.spec.luau", "tests\lune\promiseAllocation.spec.luau")
)

$ErrorActionPreference = "Stop"

function Resolve-RokitBinary {
	param([string]$Name)

	$rokitBin = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".rokit\bin"
	foreach ($fileName in @("$Name.exe", $Name)) {
		$binaryPath = Join-Path $rokitBin $fileName
		if (Test-Path -LiteralPath $binaryPath -PathType Leaf) {
			return $binaryPath
		}
	}

	throw "Rokit-managed '$Name' binary was not found in '$rokitBin'. Run 'rokit install' from the repository root."
}

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
foreach ($suite in $Spec) {
	$specPath = Join-Path $repoRoot $suite
	if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) {
		throw "Promise spec was not found at '$specPath'."
	}
}

$lune = Resolve-RokitBinary "lune"

Push-Location $repoRoot
try {
	foreach ($suite in $Spec) {
		& $lune "run" $suite
		if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	}
	exit 0
} finally {
	Pop-Location
}

