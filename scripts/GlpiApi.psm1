<#
    GlpiApi.psm1 — camada de acesso a API REST do GLPI para o projeto Homy Química.

    Regras que este modulo impoe, e nao apenas sugere:
      - token NUNCA vem de arquivo. Somente de variavel de ambiente ou SecretManagement.
      - toda requisicao e registrada com o corpo SANITIZADO (segredos mascarados).
      - busca sempre por nome + entidade. Mais de um resultado = erro, nao "pega o primeiro".
      - 429 e 5xx tem retry com espera exponencial. 4xx nao tem retry.
      - a sessao e encerrada em finally, inclusive quando o script falha.

    Testado contra: a definir na primeira execucao do Discover.
    Nao presumir que campos de exemplos de GLPI 10 existam na 11.0.8.
#>

Set-StrictMode -Version Latest

$script:GlpiContext = $null
$script:AuditLog    = [System.Collections.Generic.List[object]]::new()

function Write-GlpiAudit {
    param([string]$Action, [string]$Resource, [object]$Payload, [string]$Result, [int]$StatusCode)
    $script:AuditLog.Add([pscustomobject]@{
        Timestamp  = (Get-Date).ToString('o')
        Action     = $Action
        Resource   = $Resource
        Payload    = (ConvertTo-SanitizedString $Payload)
        Result     = $Result
        StatusCode = $StatusCode
    })
}

function Get-GlpiAuditLog { $script:AuditLog }

function ConvertTo-SanitizedString {
    <# Mascara qualquer coisa que pareca segredo antes de ir para log ou tela. #>
    param([object]$Object)
    if ($null -eq $Object) { return '' }
    $text = if ($Object -is [string]) { $Object } else { $Object | ConvertTo-Json -Depth 8 -Compress }
    foreach ($pattern in @(
        '(?i)("?(user_token|app_token|session_token|password|api_token|authorization)"?\s*[:=]\s*"?)([^",}\s]+)'
    )) {
        $text = [regex]::Replace($text, $pattern, '$1***REDACTED***')
    }
    return $text
}

function New-GlpiSession {
    <#
        .SYNOPSIS
            Abre sessao na API do GLPI. Tokens vem SOMENTE de variavel de ambiente.
        .DESCRIPTION
            Defina antes de chamar, no PowerShell da Duda:
                $env:GLPI_USER_TOKEN = '<token de usuario>'
                $env:GLPI_APP_TOKEN  = '<token de aplicacao>'
            Nao coloque esses valores em nenhum .ps1, .json ou commit.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [string]$UserTokenEnvVar = 'GLPI_USER_TOKEN',
        [string]$AppTokenEnvVar  = 'GLPI_APP_TOKEN'
    )

    $userToken = [Environment]::GetEnvironmentVariable($UserTokenEnvVar)
    $appToken  = [Environment]::GetEnvironmentVariable($AppTokenEnvVar)

    if ([string]::IsNullOrWhiteSpace($userToken)) {
        throw "Variavel de ambiente $UserTokenEnvVar nao definida. Nao ha token embutido neste script por decisao de seguranca."
    }

    $apiUrl  = ($BaseUrl.TrimEnd('/')) + '/apirest.php'
    $headers = @{ 'Authorization' = "user_token $userToken"; 'Content-Type' = 'application/json' }
    if (-not [string]::IsNullOrWhiteSpace($appToken)) { $headers['App-Token'] = $appToken }

    Write-Verbose "Abrindo sessao em $apiUrl"
    try {
        $resp = Invoke-RestMethod -Uri "$apiUrl/initSession" -Method Get -Headers $headers -TimeoutSec 60
    } catch {
        Write-GlpiAudit -Action 'initSession' -Resource $apiUrl -Payload '' -Result 'FALHA' -StatusCode 0
        throw "Falha ao abrir sessao no GLPI. Verifique se a API REST esta habilitada em Configuracao > Geral > API e se o token e valido. Detalhe: $($_.Exception.Message)"
    }

    if (-not $resp.session_token) { throw 'initSession respondeu sem session_token.' }

    $sessionHeaders = @{ 'Session-Token' = $resp.session_token; 'Content-Type' = 'application/json' }
    if (-not [string]::IsNullOrWhiteSpace($appToken)) { $sessionHeaders['App-Token'] = $appToken }

    $script:GlpiContext = [pscustomobject]@{ ApiUrl = $apiUrl; Headers = $sessionHeaders }
    Write-GlpiAudit -Action 'initSession' -Resource $apiUrl -Payload '' -Result 'OK' -StatusCode 200
    Write-Verbose 'Sessao aberta.'
    return $script:GlpiContext
}

