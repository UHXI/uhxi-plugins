# bootstrap.ps1 — sincroniza este ambiente Windows com o marketplace 'uhxi' e as ferramentas externas.
# Uso: pwsh -File scripts\bootstrap.ps1 [-Update] [-NoTools] [-NoPlugins] [-Project] [-AllTools]
param([switch]$Update, [switch]$NoTools, [switch]$NoPlugins, [switch]$Project, [switch]$AllTools)
$ErrorActionPreference = 'Continue'
$RepoDir  = Split-Path -Parent $PSScriptRoot
$Template = Get-Content "$RepoDir\templates\settings.user.json" -Raw | ConvertFrom-Json
$Ok=@(); $Skip=@(); $Fail=@()
function Say($t){ Write-Host "`n== $t" -ForegroundColor Cyan }
function Has($c){ $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function Run($cmd){ cmd /c $cmd *> $null; return ($LASTEXITCODE -eq 0) }

if (-not (Has 'claude')) { Write-Host "Claude Code ('claude') não encontrado — a saltar plugins."; $NoPlugins = $true }

# 1. Fundir settings.json do utilizador
Say "A fundir settings.user.json em ~\.claude\settings.json"
$SettingsPath = Join-Path $HOME '.claude\settings.json'
New-Item -ItemType Directory -Force (Split-Path $SettingsPath) | Out-Null
$S = if (Test-Path $SettingsPath) { Get-Content $SettingsPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
if (Test-Path $SettingsPath) { Copy-Item $SettingsPath "$SettingsPath.bak.$(Get-Date -Format yyyyMMddHHmmss)" }
foreach ($key in 'extraKnownMarketplaces','enabledPlugins') {
  if (-not $S.PSObject.Properties[$key]) { $S | Add-Member -NotePropertyName $key -NotePropertyValue ([pscustomobject]@{}) }
  foreach ($p in $Template.$key.PSObject.Properties) {
    if ($S.$key.PSObject.Properties[$p.Name]) { $S.$key.($p.Name) = $p.Value } else { $S.$key | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
  }
}
$S | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
$Ok += 'settings.json fundido'

# 2. Marketplaces
if (-not $NoPlugins) {
  Say "Marketplaces"
  $Known = (claude plugin marketplace list 2>$null) -join "`n"
  if ($Known -notmatch 'uhxi') { if (Run "claude plugin marketplace add `"$RepoDir`"") { $Ok += "marketplace uhxi (local)" } else { $Fail += "claude plugin marketplace add $RepoDir" } } else { $Skip += 'marketplace uhxi já registado' }
  foreach ($m in $Template.extraKnownMarketplaces.PSObject.Properties) {
    if ($m.Name -eq 'uhxi') { continue }
    $src = if ($m.Value.source.repo) { $m.Value.source.repo } else { $m.Value.source.url }
    if ($Known -match [regex]::Escape($m.Name)) { $Skip += "marketplace $($m.Name) já registado"; continue }
    if (Run "claude plugin marketplace add $src") { $Ok += "marketplace $($m.Name)" } else { $Fail += "claude plugin marketplace add $src" }
  }
  if ($Update) { if (Run "claude plugin marketplace update") { $Ok += 'marketplaces actualizados' } }

  # 3. Plugins
  Say "Plugins"
  $Installed = @()
  try { $Installed = (claude plugin list --json 2>$null | ConvertFrom-Json).id } catch {}
  foreach ($p in $Template.enabledPlugins.PSObject.Properties) {
    if ($p.Value -ne $true) { continue }
    $id = $p.Name
    if ($Installed -contains $id) {
      if ($Update) { if (Run "claude plugin update $id") { $Ok += "actualizado $id" } else { $Fail += "claude plugin update $id" } } else { $Skip += "$id já instalado" }
      continue
    }
    if (Run "claude plugin install $id --scope user -y") { $Ok += "instalado $id" } else { $Fail += "claude plugin install $id --scope user -y" }
  }
}

# 4. Ferramentas externas
if (-not $NoTools) {
  Say "Ferramentas externas (external/tools.json)"
  $Tools = (Get-Content "$RepoDir\external\tools.json" -Raw | ConvertFrom-Json).tools
  $env:PATH = "$HOME\.local\bin;$env:PATH"
  foreach ($t in $Tools) {
    if ($t.optional -and -not $AllTools) { $Skip += "$($t.id) é opcional (usar -AllTools)"; continue }
    $missing = @($t.requires | Where-Object { $_ -and -not (Has $_) })
    if ($missing) { $Fail += "$($t.id): falta o pré-requisito '$($missing -join ',')'"; continue }
    if (Run $t.check) {
      if ($Update -and $t.upgrade) { if (Run $t.upgrade) { $Ok += "actualizado $($t.id)" } else { $Fail += $t.upgrade } } else { $Skip += "$($t.id) já instalado" }
    } else {
      $inst = $t.install.windows
      if (-not $inst) { $Skip += "$($t.id) sem instalação para windows"; continue }
      if (Run $inst) { $Ok += "instalado $($t.id)"; if ($t.post_install_note) { Write-Host "  nota: $($t.post_install_note)" } } else { $Fail += $inst; continue }
    }
    $cmd = $t.register; if ($Project -and $t.register_project) { $cmd = $t.register_project }
    if ($cmd) { if (Run $cmd) { $Ok += "registado: $cmd" } else { $Fail += $cmd } }
  }
}

# 5. Relatório
Say "Resumo"
Write-Host "  feito:   $($Ok -join '; ')"
Write-Host "  saltado: $($Skip -join '; ')"
Write-Host "  falhou:  $($Fail -join '; ')" -ForegroundColor $(if ($Fail) {'Yellow'} else {'Gray'})
exit $(if ($Fail) {1} else {0})
