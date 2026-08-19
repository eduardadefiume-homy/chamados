<#
    FASE 2 — APLICACAO. Idempotente. Suporta -WhatIf.

    Le blueprint/homy-glpi-blueprint.json e blueprint/setores-gestores.csv e cria, no GLPI:
      entidades, grupos tecnicos, grupos de setor, grupos de gestores,
      categorias ITIL, calendario util e niveis de SLA.

    NAO cria: formularios, regras de negocio e notificacoes.
    Esses tres sao construidos na interface e exportados em JSON nativo depois de revisados
    — e o importador de formulario so e seguro a partir da 11.0.8.

    Ordem obrigatoria: entidades -> grupos -> categorias -> calendario -> SLA.
    O script recusa criar SLA se o calendario nao existir.

    SEMPRE rodar primeiro com -WhatIf:
        .\Invoke-GlpiApply.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -WhatIf -Verbose

    Depois, para valer:
        .\Invoke-GlpiApply.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -Confirm
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [string]$BlueprintPath = (Join-Path $PSScriptRoot '..\blueprint\homy-glpi-blueprint.json'),
    [string]$SetoresPath   = (Join-Path $PSScriptRoot '..\blueprint\setores-gestores.csv'),
    [string]$OutputPath    = (Join-Path $PSScriptRoot '..\out\apply'),
    [switch]$SkipSla
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GlpiApi.psm1') -Force

if (-not (Test-Path $BlueprintPath)) { throw "Blueprint nao encontrado: $BlueprintPath" }
$bp = Get-Content $BlueprintPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$changes = [System.Collections.Generic.List[object]]::new()
function Add-Change { param($r) if ($r) { $changes.Add($r); Write-Host ("  [{0,-18}] {1} :: {2}" -f $r.Action, $r.ItemType, $r.Name) } }

