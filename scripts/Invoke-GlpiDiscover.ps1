<#
    FASE 1 - DESCOBERTA. Somente leitura. Nao escreve nada no GLPI.

    Objetivo: substituir suposicao por estado confirmado antes de qualquer escrita.
    Confirma versao, integridade do banco, entidades, grupos, categorias, localizacoes,
    calendarios, feriados, SLA/SLM, regras de chamado, contas, plugins, cron e os CAMPOS
    que a versao instalada realmente aceita.

    Uso:
        $env:GLPI_USER_TOKEN = '<token de usuario>'
        $env:GLPI_APP_TOKEN  = '<token de aplicacao>'
        ./Invoke-GlpiDiscover.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -Verbose

    A secao PRE-AUTENTICACAO roda mesmo sem token: status.php e publico.
    Nao commitar a pasta de saida: ela contem nomes e e-mails de colaboradores.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..' 'out' 'discover')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GlpiApi.psm1') -Force

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = [ordered]@{ executado_em = (Get-Date).ToString('o'); base_url = $BaseUrl }

function Get-Prop {
    <# Leitura tolerante de propriedade sob Set-StrictMode. #>
    param([object]$Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $Default
}

# ---------------------------------------------------------------------------
# 0. PRE-AUTENTICACAO - status.php e publico e nao exige token
# ---------------------------------------------------------------------------
Write-Host "`n=== PRE-AUTENTICACAO (status.php) ===" -ForegroundColor Cyan
try {
    $status = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/status.php" -Method Get -TimeoutSec 60
    $report['status_publico'] = $status
    Write-Host ("GLPI ................. {0}" -f (Get-Prop (Get-Prop $status 'glpi') 'status' '?'))
    Write-Host ("Banco principal ...... {0}" -f (Get-Prop (Get-Prop (Get-Prop $status 'db') 'main') 'status' '?'))
    Write-Host ("Replicas de banco .... {0}" -f (Get-Prop (Get-Prop (Get-Prop $status 'db') 'replicas') 'status' '?'))
    Write-Host ("LDAP ................. {0}" -f (Get-Prop (Get-Prop $status 'ldap') 'status' '?'))
    Write-Host ("Coletores de e-mail .. {0}" -f (Get-Prop (Get-Prop $status 'mail_collectors') 'status' '?'))
    Write-Host ("Acoes automaticas .... {0}" -f (Get-Prop (Get-Prop $status 'crontasks') 'status_msg' '?'))
    Write-Host ("Sistema de arquivos .. {0}" -f (Get-Prop (Get-Prop $status 'filesystem') 'status' '?'))
    Write-Host ("Plugins .............. {0}" -f (Get-Prop (Get-Prop $status 'plugins') 'status' '?'))
    $stuck = @(Get-Prop (Get-Prop $status 'crontasks') 'stuck' @())
    if ($stuck.Count -gt 0) { Write-Warning "Tarefas de cron TRAVADAS: $($stuck -join ', ')" }
} catch {
    Write-Warning "status.php indisponivel: $($_.Exception.Message)"
}
Write-Host "NOTA: status.php esta publico sem autenticacao. Avaliar restringir por IP." -ForegroundColor Yellow

try {
    New-GlpiSession -BaseUrl $BaseUrl | Out-Null

    # -----------------------------------------------------------------------
    # 1. IDENTIDADE DA CONTA DE SERVICO
    # -----------------------------------------------------------------------
    Write-Host "`n=== CONTA DE SERVICO EM USO ===" -ForegroundColor Cyan
    try {
        $full    = Invoke-GlpiRequest -Path 'getFullSession'
        $session = Get-Prop $full 'session'
        Write-Host ("Login .............. {0}" -f (Get-Prop $session 'glpiname' '?'))
        Write-Host ("Perfil ativo ....... {0}" -f (Get-Prop (Get-Prop $session 'glpiactiveprofile') 'name' '?'))
        Write-Host ("Entidade ativa ..... {0}" -f (Get-Prop $session 'glpiactive_entity_name' '?'))
        Write-Host ("Ve sub-entidades ... {0}" -f (Get-Prop $session 'glpiactive_entity_recursive' '?'))
        $report['conta_servico'] = [ordered]@{
            login      = (Get-Prop $session 'glpiname' '?')
            perfil     = (Get-Prop (Get-Prop $session 'glpiactiveprofile') 'name' '?')
            entidade   = (Get-Prop $session 'glpiactive_entity_name' '?')
            recursivo  = (Get-Prop $session 'glpiactive_entity_recursive' '?')
        }
    } catch { Write-Warning "getFullSession indisponivel: $($_.Exception.Message)" }

    # -----------------------------------------------------------------------
    # 2. VERSAO E CONFIGURACAO
    # -----------------------------------------------------------------------
    Write-Host "`n=== VERSAO E CONFIGURACAO ===" -ForegroundColor Cyan
    $cfgRoot = Invoke-GlpiRequest -Path 'getGlpiConfig'
    $cfg     = Get-Prop $cfgRoot 'cfg_glpi'
    $ver     = Get-Prop $cfg 'version' '(nao exposto)'
    $report['versao_glpi'] = $ver
    Write-Host "GLPI ............... $ver"
    Write-Host ("Fuso horario ....... {0}" -f (Get-Prop $cfg 'timezone' '(padrao do banco)'))
    Write-Host ("Notificacoes ....... {0}" -f (Get-Prop $cfg 'use_notifications' '?'))
    Write-Host ("Modo de e-mail ..... {0}" -f (Get-Prop $cfg 'smtp_mode' '?'))
    Write-Host ("Remetente admin .... {0}" -f (Get-Prop $cfg 'admin_email' '(vazio)'))
    Write-Host ("Nome do remetente .. {0}" -f (Get-Prop $cfg 'admin_email_name' '(vazio)'))
    Write-Host ("Resposta para ...... {0}" -f (Get-Prop $cfg 'admin_reply' '(vazio)'))
    Write-Host ("URL da base ........ {0}" -f (Get-Prop $cfg 'url_base' '(vazio)'))
    $report['config'] = [ordered]@{
        timezone         = (Get-Prop $cfg 'timezone' $null)
        use_notifications= (Get-Prop $cfg 'use_notifications' $null)
        smtp_mode        = (Get-Prop $cfg 'smtp_mode' $null)
        admin_email      = (Get-Prop $cfg 'admin_email' $null)
        admin_email_name = (Get-Prop $cfg 'admin_email_name' $null)
        admin_reply      = (Get-Prop $cfg 'admin_reply' $null)
        url_base         = (Get-Prop $cfg 'url_base' $null)
        default_calendar = (Get-Prop $cfg 'calendars_id' $null)
    }

    if ($ver -match '^11\.0\.([0-7])$' -or $ver -match '^10\.') {
        Write-Warning "ATENCAO: versao $ver esta ABAIXO do piso de seguranca 11.0.8 (CVE-2026-48482 RCE no importador de formularios, CVE-2026-52848 desvio de MFA). NAO importar formulario nesta versao."
    }

    # -----------------------------------------------------------------------
    # 3. INVENTARIO
    #    is_recursive: sem isso a listagem enxerga so a entidade ativa e
    #    sub-relata objetos das filhas.
    # -----------------------------------------------------------------------
    $inventory = [ordered]@{}
    $tipos = @(
        @{ t = 'Entity';        label = 'Entidades';                       rec = $true  },
        @{ t = 'Group';         label = 'Grupos';                          rec = $true  },
        @{ t = 'ITILCategory';  label = 'Categorias ITIL';                 rec = $true  },
        @{ t = 'Location';      label = 'Localizacoes';                    rec = $true  },
        @{ t = 'Calendar';      label = 'Calendarios';                     rec = $true  },
        @{ t = 'CalendarSegment';label= 'Faixas de horario do calendario'; rec = $true  },
        @{ t = 'Holiday';       label = 'Feriados';                        rec = $true  },
        @{ t = 'SLM';           label = 'Acordos de nivel de servico (SLM)';rec = $true },
        @{ t = 'SLA';           label = 'Niveis de SLA';                   rec = $true  },
        @{ t = 'OLA';           label = 'Niveis de OLA';                   rec = $true  },
        @{ t = 'Profile';       label = 'Perfis';                          rec = $false },
        @{ t = 'Plugin';        label = 'Plugins';                         rec = $false },
        @{ t = 'AuthLDAP';      label = 'Diretorios LDAP/AD';              rec = $false },
        @{ t = 'MailCollector'; label = 'Caixas coletoras';                rec = $false },
        @{ t = 'Notification';  label = 'Notificacoes';                    rec = $true  },
        @{ t = 'RequestType';   label = 'Origens de requisicao';           rec = $false },
        @{ t = 'SolutionType';  label = 'Tipos de solucao';                rec = $true  },
        @{ t = 'TaskCategory';  label = 'Categorias de tarefa';            rec = $true  }
    )

    Write-Host "`n=== INVENTARIO ATUAL ===" -ForegroundColor Cyan
    foreach ($tipo in $tipos) {
        try {
            $itens = if ($tipo.rec) { Get-GlpiItems -ItemType $tipo.t -Recursive } else { Get-GlpiItems -ItemType $tipo.t }
            $inventory[$tipo.t] = @($itens | Select-Object id, name, entities_id, is_active, comment -ErrorAction SilentlyContinue)
            Write-Host ("{0,-38} {1,4} objeto(s)" -f $tipo.label, @($itens).Count)
            foreach ($i in $itens) {
                $n = Get-Prop $i 'name' "(id $(Get-Prop $i 'id' '?'))"
                Write-Host "    - $n"
            }
        } catch {
            Write-Warning "Nao foi possivel listar $($tipo.t): $($_.Exception.Message)"
            $inventory[$tipo.t] = @()
        }
    }
    $report['inventario'] = $inventory

    # -----------------------------------------------------------------------
    # 4. CRON / ACOES AUTOMATICAS
    #    mode 1 = disparado pela navegacao web (fraco). mode 2 = CLI/systemd (correto).
    # -----------------------------------------------------------------------
    Write-Host "`n=== ACOES AUTOMATICAS (CRON) ===" -ForegroundColor Cyan
    try {
        $crons  = Get-GlpiItems -ItemType 'CronTask'
        $porModo = @{ 1 = 0; 2 = 0 }
        $desligadas = @()
        foreach ($c in $crons) {
            $m = [int](Get-Prop $c 'mode' 0)
            if ($porModo.ContainsKey($m)) { $porModo[$m]++ }
            if ([int](Get-Prop $c 'state' 0) -eq 0) { $desligadas += (Get-Prop $c 'name' '?') }
        }
        Write-Host "Total de tarefas ......... $(@($crons).Count)"
        Write-Host "Modo CLI (correto) ....... $($porModo[2])"
        Write-Host "Modo web/navegacao ....... $($porModo[1])"
        Write-Host "Desativadas .............. $($desligadas.Count)"
        if ($porModo[1] -gt 0) {
            Write-Warning "Ha $($porModo[1]) tarefa(s) em modo web. Notificacao e escalonamento de SLA dependem de cron CLI real (systemd timer ou crontab), senao disparam so quando alguem navega."
        }
        $criticas = @('queuednotification','slaticket','olaticket','watcher','ticketrecall')
        foreach ($c in $crons) {
            $nome = (Get-Prop $c 'name' '')
            if ($criticas -contains $nome.ToLower()) {
                Write-Host ("  {0,-22} modo={1} estado={2} ultima={3}" -f $nome, (Get-Prop $c 'mode' '?'), (Get-Prop $c 'state' '?'), (Get-Prop $c 'lastrun' 'nunca'))
            }
        }
        $report['cron'] = @($crons | Select-Object name, mode, state, frequency, lastrun, itemtype)
    } catch { Write-Warning "Nao foi possivel listar CronTask: $($_.Exception.Message)" }

    # -----------------------------------------------------------------------
    # 5. USUARIOS E CONTAS DE FABRICA
    # -----------------------------------------------------------------------
    Write-Host "`n=== USUARIOS ===" -ForegroundColor Cyan
    try {
        $users    = Get-GlpiItems -ItemType 'User' -Recursive
        $ativos   = @($users | Where-Object { (Get-Prop $_ 'is_active' 0) -eq 1 })
        $inativos = @($users | Where-Object { (Get-Prop $_ 'is_active' 0) -ne 1 })
        $deletados= @($users | Where-Object { (Get-Prop $_ 'is_deleted' 0) -eq 1 })
        Write-Host "Total: $(@($users).Count) | Ativos: $($ativos.Count) | Inativos: $($inativos.Count) | Na lixeira: $($deletados.Count)"

        # O instalador do GLPI cria quatro contas com senha publicada na documentacao.
        Write-Host "`nContas de fabrica:"
        $fabrica = @('glpi','tech','normal','post-only')
        $estadoFabrica = [ordered]@{}
        foreach ($f in $fabrica) {
            $conta = @($users | Where-Object { (Get-Prop $_ 'name' '') -eq $f })
            if ($conta.Count -eq 0) {
                Write-Host ("  {0,-12} ausente (correto)" -f $f) -ForegroundColor Green
                $estadoFabrica[$f] = 'ausente'
            } else {
                $ativa = (Get-Prop $conta[0] 'is_active' 0) -eq 1
                $estadoFabrica[$f] = if ($ativa) { 'ATIVA' } else { 'desativada' }
                if ($ativa) {
                    Write-Host ("  {0,-12} ATIVA - DESATIVAR (senha padrao e publica)" -f $f) -ForegroundColor Red
                } else {
                    Write-Host ("  {0,-12} desativada (correto)" -f $f) -ForegroundColor Green
                }
            }
        }
        $report['contas_fabrica'] = $estadoFabrica
        $report['usuarios'] = @{ total = @($users).Count; ativos = $ativos.Count; inativos = $inativos.Count; na_lixeira = $deletados.Count }

        Write-Host "`nBase real do Forms tem 133 colaboradores distintos abrindo chamado."
        Write-Host "Contas ativas hoje: $($ativos.Count). Lacuna: $([math]::Max(0, 133 - $ativos.Count)) conta(s)." -ForegroundColor Yellow
    } catch { Write-Warning "Nao foi possivel listar usuarios: $($_.Exception.Message)" }

    # -----------------------------------------------------------------------
    # 6. REGRAS DE NEGOCIO DE CHAMADO
    # -----------------------------------------------------------------------
    Write-Host "`n=== REGRAS DE NEGOCIO ===" -ForegroundColor Cyan
    try {
        $rules = Get-GlpiItems -ItemType 'Rule'
        $porTipo = $rules | Group-Object { Get-Prop $_ 'sub_type' '(sem tipo)' } | Sort-Object Name
        foreach ($g in $porTipo) { Write-Host ("  {0,-28} {1,3}" -f $g.Name, $g.Count) }
        $ticketRules = @($rules | Where-Object { (Get-Prop $_ 'sub_type' '') -eq 'RuleTicket' })
        Write-Host "`nRuleTicket existentes: $($ticketRules.Count)"
        foreach ($r in $ticketRules) {
            Write-Host ("    - [{0}] {1} (ativa: {2})" -f (Get-Prop $r 'ranking' '?'), (Get-Prop $r 'name' '?'), (Get-Prop $r 'is_active' '?'))
        }
        $report['regras_ticket'] = @($ticketRules | Select-Object id, name, ranking, is_active)
        $report['regras_por_tipo'] = @($porTipo | Select-Object Name, Count)
    } catch { Write-Warning "Nao foi possivel listar regras: $($_.Exception.Message)" }

    # -----------------------------------------------------------------------
    # 7. CAMPOS ACEITOS PELA VERSAO INSTALADA
    # -----------------------------------------------------------------------
    Write-Host "`n=== CAMPOS ACEITOS PELA VERSAO INSTALADA ===" -ForegroundColor Cyan
    Write-Host "Necessario porque exemplos de GLPI 10 nao garantem os mesmos campos na 11."
    $schemas = [ordered]@{}
    foreach ($t in @('Ticket','Group','ITILCategory','Calendar','CalendarSegment','Holiday','SLM','SLA','TicketValidation','Location','User')) {
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
    Write-Host "`nNao verificavel pela API, exige console no servidor via SSH:" -ForegroundColor Yellow
    Write-Host "  integridade de esquema do banco  -> bin/console database:check_schema_integrity"
    Write-Host "  versao de PHP / MariaDB / Apache -> bin/console system:status ou php -v"
    Write-Host "  cron real do sistema operacional -> systemctl list-timers / crontab -l"
    Write-Host "`nNada foi escrito no GLPI. Revise a saida antes de rodar Invoke-GlpiApply.ps1." -ForegroundColor Yellow
}
finally {
    Remove-GlpiSession
}
