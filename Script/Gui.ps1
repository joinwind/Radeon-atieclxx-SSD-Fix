# Radeon-atieclxx-SSD-Fix – Window with analysis, damage estimate and fix buttons.
# Start via START.cmd (with administrator rights). Measurements run in the background, the window stays usable.
# Test: $Global:AMDFIX_NOSHOW = $true; $Global:AMDFIX_TEST = $true; . .\Gui.ps1; $f = Build-Form
$script:ScriptDir = $PSScriptRoot
$script:CoreFile = Join-Path $PSScriptRoot 'Core.ps1'
. $script:CoreFile
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Ctrl = @{}
$script:Async = $null
$script:Last = $null
$script:Quitting = $false
$script:Timer = $null
$script:Mutex = $null
$script:TestMessages = New-Object System.Collections.ArrayList
$script:Sync = [hashtable]::Synchronized(@{ Phase = ''; End = [datetime]::MinValue })
$script:NL = [Environment]::NewLine
$script:Color = @{
  Red    = [System.Drawing.Color]::FromArgb(176, 0, 32)
  Green  = [System.Drawing.Color]::FromArgb(30, 120, 54)
  Orange = [System.Drawing.Color]::FromArgb(176, 96, 0)
  Gray   = [System.Drawing.Color]::FromArgb(90, 90, 90)
  Text   = [System.Drawing.Color]::FromArgb(32, 32, 32)
}

# Runs in its own runspace: perform the action, then analyze again.
$script:BackgroundScript = {
  param($core, $action, $source, $rateBefore, $sync)
  . $core
  $script:Progress = $sync
  $result = @{}
  switch ($action) {
    'Protection' {
      Set-Phase 'Setting the targeted protection'
      $ok = Set-Protection
      $task = $false
      if ($ok) {
        Save-ProtectionFinding -Kind 'Protection' -RateBefore $rateBefore -AllowAssumption
        Set-Phase 'Setting up the guard'
        $task = Install-Task -Source $source
        Write-Log 'Targeted protection set via the GUI.'
      }
      $result = @{ Ok = $ok; Task = $task }
    }
    'Service' {
      Set-Phase 'Disabling the service'
      $r = Disable-AmdService
      if ($r -eq 'OK' -or $r -eq 'StillRunning') {
        Save-ProtectionFinding -Kind 'Service' -RateBefore $rateBefore
        Write-Log 'Service disabled via the GUI.'
      }
      $result = @{ Result = $r }
    }
    'Revert' {
      Set-Phase 'Reverting all changes'
      Remove-All
      Write-Log 'All changes reverted via the GUI.'
      $result = @{ Ok = $true }
    }
  }
  $analysis = Get-Analysis -MeasureSeconds 8
  [pscustomobject]@{ Action = $action; Result = $result; Analysis = $analysis }
}

# ------------------------------------------------------------------ Helper functions
function Show-Message {
  param([string]$Text, [string]$Buttons = 'OK', [string]$Icon = 'Information', [string]$Title = 'Radeon-atieclxx-SSD-Fix')
  if ($Global:AMDFIX_TEST) { [void]$script:TestMessages.Add($Text); if ($Buttons -eq 'YesNo') { return 'Yes' }; return 'OK' }
  $f = $script:Ctrl.Form
  if ($f -and -not $f.IsDisposed -and $f.Visible) { return [string][System.Windows.Forms.MessageBox]::Show($f, $Text, $Title, $Buttons, $Icon) }
  return [string][System.Windows.Forms.MessageBox]::Show($Text, $Title, $Buttons, $Icon)
}
function Format-Rate([double]$b) {
  if ($b -lt 0) { return 'not measurable' }
  if ($b -ge 1MB) { return ('{0:N2} MB/s' -f ($b / 1MB)) }
  return ('{0:N0} KB/s' -f ($b / 1KB))
}
function Format-Amount([double]$Bytes) {
  if ($Bytes -ge 1e11) { return ('{0:N1} TB' -f ($Bytes / 1e12)) }
  return ('{0:N0} GB' -f ($Bytes / 1e9))
}
function New-Label($Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Text = '') {
  $l = New-Object System.Windows.Forms.Label
  $l.Location = New-Object System.Drawing.Point($X, $Y)
  $l.Size = New-Object System.Drawing.Size($W, $H)
  $l.Text = $Text
  $Parent.Controls.Add($l)
  return $l
}
function New-Button($Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Text) {
  $k = New-Object System.Windows.Forms.Button
  $k.Location = New-Object System.Drawing.Point($X, $Y)
  $k.Size = New-Object System.Drawing.Size($W, $H)
  $k.Text = $Text
  $Parent.Controls.Add($k)
  return $k
}
function New-Group($Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Text) {
  $g = New-Object System.Windows.Forms.GroupBox
  $g.Location = New-Object System.Drawing.Point($X, $Y)
  $g.Size = New-Object System.Drawing.Size($W, $H)
  $g.Text = $Text
  $Parent.Controls.Add($g)
  return $g
}

