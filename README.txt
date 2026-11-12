Radeon-atieclxx-SSD-Fix 2.2 – Radeon driver keeps writing to the SSD
====================================================================

WHAT IS THIS ABOUT?
ComputerBase reported on 2026-11-09 that the "AMD External Events Utility" service of the
AMD driver continuously writes to the system drive for many users:
https://www.computerbase.de/news/grafikkarten/schnelle-ssd-alterung-radeon-treiber-schreibt-fortwaehrend-daten-auf-die-ssd.100237/
AMD has confirmed the bug; there is no fixed driver version yet.

WHAT EXACTLY HAPPENS?
Measured with Event Tracing for Windows (ETW): with affected drivers, atieclxx.exe copies
ITSELF EVERY SECOND from the driver folder to
  C:\Windows\System32\config\systemprofile\AppData\Local\AMD\atieclxx.exe
The file is about 660 KB, which adds up to roughly 56 GB per day of continuous operation.
Afterwards the service looks for installation files of the filter driver amdkmpfd (Smart Access
Memory). That explains why turning off Resizable BAR helps some people.

THE PROGRAM (START.cmd)
START.cmd opens a window (confirm the Windows prompt for administrator rights with "Yes"). It
  - measures whether and how much atieclxx.exe writes, and shows which variant is present:
    self-copy to the known location, writing elsewhere, or not affected,
  - estimates how much has already been written to the SSD unnecessarily (write rate times
    operating time since the AMD graphics device was installed; an estimate, not an exact value),
  - offers buttons for the fix of your choice.
The measurement runs in the background, so the window stays usable.

THE FIX BUTTONS
1) Targeted protection (recommended)
   Denies only the SYSTEM account permission to overwrite or delete the copy mentioned above.
   The copy attempt fails immediately and nothing is written any more. The service keeps
   running, and FreeSync, Frame Pacing and hotkeys are untouched. This also sets up the task
   "Radeon-atieclxx-SSD-Fix" (Task Scheduler, runs as SYSTEM 3 minutes after startup and
   every 30 minutes): it re-applies the protection after driver updates and, after a driver
   change, checks by itself whether AMD has fixed the bug. If so, it lifts the protection on its own.
2) Disable service
   The variant from the article: stops the service and sets its startup type to "Disabled".
   Always works, but may impair FreeSync and Frame Pacing.
3) Revert everything
   Reverts the protection, the task and the service disabling. The program folder is kept.
The button "What is Resizable BAR?" explains the third option from the article. It can only
be changed in the BIOS, which is why there is no button for it.

No files are downloaded, no internet connection is needed, and nothing is changed in the
driver. The complete source code is open in the folder "Script".

OTHER FILES
  CHECK.cmd    quick status, measures for 10 seconds (no administrator rights needed)
  REMOVE.cmd   reverts everything and additionally deletes the program folder
  LICENSE.txt  license (MIT)
After "Targeted protection", START.cmd, CHECK.cmd, REMOVE.cmd and the log are also found in
  C:\Program Files\Radeon-atieclxx-SSD-Fix

NOTES
- If Windows warns on startup ("Windows protected your PC"):
  "More info" -> "Run anyway". Or, before extracting, unblock the ZIP file with
  right-click -> Properties -> "Unblock".
- On corporate PCs where only signed PowerShell scripts are allowed, the program does not
  start. In that case please disable the service via services.msc.
- On Windows Home the task cannot show pop-up notices (msg.exe is missing there);
  everything is still recorded in the log.
- Other driver versions may behave differently. The program therefore measures first
  and only intervenes if the fix works.

ALTERNATIVE WITHOUT THIS PROGRAM (suggestion from the article)
  Win+R -> services.msc -> "AMD External Events Utility" -> Stop, startup type "Disabled".

DISCLAIMER
Unofficial workaround, not affiliated with AMD and not reviewed by AMD. Use at your own
risk, without warranty and without liability (see LICENSE.txt). AMD, Radeon and
Smart Access Memory are trademarks of Advanced Micro Devices, Inc. As soon as AMD ships a
fixed driver, the task lifts the protection by itself; after that, everything can be removed
with REMOVE.cmd.
