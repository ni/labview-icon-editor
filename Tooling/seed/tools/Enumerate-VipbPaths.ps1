<#
.SYNOPSIS
  Emit a sorted list of dot‑notation JSON paths for every leaf field in a VIPB‑JSON file.

.EXAMPLE
  dotnet run --project ../dotnet/VipbJsonTool/VipbJsonTool.csproj -- vipb2json '../deployment/seed.vipb' tmp.json
  pwsh tools/Enumerate-VipbPaths.ps1 tmp.json > all-paths.txt
#>

param(
    [Parameter(Mandatory)] [string]$JsonPath
)

function Get-JsonPaths($Obj, $Prefix='') {
    if ($Obj -is [System.Collections.IDictionary]) {
        foreach ($k in $Obj.Keys) { Get-JsonPaths $Obj[$k] ($Prefix ? "$Prefix.$k" : $k) }
    }
    elseif ($Obj -is [System.Collections.IEnumerable] -and $Obj -isnot [string]) {
        $i = 0
        foreach ($v in $Obj) { Get-JsonPaths $v "$Prefix[$i]"; $i++ }
    }
    else { $Prefix }
}

(Get-Content $JsonPath -Raw | ConvertFrom-Json) |
    Get-JsonPaths |
    Where-Object { $_ } |
    Sort-Object -Unique
