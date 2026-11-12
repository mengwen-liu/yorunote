[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Keystore,
    [Parameter(Mandatory = $true)][string]$KeyAlias,
    [string]$BuildTools,
    [string]$KeystorePasswordEnv
)

$ErrorActionPreference = 'Stop'
if (-not $BuildTools) {
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk -and $env:LOCALAPPDATA) {
        $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    }
    if (-not $sdk) { throw 'Specify -BuildTools (Android SDK Build-Tools 36.0.0).' }
    $BuildTools = Join-Path $sdk 'build-tools/36.0.0'
}
$signerName = 'apksigner'
$aaptName = 'aapt2'
$alignName = 'zipalign'
if ($env:OS -eq 'Windows_NT') {
    $signerName = 'apksigner.bat'
    $aaptName = 'aapt2.exe'
    $alignName = 'zipalign.exe'
}
$signer = Join-Path $BuildTools $signerName
$aapt = Join-Path $BuildTools $aaptName
$align = Join-Path $BuildTools $alignName
foreach ($tool in @($signer, $aapt, $align)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing SDK tool: $tool" }
}
$keystorePath = (Resolve-Path -LiteralPath $Keystore).Path
$passwordOptions = @()
if ($KeystorePasswordEnv) {
    if ($KeystorePasswordEnv -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        -not [Environment]::GetEnvironmentVariable($KeystorePasswordEnv)) {
        throw 'The specified keystore password environment variable is missing or invalid.'
    }
    $passwordOptions = @('--ks-pass', "env:$KeystorePasswordEnv")
}

$packages = @(
    @{
        Input = 'Yorunote-0.1.0-android-arm64-unsigned.apk'
        Output = 'Yorunote-0.1.0-android-arm64.apk'
        Code = 2172
    },
    @{
        Input = 'Yorunote-0.1.0-android-arm64-upgrade-base-unsigned.apk'
        Output = 'Yorunote-0.1.0-android-arm64-upgrade-base.apk'
        Code = 2162
    }
)
$checksums = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SHA256SUMS.txt')
foreach ($package in $packages) {
    $inputPath = Join-Path $PSScriptRoot $package.Input
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inputPath).Hash.ToLowerInvariant()
    if ($checksums -cnotcontains "$hash  $($package.Input)") {
        throw "Input checksum mismatch: $($package.Input)"
    }
}

$destination = Join-Path $PSScriptRoot 'signed'
if (Test-Path -LiteralPath $destination) {
    throw 'The signed folder already exists. Preserve it and run from a fresh copy.'
}
$temporary = Join-Path $PSScriptRoot ('.signing-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $fingerprints = @()
    $signedHashes = @()
    foreach ($package in $packages) {
        $inputPath = Join-Path $PSScriptRoot $package.Input
        $outputPath = Join-Path $temporary $package.Output
        & $signer sign --ks $keystorePath --ks-key-alias $KeyAlias @passwordOptions --v4-signing-enabled false --out $outputPath $inputPath
        if ($LASTEXITCODE -ne 0) { throw "Signing failed: $($package.Input)" }

        $verification = & $signer verify --verbose --print-certs $outputPath
        if ($LASTEXITCODE -ne 0) { throw "Signature verification failed: $($package.Output)" }
        $certificates = @($verification | Select-String -Pattern '^Signer #1 certificate SHA-256 digest: ([0-9a-f]{64})$')
        if ($certificates.Count -ne 1 -or $verification -cnotcontains 'Number of signers: 1') {
            throw "Unexpected signer count: $($package.Output)"
        }
        $fingerprints += $certificates[0].Matches[0].Groups[1].Value

        $badging = & $aapt dump badging $outputPath
        if ($LASTEXITCODE -ne 0) { throw "Cannot read APK manifest: $($package.Output)" }
        $manifest = "package: name='com.mengwenliu.yorunote' versionCode='$($package.Code)' versionName='0.1.0'"
        if (-not ($badging | Where-Object { $_.StartsWith($manifest) })) {
            throw "Unexpected package or version: $($package.Output)"
        }
        & $align -c 4 $outputPath
        if ($LASTEXITCODE -ne 0) { throw "ZIP alignment verification failed: $($package.Output)" }

        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash.ToLowerInvariant()
        $signedHashes += "$hash  $($package.Output)"
    }
    if ($fingerprints[0] -cne $fingerprints[1]) { throw 'The APKs have different signing certificates.' }
    $signedHashes | Set-Content -Encoding Ascii -LiteralPath (Join-Path $temporary 'SHA256SUMS.txt')
    $fingerprints[0] | Set-Content -Encoding Ascii -LiteralPath (Join-Path $temporary 'certificate.sha256')
    Move-Item -LiteralPath $temporary -Destination $destination
    Write-Output "Signed APKs: $destination"
    Write-Output "Certificate SHA-256: $($fingerprints[0])"
} finally {
    if (Test-Path -LiteralPath $temporary) {
        foreach ($name in @($packages.Output) + @('SHA256SUMS.txt', 'certificate.sha256')) {
            $file = Join-Path $temporary $name
            if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file }
        }
        if (-not (Get-ChildItem -Force -LiteralPath $temporary)) {
            Remove-Item -LiteralPath $temporary
        }
    }
}
