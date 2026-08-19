# GLPI Homy Química — configuração do Service Desk

Configuração como código do GLPI da Homy Química, derivada dos dados reais do sistema atual (Microsoft Forms → Power Automate → Dataverse → Planner → Teams → SharePoint).

**Levantamento e desenho:** 19/08/2026.

## Estado confirmado nesta data

| Item | Estado |
|---|---|
| Versão instalada | 11.0.8 |
| Release corrigida atual | **11.0.8 (24/06/2026)** — confirmado em `github.com/glpi-project/glpi/releases` em 19/08/2026. Nenhuma 11.0.x posterior publicada |
| Vulnerabilidades cobertas | CVE-2026-48482 (RCE no importador de formulários), CVE-2026-52848 e CVE-2026-49470 (desvio de MFA), CVE-2026-53625 (escalação de privilégio) |
| Conclusão | A instalação está no piso de segurança e é seguro importar formulário |

## O que este repositório contém

```
docs/         decisões, especificação e critérios de aceite
blueprint/    catálogo declarativo em JSON + planilhas de apoio
scripts/      provisionador PowerShell em duas fases + testes
```

| Documento | Conteúdo |
|---|---|
| [`docs/01-analise-origem.md`](docs/01-analise-origem.md) | 627 chamados, 133 colaboradores, 26 setores, as 56 colunas do Forms e as divergências encontradas |
| [`docs/02-arquitetura-glpi.md`](docs/02-arquitetura-glpi.md) | Entidades, perfis, 7 grupos técnicos, 26 grupos de setor, grupos de aprovação |
| [`docs/03-catalogo-formularios.md`](docs/03-catalogo-formularios.md) | Os 8 formulários especificados campo a campo, com condicionais |
| [`docs/04-prioridade-sla.md`](docs/04-prioridade-sla.md) | Calendário, matriz impacto × urgência, status, motivos de pendência e SLA |
| [`docs/05-aprovacoes.md`](docs/05-aprovacoes.md) | Validação nativa dirigida ao gestor do setor do solicitante |
| [`docs/06-roteamento-notificacoes.md`](docs/06-roteamento-notificacoes.md) | Regras de roteamento e matriz de notificações |
| [`docs/07-migracao-corte.md`](docs/07-migracao-corte.md) | Migração dos cards ativos e plano de corte com retorno |
| [`docs/08-homologacao.md`](docs/08-homologacao.md) | 21 cenários de teste, isolamento, segurança e governança contínua |

## As decisões que sustentam o desenho

**1. Prioridade é calculada, não declarada.** No Forms atual, 35% dos chamados se autoavaliaram como "Alta (impede o trabalho)" — medido em duas amostras independentes (33% em 580 respostas, 35,2% em 287). O campo é descontinuado. Prioridade passa a sair de impacto × urgência, alimentados por duas perguntas factuais presentes em todos os formulários.

**2. Nome, e-mail, setor e data não se perguntam.** Vêm do usuário autenticado e do carimbo do GLPI. Isso elimina 4 das 56 colunas — e depende de cada colaborador ter conta individual com setor preenchido.

**3. Chamado vai para grupo, nunca para pessoa.** O desenho de origem amarrava tudo a duas pessoas nomeadas ("INFRA → Eduarda", "SISTEMAS → Bárbara"). Aqui o grupo recebe e o técnico assume depois.

**4. Espera é motivo de pendência, não status.** Os buckets de espera do Planner (Pausado, Aguardando Manutenção Interna/Externa, Aguardando Suprimentos) viram motivos dentro do status nativo **Pendente**. Sete status de espera produziriam sete relógios e nenhum relatório confiável.

**5. Aprova-se concessão e custo; não se aprova conserto.** Acesso, admissão e compra exigem validação do gestor do setor. Incidente não.

**6. Muitos formulários curtos.** Oito formulários dedicados no lugar de um Forms de 56 perguntas.

## Ordem de execução

Os portões são sequenciais. Não pular um porque a tela seguinte parece disponível.

| # | Etapa | Como | Bloqueante |
|---|---|---|---|
| 1 | Descoberta do estado real | `Invoke-GlpiDiscover.ps1` | — |
| 2 | Backup com restauração testada | manual | **sim** |
| 3 | Entidades, grupos, categorias, calendário | `Invoke-GlpiApply.ps1 -WhatIf` e depois sem | — |
| 4 | Feriados do calendário | interface | **sim, para o SLA** |
| 5 | Contas individuais dos 133 colaboradores | importação de identidade | **sim, para roteamento e aprovação** |
| 6 | Preencher `setores-gestores.csv` | manual | **sim, para aprovação** |
| 7 | Construir os 8 formulários | interface (`docs/03`) | — |
| 8 | Regras de roteamento e prioridade | interface (`docs/06`) | — |
| 9 | Aprovar e ativar o SLA | Fabia / Ricardo (`docs/04`) | **sim** |
| 10 | Notificações e assinatura de e-mail | interface (`docs/06`) | — |
| 11 | Homologação — 21 cenários | `docs/08` | **sim** |
| 12 | Migração e corte | `docs/07` | — |

