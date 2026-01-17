# Self-hosted runner startup and console pause issues

This guide covers a common Windows self-hosted runner symptom where jobs appear to wait for Enter before starting.

## Symptom
- A job sits idle until Enter or Esc is pressed in the runner terminal.
- GitHub job logs show a gap before the first "Set up job" line.

## Root cause
The runner is launched in an interactive console with QuickEdit/selection mode active. When the console is paused, the runner process is suspended until a key press.

## Fix (recommended): run the runner as a service
1. Stop the interactive runner (`run.cmd`) if it is running.
2. If the runner is already configured, remove it first:
   ```
   .\config.cmd remove
   ```
3. Configure the runner as a Windows service (requires a fresh registration token):
   ```
   .\config.cmd --unattended --url https://github.com/<owner>/<repo> --token <token> --runasservice --replace
   ```
4. Confirm the service is running and re-run the workflow.

## Headless VM note: use a dedicated service account for PPL performance
When the runner is a Windows service under `NetworkService` or `LocalSystem`, LabVIEW
PPL builds can be much slower because LabVIEW caches are per-user. On a headless VM
you still need a service, so run the service under a real user account with a
persistent profile.

### Steps (admin)
1. Create a local user (example: `lvsvc`) and add it to Administrators:
   ```
   net user lvsvc <password> /add
   net localgroup Administrators lvsvc /add
   ```
2. Grant **Log on as a service**:
   - Open `secpol.msc`
   - Local Policies -> User Rights Assignment -> Log on as a service
   - Add `.\lvsvc`
3. Switch the runner service to that account:
   ```
   Get-Service | Where-Object { $_.Name -like 'actions.runner*' }
   Stop-Service <runner-service-name>
   sc.exe config <runner-service-name> obj= ".\lvsvc" password= "<password>"
   Start-Service <runner-service-name>
   ```
4. Initialize the profile once (creates `C:\Users\lvsvc`) and ensure the LabVIEW data folder exists:
   ```
   runas /user:.\lvsvc "cmd /c mkdir \"C:\Users\lvsvc\Documents\LabVIEW Data\""
   ```
5. Re-run the workflow and compare the 64-bit PPL build time.

### Notes
- If you cannot use a dedicated service account, expect slower PPL builds.
- Interactive `run.cmd` can be fast but requires a logged-in session.

## Alternative: disable QuickEdit for the runner console
If you must run interactively, disable QuickEdit:

```
Set-ItemProperty -Path HKCU:\Console -Name QuickEdit -Value 0
```

Then close and reopen the console window before starting `run.cmd`.

## Verification
- Re-run a workflow and confirm the job starts without any manual key press.
