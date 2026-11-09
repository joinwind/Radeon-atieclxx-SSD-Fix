# Radeon-atieclxx-SSD-Fix – Wächter. Läuft als SYSTEM über die Aufgabe "Radeon-atieclxx-SSD-Fix" (3 Minuten nach dem Start und alle 30 Minuten).
# Hält den gezielten Schutz aktuell und prüft nach einem Treiberwechsel, ob AMD den Fehler behoben hat.
. (Join-Path $PSScriptRoot 'Kern.ps1')

$proz = Get-AmdProzess
if (-not $proz) { return }   # Dienst läuft nicht (z. B. deaktiviert): nichts zu tun
$kennung = ''
try { $kennung = $proz.MainModule.FileVersionInfo.FileVersion + ' | ' + $proz.MainModule.FileName } catch { try { $kennung = [string]$proz.Path } catch {} }
$z = $null
if (Test-Path -LiteralPath $script:ZustandDatei) { try { $z = Get-Content -LiteralPath $script:ZustandDatei -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
function Merken([string]$Befund) {
  try {
    New-Item -ItemType Directory -Force -Path $script:InstallDir | Out-Null
    [pscustomobject]@{ Kennung = $kennung; Befund = $Befund; Datum = (Get-Date -Format s) } | ConvertTo-Json | Set-Content -LiteralPath $script:ZustandDatei -Encoding UTF8
  } catch {}
}
function KB([double]$Bytes) { '{0:N0} KB/s' -f ([math]::Max($Bytes, 0) / 1KB) }
$gleich = [bool]($z -and $z.Kennung -eq $kennung)

if (Test-Schutz) {
  if ($gleich) { return }                                   # Normalfall: Schutz steht, Treiber unverändert
  if (-not $z) { Merken 'Fehler'; Write-Protokoll ('Wächter eingerichtet, Schutz aktiv (Treiber ' + $kennung + ').'); return }
  # Treiber gewechselt: Schutz kurz aufheben und messen, ob der Fehler noch besteht.
  Remove-Schutz | Out-Null
  $b = Measure-Schreibrate 8
  if ($b -lt 0) { Set-Schutz | Out-Null; return }
  if ($b -lt $script:SchreibGrenze) {
    Merken 'Behoben'
    Write-Protokoll ('Neuer Treiber (' + $kennung + '): keine Dauerschreiblast mehr (' + (KB $b) + '). AMD hat den Fehler behoben, der Schutz bleibt aufgehoben.')
    return
  }
  $ok = Set-Schutz
  Start-Sleep -Seconds 2
  $n = Measure-Schreibrate 8
  if ($ok -and $n -ge 0 -and $n -lt $script:SchreibGrenze) {
    Merken 'Fehler'
    Write-Protokoll ('Neuer Treiber (' + $kennung + '): Fehler besteht weiter (' + (KB $b) + '), Schutz wieder gesetzt, danach ' + (KB $n) + '.')
  } else {
    Merken 'Andere'
    Write-Protokoll ('WARNUNG: Neuer Treiber (' + $kennung + ') schreibt trotz Schutz weiter (' + (KB $n) + '). Bitte Radeon-atieclxx-SSD-Fix öffnen und "Dienst deaktivieren" wählen.')
    Send-Meldung 'Radeon-atieclxx-SSD-Fix: Der AMD-Treiber schreibt trotz Schutz dauerhaft auf die SSD. Bitte Radeon-atieclxx-SSD-Fix öffnen und "Dienst deaktivieren" wählen.'
  }
  return
}

# Kein Schutz gesetzt (z. B. nach einem Treiber-Update, das die Datei ersetzt hat): messen.
$b = Measure-Schreibrate 8
if ($b -lt 0) { return }
if ($b -lt $script:SchreibGrenze) {
  if (-not ($gleich -and $z.Befund -eq 'Behoben')) { Merken 'Behoben'; Write-Protokoll ('Keine Dauerschreiblast (' + (KB $b) + ', Treiber ' + $kennung + '), nichts zu tun.') }
  return
}
if ($gleich -and $z.Befund -eq 'Andere') { return }       # bei diesem Treiber schon gemeldet
$ok = Set-Schutz
$n = $b
if ($ok) { Start-Sleep -Seconds 2; $n = Measure-Schreibrate 8 }
if ($ok -and $n -ge 0 -and $n -lt $script:SchreibGrenze) {
  Save-SchutzBefund -Art 'Schutz' -RateVorher $b
  Merken 'Fehler'
  Write-Protokoll ('Fehler erkannt (' + (KB $b) + ', Treiber ' + $kennung + '), Schutz gesetzt, danach ' + (KB $n) + '.')
} else {
  Merken 'Andere'
  Write-Protokoll ('WARNUNG: atieclxx.exe schreibt dauerhaft (' + (KB $b) + '), der gezielte Schutz greift hier nicht. Bitte Radeon-atieclxx-SSD-Fix öffnen und "Dienst deaktivieren" wählen.')
  Send-Meldung 'Radeon-atieclxx-SSD-Fix: Der AMD-Treiber schreibt dauerhaft auf die SSD, der gezielte Schutz greift hier nicht. Bitte Radeon-atieclxx-SSD-Fix öffnen und "Dienst deaktivieren" wählen.'
}