try {
    New-GlpiSession -BaseUrl $BaseUrl | Out-Null

    # ---------- PORTAO DE SEGURANCA ----------
    $cfg = Invoke-GlpiRequest -Path 'getGlpiConfig'
    $ver = if ($cfg.PSObject.Properties.Name -contains 'cfg_glpi') { $cfg.cfg_glpi.version } else { $null }
    Write-Host "Versao instalada: $ver" -ForegroundColor Cyan
    if ($ver -and ($ver -match '^11\.0\.[0-7]$' -or $ver -match '^10\.')) {
        throw "BLOQUEADO: versao $ver esta abaixo do piso de seguranca 11.0.8. Atualize antes de aplicar configuracao estrutural."
    }

    Write-Host "`n=== BACKUP ===" -ForegroundColor Yellow
    Write-Host "Este script NAO faz backup. Confirme que existe backup de banco e arquivos"
    Write-Host "COM RESTAURACAO TESTADA antes de prosseguir sem -WhatIf."

    # ---------- 1. ENTIDADES ----------
    Write-Host "`n=== 1. ENTIDADES ===" -ForegroundColor Cyan
    $entCache = Get-GlpiItems -ItemType 'Entity'
    $entIds   = @{}
    foreach ($e in $bp.entities) {
        if ($e.phase -eq 'futura') { Write-Host "  [pulado           ] Entity :: $($e.name) (fase futura)"; continue }
        $fields = @{ name = $e.name }
        if ($e.PSObject.Properties.Name -contains 'parent' -and $e.parent) {
            $parent = Find-GlpiItem -ItemType 'Entity' -Name $e.parent -Cache $entCache
            if ($null -eq $parent) { throw "Entidade pai '$($e.parent)' nao existe. Crie a raiz antes." }
            $fields['entities_id'] = $parent.id
        }
        $r = Set-GlpiItemIdempotent -ItemType 'Entity' -Fields $fields -Cache $entCache
        Add-Change $r
        if ($r.Id) { $entIds[$e.name] = $r.Id }
    }
    $entCache = Get-GlpiItems -ItemType 'Entity'
    foreach ($e in $entCache) { if ($e.PSObject.Properties.Name -contains 'name') { $entIds[$e.name] = $e.id } }

    $tiEntity = if ($entIds.ContainsKey('Service Desk - TI')) { $entIds['Service Desk - TI'] } else { 0 }
    $rootEnt  = if ($entIds.ContainsKey('Homy Química'))      { $entIds['Homy Química'] }      else { 0 }
    Write-Host "Entidade de TI: id $tiEntity | Raiz: id $rootEnt"

    # ---------- 2. GRUPOS ----------
    Write-Host "`n=== 2. GRUPOS TECNICOS ===" -ForegroundColor Cyan
    $grpCache = Get-GlpiItems -ItemType 'Group'
    foreach ($g in $bp.technical_groups) {
        Add-Change (Set-GlpiItemIdempotent -ItemType 'Group' -Fields @{
            name = $g.name; comment = $g.purpose; entities_id = $tiEntity
            is_recursive = 0; is_assign = 1; is_requester = 0
        } -EntityId $tiEntity -Cache $grpCache)
    }

    Write-Host "`n=== 3. GRUPOS DE SETOR (solicitantes) ===" -ForegroundColor Cyan
    $prefixoSetor = $bp.organizational_groups.prefixo
    foreach ($s in $bp.organizational_groups.setores) {
        Add-Change (Set-GlpiItemIdempotent -ItemType 'Group' -Fields @{
            name = "$prefixoSetor$s"; comment = "Grupo organizacional do setor $s. Base do roteamento e da aprovacao."
            entities_id = $rootEnt; is_recursive = 1; is_assign = 0; is_requester = 1
        } -EntityId $rootEnt -Cache $grpCache)
    }

    Write-Host "`n=== 4. GRUPOS DE GESTORES (aprovadores) ===" -ForegroundColor Cyan
    $semGestor = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $SetoresPath) {
        foreach ($row in (Import-Csv $SetoresPath -Encoding UTF8)) {
            $nome = $row.grupo_aprovador_glpi
            if ([string]::IsNullOrWhiteSpace($nome)) { continue }
            Add-Change (Set-GlpiItemIdempotent -ItemType 'Group' -Fields @{
                name = $nome; comment = "Aprovadores do setor $($row.setor). Validacao nativa de chamado."
                entities_id = $rootEnt; is_recursive = 1; is_assign = 0; is_requester = 0
            } -EntityId $rootEnt -Cache $grpCache)
            if ([string]::IsNullOrWhiteSpace($row.gestor_email)) { $semGestor.Add($row.setor) }
        }
        if ($semGestor.Count -gt 0) {
            Write-Warning "$($semGestor.Count) grupo(s) de gestores SEM membro definido: $($semGestor -join ', ')"
            Write-Warning "A validacao NAO deve ser ativada para esses setores — o chamado ficaria preso em Pendente para sempre."
            Write-Warning "Preencha gestor_nome e gestor_email em $SetoresPath e vincule os membros."
        }
    } else {
        Write-Warning "CSV de setores nao encontrado em $SetoresPath. Grupos de gestores nao criados."
    }

    # ---------- 5. CATEGORIAS ITIL ----------
    Write-Host "`n=== 5. CATEGORIAS ITIL ===" -ForegroundColor Cyan
    $catCache = Get-GlpiItems -ItemType 'ITILCategory'
    foreach ($c in $bp.itil_categories) {
        $r = Set-GlpiItemIdempotent -ItemType 'ITILCategory' -Fields @{
            name = $c.name; entities_id = $tiEntity; is_recursive = 1
        } -EntityId $tiEntity -Cache $catCache
        Add-Change $r
        $catCache = Get-GlpiItems -ItemType 'ITILCategory'
        $parent = Find-GlpiItem -ItemType 'ITILCategory' -Name $c.name -EntityId $tiEntity -Cache $catCache
        if ($null -ne $parent -and $c.children) {
            foreach ($child in $c.children) {
                Add-Change (Set-GlpiItemIdempotent -ItemType 'ITILCategory' -Fields @{
                    name = $child; entities_id = $tiEntity; is_recursive = 1; itilcategories_id = $parent.id
                } -EntityId $tiEntity -Cache $catCache)
            }
            $catCache = Get-GlpiItems -ItemType 'ITILCategory'
        }
    }

    # ---------- 6. CALENDARIO ----------
    Write-Host "`n=== 6. CALENDARIO UTIL ===" -ForegroundColor Cyan
    $calCache = Get-GlpiItems -ItemType 'Calendar'
    $calName  = $bp.calendar.name
    Add-Change (Set-GlpiItemIdempotent -ItemType 'Calendar' -Fields @{
        name = $calName; entities_id = $rootEnt; is_recursive = 1
        comment = "Seg-Sex $($bp.calendar.segments[0].begin)-$($bp.calendar.segments[0].end). $($bp.calendar.minutos_por_dia_util) min/dia util."
    } -EntityId $rootEnt -Cache $calCache)

    $calCache = Get-GlpiItems -ItemType 'Calendar'
    $cal = Find-GlpiItem -ItemType 'Calendar' -Name $calName -EntityId $rootEnt -Cache $calCache

    if ($null -ne $cal) {
        $dayMap  = @{ monday = 1; tuesday = 2; wednesday = 3; thursday = 4; friday = 5 }
        $segsNow = @()
        try { $segsNow = @(Invoke-GlpiRequest -Path "Calendar/$($cal.id)/CalendarSegment") } catch { $segsNow = @() }
        foreach ($seg in $bp.calendar.segments) {
            $d = $dayMap[$seg.day]
            $ja = @($segsNow | Where-Object { $_.day -eq $d -and $_.begin -like "$($seg.begin)*" -and $_.end -like "$($seg.end)*" })
            if ($ja.Count -gt 0) { Write-Host "  [Inalterado        ] CalendarSegment :: $($seg.day)"; continue }
            if ($PSCmdlet.ShouldProcess("CalendarSegment $($seg.day) $($seg.begin)-$($seg.end)", 'CRIAR')) {
                Invoke-GlpiRequest -Path 'CalendarSegment' -Method Post -Body @{ input = @{
                    calendars_id = $cal.id; day = $d; begin = "$($seg.begin):00"; end = "$($seg.end):00" } } | Out-Null
                Write-Host "  [Criado            ] CalendarSegment :: $($seg.day) $($seg.begin)-$($seg.end)"
            } else {
                Write-Host "  [Criaria (WhatIf)  ] CalendarSegment :: $($seg.day) $($seg.begin)-$($seg.end)"
            }
        }
        Write-Warning "FERIADOS NAO CARREGADOS. O GLPI vai contar feriado como dia util e vencer SLA de chamado que ninguem podia atender."
        Write-Warning "Carregue os feriados em Configuracao > Calendarios > $calName > Feriados ANTES de ativar o SLA."
        if ($bp.calendar.PSObject.Properties.Name -contains 'pendencia') { Write-Warning $bp.calendar.pendencia }
    }

    # ---------- 7. SLA ----------
    if ($SkipSla) {
        Write-Host "`n=== 7. SLA — PULADO (-SkipSla) ===" -ForegroundColor Yellow
    } elseif ($null -eq $cal) {
        Write-Warning "`n=== 7. SLA — PULADO: calendario nao existe. SLA sem calendario produz prazo errado com aparencia de certo. ==="
    } else {
        Write-Host "`n=== 7. SLA ===" -ForegroundColor Cyan
        Write-Warning "SLA e PROPOSTA ate aprovacao de $($bp.sla.aprovador_pendente). Aplicando como estrutura; revise os prazos antes de ativar."
        $slmCache = Get-GlpiItems -ItemType 'SLM'
        $slmName  = 'SLA Service Desk TI - Homy'
        Add-Change (Set-GlpiItemIdempotent -ItemType 'SLM' -Fields @{
            name = $slmName; entities_id = $tiEntity; is_recursive = 1; calendars_id = $cal.id
            comment = 'Proposta. Prazos em minutos uteis sobre o calendario Comercial Homy - TI.'
        } -EntityId $tiEntity -Cache $slmCache)

        $slmCache = Get-GlpiItems -ItemType 'SLM'
        $slm = Find-GlpiItem -ItemType 'SLM' -Name $slmName -EntityId $tiEntity -Cache $slmCache
        if ($null -ne $slm) {
            $slaCache = Get-GlpiItems -ItemType 'SLA'
            foreach ($n in $bp.sla.niveis) {
                # type 1 = TTR (tempo de resolucao), type 0 = TTO (tempo de atendimento)
                Add-Change (Set-GlpiItemIdempotent -ItemType 'SLA' -Fields @{
                    name = "TTO $($n.prioridade)"; entities_id = $tiEntity; slms_id = $slm.id
                    type = 0; number_time = $n.tto_min; definition_time = 'minute'
                } -EntityId $tiEntity -Cache $slaCache)
                Add-Change (Set-GlpiItemIdempotent -ItemType 'SLA' -Fields @{
                    name = "TTR $($n.prioridade)"; entities_id = $tiEntity; slms_id = $slm.id
                    type = 1; number_time = $n.ttr_min_uteis; definition_time = 'minute'
                } -EntityId $tiEntity -Cache $slaCache)
            }
        }
    }

    # ---------- RELATORIO ----------
    $diffFile  = Join-Path $OutputPath "diferencas-$stamp.csv"
    $auditFile = Join-Path $OutputPath "audit-$stamp.csv"
    $changes | Export-Csv -Path $diffFile -NoTypeInformation -Encoding UTF8
    Get-GlpiAuditLog | Export-Csv -Path $auditFile -NoTypeInformation -Encoding UTF8

    Write-Host "`n=== RESUMO ===" -ForegroundColor Green
    $changes | Group-Object Action | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-20} {1}" -f $_.Name, $_.Count) }
    Write-Host "`nDiferencas: $diffFile"
    Write-Host "Auditoria:  $auditFile"

    Write-Host "`n=== O QUE ESTE SCRIPT NAO FEZ ===" -ForegroundColor Yellow
    Write-Host "  - Formularios: construir na interface (docs/03) e exportar JSON nativo depois de revisar"
    Write-Host "  - Regras de negocio de roteamento e prioridade: docs/06"
    Write-Host "  - Validacao/aprovacao: so ativar depois de preencher os gestores (docs/05)"
    Write-Host "  - Notificacoes e assinatura de e-mail: docs/06"
    Write-Host "  - Feriados do calendario: bloqueante para o SLA"
    Write-Host "  - Membros dos grupos: vincular usuarios manualmente ou por importacao de identidade"
}
finally {
    Remove-GlpiSession
}
