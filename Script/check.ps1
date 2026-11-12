# Radeon-atieclxx-SSD-Fix – quick status, no administrator rights needed.
. (Join-Path $PSScriptRoot 'Core.ps1')
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + ' - Status')
Write-Host ''
$t = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
$installed = [bool]$t -or (Test-Path -LiteralPath (Join-Path $script:InstallDir 'Script\guard.ps1'))
if ($t) {
  $i = $null
  try { $i = Get-ScheduledTaskInfo -TaskName $script:TaskName -ErrorAction Stop } catch {}
  Write-Host 'Guard:   set up' -ForegroundColor Green
  if ($i) {
    $last = $(if ($i.LastRunTime -and $i.LastRunTime.Year -ge 2000) { $i.LastRunTime.ToString('yyyy-MM-dd HH:mm') } else { 'not yet' })
    $next = $(if ($i.NextRunTime) { $i.NextRunTime.ToString('yyyy-MM-dd HH:mm') } else { 'unknown' })
    Write-Host ('  last run: ' + $last + '   next run: ' + $next)
  }
} elseif ($installed) { Write-Host 'Guard:   set up (details readable with administrator rights only)' -ForegroundColor Green }
else { Write-Host 'Guard:   not set up' -ForegroundColor Yellow }
Write-Host ('Service: ' + (Get-ServiceText (Get-AmdService)))
if (Test-Path -LiteralPath $script:LogFile) {
  Write-Host 'Latest log entries:'
  Get-Content -LiteralPath $script:LogFile -Tail 5 -Encoding UTF8 | ForEach-Object { Write-Host ('  ' + $_) }
}
Write-Host ''
if (-not (Get-AmdProcess)) { Write-Host 'atieclxx.exe is not running - no write load.' -ForegroundColor Green; return }
Write-Host 'Measuring for 10 seconds ...'
$rate = Measure-WriteRate 10
if ($rate -lt 0) { Write-Host 'atieclxx.exe was terminated during the measurement.'; return }
Write-Host ('atieclxx.exe writes {0:N0} KB/s (about {1:N1} GB per day if it keeps going)' -f ($rate / 1KB), ($rate * 86400 / 1e9))
if ($rate -ge $script:WriteThreshold) {
  if ($installed) { Write-Host 'AFFECTED: atieclxx.exe writes continuously. The guard acts on its next run; to act immediately: START.cmd.' -ForegroundColor Red }
  else { Write-Host 'AFFECTED: atieclxx.exe writes continuously. Run START.cmd and choose a fix.' -ForegroundColor Red }
} else { Write-Host 'OK: no continuous write load.' -ForegroundColor Green }
