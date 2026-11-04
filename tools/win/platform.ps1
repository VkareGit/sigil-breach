# Windows only: Linux has its own tools/linux/project.sh.
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Resolve-SigilCommand([string]$Name, [string]$Description) {
    if ($Name -and (Test-Path -LiteralPath $Name -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $Name).Path
    }
    $command = if ($Name) { Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($command) { return $command.Source }
    throw $Description
}

function Get-LoveRuntime([switch]$Console) {
    if ($env:SIGIL_LOVE) {
        return Resolve-SigilCommand $env:SIGIL_LOVE 'SIGIL_LOVE must name an existing LOVE 11.5 executable (without arguments).'
    }
    $name = if ($Console) { 'lovec.exe' } else { 'love.exe' }
    return Resolve-SigilCommand (Join-Path (Join-Path $repoRoot 'toolchain/love-11.5-win64') $name) 'Missing bundled LOVE 11.5 Windows runtime.'
}

function Get-Stylua {
    $bundled = Join-Path $repoRoot 'toolchain/stylua/stylua.exe'
    $selected = if ($env:SIGIL_STYLUA) { $env:SIGIL_STYLUA } else { $bundled }
    $formatter = Resolve-SigilCommand $selected 'Missing bundled StyLua; see toolchain/stylua/PROVENANCE.txt or set SIGIL_STYLUA.'
    if ($formatter -eq $bundled) {
        $expected = '8BE0383E979B3C699BF6BFBFC0770038534D071B0479FEE188636C4B54CD338B'
        if ((Get-FileHash -LiteralPath $formatter -Algorithm SHA256).Hash -ne $expected) { throw 'Bundled StyLua differs from pinned 2.6.0; see toolchain/stylua/PROVENANCE.txt.' }
    }
    $version = & $formatter --version
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^stylua 2\.6\.0\s*$') { throw "StyLua 2.6.0 is required; found: $version" }
    return $formatter
}

function Get-LoveDataRoot { return Join-Path $env:APPDATA 'LOVE' }

# Arguments here are already quoted for Start-Process.
function Start-SigilProcess([string]$Executable, [string[]]$Arguments, [string]$Root,
    [string]$Stdout, [string]$Stderr, [switch]$NoDisplay) {
    $options = @{ FilePath = $Executable; ArgumentList = $Arguments; WorkingDirectory = $Root; PassThru = $true; WindowStyle = 'Hidden' }
    if ($Stdout) { $options.RedirectStandardOutput = $Stdout }
    if ($Stderr) { $options.RedirectStandardError = $Stderr }
    return Start-Process @options
}

function Stop-SigilProcess([Diagnostics.Process]$Process) {
    Stop-Process -Id $Process.Id -Force
    $Process.WaitForExit()
}

# Interactive entry points preserve argument boundaries without a shell.
function Invoke-Love([string[]]$GameArguments) {
    & (Get-LoveRuntime) @GameArguments
    if ($LASTEXITCODE -ne 0) { throw "LOVE exited with code $LASTEXITCODE." }
}