# ------------------------------------------------------------------ Window
function Build-Form {
  $f = New-Object System.Windows.Forms.Form
  $f.SuspendLayout()
  $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
  $f.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
  $f.Text = 'Radeon-atieclxx-SSD-Fix ' + $script:Version
  $f.ClientSize = New-Object System.Drawing.Size(660, 620)
  $f.StartPosition = 'CenterScreen'
  $f.FormBorderStyle = 'FixedSingle'
  $f.MaximizeBox = $false
  $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
  $f.BackColor = [System.Drawing.Color]::White
  try { $f.Icon = [System.Drawing.SystemIcons]::Shield } catch {}
  $bold = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

  $head = New-Label $f 18 14 624 32 'Analyzing ...'
  $head.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
  $head.ForeColor = $script:Color.Gray
  $sub = New-Label $f 20 48 624 20 'Please wait a moment'
  $sub.ForeColor = $script:Color.Gray

  $g1 = New-Group $f 18 74 624 134 'Which bug is present?'
  $finding = New-Label $g1 14 22 596 104
  $g2 = New-Group $f 18 214 624 160 'Damage to the SSD so far (estimate)'
  $damage = New-Label $g2 14 22 596 130
  $g3 = New-Group $f 18 380 624 168 'Choose a fix'
  $btnProtect = New-Button $g3 16 26 250 40 'Targeted protection (recommended)'
  $l1 = New-Label $g3 276 26 334 42 'Stops only the self-copy. The service, FreeSync and Frame Pacing keep working normally.'
  $btnService = New-Button $g3 16 74 250 38 'Disable service'
  $l2 = New-Label $g3 276 74 334 40 'The variant from the article: reliable, but may impair FreeSync and Frame Pacing.'
  $btnRevert = New-Button $g3 16 120 250 36 'Revert everything'
  $l3 = New-Label $g3 276 120 334 40 'Reverts the protection, the guard and the service disabling.'
  foreach ($l in $l1, $l2, $l3) { $l.ForeColor = $script:Color.Gray }

  $btnCheck = New-Button $f 18 558 140 30 'Check again'
  $btnReBar = New-Button $f 166 558 180 30 'What is Resizable BAR?'
  $btnLog = New-Button $f 354 558 130 30 'Log'
  $btnHelp = New-Button $f 492 558 150 30 'Instructions'
  $foot = New-Label $f 20 594 624 22
  $foot.ForeColor = $script:Color.Gray

  $script:Ctrl = @{ Form = $f; Head = $head; Sub = $sub; Finding = $finding; Damage = $damage; Bold = $bold; Normal = $f.Font
    BtnProtect = $btnProtect; BtnService = $btnService; BtnRevert = $btnRevert; BtnCheck = $btnCheck
    BtnReBar = $btnReBar; BtnLog = $btnLog; BtnHelp = $btnHelp; Foot = $foot }
  foreach ($k in 'BtnProtect', 'BtnService', 'BtnRevert', 'BtnCheck') { $script:Ctrl[$k].Enabled = $false }
  $btnLog.Enabled = Test-Path -LiteralPath $script:LogFile

  $btnCheck.Add_Click({ Click-Check })
  $btnProtect.Add_Click({ Click-Protect })
  $btnService.Add_Click({ Click-Service })
  $btnRevert.Add_Click({ Click-Revert })
  $btnReBar.Add_Click({ Click-ReBar })
  $btnLog.Add_Click({ Click-Log })
  $btnHelp.Add_Click({ Click-Help })
  $f.Add_FormClosing({ On-Closing $_ })

  $script:Timer = New-Object System.Windows.Forms.Timer
  $script:Timer.Interval = 200
  $script:Timer.Add_Tick({ Tick-Background })

  $f.ResumeLayout($false)
  return $f
}

