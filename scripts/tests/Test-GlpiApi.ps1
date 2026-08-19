<#
    Testes das funcoes de seguranca do modulo GlpiApi.
    Nao precisam de servidor GLPI — validam a logica pura.

    Uso:  pwsh ./scripts/tests/Test-GlpiApi.ps1
    Ultima execucao verde: 19/08/2026, PowerShell 7.4.6 — 5/5.
#>
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\GlpiApi.psm1') -Force
$fail = 0

Write-Host 'TESTE 1 - mascaramento de segredo em log'
$s = ConvertTo-SanitizedString @{ user_token = 'abc123SECRET'; app_token = 'xyz789SECRET'; name = 'TI | Triagem' }
if ($s -match 'abc123SECRET' -or $s -match 'xyz789SECRET') { Write-Host '  FALHOU: segredo vazou' -ForegroundColor Red; $fail++ }
elseif ($s -notmatch 'TI \| Triagem') { Write-Host '  FALHOU: mascarou demais' -ForegroundColor Red; $fail++ }
else { Write-Host '  OK' -ForegroundColor Green }

Write-Host 'TESTE 2 - Find-GlpiItem rejeita ambiguidade'
$cache = @(
    [pscustomobject]@{ id = 1; name = 'TI | Triagem';        entities_id = 2 },
    [pscustomobject]@{ id = 9; name = 'TI | Triagem';        entities_id = 2 },
    [pscustomobject]@{ id = 3; name = 'TI | Infraestrutura'; entities_id = 2 }
)
try {
    Find-GlpiItem -ItemType Group -Name 'TI | Triagem' -EntityId 2 -Cache $cache | Out-Null
    Write-Host '  FALHOU: aceitou duplicata' -ForegroundColor Red; $fail++
} catch {
    if ($_.Exception.Message -match 'AMBIGUIDADE') { Write-Host '  OK' -ForegroundColor Green }
    else { Write-Host "  FALHOU: $($_.Exception.Message)" -ForegroundColor Red; $fail++ }
}

Write-Host 'TESTE 3 - Find-GlpiItem acha unico e respeita entidade'
if ((Find-GlpiItem -ItemType Group -Name 'TI | Infraestrutura' -EntityId 2 -Cache $cache).id -ne 3) { Write-Host '  FALHOU' -ForegroundColor Red; $fail++ }
elseif ($null -ne (Find-GlpiItem -ItemType Group -Name 'TI | Infraestrutura' -EntityId 99 -Cache $cache)) { Write-Host '  FALHOU: ignorou entidade' -ForegroundColor Red; $fail++ }
else { Write-Host '  OK' -ForegroundColor Green }

Write-Host 'TESTE 4 - Set-GlpiItemIdempotent exige name'
try { Set-GlpiItemIdempotent -ItemType Group -Fields @{ comment = 'x' } -WhatIf | Out-Null; Write-Host '  FALHOU' -ForegroundColor Red; $fail++ }
catch { if ($_.Exception.Message -match 'exige a chave') { Write-Host '  OK' -ForegroundColor Green } else { Write-Host '  FALHOU' -ForegroundColor Red; $fail++ } }

Write-Host 'TESTE 5 - New-GlpiSession recusa rodar sem token no ambiente'
$env:GLPI_USER_TOKEN = $null
try { New-GlpiSession -BaseUrl 'https://exemplo.invalido' | Out-Null; Write-Host '  FALHOU' -ForegroundColor Red; $fail++ }
catch { if ($_.Exception.Message -match 'nao definida') { Write-Host '  OK' -ForegroundColor Green } else { Write-Host '  FALHOU' -ForegroundColor Red; $fail++ } }

Write-Host ''
if ($fail -eq 0) { Write-Host '5/5 testes passaram' -ForegroundColor Green; exit 0 }
Write-Host "$fail teste(s) falharam" -ForegroundColor Red; exit 1