function Remove-GlpiSession {
    [CmdletBinding()]
    param()
    if ($null -eq $script:GlpiContext) { return }
    try {
        Invoke-RestMethod -Uri "$($script:GlpiContext.ApiUrl)/killSession" -Method Get -Headers $script:GlpiContext.Headers -TimeoutSec 30 | Out-Null
        Write-GlpiAudit -Action 'killSession' -Resource $script:GlpiContext.ApiUrl -Payload '' -Result 'OK' -StatusCode 200
        Write-Verbose 'Sessao encerrada.'
    } catch {
        Write-Warning "Nao foi possivel encerrar a sessao limpa: $($_.Exception.Message)"
    } finally {
        $script:GlpiContext = $null
    }
}

function Invoke-GlpiRequest {
    <# Requisicao com retry exponencial em 429 e 5xx. 4xx nao repete: erro de dados nao melhora repetindo. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Get','Post','Put','Delete')][string]$Method = 'Get',
        [object]$Body,
        [int]$MaxRetries = 4
    )
    if ($null -eq $script:GlpiContext) { throw 'Sem sessao ativa. Chame New-GlpiSession primeiro.' }

    $uri     = "$($script:GlpiContext.ApiUrl)/$($Path.TrimStart('/'))"
    $json    = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 10 } else { $null }
    $attempt = 0

    while ($true) {
        $attempt++
        try {
            $params = @{ Uri = $uri; Method = $Method; Headers = $script:GlpiContext.Headers; TimeoutSec = 120 }
            if ($json) { $params['Body'] = $json }
            $result = Invoke-RestMethod @params
            Write-GlpiAudit -Action $Method -Resource $Path -Payload $Body -Result 'OK' -StatusCode 200
            return $result
        } catch {
            $status = 0
            if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
                try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
            }
            $retryable = ($status -eq 429 -or $status -ge 500 -or $status -eq 0)

            if ($retryable -and $attempt -le $MaxRetries) {
                $wait = [math]::Pow(2, $attempt)
                Write-Warning "HTTP $status em $Path. Tentativa $attempt de $MaxRetries. Aguardando ${wait}s."
                Start-Sleep -Seconds $wait
                continue
            }
            Write-GlpiAudit -Action $Method -Resource $Path -Payload $Body -Result 'FALHA' -StatusCode $status
            throw "Requisicao $Method $Path falhou com HTTP $status. $($_.Exception.Message)"
        }
    }
}

function Get-GlpiItems {
    <# Lista todos os itens de um tipo, tratando paginacao por Content-Range. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ItemType,
        [int]$PageSize = 200,
        [switch]$Recursive
    )
    $all   = [System.Collections.Generic.List[object]]::new()
    $start = 0
    while ($true) {
        $q = "range=$start-$($start + $PageSize - 1)"
        if ($Recursive) { $q += '&is_recursive=1' }
        $page = Invoke-GlpiRequest -Path "$ItemType`?$q"
        if ($null -eq $page) { break }
        $items = @($page)
        if ($items.Count -eq 0) { break }
        $all.AddRange($items)
        if ($items.Count -lt $PageSize) { break }
        $start += $PageSize
    }
    return $all
}