function Set-Buttons($a) {
  $c = $script:Ctrl
  $disabled = [bool]($a.Service -and [string]$a.Service.StartType -eq 'Disabled')
  $c.BtnProtect.Enabled = ($a.Status -eq 'AffectedSelfCopy') -or ($a.Status -eq 'Protected' -and -not $a.Task)
  $c.BtnService.Enabled = [bool]$a.Service -and -not $disabled
  $c.BtnRevert.Enabled = [bool]($a.Protection -or $a.Task -or $disabled -or $a.Finding)
  $c.BtnCheck.Enabled = $true
  $c.BtnLog.Enabled = Test-Path -LiteralPath $script:LogFile
  $c.BtnProtect.Font = $(if ($c.BtnProtect.Enabled) { $c.Bold } else { $c.Normal })
  $c.BtnService.Font = $(if ($a.Status -in 'AffectedOther', 'ProtectionFails') { $c.Bold } else { $c.Normal })
}
function Set-Interactive([bool]$On) {
  $c = $script:Ctrl
  if ($On) {
    if ($script:Last) { Set-Buttons $script:Last } else { $c.BtnCheck.Enabled = $true }
  } else {
    foreach ($k in 'BtnProtect', 'BtnService', 'BtnRevert', 'BtnCheck') { $c[$k].Enabled = $false }
  }
}

