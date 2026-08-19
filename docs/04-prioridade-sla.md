# 04 — Calendário, prioridade, status e SLA

Ordem obrigatória: **calendário → feriados → matriz de prioridade → SLA**. SLA configurado antes do calendário produz prazo errado com aparência de certo.

## Calendário útil

**Comercial Homy - TI** — Segunda a sexta, **07:45 às 17:10**. Confirmado por Duda em 19/08/2026.

- 565 minutos por dia útil
- 47h05 por semana

> **Pendência que muda todos os números abaixo:** não foi informado se há intervalo de almoço a excluir do relógio de SLA. Se houver 1h de intervalo, o dia útil cai para 505 minutos e todos os prazos em dias sobem ~12%. O GLPI aceita dois segmentos por dia — é uma alteração de um campo, mas precisa ser decidida **antes** de o SLA entrar em produção.

**Feriados — pendência bloqueante.** Feriados nacionais, estaduais, municipais e o recesso da Homy não foram informados. Sem eles, o GLPI conta 20/11 e 25/12 como dias úteis e vence SLA de chamado que ninguém tinha como atender. **O SLA não entra em produção sem o calendário de feriados carregado.**

## Prioridade: impacto × urgência

O GLPI calcula prioridade a partir de urgência e impacto. O papel do formulário é alimentar os dois com **fato**, não com autoavaliação.

### Impacto — de "Quantas pessoas foram afetadas?"

| Resposta do colaborador | Impacto GLPI |
|---|---|
| Só eu | 2 — Baixo |
| Meu setor | 3 — Médio |
| Múltiplos setores | 4 — Alto |
| Empresa toda | 5 — Muito alto |

### Urgência — de "Seu trabalho está totalmente parado?" + tipo

| Situação | Urgência GLPI |
|---|---|
| Incidente **e** trabalho totalmente parado | 4 — Alta |
| Incidente sem parada total | 3 — Média |
| Requisição planejada | 2 — Baixa |
| Dúvida, melhoria ou uso interno do TI | 1 — Muito baixa |

### Matriz resultante

| Urgência ↓ / Impacto → | 2 Só eu | 3 Meu setor | 4 Múltiplos setores | 5 Empresa toda |
|---|---|---|---|---|
| **4 Parado (incidente)** | P3 Média | P2 Alta | **P1 Crítica** | **P1 Crítica** |
| **3 Prejudica (incidente)** | P3 Média | P3 Média | P2 Alta | P2 Alta |
| **2 Requisição** | P4 Baixa | P4 Baixa | P3 Média | P2 Alta |
| **1 Melhoria / uso interno** | P5 Muito baixa | P4 Baixa | P3 Média | P3 Média |

Leitura: um usuário sozinho travado é P3, não P1. A empresa toda travada é P1 mesmo que ninguém tenha marcado "urgente". É exatamente a correção que os 35% de autoavaliação "Alta" tornavam necessária.

## Status e motivos de pendência

Usar **os status nativos do GLPI**. Não criar status personalizados para representar espera.

| Estado operacional | GLPI |
|---|---|
| Chamado recebido | Novo |
| Em atendimento | Processando (atribuído) / Processando (planejado) |
| Parado esperando algo | **Pendente** + motivo obrigatório |
| Resolvido | Solucionado |
| Encerrado | Fechado |

### Motivos de pendência

Os buckets de espera do Planner antigo sobrevivem aqui — como motivo, não como status:

- Aguardando solicitante
- Aguardando fornecedor
- Aguardando manutenção externa
- Aguardando manutenção interna
- Aguardando suprimentos / compra
- Aguardando aprovação
- Aguardando agendamento com o usuário

Por que motivo e não status: o relógio de SLA pausa em Pendente e o motivo diz **por quê**. Sete status de espera produziriam sete relógios diferentes e nenhum relatório confiável de "quanto tempo a TI realmente segurou o chamado".

### Regras de transição

- **Pendente** exige motivo.
- **Solucionado** exige descrição da solução.
- **Reabertura** exige comentário.
- **Cancelamento** exige motivo.

Isso é o equivalente nativo da `homy_regratransicaostatus` do desenho em Dataverse — sem precisar construir uma State Engine.

**Reabertura:** o desenho de origem define 7 dias, acima disso cria chamado novo vinculado. O GLPI faz isso por configuração de fechamento automático + prazo de reabertura. Aplicar apenas depois de testar o período com a equipe.

## SLA proposto

> **Status: proposta.** Não configurar em produção antes da aprovação de Fabia e/ou Ricardo. Números derivados do blueprint anterior e recalculados sobre o calendário real de 565 min/dia.

| Prioridade | TTO (atendimento) | TTR (resolução) | TTR em dias úteis |
|---|---|---|---|
| **P1 Crítica** | 15 min | 4h úteis | ~0,4 dia |
| **P2 Alta** | 1h útil | 8h úteis | ~0,9 dia |
| **P3 Média** | 4h úteis | 16h úteis | ~1,7 dia |
| **P4 Baixa** | 8h úteis | 40h úteis | ~4,3 dias |
| **P5 Muito baixa** | 8h úteis | 80h úteis | ~8,5 dias |

Se houver 1h de almoço a excluir (505 min/dia), os dias equivalentes passam a 0,5 · 1,0 · 1,9 · 4,8 · 9,5.

> **Não chamar TTO de "primeira resposta"** antes de testar, na 11.0.8 instalada, qual evento encerra o relógio. Em algumas configurações é a atribuição, em outras o primeiro acompanhamento. Isso muda o comportamento e precisa de chamado de teste, não de suposição.

## Escalonamento

| Consumo do SLA | Quem é notificado |
|---|---|
| 50% | Grupo atribuído |
| 75% | Grupo atribuído + Duda + `TI \| Gestão` |
| 100% | `TI \| Gestão`, chamado marcado como vencido |

**Alerta de SLA nunca vai ao solicitante.** Escalonamento é instrumento interno de gestão; mandar "seu chamado está atrasado" para quem espera só gera um segundo chamado cobrando o primeiro.

## O que precisa ser aprovado antes de ligar

1. Intervalo de almoço — entra ou não no relógio.
2. Calendário de feriados e recesso.
3. Os prazos da tabela de SLA (Fabia / Ricardo).
4. O valor de corte para escalonar compras à Diretoria (`docs/03`, formulário 6).
