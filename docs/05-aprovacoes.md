# 05 — Aprovação de gestores (validação nativa do GLPI)

**Decisão de Duda em 19/08/2026:** o aprovador é o **gestor do setor do solicitante**.

Isso substitui o desenho de origem, em que a aprovação era um Adaptive Card no Teams dirigido a uma pessoa fixa (Fabia). O motivo é de controle, não de preferência: quem autoriza um colaborador a receber acesso, equipamento ou custo é o gestor daquele colaborador — não a TI. A TI **executa** o que foi aprovado; não é ela quem aprova o pedido de outra área.

## Como fica no GLPI

O GLPI tem **Validação** nativa em chamado. Ela pode ser dirigida a um usuário ou a um **grupo**. Usamos grupo.

```
Solicitante  →  pertence a  →  Setor | Fiscal
                                    ↓  (regra de negócio)
                              Gestores | Fiscal   ←  validação do chamado
                                    ↓
                        qualquer membro aprova ou recusa
```

**Por que grupo e não pessoa:** um aprovador nomeado em férias trava a fila inteira daquele setor. Grupo com dois membros (gestor + substituto) não trava. Também evita reconfigurar regra toda vez que alguém muda de cargo.

## O que exige aprovação

| Formulário | Aprovação | Aprovador | Por quê |
|---|---|---|---|
| 4 — Acessos e Permissões | **obrigatória** | `Gestores \| <setor do solicitante>` | Concessão de permissão sem aprovação registrada é achado de auditoria. O padrão "copiar tudo o que o fulano tem acesso" está em uso real na base e concede permissão por herança sem ninguém revisar o que está sendo herdado |
| 5 — Ciclo de Vida do Colaborador | **obrigatória** | `Gestores \| <setor de destino>` | Envolve custo (equipamento, celular, licença M365) e acesso. O aprovador é o gestor do **setor de destino do colaborador**, não do solicitante — quem abre normalmente é o RH |
| 6 — Compras, NF e Fornecedores | **obrigatória** | `Gestores \| <setor do solicitante>` | Compromete orçamento e centro de custo |
| 1, 2, 3, 7, 8 | não | — | Incidente não se aprova, se atende. Exigir aprovação para consertar um mouse quebrado só adiciona atraso |

Regra geral: **aprova-se concessão e custo; não se aprova conserto.**

## Comportamento do chamado

1. Colaborador envia o formulário.
2. Chamado nasce com status **Pendente**, motivo **Aguardando aprovação**. O relógio de SLA fica parado — a TI não pode ser cobrada por tempo em que ela não podia agir.
3. O grupo `Gestores | <setor>` recebe notificação de validação.
4. **Aprovado:** o chamado sai de Pendente, cai na fila do grupo técnico e o SLA começa a contar.
5. **Recusado:** o gestor é obrigado a escrever o motivo, o solicitante é notificado com esse motivo e o chamado é fechado.

Prazos de resolução só começam a contar **depois** da aprovação. É a diferença entre medir a TI e medir a espera do negócio.

## Pré-requisito bloqueante

`blueprint/setores-gestores.csv` está gerado com os 26 setores reais e as colunas `gestor_nome` e `gestor_email` **em branco**.

Sem esse mapa preenchido:

- os grupos `Gestores | <setor>` ficam vazios;
- a validação vai para um grupo sem membros;
- o chamado fica preso em Pendente para sempre.

**Preencher o CSV é pré-requisito de ativação da aprovação.** Enquanto não estiver preenchido, deixar a regra de validação criada e **desativada** — os formulários 4, 5 e 6 funcionam sem ela, só sem o portão de aprovação.

Sugestão para reduzir esforço: preencher primeiro os 8 setores que concentram 71% do volume — Comercial (91), Fiscal (84), RH (72), TI (62), Laboratório (40), Suprimentos (39), Contabilidade (28), PCP (25). Os 18 restantes podem cair temporariamente em `TI | Gestão` como aprovador de exceção.

## O que não prometer

A Super-Admin da entidade raiz tem acesso técnico potencial a qualquer chamado, inclusive aos que passam por aprovação. Isso não é falha de configuração — é como o GLPI funciona. Suas ações ficam auditáveis, mas sigilo absoluto contra a Super-Admin exigiria governança adicional ou instância separada. Se o RH entrar com casos sensíveis (`DECISÃO 14`), esse ponto precisa ser dito explicitamente antes, não descoberto depois.
