# Shared release metadata and packaging primitives. Dot-source from entry scripts.
function Get-Project {
    $root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
    # The version is game/src/core/build.lua (the simulation stamps it on
    # journals); title and QA output are game/src/app/release.lua.
    $build = [IO.File]::ReadAllText((Join-Path $root 'game\src\core\build.lua'))
    $identity = [IO.File]::ReadAllText((Join-Path $root 'game\src\app\release.lua'))
    $values = @{}
    foreach ($entry in @(@('version', $build), @('title', $identity), @('qaOutput', $identity))) {
        $key = $entry[0]
        $match = [regex]::Match($entry[1], "(?m)\b" + $key + "\s*=\s*'([^']+)'")
        if (-not $match.Success) { throw "Missing literal release metadata: $key" }
        $values[$key] = $match.Groups[1].Value
    }
    if ($values.version -notmatch '^\d+\.\d+(\.\d+)?$') { throw 'Invalid release version.' }
    $qa = Assert-ChildPath (Join-Path $root $values.qaOutput) (Join-Path $root 'work')
    $releaseName = 'SIGIL-BREACH-' + $values.version
    return [PSCustomObject]@{
        Root = $root; Source = (Join-Path $root 'game'); Qa = $qa
        Version = $values.version; Title = $values.title; Name = $releaseName
        Release = (Join-Path $root ('outputs\' + $releaseName))
        Zip = (Join-Path $root ('outputs\' + $releaseName + '-Windows.zip'))
        RenderEvidence = @('lighting-review.txt','weapon-carry-readability.txt',
            'movement-impact-clocks.csv','impact-review-clocks.txt',
            'detail-review-v17.txt','detail-review-v17.csv','detail-contacts-v17.csv',
            'detail-shot-revolver-sequence.png','detail-shot-shotgun-sequence.png',
            'detail-carry-revolver-sequence.png','firing-review-v19.txt','firing-review-v19.csv',
            'firing-exorcist-empty-range-weapon-sequence.png','firing-judge-empty-range-weapon-sequence.png',
            'firing-exorcist-imp-sequence.png','firing-judge-armored-sequence.png',
            'summoning-review-v23.txt','summoning-review-v23.csv',
            'summoning-opening-arrival-sequence.png','summoning-cohort-colors-sequence.png',
            'summoning-live-leap-sequence.png','summoning-live-evade-sequence.png',
            'hit-fit.txt','hit-fit.csv','hit-shots.txt','hit-dying.txt','hit-engine.txt',
            'hit-frame-rects.csv','hit-landmarks-boss-9.png','hit-landmarks-imp-16.png',
            'hit-gpu.csv','hit-timing.csv','hit-performance.txt','hit-performance.csv',
            'hit-outcomes.txt','hit-outcomes.csv','hit-outcomes-summary.csv',
            'hit-outcomes-mousepress.txt','hit-outcomes-mousepress.csv','hit-outcomes-mousepress-summary.csv',
            'hit-outcomes-press-buffer.txt','hit-outcomes-press-buffer.csv','hit-outcomes-press-buffer-summary.csv',
            'weapon-material.txt','weapon-material-comparison.png',
            'hit-overlay-claw-active.png','hit-overlay-falling-body.png','hit-overlay-boss-exposed.png',
            'creature-pigment.txt','pigment-leap-before.png','pigment-leap-after.png',
            'pigment-evade-before.png','pigment-evade-after.png',
            'pigment-leap-frames.png','pigment-evade-frames.png',
            'pigment-leap-shade.png','pigment-leap-flash.png','pigment-leap-swapped.png',
            'pigment-evade-shade.png','pigment-evade-flash.png','pigment-evade-swapped.png',
            'ritual-review.txt','foundation-ui-review.txt',
            '02-stolas-pad-near.png','02-stolas-pad-near-4by3.png','02-stolas-pad-near-large.png',
            '04-buer-pad.png','05-asmoday-pad.png','06-weapon-refill-pads.png',
            '07-west-altar-close.png','09-focused-board.png','10-spawn-portal.png',
            'loading-1280x720.png','loading-1024x768.png','loading-1920x1080.png',
            'charge-handoff-on-0.png','charge-handoff-on-8.png','charge-handoff-on-17.png',
            'charge-handoff-on-50.png','charge-handoff-on-100.png',
            'charge-handoff-off-0.png','charge-handoff-off-8.png','charge-handoff-off-17.png',
            'charge-handoff-off-50.png','charge-handoff-off-100.png',
            'charge-return-on.png','charge-return-off.png')
        Documents = @('docs\INSTRUKCJA.txt', ('docs\ZMIANY-' + $values.version + '.txt'),
            'docs\ARCHITEKTURA.txt', 'docs\DEVELOPMENT.txt', 'docs\ROZSZERZANIE.txt', 'docs\SYSTEM-SWIATA-0.14.txt',
            'docs\KIERUNEK-ARTYSTYCZNY.txt', 'docs\MANIFEST-NIKOGO.txt',
            'docs\ANATOMIA-I-FIZYKA-0.28.txt', 'docs\PLAN-ROZWOJU-v7.md', ('docs\ODBIOR-' + $values.version + '.txt'))
    }
}

function Assert-ChildPath([string]$Path, [string]$Root) {
    $full = [IO.Path]::GetFullPath($Path)
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not $full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must stay inside '$base': $full"
    }
    return $full
}

function Write-Archive([string]$Root, [string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
    $archive = $null
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
        foreach ($file in (Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName)) {
            $name = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $destinationStream = $entry.Open(); $sourceStream = [IO.File]::OpenRead($file.FullName)
            try { $sourceStream.CopyTo($destinationStream) }
            finally { $sourceStream.Dispose(); $destinationStream.Dispose() }
        }
    }
    finally { if ($archive) { $archive.Dispose() }; $stream.Dispose() }
}

function Hash-Stream([IO.Stream]$Stream) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($Stream))).Replace('-', '') }
    finally { $hash.Dispose() }
}

