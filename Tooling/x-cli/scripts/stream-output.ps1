[CmdletBinding(PositionalBinding=$false)]
Param(
  [Parameter(Position=0, Mandatory=$true)]
  [string]$Command,
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Use ProcessStartInfo with ArgumentList to preserve individual
# argument boundaries and avoid quoting issues.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Command
foreach ($a in $Args) {
  [void]$psi.ArgumentList.Add($a)
}
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [Console]::OutputEncoding
$psi.StandardErrorEncoding  = [Console]::OutputEncoding

try {
  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $proc.Start() | Out-Null

  # Stream outputs in near real-time, including carriage-return updates (e.g., progress bars)
  $outReader = $proc.StandardOutput
  $errReader = $proc.StandardError
  while (-not $proc.HasExited -or -not $outReader.EndOfStream -or -not $errReader.EndOfStream) {
    try {
      while (-not $outReader.EndOfStream -and $outReader.Peek() -ne -1) {
        $ch = [char]$outReader.Read()
        [Console]::Out.Write($ch)
      }
    } catch {}
    try {
      while (-not $errReader.EndOfStream -and $errReader.Peek() -ne -1) {
        $ch = [char]$errReader.Read()
        [Console]::Error.Write($ch)
      }
    } catch {}
    Start-Sleep -Milliseconds 10
  }
  $exit = $proc.ExitCode
} finally {
  if ($null -ne $proc) { $proc.Dispose() }
}

exit $exit