function Refresh-View {
  param($a)
  $c = $script:Ctrl
  if (-not $c.Form -or $c.Form.IsDisposed) { return }
  $head = @{
    NoService         = @('Not affected: no AMD External Events Utility', 'Green')
    ServiceDisabled   = @('Stopped: the service is disabled', 'Green')
    ServiceStopped    = @('The service is not running right now', 'Gray')
    MeasurementFailed = @('Measurement not possible', 'Orange')
    Protected         = @('Protected: the targeted protection is active', 'Green')
    NotAffected       = @('This PC is not affected', 'Green')
    AffectedSelfCopy  = @('Affected: continuous writing to the SSD', 'Red')
    AffectedOther     = @('Affected: continuous writing elsewhere', 'Red')
    ProtectionFails   = @('Warning: the protection does not work here', 'Red')
  }[[string]$a.Status]
  if (-not $head) { $head = @([string]$a.Status, 'Gray') }
  $c.Head.Text = $head[0]
  $c.Head.ForeColor = $script:Color[$head[1]]
  $c.Sub.Text = 'Measured at ' + $a.Time.ToString('HH:mm:ss') + '  –  ' + $(if ($a.Rate -lt 0) { 'atieclxx.exe is not running' } else { 'atieclxx.exe writes ' + (Format-Rate $a.Rate) })

  $z = New-Object System.Collections.ArrayList
  switch ([string]$a.Status) {
    'AffectedSelfCopy' {
      [void]$z.Add('atieclxx.exe keeps copying itself (about once per second) to:')
      [void]$z.Add('    ' + $script:TargetFile)
      [void]$z.Add('This is the known bug. The targeted protection stops exactly this copy.')
    }
    'AffectedOther' {
      [void]$z.Add('atieclxx.exe writes continuously, but not to the known location. Found:')
      if (@($a.Targets).Count) { foreach ($p in @($a.Targets)) { [void]$z.Add('    ' + $p) } } else { [void]$z.Add('    (target could not be determined)') }
      [void]$z.Add('The targeted protection does not fit here. Recommended: disable the service.')
    }
    'ProtectionFails' {
      [void]$z.Add('The targeted protection is set, yet the copy is still being written:')
      [void]$z.Add('    ' + $script:TargetFile)
      [void]$z.Add('Recommended: disable the service.')
    }
    'Protected' {
      [void]$z.Add('The SYSTEM account may no longer overwrite the copy:')
      [void]$z.Add('    ' + $script:TargetFile)
      [void]$z.Add('The self-copy fails immediately, the service keeps running normally.')
      [void]$z.Add('Guard for driver updates: ' + $(if ($a.Task) { 'set up' } else { 'missing - set it up with "Targeted protection"' }))
    }
    'ServiceDisabled' {
      [void]$z.Add('The service "AMD External Events Utility" is disabled. atieclxx.exe is not running and writes nothing.')
      [void]$z.Add('Downside: FreeSync and Frame Pacing may be impaired. Undo with "Revert everything".')
    }
    'NotAffected' { [void]$z.Add('atieclxx.exe is running but does not write continuously. No action needed.') }
    'ServiceStopped' { [void]$z.Add('The service is installed but not running right now. Please check again later.') }
    'NoService' { [void]$z.Add('This PC has no "AMD External Events Utility". It is not affected by this bug.') }
    'MeasurementFailed' { [void]$z.Add('atieclxx.exe was terminated or restarted during the measurement. Please check again.') }
  }
  $c.Finding.Text = ($z -join $script:NL)
  $c.Finding.ForeColor = $(if ($a.Affected) { $script:Color.Red } else { $script:Color.Text })

  $s = $a.Damage
  $ssdName = $(if ($a.Ssd -and $a.Ssd.Model) { [string]$a.Ssd.Model } else { 'System drive' })
  $d = New-Object System.Collections.ArrayList
  if (-not $s) {
    [void]$d.Add('No continuous writing detected - no damage from this bug can be measured.')
    if ($a.Ssd -and $a.Ssd.Wear) { [void]$d.Add(('Overall SSD wear according to the drive: {0} %.' -f $a.Ssd.Wear)) }
  } else {
    $until = $(if ($s.Active) { 'today' } else { $s.End.ToString('yyyy-MM-dd') })
    $from = $(if ($s.HoursSource -eq 'SSD') { 'according to the SSD' } else { 'assumed' })
    [void]$d.Add(('Period: {0} to {1} ({2} days), {3:N1} operating hours per day {4}.' -f $s.Since.ToString('yyyy-MM-dd'), $until, $s.Days, $s.HoursPerDay, $from))
    [void]$d.Add(('Written unnecessarily: about {0} to {1}.' -f (Format-Amount $s.Bytes), $ssdName))
    if ($s.PercentTbw) { [void]$d.Add(('About {0:N2} % of the usual write endurance rating of this SSD (around {1:N0} TB).' -f $s.PercentTbw, $s.TbwTB)) }
    if ($s.Wear) { [void]$d.Add(('Overall SSD wear according to the drive: {0} %.' -f $s.Wear)) }
    if ($s.Active) { [void]$d.Add(('As long as the bug is active, about {0:N0} GB per day are added.' -f $s.GbPerDay)) }
    else { [void]$d.Add('Nothing has been added since the fix.') }
    if ($s.Basis -eq 'Assumed') { [void]$d.Add('Rate before the protection unknown, assumed: one copy per second.') }
    [void]$d.Add('Estimate based on write rate and operating time since the AMD graphics device was installed.')
  }
  $c.Damage.Text = ($d -join $script:NL)

  $c.Foot.Text = 'Service: ' + (Get-ServiceText $a.Service) + '   |   Protection: ' + $(if ($a.Protection) { 'active' } else { 'off' }) + '   |   Guard: ' + $(if ($a.Task) { 'on' } else { 'off' }) + '   |   ' + $ssdName
  Set-Buttons $a
}