function Check-Hash([string]$Expected, [string]$Actual, [string]$Description) {
    if ($Expected -ne $Actual) { throw ('SHA-256 mismatch: ' + $Description) }
}

function Last-Write([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Get-Item -LiteralPath $Path).LastWriteTimeUtc }
    return [DateTime]::MinValue
}

function Require-Fresh([string]$Path, [DateTime]$Started, [DateTime]$Previous) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Test did not create its report: $Path" }
    $current = (Get-Item -LiteralPath $Path).LastWriteTimeUtc
    if ($current -lt $Started -or $current -eq $Previous) { throw "Report was not freshly rewritten: $Path" }
}

function Invoke-IsolatedGame([string]$Executable, [string[]]$Arguments, [string]$Root,
    [string]$Qa, [string]$Name, [int]$TimeoutSeconds = 300) {
    $stdout = Join-Path $Qa ($Name + '.stdout.txt')
    $stderr = Join-Path $Qa ($Name + '.stderr.txt')
    $started = [DateTime]::UtcNow
    # The child must write into this invocation's directory even when the caller
    # uses a custom QA override for a separate manual investigation.
    $previousQa = $env:SIGIL_UI_QA_DIR
    try {
        $env:SIGIL_UI_QA_DIR = $Qa
        $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    }
    finally { $env:SIGIL_UI_QA_DIR = $previousQa }
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        throw "Timeout: $Name. See $stdout and $stderr."
    }
    $process.WaitForExit(); $process.Refresh()
    if ($process.ExitCode -ne 0) { throw "Failed: $Name; exit $($process.ExitCode). See $stdout and $stderr." }
    return [PSCustomObject]@{Started=$started; Finished=[DateTime]::UtcNow; ExitCode=$process.ExitCode; Stdout=$stdout; Stderr=$stderr}
}
