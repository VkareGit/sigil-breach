# Shared by Windows PowerShell 5.1 and PowerShell 7. Do not use $IsWindows:
# the automatic platform variables are absent in Windows PowerShell.
function Test-SigilWindows { return [IO.Path]::DirectorySeparatorChar -eq '\' }

function Resolve-SigilCommand([string]$Name, [string]$Description) {
    if ($Name -and (Test-Path -LiteralPath $Name -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $Name).Path
    }
    $command = if ($Name) { Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($command) { return $command.Source }
    throw $Description
}

function Get-LoveRuntime([switch]$Console) {
    $root = Split-Path -Parent $PSScriptRoot
    if ($env:SIGIL_LOVE) {
        return Resolve-SigilCommand $env:SIGIL_LOVE 'SIGIL_LOVE must name an existing LOVE 11.5 executable (without arguments).'
    }
    if (Test-SigilWindows) {
        $name = if ($Console) { 'lovec.exe' } else { 'love.exe' }
        return Resolve-SigilCommand (Join-Path (Join-Path $root 'toolchain/love-11.5-win64') $name) 'Missing bundled LOVE 11.5 Windows runtime.'
    }
    return Resolve-SigilCommand 'love' 'Install LOVE 11.5 and put love on PATH, or set SIGIL_LOVE to its executable. See docs/LINUX.md.'
}

function Get-Stylua {
    $root = Split-Path -Parent $PSScriptRoot
    $name = if (Test-SigilWindows) { 'stylua.exe' } else { 'stylua' }
    $bundled = Join-Path $root ('toolchain/stylua/' + $name)
    $selected = if ($env:SIGIL_STYLUA) { $env:SIGIL_STYLUA } elseif (Test-Path -LiteralPath $bundled -PathType Leaf) { $bundled } else { 'stylua' }
    $formatter = Resolve-SigilCommand $selected 'Install StyLua 2.6.0 (Linux release binary on PATH, or cargo install stylua --version 2.6.0 --locked --features luajit); alternatively set SIGIL_STYLUA. See docs/LINUX.md.'
    if ((Test-SigilWindows) -and $formatter -eq $bundled) {
        $expected = '8BE0383E979B3C699BF6BFBFC0770038534D071B0479FEE188636C4B54CD338B'
        if ((Get-FileHash -LiteralPath $formatter -Algorithm SHA256).Hash -ne $expected) { throw 'Bundled StyLua differs from pinned 2.6.0; see toolchain/stylua/PROVENANCE.txt.' }
    }
    $version = & $formatter --version
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^stylua 2\.6\.0\s*$') { throw "StyLua 2.6.0 is required; found: $version" }
    return $formatter
}

function Get-LoveDataRoot {
    if (Test-SigilWindows) { return Join-Path $env:APPDATA 'LOVE' }
    $base = if ($env:XDG_DATA_HOME -and [IO.Path]::IsPathRooted($env:XDG_DATA_HOME)) { $env:XDG_DATA_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/share' }
    return Join-Path $base 'love'
}

function Assert-WindowsPackaging {
    if (-not (Test-SigilWindows)) { throw 'EXE packaging and -Release are Windows-only. On Linux use ./RUN.ps1 or ./BUILD.ps1 without -Package.' }
}

# Arguments here are already quoted for Start-Process (also on PowerShell 7).
# Architecture disables graphics entirely and does not need an X server.
function Start-SigilProcess([string]$Executable, [string[]]$Arguments, [string]$Root,
    [string]$Stdout, [string]$Stderr, [switch]$NoDisplay) {
    $options = @{ FilePath = $Executable; ArgumentList = $Arguments; WorkingDirectory = $Root; PassThru = $true }
    if (Test-SigilWindows) { $options.WindowStyle = 'Hidden' }
    elseif (-not $NoDisplay -and -not $env:DISPLAY -and -not $env:WAYLAND_DISPLAY) {
        $options.FilePath = Resolve-SigilCommand 'xvfb-run' 'No DISPLAY/WAYLAND_DISPLAY. Install xvfb (including xauth), or run in a graphical desktop session.'
        $options.ArgumentList = @('-a', '--', ('"' + $Executable + '"')) + $Arguments
    }
    if ($Stdout) { $options.RedirectStandardOutput = $Stdout }
    if ($Stderr) { $options.RedirectStandardError = $Stderr }
    return Start-Process @options
}

function Stop-SigilProcess([Diagnostics.Process]$Process) {
    # Kill descendants too: xvfb-run owns both LOVE and the temporary X server.
    if (Test-SigilWindows) { Stop-Process -Id $Process.Id -Force }
    else { $Process.Kill($true) }
    $Process.WaitForExit()
}

# Interactive entry points preserve argument boundaries without a shell.
function Invoke-Love([string[]]$GameArguments) {
    $runtime = Get-LoveRuntime
    if (-not (Test-SigilWindows) -and -not $env:DISPLAY -and -not $env:WAYLAND_DISPLAY) {
        $xvfb = Resolve-SigilCommand 'xvfb-run' 'No display: install xvfb (including xauth), or use a graphical desktop.'
        & $xvfb -a $runtime @GameArguments
    }
    else { & $runtime @GameArguments }
    if ($LASTEXITCODE -ne 0) { throw "LOVE exited with code $LASTEXITCODE." }
}