# ------------------------------------------------------------------ Background work
function Start-Background([string]$Action) {
  if ($script:Async) { return }
  $c = $script:Ctrl
  Set-Interactive $false
  $title = @{ Analysis = 'Analyzing ...'; Protection = 'Setting the targeted protection ...'; Service = 'Disabling the service ...'; Revert = 'Reverting everything ...' }[$Action]
  $c.Head.Text = $title
  $c.Head.ForeColor = $script:Color.Gray
  $c.Sub.Text = 'Please wait a moment'
  $script:Sync.Phase = ''
  $script:Sync.End = [datetime]::MinValue
  $rateBefore = $(if ($script:Last) { [double]$script:Last.Rate } else { -1.0 })
  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass
  $rs = [runspacefactory]::CreateRunspace($iss)
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript($script:BackgroundScript.ToString()).AddArgument($script:CoreFile).AddArgument($Action).AddArgument($script:ScriptDir).AddArgument($rateBefore).AddArgument($script:Sync)
  $script:Async = @{ PS = $ps; RS = $rs; Action = $Action; Handle = $ps.BeginInvoke() }
  $script:Timer.Start()
}
function Tick-Background {
  try {
    $a = $script:Async
    if (-not $a) { $script:Timer.Stop(); return }
    if (-not $a.Handle.IsCompleted) {
      try {
        $ph = [string]$script:Sync.Phase
        if ($ph) {
          $end = [datetime]$script:Sync.End
          $text = $ph + ' ...'
          if ($end -gt [datetime]::MinValue) {
            $sec = ($end - (Get-Date)).TotalSeconds
            if ($sec -gt 0 -and $sec -lt 3600) { $text = $ph + ' - ' + [math]::Ceiling($sec) + ' s left' }
          }
          $script:Ctrl.Sub.Text = $text
        }
      } catch {}   # a faulty progress display must never abort the running work
      return
    }
    $script:Timer.Stop()
    $res = @(); $err = ''
    try { $res = @($a.PS.EndInvoke($a.Handle)) } catch { $err = $_.Exception.Message }
    if (-not $err -and $a.PS.Streams.Error.Count) { $err = [string]$a.PS.Streams.Error[0] }
    try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {}
    $script:Async = $null
    if ($script:Quitting -or $script:Ctrl.Form.IsDisposed) { return }
    $pack = $res | Where-Object { $_ -and $_.PSObject.Properties['Analysis'] } | Select-Object -Last 1
    if (-not $pack -or -not $pack.Analysis) {
      $script:Ctrl.Head.Text = 'Analysis failed'
      $script:Ctrl.Head.ForeColor = $script:Color.Orange
      $script:Ctrl.Sub.Text = 'Please try "Check again"'
      Set-Interactive $true
      Show-Message ('The analysis failed.' + $script:NL + $err) 'OK' 'Warning' | Out-Null
      return
    }
    $script:Last = $pack.Analysis
    Refresh-View $pack.Analysis
    Report-Action $pack
  } catch {
    # If the background work is still running, keep waiting instead of losing track of it
    # (otherwise two actions could overlap).
    $a = $script:Async
    if ($a -and -not $a.Handle.IsCompleted) { return }
    try { $script:Timer.Stop() } catch {}
    if ($a) { try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {} }
    $script:Async = $null
    Set-Interactive $true
    Show-Message ('Unexpected error: ' + $_.Exception.Message) 'OK' 'Error' | Out-Null
  }
}
function Stop-Background {
  try { if ($script:Timer) { $script:Timer.Stop() } } catch {}
  $a = $script:Async
  $script:Async = $null
  if ($a) {
    try { $a.PS.Stop() } catch {}
    try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {}
  }
  & logman stop $script:TraceName -ets *> $null   # in case a trace was running
}
function Report-Action($p) {
  $e = $p.Result
  switch ([string]$p.Action) {
    'Protection' {
      if ($e.Ok) {
        $auto = $(if ($e.Task) { 'The guard is set up: it checks at startup and every 30 minutes, sets the protection again after driver updates and lifts it as soon as AMD has fixed the bug.' }
                  else { 'The guard could not be set up. The protection works nonetheless, until a driver update replaces the file.' })
        Show-Message ('Targeted protection set. The self-copy is stopped, the service keeps running.' + $script:NL + $script:NL + $auto) 'OK' 'Information' | Out-Null
      } else {
        Show-Message 'The protection could not be set: the copy was not found or permissions are missing.' 'OK' 'Warning' | Out-Null
      }
    }
    'Service' {
      $t = switch ([string]$e.Result) {
        'OK'           { 'The service is disabled, atieclxx.exe is no longer running.' }
        'StillRunning' { 'The service is disabled, but atieclxx.exe is still running. It will be gone after a restart.' }
        'NoService'    { 'The service was not found.' }
        default        { 'The service could not be disabled.' }
      }
      Show-Message $t 'OK' $(if ([string]$e.Result -eq 'OK') { 'Information' } else { 'Warning' }) | Out-Null
    }
    'Revert' { Show-Message ('All changes have been reverted.' + $script:NL + 'The program folder is kept. To remove it completely: REMOVE.cmd.') 'OK' 'Information' | Out-Null }
  }
}

