# Radeon-atieclxx-SSD-Fix – Remove (started by REMOVE.cmd with administrator rights).
# Reverts every change and deletes the program folder.
. (Join-Path $PSScriptRoot 'Core.ps1')
if (-not (Test-IsAdmin)) { Write-Host 'Please start this via REMOVE.cmd (administrator rights required).' -ForegroundColor Red; return }
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + ' - Remove')
Write-Host ''
Remove-All
& logman stop $script:TraceName -ets *> $null
Write-Host ('Task:       ' + $(if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) { 'still present!' } else { 'removed' }))
Write-Host ('Protection: ' + $(if (Test-Protection) { 'still active!' } else { 'removed' }))
Write-Host ('Service:    ' + (Get-ServiceText (Get-AmdService)))
if (Test-Path -LiteralPath $script:InstallDir) {
  $fromInside = $PSScriptRoot.StartsWith($script:InstallDir + '\', [StringComparison]::OrdinalIgnoreCase)
  if ($fromInside) {
    # Running from the program folder: delete only once this window is closed.
    $waitFor = $PID
    try {
      $me = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
      $parent = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $me.ParentProcessId)
      if ($parent -and $parent.Name -eq 'cmd.exe') { $waitFor = [int]$parent.ProcessId }
    } catch {}
    $command = 'Wait-Process -Id ' + $waitFor + ' -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; Remove-Item -LiteralPath ''' + $script:InstallDir + ''' -Recurse -Force -ErrorAction SilentlyContinue'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList ('-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + $enc) -WindowStyle Hidden -WorkingDirectory $env:SystemRoot
    Write-Host ('Folder:     will be deleted after this window is closed (' + $script:InstallDir + ')')
  } else {
    Remove-Item -LiteralPath $script:InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ('Folder:     ' + $(if (Test-Path -LiteralPath $script:InstallDir) { 'could not be deleted' } else { 'deleted' }))
  }
}
Write-Host ''
Write-Host 'Everything reverted. With affected drivers, atieclxx.exe now copies itself every second again.' -ForegroundColor Yellow
