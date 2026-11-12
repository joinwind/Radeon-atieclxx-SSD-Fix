# Radeon-atieclxx-SSD-Fix – Guard. Runs as SYSTEM via the task "Radeon-atieclxx-SSD-Fix" (3 minutes after startup and every 30 minutes).
# Keeps the targeted protection up to date and, after a driver change, checks whether AMD has fixed the bug.
. (Join-Path $PSScriptRoot 'Core.ps1')

$proc = Get-AmdProcess
if (-not $proc) { return }   # service not running (e.g. disabled): nothing to do
$ident = ''
try { $ident = $proc.MainModule.FileVersionInfo.FileVersion + ' | ' + $proc.MainModule.FileName } catch { try { $ident = [string]$proc.Path } catch {} }
$z = $null
if (Test-Path -LiteralPath $script:StateFile) { try { $z = Get-Content -LiteralPath $script:StateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
function Remember([string]$Finding) {
  try {
    New-Item -ItemType Directory -Force -Path $script:InstallDir | Out-Null
    [pscustomobject]@{ Ident = $ident; Finding = $Finding; Date = (Get-Date -Format s) } | ConvertTo-Json | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
  } catch {}
}
function KB([double]$Bytes) { '{0:N0} KB/s' -f ([math]::Max($Bytes, 0) / 1KB) }
$same = [bool]($z -and $z.Ident -eq $ident)

if (Test-Protection) {
  if ($same) { return }                                     # normal case: protection in place, driver unchanged
  if (-not $z) { Remember 'Bug'; Write-Log ('Guard set up, protection active (driver ' + $ident + ').'); return }
  # Driver changed: lift the protection briefly and measure whether the bug still exists.
  Remove-Protection | Out-Null
  $b = Measure-WriteRate 8
  if ($b -lt 0) { Set-Protection | Out-Null; return }
  if ($b -lt $script:WriteThreshold) {
    Remember 'Fixed'
    Write-Log ('New driver (' + $ident + '): no more continuous writing (' + (KB $b) + '). AMD has fixed the bug, the protection stays lifted.')
    return
  }
  $ok = Set-Protection
  Start-Sleep -Seconds 2
  $n = Measure-WriteRate 8
  if ($ok -and $n -ge 0 -and $n -lt $script:WriteThreshold) {
    Remember 'Bug'
    Write-Log ('New driver (' + $ident + '): the bug persists (' + (KB $b) + '), protection set again, afterwards ' + (KB $n) + '.')
  } else {
    Remember 'Other'
    Write-Log ('WARNING: New driver (' + $ident + ') keeps writing despite the protection (' + (KB $n) + '). Please open Radeon-atieclxx-SSD-Fix and choose "Disable service".')
    Send-Notice 'Radeon-atieclxx-SSD-Fix: The AMD driver keeps writing to the SSD despite the protection. Please open Radeon-atieclxx-SSD-Fix and choose "Disable service".'
  }
  return
}

# No protection set (e.g. after a driver update that replaced the file): measure.
$b = Measure-WriteRate 8
if ($b -lt 0) { return }
if ($b -lt $script:WriteThreshold) {
  if (-not ($same -and $z.Finding -eq 'Fixed')) { Remember 'Fixed'; Write-Log ('No continuous writing (' + (KB $b) + ', driver ' + $ident + '), nothing to do.') }
  return
}
if ($same -and $z.Finding -eq 'Other') { return }           # already reported for this driver
$ok = Set-Protection
$n = $b
if ($ok) { Start-Sleep -Seconds 2; $n = Measure-WriteRate 8 }
if ($ok -and $n -ge 0 -and $n -lt $script:WriteThreshold) {
  Save-ProtectionFinding -Kind 'Protection' -RateBefore $b
  Remember 'Bug'
  Write-Log ('Bug detected (' + (KB $b) + ', driver ' + $ident + '), protection set, afterwards ' + (KB $n) + '.')
} else {
  Remember 'Other'
  Write-Log ('WARNING: atieclxx.exe writes continuously (' + (KB $b) + '), the targeted protection does not work here. Please open Radeon-atieclxx-SSD-Fix and choose "Disable service".')
  Send-Notice 'Radeon-atieclxx-SSD-Fix: The AMD driver writes continuously to the SSD, the targeted protection does not work here. Please open Radeon-atieclxx-SSD-Fix and choose "Disable service".'
}
