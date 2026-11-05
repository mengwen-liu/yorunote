param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [Parameter(Mandatory=$true)][ValidateSet('distribution','seed','restart')][string]$Phase
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Restricted to disposable Windows CI.' }
$exePath = (Resolve-Path -LiteralPath $Exe).Path
$evidencePath = [IO.Path]::GetFullPath($Evidence)
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
if (-not $evidencePath.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Evidence must stay inside RUNNER_TEMP.'
}
[IO.Directory]::CreateDirectory($evidencePath) | Out-Null
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
if ($version.ProductName -ne 'Yorunote' -or $version.OriginalFilename -ne 'yorunote.exe') {
    throw 'Unexpected Windows product identity.'
}
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class YorunoteCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
}
'@

function Save-AppWindow([Diagnostics.Process]$Process, [string]$Name) {
    $Process.Refresh()
    $handle = $Process.MainWindowHandle
    if ($handle -eq [IntPtr]::Zero) {
        return @{captured=$false; reason='No top-level window handle'}
    }
    $rect = New-Object YorunoteCapture+RECT
    if (-not [YorunoteCapture]::GetWindowRect($handle, [ref]$rect)) {
        return @{captured=$false; reason='Cannot read window bounds'}
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 100 -or $height -lt 100 -or $width -gt 4096 -or $height -gt 4096) {
        return @{captured=$false; reason='Unexpected window bounds'}
    }
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $method = 'PrintWindow'
    try {
        $dc = $graphics.GetHdc()
        try { $printed = [YorunoteCapture]::PrintWindow($handle, $dc, 2) }
        finally { $graphics.ReleaseHdc($dc) }
        $colours = [Collections.Generic.HashSet[int]]::new()
        for ($y=0; $y -lt $height; $y+=37) {
            for ($x=0; $x -lt $width; $x+=37) {
                [void]$colours.Add($bitmap.GetPixel($x,$y).ToArgb())
            }
        }
        if (-not $printed -or $colours.Count -lt 4) {
            $method = 'CopyFromScreen'
            $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
            $colours.Clear()
            for ($y=0; $y -lt $height; $y+=37) {
                for ($x=0; $x -lt $width; $x+=37) {
                    [void]$colours.Add($bitmap.GetPixel($x,$y).ToArgb())
                }
            }
        }
        if ($colours.Count -lt 4) {
            return @{captured=$false; reason='Capture blank or unavailable'; method=$method}
        }
        $destination = Join-Path $evidencePath ($Name + '.png')
        $bitmap.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
        return @{captured=$true; file=($Name+'.png'); method=$method; width=$width; height=$height; sampled_colours=$colours.Count}
    } catch {
        return @{captured=$false; reason=$_.Exception.Message; method=$method}
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$env:YORUNOTE_SMOKE_EVIDENCE = $evidencePath
$env:YORUNOTE_SMOKE_PHASE = $Phase
$seen = [Collections.Generic.HashSet[string]]::new()
$captures = [Collections.Generic.List[object]]::new()
$process = $null
try {
    $process = Start-Process -FilePath $exePath -WorkingDirectory (Get-Location).Path -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $evidencePath ($Phase+'-stdout.log')) -RedirectStandardError (Join-Path $evidencePath ($Phase+'-stderr.log'))
    $deadline = [DateTime]::UtcNow.AddSeconds(240)
    $windowSince = $null
    $distributionVerified = $false
    while (-not $process.HasExited) {
        if ([DateTime]::UtcNow -gt $deadline) { throw ('App timed out: ' + $Phase) }
        $process.Refresh()
        if ($Phase -eq 'distribution') {
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                if ($null -eq $windowSince) { $windowSince = [DateTime]::UtcNow }
                if (([DateTime]::UtcNow - $windowSince).TotalSeconds -ge 10) {
                    if (-not $process.Responding) { throw 'Distributed executable is not responding.' }
                    $capture = Save-AppWindow $process 'distribution-home'
                    $captures.Add($capture)
                    if (-not $process.CloseMainWindow()) { throw 'Cannot close distributed application normally.' }
                    if (-not $process.WaitForExit(30000)) { throw 'Distributed application did not exit after close.' }
                    $distributionVerified = $true
                    break
                }
            }
        } else {
            $stageFile = Join-Path $evidencePath 'stage.json'
            if (Test-Path -LiteralPath $stageFile) {
                $stage = $null
                try { $stage = (Get-Content -LiteralPath $stageFile -Raw | ConvertFrom-Json).stage } catch {}
                if ($stage -match '^(seed|restart)-[a-zA-Z0-9-]+$' -and $seen.Add($stage)) {
                    $capture = Save-AppWindow $process $stage
                    $captures.Add(@{stage=$stage; capture=$capture})
                    [IO.File]::WriteAllText((Join-Path $evidencePath ('ack-'+$stage+'.json')), ($capture | ConvertTo-Json -Depth 5))
                }
            }
        }
        Start-Sleep -Milliseconds 150
    }
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    if ($Phase -eq 'distribution' -and -not $distributionVerified) {
        throw 'Distributed executable did not survive the full launch check.'
    }
    if ($exitCode -ne 0) { throw ('App exit code: ' + $exitCode + ', phase: ' + $Phase) }
    if ($Phase -ne 'distribution') {
        $reportFile = Join-Path $evidencePath ('smoke-'+$Phase+'.json')
        if (-not (Test-Path -LiteralPath $reportFile)) { throw 'Acceptance report was not written.' }
        $report = Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json
        if (-not $report.passed) { throw 'App acceptance report failed.' }
        if ($report.source -ne $env:YORUNOTE_SMOKE_SOURCE) { throw 'Acceptance source does not match.' }
    }
    $summary = @{
        phase=$Phase; exit_code=$exitCode; product=$version.ProductName
        original_filename=$version.OriginalFilename; captures=$captures.ToArray()
        scope='Disposable CI Windows desktop; synthetic fixtures only'
    }
    [IO.File]::WriteAllText((Join-Path $evidencePath ('process-'+$Phase+'.json')), ($summary | ConvertTo-Json -Depth 7))
    $summary | ConvertTo-Json -Depth 7
} finally {
    if ($null -ne $process -and -not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(15000)) {
            Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        }
    }
}
