$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('C:/Users/svelderr/AppData/Local/Temp/lv-ie-worktree-20251127-230634-c90fa7b/scripts/build/Build.ps1',[ref]$tokens,[ref]$errors) | Out-Null
if($errors){ $errors | Format-List Message,Extent }
else { 'No parse errors' }
