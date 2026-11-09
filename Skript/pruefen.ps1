# Radeon-atieclxx-SSD-Fix – schneller Status, ohne Administratorrechte.
. (Join-Path $PSScriptRoot 'Kern.ps1')
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + ' - Status')
Write-Host ''
$t = Get-ScheduledTask -TaskName $script:AufgabeName -ErrorAction SilentlyContinue
$eingerichtet = [bool]$t -or (Test-Path -LiteralPath (Join-Path $script:InstallDir 'Skript\schutz.ps1'))
if ($t) {
  $i = $null
  try { $i = Get-ScheduledTaskInfo -TaskName $script:AufgabeName -ErrorAction Stop } catch {}
  Write-Host 'Automatik: eingerichtet' -ForegroundColor Green
  if ($i) {
    $letzter = $(if ($i.LastRunTime -and $i.LastRunTime.Year -ge 2000) { $i.LastRunTime.ToString('dd.MM.yyyy HH:mm') } else { 'noch nicht' })
    $naechster = $(if ($i.NextRunTime) { $i.NextRunTime.ToString('dd.MM.yyyy HH:mm') } else { 'unbekannt' })
    Write-Host ('  letzter Lauf: ' + $letzter + '   nächster Lauf: ' + $naechster)
  }
} elseif ($eingerichtet) { Write-Host 'Automatik: eingerichtet (Details nur mit Adminrechten lesbar)' -ForegroundColor Green }
else { Write-Host 'Automatik: nicht eingerichtet' -ForegroundColor Yellow }
Write-Host ('Dienst:    ' + (Get-DienstText (Get-AmdDienst)))
if (Test-Path -LiteralPath $script:ProtokollDatei) {
  Write-Host 'Letzte Einträge im Protokoll:'
  Get-Content -LiteralPath $script:ProtokollDatei -Tail 5 -Encoding UTF8 | ForEach-Object { Write-Host ('  ' + $_) }
}
Write-Host ''
if (-not (Get-AmdProzess)) { Write-Host 'atieclxx.exe läuft nicht - keine Schreiblast.' -ForegroundColor Green; return }
Write-Host 'Messe 10 Sekunden lang ...'
$rate = Measure-Schreibrate 10
if ($rate -lt 0) { Write-Host 'atieclxx.exe wurde während der Messung beendet.'; return }
Write-Host ('atieclxx.exe schreibt {0:N0} KB/s (ca. {1:N1} GB pro Tag im Dauerbetrieb)' -f ($rate / 1KB), ($rate * 86400 / 1e9))
if ($rate -ge $script:SchreibGrenze) {
  if ($eingerichtet) { Write-Host 'BETROFFEN: atieclxx.exe schreibt dauerhaft. Die Automatik greift beim nächsten Lauf, sofort: START.cmd.' -ForegroundColor Red }
  else { Write-Host 'BETROFFEN: atieclxx.exe schreibt dauerhaft. START.cmd ausführen und einen Fix wählen.' -ForegroundColor Red }
} else { Write-Host 'OK: keine Dauerschreiblast.' -ForegroundColor Green }