# ------------------------------------------------------------------ Buttons
function Show-Error($Err) { Set-Interactive $true; Show-Message ('Unexpected error: ' + $Err.Exception.Message) 'OK' 'Error' | Out-Null }
function Click-Check { try { Start-Background 'Analysis' } catch { Show-Error $_ } }
function Click-Protect { try { Start-Background 'Protection' } catch { Show-Error $_ } }
function Click-Service {
  try {
    $r = Show-Message ('Disable the service "AMD External Events Utility"?' + $script:NL + $script:NL +
      'This reliably stops the writing, but may impair FreeSync and Frame Pacing. You can undo it any time with "Revert everything".') 'YesNo' 'Warning'
    if ($r -eq 'Yes') { Start-Background 'Service' }
  } catch { Show-Error $_ }
}
function Click-Revert {
  try {
    $r = Show-Message 'Revert all changes (protection, guard, service disabling)?' 'YesNo' 'Question'
    if ($r -eq 'Yes') { Start-Background 'Revert' }
  } catch { Show-Error $_ }
}
function Click-ReBar {
  Show-Message ('Resizable BAR (called "Smart Access Memory" by AMD) lets the processor access the entire graphics memory at once and brings a little more performance in many games.' + $script:NL + $script:NL +
    'The article suggests turning Resizable BAR off in the BIOS, because the bug sits in the Smart Access Memory part of the driver. That can help, but costs performance depending on the game and can only be changed in the BIOS, not from here.' + $script:NL + $script:NL +
    'The targeted protection solves the problem without touching Resizable BAR.') 'OK' 'Information' 'What is Resizable BAR?' | Out-Null
}
function Click-Log {
  if (Test-Path -LiteralPath $script:LogFile) { Start-Process notepad.exe -ArgumentList ('"' + $script:LogFile + '"') }
  else { Show-Message 'No log yet.' | Out-Null }
}
function Click-Help {
  $file = Join-Path (Split-Path -Parent $script:ScriptDir) 'README.txt'
  if (-not (Test-Path -LiteralPath $file)) { $file = Join-Path $script:InstallDir 'README.txt' }
  if (Test-Path -LiteralPath $file) { Start-Process notepad.exe -ArgumentList ('"' + $file + '"') }
  else { Show-Message 'The instructions (README.txt) were not found.' | Out-Null }
}
function On-Closing($e) {
  if ($script:Async -and $script:Async.Action -ne 'Analysis') {
    Show-Message 'Please wait until the running action has finished.' | Out-Null
    $e.Cancel = $true
    return
  }
  $script:Quitting = $true
  Stop-Background
}

# ------------------------------------------------------------------ Start
if (-not $Global:AMDFIX_NOSHOW) {
  try {
    if (-not (Test-IsAdmin)) {
      # Restart with administrator rights (same PowerShell version).
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = (Get-Process -Id $PID).Path
      $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $PSCommandPath + '"'
      $psi.Verb = 'runas'
      $psi.UseShellExecute = $true
      try { [void][System.Diagnostics.Process]::Start($psi) } catch {}   # Windows prompt declined
      return
    }
    $isNew = $false
    $script:Mutex = New-Object System.Threading.Mutex($true, 'Global\Radeon-atieclxx-SSD-Fix-Gui', [ref]$isNew)
    if (-not $isNew) {
      [void][System.Windows.Forms.MessageBox]::Show('Radeon-atieclxx-SSD-Fix is already open.', 'Radeon-atieclxx-SSD-Fix', 'OK', 'Information')
      $script:Mutex.Dispose()
      $script:Mutex = $null
      return
    }
    & logman stop $script:TraceName -ets *> $null    # end leftovers of an aborted trace
    $form = Build-Form
    $form.Add_Shown({ $this.Activate(); Start-Background 'Analysis' })
    [void]$form.ShowDialog()
  } catch {
    $text = 'Radeon-atieclxx-SSD-Fix could not be run:' + $script:NL + $_.Exception.Message
    try { Add-Content -LiteralPath (Join-Path $env:TEMP 'Radeon-atieclxx-SSD-Fix-error.txt') -Value ((Get-Date -Format s) + '  ' + $_.Exception.ToString()) -Encoding UTF8 } catch {}
    try { [void][System.Windows.Forms.MessageBox]::Show($text, 'Radeon-atieclxx-SSD-Fix', 'OK', 'Error') } catch {}
  } finally {
    if (Test-IsAdmin) { Stop-Background }
    if ($script:Timer) { try { $script:Timer.Dispose() } catch {} }
    if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() } catch {}; try { $script:Mutex.Dispose() } catch {} }
  }
}