function Find-GlpiItem {
    <#
        .SYNOPSIS
            Localiza UM item por nome (e opcionalmente entidade). Ambiguidade e erro.
        .DESCRIPTION
            Nunca "pega o primeiro". Se dois objetos tem o mesmo nome na mesma entidade,
            isso e um problema de dados que precisa de decisao humana, nao de palpite do script.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ItemType,
        [Parameter(Mandatory)][string]$Name,
        [Nullable[int]]$EntityId,
        [object[]]$Cache
    )
    $pool = if ($Cache) { $Cache } else { Get-GlpiItems -ItemType $ItemType }
    $hits = @($pool | Where-Object {
        $_.PSObject.Properties.Name -contains 'name' -and
        $_.name -eq $Name -and
        ($null -eq $EntityId -or ($_.PSObject.Properties.Name -contains 'entities_id' -and $_.entities_id -eq $EntityId))
    })

    if ($hits.Count -gt 1) {
        throw "AMBIGUIDADE: $($hits.Count) objetos '$ItemType' chamados '$Name'" +
              $(if ($null -ne $EntityId) { " na entidade $EntityId" }) +
              ". Resolva manualmente antes de continuar. IDs: $($hits.id -join ', ')"
    }
    if ($hits.Count -eq 0) { return $null }
    return $hits[0]
}

function Set-GlpiItemIdempotent {
    <#
        .SYNOPSIS
            Cria o item se nao existir; atualiza SOMENTE os campos declarados se existir.
        .DESCRIPTION
            Respeita -WhatIf. Nunca apaga campo que o chamador nao declarou.
            Retorna objeto com Action = Criado | Atualizado | Inalterado.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$ItemType,
        [Parameter(Mandatory)][hashtable]$Fields,
        [Nullable[int]]$EntityId,
        [object[]]$Cache
    )
    if (-not $Fields.ContainsKey('name')) { throw "Set-GlpiItemIdempotent exige a chave 'name' em -Fields." }
    $name     = $Fields['name']
    $existing = Find-GlpiItem -ItemType $ItemType -Name $name -EntityId $EntityId -Cache $Cache

    if ($null -eq $existing) {
        if ($PSCmdlet.ShouldProcess("$ItemType '$name'", 'CRIAR')) {
            $created = Invoke-GlpiRequest -Path $ItemType -Method Post -Body @{ input = $Fields }
            $newId   = if ($created -is [array]) { $created[0].id } else { $created.id }
            return [pscustomobject]@{ ItemType = $ItemType; Name = $name; Id = $newId; Action = 'Criado'; Changed = $Fields.Keys -join ',' }
        }
        return [pscustomobject]@{ ItemType = $ItemType; Name = $name; Id = $null; Action = 'Criaria (WhatIf)'; Changed = $Fields.Keys -join ',' }
    }

    $diff = @{}
    foreach ($k in $Fields.Keys) {
        if ($k -eq 'name') { continue }
        $current = if ($existing.PSObject.Properties.Name -contains $k) { $existing.$k } else { $null }
        if ("$current" -ne "$($Fields[$k])") { $diff[$k] = $Fields[$k] }
    }

    if ($diff.Count -eq 0) {
        return [pscustomobject]@{ ItemType = $ItemType; Name = $name; Id = $existing.id; Action = 'Inalterado'; Changed = '' }
    }
    if ($PSCmdlet.ShouldProcess("$ItemType '$name' (id $($existing.id))", "ATUALIZAR: $($diff.Keys -join ', ')")) {
        $diff['id'] = $existing.id
        Invoke-GlpiRequest -Path $ItemType -Method Put -Body @{ input = $diff } | Out-Null
        return [pscustomobject]@{ ItemType = $ItemType; Name = $name; Id = $existing.id; Action = 'Atualizado'; Changed = (($diff.Keys | Where-Object { $_ -ne 'id' }) -join ',') }
    }
    return [pscustomobject]@{ ItemType = $ItemType; Name = $name; Id = $existing.id; Action = 'Atualizaria (WhatIf)'; Changed = (($diff.Keys | Where-Object { $_ -ne 'id' }) -join ',') }
}

function Get-GlpiFieldSchema {
    <# Campos que a versao INSTALADA aceita para um itemtype. Use antes de assumir nome de campo. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ItemType)
    return Invoke-GlpiRequest -Path "listSearchOptions/$ItemType"
}

Export-ModuleMember -Function New-GlpiSession, Remove-GlpiSession, Invoke-GlpiRequest,
    Get-GlpiItems, Find-GlpiItem, Set-GlpiItemIdempotent, Get-GlpiFieldSchema,
    Get-GlpiAuditLog, ConvertTo-SanitizedString
