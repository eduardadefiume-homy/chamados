# 07 — Migração e corte

## O que está sendo desligado

O sistema atual não é mais o desenho de Janeiro/2026. Evoluiu para:

```
Forms → Power Automate → Dataverse (fonte de verdade) → Planner (UI operacional)
                              ↓            ↓
                        SharePoint      Teams (comunicação)
```

Consequência prática: **o corte precisa desligar mais coisas do que o previsto.** Não basta desligar o gatilho do Forms. Ficam órfãos, se ninguém tratar:

| Componente | O que fazer no corte |
|---|---|
| Microsoft Forms "Chamados de TI" | Desativar o formulário e publicar aviso apontando para o GLPI |
| Fluxo 01 — Abertura (Forms → Dataverse → Planner) | Desligar |
| Fluxo 02 — Evidências (Forms → SharePoint) | Desligar |
| Fluxo de sincronização Planner ↔ Dataverse (recorrência 3–5 min) | Desligar — senão continua rodando e notificando para sempre |
| Solution `Homy.ServiceDesk.Core` (Dataverse) | Congelar em somente leitura. Não excluir: é o histórico |
| Planner "Chamados TI" | Congelar. Cards fechados permanecem consultáveis como arquivo |
| SharePoint — evidências e lista `Estado Chamados Planner` | Manter como arquivo somente leitura |
| Canal/chats do Teams | Manter histórico; parar de criar chat novo por chamado |

**Nunca deixar Forms, Planner e GLPI ativos ao mesmo tempo.** Três fontes ativas produzem três verdades e nenhuma confiável.

## Migração de cards

**Migrar apenas cards ativos.** Não importar histórico fechado.

Cards a migrar — os que estiverem nos buckets de trabalho:

- `INFRA`
- `INFRA (Em Andamento)`
- `SISTEMAS (Protheus / Fluig / Transmite)`
- `SISTEMAS (Em Andamento)`

Cards em `INFRA (Concluído)` e `SISTEMAS (Concluído)` **não migram** — ficam no Planner como arquivo.

### Mapa de estado

| Bucket do Planner | Status no GLPI | Grupo |
|---|---|---|
| INFRA | Novo | `TI \| Infraestrutura` |
| INFRA (Em Andamento) | Processando (atribuído) | `TI \| Infraestrutura` |
| INFRA (Concluído) | *não migra* | — |
| SISTEMAS (Protheus / Fluig / Transmite) | Novo | `TI \| Sistemas Protheus` |
| SISTEMAS (Em Andamento) | Processando (atribuído) | `TI \| Sistemas Protheus` |
| SISTEMAS (Concluído) | *não migra* | — |

Os estados de espera do conjunto antigo de 7 buckets (Pausado, Aguardando Manutenção Interna / Externa / Suprimentos) não têm bucket próprio hoje. Se algum card ainda carregar esse estado em etiqueta ou comentário, ele entra no GLPI como **Pendente + motivo correspondente** (`docs/04`).

### Como cada card migra

Cada chamado migrado recebe:

- **Origem:** `Migração Planner`
- **ID original** do card do Planner
- **Link** para o card original
- Descrição, solicitante, setor e data de abertura originais preservados
- Categoria e grupo conforme o mapa acima

### Regras da carga

1. **Suspender notificações antes da carga.** 100 chamados importados com notificação ligada geram 100 e-mails para gente que não pediu nada. Religar depois.
2. **Backup verificado antes** — banco e arquivos, com restauração testada, não só existência de arquivo.
3. **Reconciliar por contagem, ID e status.** Contar cards ativos no Planner antes, contar chamados criados no GLPI depois, conferir um a um os IDs. Divergência de um card já invalida a carga.
4. Rodar em homologação primeiro.

## Pendência bloqueante da migração

**A contagem de cards ativos não foi levantada.** Não há ferramenta de Planner nesta sessão e a lista `Estado Chamados Planner` do SharePoint não é alcançável pelas ferramentas de arquivo disponíveis.

Antes do corte, extrair do Planner (ou da tabela `homy_chamado` do Dataverse, que é a fonte de verdade atual):

- quantidade de cards em cada um dos 4 buckets ativos;
- para cada card: ID, título, solicitante, setor, data de abertura, descrição, responsável, anexos.

Sem essa extração não há como reconciliar a carga — e carga sem reconciliação não é migração, é esperança.

## Sequência do corte

1. Homologação completa aprovada (`docs/08`)
2. Contagem de cards ativos extraída e conferida
3. Backup verificado com restauração testada
4. Notificações suspensas
5. Carga dos cards ativos
6. Reconciliação por contagem, ID e status
7. Notificações religadas
8. **Comunicado oficial** publicado: o canal de abertura passa a ser o GLPI
9. Forms desativado, fluxos do Power Automate desligados, Planner congelado
10. Dataverse e SharePoint congelados em somente leitura
11. Janela de acompanhamento com plano de retorno ativo

## Plano de retorno

Definido **antes** do corte, com responsável e janela:

- Se o GLPI apresentar falha crítica na primeira semana, o Forms é reativado e os fluxos religados.
- Chamados abertos no GLPI durante a janela precisam ser transportados manualmente de volta — por isso a janela é curta e monitorada.
- Responsável pela decisão de retorno: `TI | Gestão`.

Corte sem plano de retorno escrito não deve acontecer.
