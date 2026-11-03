param([string]$Source = (Join-Path (Split-Path -Parent $PSScriptRoot) 'game'), [string]$Report)
$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path -LiteralPath $Source).Path
$entries = @(Get-ChildItem -LiteralPath $Source -Recurse -Force)
$known = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
$leaves = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$issues = [Collections.Generic.List[string]]::new()
$checked = 0
foreach ($entry in $entries) {
    $relative = $entry.FullName.Substring($Source.Length + 1).Replace('\', '/')
    if ($known.ContainsKey($relative) -and $known[$relative] -cne $relative) {
        $issues.Add("CASE COLLISION: $relative / $($known[$relative])")
    } else { $known[$relative] = $relative }
    if (-not $entry.PSIsContainer) {
        if (-not $leaves.ContainsKey($entry.Name)) { $leaves[$entry.Name] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal) }
        [void]$leaves[$entry.Name].Add($entry.Name)
    }
}
# Compare against enumerated spellings, never Test-Path (case-insensitive on Windows).
# Literal prefixes are checked too: e.g. assets/sounds/ + family + /B1-1.wav.
# Dynamic suffixes remain covered by the runtime asset/registry tests.
foreach ($file in $entries | Where-Object { -not $_.PSIsContainer -and $_.Extension -in @('.lua', '.json') }) {
    $relative = $file.FullName.Substring($Source.Length + 1).Replace('\', '/')
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($match in [regex]::Matches($text, '[''"]([^''"/\\\r\n]+\.(?:png|jpg|wav|lua|json|txt|save))[''"]', 'IgnoreCase')) {
        $value = $match.Groups[1].Value
        if ($leaves.ContainsKey($value)) {
            $checked++
            if (-not $leaves[$value].Contains($value)) { $issues.Add("CASE: ${relative}: $value (expected $($leaves[$value] -join ', '))") }
        }
    }
    foreach ($match in [regex]::Matches($text, '[''"]((?:game/)?(?:assets|src|tests|qa|docs)[/.][^''"\r\n]*)[''"]', 'IgnoreCase')) {
        $value = $match.Groups[1].Value
        $path = $value -replace '^(?i)game/', ''
        if ($path -match '^(?i)(src|qa|tests|assets)\.[\w.-]+$') { $path = $path.Replace('.', '/') + '.lua' }
        $path = $path.TrimEnd('/')
        # A literal can end in a filename prefix before concatenation.
        while ($path -and -not $known.ContainsKey($path) -and $path.Contains('/')) { $path = $path.Substring(0, $path.LastIndexOf('/')) }
        if ($path -and $known.ContainsKey($path)) {
            $checked++
            if ($path -cne $known[$path]) {
                $line = 1 + [regex]::Matches($text.Substring(0, $match.Index), '\n').Count
                $issues.Add("CASE: ${relative}:${line}: $value (expected $($known[$path]))")
            }
        }
    }
}
$lines = @($issues) + @("PATH CASE: $checked references checked; $($issues.Count) issues.")
if ($Report) { [IO.File]::WriteAllLines($Report, [string[]]$lines, [Text.UTF8Encoding]::new($false)) }
$lines | ForEach-Object { Write-Host $_ }
if ($issues.Count) { throw 'Path case check failed.' }
