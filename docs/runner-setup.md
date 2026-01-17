# Self-hosted runner startup and console pause issues

This guide covers a common Windows self-hosted runner symptom where jobs appear to wait for Enter before starting.

## Symptom
- A job sits idle until Enter or Esc is pressed in the runner terminal.
- GitHub job logs show a gap before the first "Set up job" line.

## Root cause
The runner is launched in an interactive console with QuickEdit/selection mode active. When the console is paused, the runner process is suspended until a key press.

## Fix (recommended): run the runner as a service
1. Stop the interactive runner (`run.cmd`) if it is running.
2. From an elevated PowerShell in the runner root:
   ```
   .\svc install
   .\svc start
   ```
3. Confirm the service is running and re-run the workflow.

## Alternative: disable QuickEdit for the runner console
If you must run interactively, disable QuickEdit:

```
Set-ItemProperty -Path HKCU:\Console -Name QuickEdit -Value 0
```

Then close and reopen the console window before starting `run.cmd`.

## Verification
- Re-run a workflow and confirm the job starts without any manual key press.
