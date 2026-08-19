# 01 — Análise das fontes reais

Levantado em 19/08/2026 a partir dos artefatos vivos do Microsoft 365, não de memória de sessão anterior.

## Fontes lidas

| Fonte | Local | Data | O que provou |
|---|---|---|---|
| `Chamados de TI - Homy.xlsx` | `sites/TI-Chamados/Documentos Compartilhados` | atualizado 19/08/2026, base até 11/08/2026 | 627 chamados, 133 colaboradores, 26 setores, e as 56 colunas do Forms |
| `DOC SISTEMA CHAMADOS TI - HOMY.docx` | OneDrive Duda, chats do Teams | v2.0, Janeiro/2026 | Arquitetura Forms → Power Automate → Planner → SharePoint → Teams |
| `Documentação Service Desk 2 13-04.docx` | OneDrive Duda, `Projects/Service Desk - Homy` | 13/04/2026 | Evolução para Dataverse, State Engine, SLA, aprovação e 15 decisões arquiteturais datadas |

## O que não foi possível ler

**Planner ao vivo.** O conector Microsoft 365 desta sessão expõe Outlook, Teams, SharePoint e OneDrive — não expõe Planner nem a estrutura de perguntas do Microsoft Forms. Os buckets e os cards foram reconstruídos a partir da documentação e **confirmados por Duda em 19/08/2026** como sendo o conjunto de 6 buckets da decisão de 09/03/2026:

```
INFRA · INFRA (Em Andamento) · INFRA (Concluído)
SISTEMAS (Protheus / Fluig / Transmite) · SISTEMAS (Em Andamento) · SISTEMAS (Concluído)
```

O conjunto de 7 buckets do DOC v2.0 (Não Atendidos, Pausado, Aguardando Manutenção Interna/Externa, Aguardando Suprimentos, Resolvido) está **superado**. Seus estados de espera não viram status no GLPI — viram motivos de pendência (ver `docs/04`).

**Contagem de cards ativos.** Não foi possível contar quantos cards estão abertos hoje. A migração (`docs/07`) depende dessa contagem e ela precisa ser extraída antes do corte.

## Volume real por categoria

Amostra de 318 registros legíveis da aba `Chamados` (o arquivo excede o limite de leitura em uma passada; a distribuição bate com a análise anterior de 580 respostas, o que a torna representativa).

| Categoria do chamado | Amostra | % | Destino no GLPI |
|---|---:|---:|---|
| Sistemas (Protheus / Fluig / Transmite) | 164 | 51,6% | Formulário Sistemas |
| Outro | 31 | 9,7% | Formulário Triagem |
| E-mail / Microsoft 365 | 29 | 9,1% | Formulário M365 |
| Periféricos | 18 | 5,7% | Formulário Infraestrutura |
| Acessos e permissões | 18 | 5,7% | **Formulário Acessos (novo)** |
| Computador / Notebook | 13 | 4,1% | Formulário Infraestrutura |
| Acessos e permissões (Arquivos F:) | 8 | 2,5% | **Formulário Acessos (novo)** |
| Uso interno do TI | 5 | 1,6% | **Formulário Uso Interno (novo)** |
| Novo colaborador / Mudança / Desligamento | 4 | 1,3% | **Formulário Ciclo de Vida (novo)** |
| Internet / Wi-Fi / Rede / VPN | 3 | 0,9% | Formulário Infraestrutura |
| Infraestrutura / Predial / CFTV | 3 | 0,9% | Formulário Infraestrutura |
| Melhoria / Projeto / Automação | 2 | 0,6% | Formulário M365 |
| Compras / NF / Rateio | 2 | 0,6% | **Formulário Compras (novo)** |

**Consequência de projeto:** Sistemas é metade do volume e é o único ramo com estrutura condicional rica. Acessos somados (5,7% + 2,5% = 8,2%) superam Computador/Notebook e não tinham formulário próprio — passam a ter, porque são também o ramo que exige aprovação.

## Dentro de Sistemas

| Sistema | Amostra |
|---|---:|
| ERP – Protheus | 157 |
| Fluig | 6 |
| Outro sistema | 1 |

