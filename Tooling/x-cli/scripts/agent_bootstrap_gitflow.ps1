param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$repo = 'LabVIEW-Community-CI-CD/x-cli'
$startBranch = (git.exe rev-parse --abbrev-ref HEAD 2>$null)
if (-not $startBranch) { $startBranch = 'HEAD' }

Write-Host "[bootstrap] Repo slug: $repo"
if ($env:GITHUB_REPOSITORY -ne $repo) {
  $env:GITHUB_REPOSITORY = $repo
}

$canPush = $true
$remoteUrl = "git@github.com:$repo.git"
if ($env:CI) {
  $canPush = $false
  $remoteUrl = "https://github.com/$repo.git"
}

if (git.exe remote get-url upstream 2>$null) {
  git.exe remote set-url upstream $remoteUrl
} else {
  git.exe remote add upstream $remoteUrl
}

git.exe fetch upstream

if (git.exe show-ref --verify --quiet refs/heads/main) {
  git.exe checkout main
} else {
  git.exe checkout -b main upstream/main
}

git.exe pull upstream main

if (git.exe show-ref --verify --quiet refs/heads/develop) {
  git.exe checkout develop
  git.exe pull upstream develop 2>$null
} elseif (git.exe show-ref --verify --quiet refs/remotes/upstream/develop) {
  git.exe checkout -b develop upstream/develop
} else {
  git.exe checkout -b develop
  if ($canPush) {
    git.exe push upstream develop
  } else {
    Write-Host '::notice::Skipping git push (CI mode)'
  }
}

try { git.exe flow init -h | Out-Null } catch { }
if (Get-Command git.exe -ErrorAction SilentlyContinue) {
  try {
    git.exe flow init -d -b main -d develop -f feature/ -r release/ -h hotfix/ | Out-Null
  } catch {
    Write-Host '::notice::git flow not installed; skipping git flow init'
  }
}

function Check-Secret($Name) {
  $out = & gh.exe secret list -R $repo
  if (-not $out.Contains($Name)) {
    Write-Warning "Secret $Name missing in $repo"
    $script:missing = $true
  }
}
$script:missing = $false
if (Get-Command gh.exe -ErrorAction SilentlyContinue) {
  try {
    gh.exe auth status --show-token | Out-Null
    Check-Secret 'GH_ORG_TOKEN'
    Check-Secret 'GHCR_USER'
    Check-Secret 'GHCR_TOKEN'
    if ($script:missing) {
      Write-Warning 'One or more secrets missing; see docs/issues/cleanup-workflows-and-docs.md'
    }
  } catch {
    Write-Warning 'gh CLI not authenticated; skipping secret check'
  }
} else {
  Write-Warning 'gh CLI not found; skipping secret check'
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
  $ver = '7.4.11'
  $msi = Join-Path $env:TEMP "PowerShell-$ver-win-x64.msi"
  Invoke-WebRequest "https://github.com/PowerShell/PowerShell/releases/download/v$ver/PowerShell-$ver-win-x64.msi" -OutFile $msi
  Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn /norestart"
  "$env:ProgramFiles\PowerShell\7" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
}

if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
  pre-commit run lint-pwsh-shell --all-files | Out-Null
} else {
  Write-Host '::notice::pre-commit not installed; skipping lint-pwsh-shell'
}

try {
  git.exe checkout $startBranch 2>$null | Out-Null
} catch {}

Write-Host "Bootstrap complete for $repo"
