# Radeon-atieclxx-SSD-Fix – Entfernen (wird von ENTFERNEN.cmd mit Administratorrechten gestartet).
# Nimmt alle Eingriffe zurück und löscht den Programmordner.
. (Join-Path $PSScriptRoot 'Kern.ps1')
if (-not (Test-IstAdmin)) { Write-Host 'Bitte über ENTFERNEN.cmd starten (Administratorrechte nötig).' -ForegroundColor Red; return }
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + ' - Entfernen')
Write-Host ''
Remove-Alles
& logman stop $script:TraceName -ets *> $null
Write-Host ('Aufgabe:  ' + $(if (Get-ScheduledTask -TaskName $script:AufgabeName -ErrorAction SilentlyContinue) { 'noch vorhanden!' } else { 'entfernt' }))
Write-Host ('Schutz:   ' + $(if (Test-Schutz) { 'noch aktiv!' } else { 'entfernt' }))
Write-Host ('Dienst:   ' + (Get-DienstText (Get-AmdDienst)))
if (Test-Path -LiteralPath $script:InstallDir) {
  $vonDrinnen = $PSScriptRoot.StartsWith($script:InstallDir + '\', [StringComparison]::OrdinalIgnoreCase)
  if ($vonDrinnen) {
    # Läuft aus dem Programmordner: erst löschen, wenn dieses Fenster geschlossen ist.
    $warte = $PID
    try {
      $ich = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
      $eltern = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $ich.ParentProcessId)
      if ($eltern -and $eltern.Name -eq 'cmd.exe') { $warte = [int]$eltern.ProcessId }
    } catch {}
    $befehl = 'Wait-Process -Id ' + $warte + ' -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; Remove-Item -LiteralPath ''' + $script:InstallDir + ''' -Recurse -Force -ErrorAction SilentlyContinue'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($befehl))
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList ('-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + $enc) -WindowStyle Hidden -WorkingDirectory $env:SystemRoot
    Write-Host ('Ordner:   wird nach dem Schließen dieses Fensters gelöscht (' + $script:InstallDir + ')')
  } else {
    Remove-Item -LiteralPath $script:InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ('Ordner:   ' + $(if (Test-Path -LiteralPath $script:InstallDir) { 'konnte nicht gelöscht werden' } else { 'gelöscht' }))
  }
}
Write-Host ''
Write-Host 'Alles zurückgenommen. Bei betroffenen Treibern kopiert sich atieclxx.exe jetzt wieder jede Sekunde.' -ForegroundColor Yellow