Módulos do Protheus com volume real: Livros Fiscais (31), PCP (22), Compras (21), Faturamento (20), Call Center (16), Gestão de Pessoal (15), Estoque e Custos (14), Meu RH (4), Financeiro (4), Ativo Fixo (4), Específicos Homy (3), Contabilidade Gerencial (2), Manutenção de Ativos (1).

Tipos de demanda Protheus: Parametrização/cadastro (49), Outros (34), Acesso/criação/bloqueio (20), Erro na tela SmartClient (18+17), Relatório (14), Melhoria/Customização (5).

**Consequência:** Fluig e Transmite juntos não chegam a 5% do volume de Sistemas. Manter os três no mesmo formulário com condicional é correto; criar três formulários separados não é.

## Volume por setor — base de 604 chamados com setor preenchido

| Setor | Chamados | | Setor | Chamados |
|---|---:|---|---|---:|
| Comercial | 91 | | Recepção | 12 |
| Fiscal | 84 | | SGI | 7 |
| RH | 72 | | Diretoria Presidencial | 6 |
| TI | 62 | | Qualidade | 5 |
| Laboratório | 40 | | Marketing | 5 |
| Suprimentos | 39 | | Expedição | 5 |
| Contabilidade | 28 | | Almoxarifado Insumos / MP | 3 |
| PCP | 25 | | Manutenção | 2 |
| Financeiro | 21 | | Gerência Geral | 2 |
| Custos | 21 | | Controladoria | 2 |
| Produção | 20 | | Diretoria Técnica | 1 |
| Faturamento / Logística | 20 | | Diretoria Administrativa | 1 |
| Portaria | 16 | | | |
| HomyTec | 14 | | **Total** | **604** |

Esses 26 setores viram grupos organizacionais `Setor | <nome>` no GLPI. Não viram entidades — nenhum deles presta atendimento.

## O viés que sustenta a decisão de não perguntar prioridade

Campo "Qual a prioridade do chamado?", 287 respostas preenchidas na amostra:

| Autoavaliação | Respostas | % |
|---|---:|---:|
| Média (Prejudica, mas dá pra seguir) | 108 | 37,6% |
| **Alta (Impede o trabalho)** | **101** | **35,2%** |
| Baixa (Não impede o trabalho) | 78 | 27,2% |

Um terço da base declarando "impede o trabalho" é incompatível com a operação real. A medição anterior deu 33% sobre 580 respostas; esta deu 35,2% sobre 287. Duas amostras independentes convergindo confirmam o viés, não um acaso.

**Decisão:** o campo é descontinuado. Prioridade passa a ser calculada por impacto × urgência a partir de perguntas factuais (`docs/04`).

## Divergências encontradas contra o contexto anterior

Registradas porque mudam a configuração:

1. **Gestora da TI.** O documento de 09/03/2026 define **Fabia Garcia** como a aprovadora do fluxo ("Solicitar aprovação da Fabia", via Adaptive Card no Teams). O contexto herdado atribuía gestão/supervisão a Ricardo. Fabia aparece na base com 9 chamados sob o setor TI. **Ambos foram mantidos em `TI | Gestão`**; a aprovação de negócio, porém, foi direcionada ao gestor do setor solicitante, conforme decisão de Duda em 19/08/2026.
2. **Responsável por Sistemas.** O mesmo documento define "SISTEMAS → Bárbara" como responsável automático. Bárbara não consta do contexto herdado nem da equipe declarada (Duda, Ricardo, Mateus, André). **Pendência aberta** — confirmar antes de popular `TI | Sistemas Protheus`.
3. **Arquitetura de origem evoluiu.** O sistema atual não é mais Forms → Planner → SharePoint. É Forms → Power Automate → **Dataverse** → Planner → Teams → SharePoint, com Dataverse como fonte única de verdade (decisões 01 e 10). O corte para o GLPI precisa desligar também os fluxos de Dataverse, não apenas o Forms.
4. **Ramos do Forms sem formulário no GLPI.** As colunas 25–47 (admissão/mudança/desligamento) e 49–51 (fornecedores) são ramos completos e ativos do Forms atual que não tinham correspondente entre os formulários já construídos no GLPI. Ambos passam a ter.