## Usando o provisionador

Precisa de PowerShell 7+. Testado em 7.4.6.

```powershell
# tokens vêm do ambiente. Nunca de arquivo, nunca de commit.
$env:GLPI_USER_TOKEN = '<token de usuário>'
$env:GLPI_APP_TOKEN  = '<token de aplicação>'

# fase 1 — somente leitura, não escreve nada
.\scripts\Invoke-GlpiDiscover.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -Verbose

# fase 2 — simulação primeiro, sempre
.\scripts\Invoke-GlpiApply.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -WhatIf -Verbose

# fase 2 — aplicando de verdade, depois de revisar a simulação
.\scripts\Invoke-GlpiApply.ps1 -BaseUrl 'https://chamados.homyquimica.com.br' -Confirm
```

Garantias do provisionador, verificadas por `scripts/tests/Test-GlpiApi.ps1` (5/5 em 19/08/2026):

- token só vem de variável de ambiente — o script se recusa a rodar sem;
- segredos são mascarados no log de auditoria;
- busca por nome + entidade, e **ambiguidade lança erro** em vez de "pegar o primeiro";
- cria o ausente, atualiza só os campos declarados, não toca no resto;
- retry exponencial em 429 e 5xx; 4xx não repete;
- sessão encerrada em `finally`, inclusive quando o script falha;
- recusa aplicar se a versão estiver abaixo de 11.0.8;
- recusa criar SLA se o calendário não existir;
- gera CSV de diferenças e de auditoria a cada execução.

O provisionador **não** cria formulários, regras de negócio nem notificações. Esses três são construídos na interface, revisados e só então exportados em JSON nativo.

## Pendências abertas

| # | Pendência | Bloqueia | Dono |
|---|---|---|---|
| 1 | Contas individuais dos 133 colaboradores e fonte de identidade (local / LDAP / Entra ID) | Roteamento por setor e aprovação | Duda |
| 2 | Mapa setor → gestor em `blueprint/setores-gestores.csv` | Aprovação | Duda |
| 3 | Feriados e recesso da Homy | SLA em produção | Duda |
| 4 | Intervalo de almoço entra ou não no relógio de SLA | Todos os prazos | Duda |
| 5 | Aprovação dos prazos de SLA | SLA em produção | Fabia / Ricardo |
| 6 | Contagem de cards ativos no Planner | Migração e reconciliação | Duda |
| 7 | Quem é "Bárbara", responsável por SISTEMAS no desenho de origem | Composição de `TI \| Sistemas Protheus` | Duda |
| 8 | Estado do cron / ações automáticas | Notificação e escalonamento de SLA | Duda |
| 9 | Valor de corte para escalar compra à Diretoria | Regra do formulário 6 | Duda |
| 10 | Localizações físicas (planta da Homy) | Regras que dependem de local | Duda |
| 11 | Endereço remetente e caixa coletora definitivos | Notificações | Duda |
| 12 | PHP, MariaDB, servidor web e plugins instalados | Preflight | `Invoke-GlpiDiscover.ps1` resolve parte |

## Liberando o acesso ao GLPI a partir do Claude Code

Nesta sessão, `chamados.homyquimica.com.br` foi recusado pela política de rede do ambiente (403 no CONNECT do proxy). Para que uma sessão futura consiga rodar o provisionador direto contra a API:

1. Em [claude.ai/code](https://claude.ai/code), abra o seletor de ambiente (ícone de nuvem) e edite o ambiente usado — ou crie um novo com **Add cloud environment**.
2. Em **Network access**, troque de **Trusted** para **Custom**.
3. Em **Allowed domains**, acrescente uma linha:

   ```text
   chamados.homyquimica.com.br
   ```

4. Marque **Also include default list of common package managers** — sem isso o ambiente perde o acesso aos registries de pacote.
5. Salve e **abra uma sessão nova**. A política é aplicada na criação da sessão; a atual continua bloqueada.

O tráfego de GitHub e o dos conectores MCP (Microsoft 365) usam caminhos próprios e não passam por essa allowlist — por isso a leitura do SharePoint funcionou mesmo com o GLPI bloqueado.

## Limites deste levantamento

- **Planner não foi lido ao vivo.** O conector Microsoft 365 desta sessão expõe Outlook, Teams, SharePoint e OneDrive — não expõe Planner nem a estrutura de perguntas do Forms. Buckets e cards vieram da documentação e foram confirmados por Duda; a contagem de cards ativos continua pendente.
- **O GLPI não foi acessado.** `chamados.homyquimica.com.br` está bloqueado pela política de rede do ambiente Claude Code (403 no CONNECT do proxy). Nada foi lido nem escrito no servidor. Todo estado do GLPI citado aqui é herdado de sessões anteriores e precisa ser reconfirmado pelo `Invoke-GlpiDiscover.ps1`.
- **A base de chamados foi lida em amostra.** 318 de 627 linhas (o arquivo excede o limite de leitura em uma passada). As distribuições convergem com a análise anterior de 580 respostas, o que as torna representativas — mas são amostra, não censo.
