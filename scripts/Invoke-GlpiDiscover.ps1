<#
    FASE 1 — DESCOBERTA. Somente leitura. Nao escreve nada no GLPI.

    Objetivo: substituir suposicao por estado confirmado antes de qualquer escrita.
    Confirma versao, entidades, grupos, categorias, calendario, SLA, regras, usuarios
    e os CAMPOS que a versao instalada realmente aceita.

    Uso, no PowerShell da Duda:
        $env:GLPI_USER_TOKEN = '<token de usuario>'
        $env:GLPI_APP_TOKEN  = '<token de aplicacao>'
        .\Invoke-GlpiDiscover.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -Verbose

    Nao commitar a pasta de saida: ela contem nomes e e-mails de colaboradores.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\out\discover')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GlpiApi.psm1') -Force

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = [ordered]@{ executado_em = (Get-Date).ToString('o'); base_url = $BaseUrl }

try {
    New-GlpiSession -BaseUrl $BaseUrl | Out-Null

    Write-Host "`n=== VERSAO E CONFIGURACAO ===" -ForegroundColor Cyan
    $cfg = Invoke-GlpiRequest -Path 'getGlpiConfig'
    $ver = if ($cfg.PSObject.Properties.Name -contains 'cfg_glpi') { $cfg.cfg_glpi.version } else { '(nao exposto)' }
    $report['versao_glpi'] = $ver
    Write-Host "GLPI: $ver"
    if ($ver -match '^11\.0\.([0-7])$' -or $ver -match '^10\.') {
        Write-Warning "ATENCAO: versao $ver esta ABAIXO do piso de seguranca 11.0.8 (CVE-2026-48482 RCE no importador de formularios, CVE-2026-52848 desvio de MFA). NAO importar formulario nesta versao."
    }

    $inventory = [ordered]@{}
    $tipos = @(
        @{ t = 'Entity';       label = 'Entidades' },
        @{ t = 'Group';        label = 'Grupos' },
        @{ t = 'ITILCategory'; label = 'Categorias ITIL' },
        @{ t = 'Location';     label = 'Localizacoes' },
        @{ t = 'Calendar';     label = 'Calendarios' },
        @{ t = 'Holiday';      label = 'Feriados' },
        @{ t = 'SLM';          label = 'Acordos de nivel de servico (SLM)' },
        @{ t = 'SLA';          label = 'Niveis de SLA' },
        @{ t = 'Profile';      label = 'Perfis' },
        @{ t = 'Plugin';       label = 'Plugins' }
    )

    Write-Host "`n=== INVENTARIO ATUAL ===" -ForegroundColor Cyan
    foreach ($tipo in $tipos) {
        try {
            $itens = Get-GlpiItems -ItemType $tipo.t
            $inventory[$tipo.t] = @($itens | Select-Object id, name, entities_id, comment -ErrorAction SilentlyContinue)
            Write-Host ("{0,-34} {1,4} objeto(s)" -f $tipo.label, @($itens).Count)
            foreach ($i in $itens) {
                $n = if ($i.PSObject.Properties.Name -contains 'name') { $i.name } else { "(id $($i.id))" }
                Write-Host "    - $n"
            }
        } catch {
            Write-Warning "Nao foi possivel listar $($tipo.t): $($_.Exception.Message)"
            $inventory[$tipo.t] = @()
        }
    }
    $report['inventario'] = $inventory

    Write-Host "`n=== USUARIOS ===" -ForegroundColor Cyan
    try {
        $users = Get-GlpiItems -ItemType 'User'
        $ativos   = @($users | Where-Object { $_.is_active -eq 1 })
        $inativos = @($users | Where-Object { $_.is_active -ne 1 })
        Write-Host "Total: $(@($users).Count) | Ativos: $($ativos.Count) | Inativos: $($inativos.Count)"
        $glpiDefault = @($users | Where-Object { $_.name -eq 'glpi' })
        if ($glpiDefault.Count -gt 0) {
            $st = if ($glpiDefault[0].is_active -eq 1) { 'ATIVO — DESATIVAR' } else { 'desativado (correto)' }
            Write-Host "Conta de fabrica 'glpi': $st" -ForegroundColor $(if ($glpiDefault[0].is_active -eq 1) { 'Red' } else { 'Green' })
        }
        $report['usuarios'] = @{ total = @($users).Count; ativos = $ativos.Count; inativos = $inativos.Count }
        Write-Host "`nBase real do Forms tem 133 colaboradores distintos abrindo chamado."
        Write-Host "Contas ativas hoje: $($ativos.Count). Lacuna: $([math]::Max(0, 133 - $ativos.Count)) conta(s)." -ForegroundColor Yellow
    } catch { Write-Warning "Nao foi possivel listar usuarios: $($_.Exception.Message)" }

    Write-Host "`n=== REGRAS DE NEGOCIO DE CHAMADO ===" -ForegroundColor Cyan
    try {
        $rules = Get-GlpiItems -ItemType 'Rule'
        $ticketRules = @($rules | Where-Object { $_.sub_type -eq 'RuleTicket' })
        Write-Host "RuleTicket existentes: $($ticketRules.Count)"
        foreach ($r in $ticketRules) { Write-Host "    - [$($r.ranking)] $($r.name) (ativa: $($r.is_active))" }
        $report['regras_ticket'] = @($ticketRules | Select-Object id, name, ranking, is_active)
    } catch { Write-Warning "Nao foi possivel listar regras: $($_.Exception.Message)" }

    Write-Host "`n=== CAMPOS ACEITOS PELA VERSAO INSTALADA ===" -ForegroundColor Cyan
    Write-Host "Necessario porque exemplos de GLPI 10 nao garantem os mesmos campos na 11."
    $schemas = [ordered]@{}
    foreach ($t in @('Ticket','Group','ITILCategory','Calendar','SLA','TicketValidation')) {
        try {
            $schemas[$t] = Get-GlpiFieldSchema -ItemType $t
            Write-Host "  schema de $t capturado"
        } catch { Write-Warning "  schema de $t indisponivel: $($_.Exception.Message)" }
    }
    $schemas | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $OutputPath "schemas-$stamp.json") -Encoding UTF8

    $reportFile = Join-Path $OutputPath "discover-$stamp.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportFile -Encoding UTF8
    Get-GlpiAuditLog | Export-Csv -Path (Join-Path $OutputPath "audit-$stamp.csv") -NoTypeInformation -Encoding UTF8

    Write-Host "`n=== SAIDA ===" -ForegroundColor Green
    Write-Host "Relatorio: $reportFile"
    Write-Host "Schemas:   $(Join-Path $OutputPath "schemas-$stamp.json")"
    Write-Host "Auditoria: $(Join-Path $OutputPath "audit-$stamp.csv")"
    Write-Host "`nNada foi escrito no GLPI. Revise a saida antes de rodar Invoke-GlpiApply.ps1." -ForegroundColor Yellow
}
finally {
    Remove-GlpiSession
}
