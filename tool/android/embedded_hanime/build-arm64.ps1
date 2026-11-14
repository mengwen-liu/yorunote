
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FlutterRoot,
    [Parameter(Mandatory)][string]$AndroidSdk,
    [Parameter(Mandatory)][string]$JavaHome,
    [Parameter(Mandatory)][string]$RustupHome,
    [Parameter(Mandatory)][string]$CMakeRoot,
    [string]$CargoHome,
    [string]$GradleHome,
    [switch]$Offline
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$work = Join-Path $repo '.local-data/build-env'
$env:FLUTTER_ROOT = (Resolve-Path -LiteralPath $FlutterRoot).Path
$env:ANDROID_HOME = (Resolve-Path -LiteralPath $AndroidSdk).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_HOME = (Resolve-Path -LiteralPath $JavaHome).Path
$env:RUSTUP_HOME = (Resolve-Path -LiteralPath $RustupHome).Path
$cmake = (Resolve-Path -LiteralPath $CMakeRoot).Path
if ($CargoHome) { $env:CARGO_HOME = (Resolve-Path -LiteralPath $CargoHome).Path }
if ($GradleHome) { $env:GRADLE_USER_HOME = (Resolve-Path -LiteralPath $GradleHome).Path }
foreach ($p in $repo, $env:FLUTTER_ROOT, $env:ANDROID_HOME, $env:JAVA_HOME, $env:RUSTUP_HOME, $cmake, $env:CARGO_HOME, $env:GRADLE_USER_HOME) {
    if (!$p) { continue }
    if ($p -match '[^\x00-\x7F]' -or (Get-Item -LiteralPath $p).LinkType) { throw "Physical ASCII path required for native Windows toolchain: $p" }
}
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
$env:RUSTUP_TOOLCHAIN = '1.85.1-x86_64-pc-windows-gnu'
$gnu = Join-Path $env:RUSTUP_HOME "toolchains/$env:RUSTUP_TOOLCHAIN/lib/rustlib/x86_64-pc-windows-gnu/bin/self-contained"
$env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = Join-Path $gnu 'x86_64-w64-mingw32-gcc.exe'
$cargoBin = if ($env:CARGO_HOME) { Join-Path $env:CARGO_HOME 'bin' } else { Join-Path $env:USERPROFILE '.cargo/bin' }
$env:PATH = "$gnu;$cargoBin;$cmake/bin;$env:FLUTTER_ROOT/bin;$env:JAVA_HOME/bin;$env:PATH"
$env:PUB_CACHE = Join-Path $work 'pub'
$env:ANDROID_USER_HOME = Join-Path $work 'android-user'
$env:YORUNOTE_ANDROID_UNSIGNED = 'true'
$env:YORUNOTE_ANDROID_CANDIDATE = 'false'
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'
$env:R2_DEBUG_STORE = Join-Path $work 'candidate-debug.jks'

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE) { throw "$Program exited $LASTEXITCODE" }
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
Push-Location $repo
try {
    if (!(Test-Path -LiteralPath $env:R2_DEBUG_STORE)) {
        Invoke-Checked "$env:JAVA_HOME/bin/keytool.exe" @('-genkeypair','-keystore',$env:R2_DEBUG_STORE,
            '-alias','androiddebugkey','-storepass','android','-keypass','android','-keyalg','RSA',
            '-keysize','2048','-validity','365','-dname','CN=Yorunote ARM64 Debug,O=Local Test')
    }
    $gradleOptions = @('--console=plain','-Pkotlin.compiler.execution.strategy=in-process')
    $pubOptions = @('pub','get','--enforce-lockfile')
    if ($Offline) {
        $gradleOptions += '--offline'
        $pubOptions += '--offline'
    }
    Invoke-Checked 'flutter.bat' $pubOptions
    Invoke-Checked 'python' @("$PSScriptRoot/prepare.py", 'pub', $env:PUB_CACHE)
    $library = @(& python "$PSScriptRoot/prepare.py" library)
    if ($LASTEXITCODE) { throw "Library source preparation exited $LASTEXITCODE" }
    Push-Location $library[-1]
    try {
        Invoke-Checked '.\gradlew.bat' ($gradleOptions + @('-I',"$PSScriptRoot/publish-local.gradle",
            ':app:testDebugUnitTest', ':app:publishDebugPublicationToR3LocalRepository',
            ':yenaly_libs:publishDebugPublicationToR3LocalRepository'))
    } finally {
        Pop-Location
    }

    $properties = 'android/local.properties'
    $lines = if (Test-Path -LiteralPath $properties) {
        Get-Content -LiteralPath $properties | Where-Object { $_ -notmatch '^(sdk|flutter|cmake)\.dir=|^flutter\.sdk=' }
    }
    $lines = @($lines | Where-Object { $_ }) + @(
        "sdk.dir=$($env:ANDROID_HOME.Replace('\','/'))",
        "flutter.sdk=$($env:FLUTTER_ROOT.Replace('\','/'))",
        "cmake.dir=$($cmake.Replace('\','/'))"
    )
    $lines | Set-Content -LiteralPath $properties -Encoding ascii
    Invoke-Checked 'flutter.bat' @('build','apk','--debug','--no-pub','--target-platform','android-arm64','--build-name=0.2.0')
} finally {
    Pop-Location
}
