# 03 — Catálogo e formulários

Módulo nativo **Administração > Formulários** do GLPI 11. Não usar plugin Formcreator.

> **Alerta de segurança.** O importador nativo de formulários foi o vetor do CVE-2026-48482 (RCE), corrigido na 11.0.8. Só importar JSON de formulário em instalação 11.0.8 ou superior, e só depois de backup verificado. A instalação da Homy está em 11.0.8 — confirmado em 19/08/2026.

## Categoria do catálogo (o que o colaborador vê)

`TI` — categoria raiz, já criada. Futuro: `RH`.

O colaborador escolhe uma **área de serviço visual**, nunca uma entidade técnica.

## Os 8 formulários

| # | Formulário | Categoria ITIL fixa | Grupo destino | Aprovação | Volume estimado | Estado |
|---|---|---|---|---|---:|---|
| 1 | Sistemas: Protheus, Fluig e Transmite | Sistemas | variável por sistema | não | 51,6% | **Construído** (ID 3) |
| 2 | Infraestrutura: Computador, Rede e Periféricos | Infraestrutura | TI \| Infraestrutura | não | 11,6% | **Construído** (ID 6) |
| 3 | Microsoft 365 e Automação | Microsoft 365 e Automação | TI \| Microsoft 365 e Automação | não | 9,7% | Em andamento |
| 4 | Acessos e Permissões | Acessos e Permissões | TI \| Acessos e Identidade | **sim** | 8,2% | **A criar** |
| 5 | Admissão, Mudança de Setor e Desligamento | Ciclo de Vida do Colaborador | TI \| Triagem → multi-equipe | **sim** | 1,3% | **A criar** |
| 6 | Compras, NF, Rateio e Fornecedores | Compras e Fornecedores | TI \| Triagem | **sim** | 0,6% | **A criar** |
| 7 | Uso interno do TI | Uso interno do TI | conforme assunto | não | 1,6% | **A criar** |
| 8 | Outro assunto de TI | Outro assunto de TI | TI \| Triagem | não | 9,7% | **A criar** |

Regra de construção: **muitos formulários curtos**. Nunca recriar o Forms gigante de 56 perguntas.

---

## Perguntas comuns a todos os formulários

Presentes em todos, porque alimentam prioridade e SLA:

| Pergunta | Tipo | Obrigatória | Alimenta |
|---|---|---|---|
| Tipo de requisição | nativo Incidente/Requisição | sim | urgência |
| Descreva o que está acontecendo | texto longo | sim | descrição do chamado |
| Seu trabalho está totalmente parado por causa disso? | Sim / Não | sim | **urgência** |
| Quantas pessoas foram afetadas? | Só eu / Meu setor / Múltiplos setores / Empresa toda | sim | **impacto** |
| Anexo de evidência | arquivo, qualquer tipo | não | anexo nativo |

**Nunca perguntados**, porque vêm do usuário autenticado ou do carimbo do GLPI: nome, e-mail, setor, data de abertura. Isso elimina 4 das 56 colunas do Forms e depende das contas individuais (`docs/02`).

**Um único campo de anexo por formulário.** O Forms atual tem dois campos de upload (colunas 22 e 56) e isso é uma causa conhecida de falha do fluxo de evidências ("Forms retorna anexos em formatos diferentes dependendo da pergunta").

---

## 1. Sistemas: Protheus, Fluig e Transmite — construído, ID 3

13 perguntas com condicional por sistema. Já validado com 2 chamados de teste (IDs 2 e 3), conferidos campo a campo e excluídos.

Estrutura confirmada: tipo de requisição → sistema afetado → descrição → impedimento → pessoas afetadas → bloco condicional Protheus (módulo com 15 opções, tipo de demanda com 6, colaborador de referência em condicional dupla) → bloco Fluig → bloco Transmite → anexo.

**Ajustes a aplicar:**

- **Grupo destino passa a ser condicional**, não vazio: Protheus → `TI | Sistemas Protheus`; Fluig ou Transmite → `TI | Sistemas Fluig e Transmite`; Outro sistema → `TI | Triagem`.
- **Bloco de ajuda do SmartClient.** As colunas 52–55 do Forms são instruções passo a passo de captura de erro, não perguntas. Vira um bloco de texto de ajuda condicional a `sistema = Protheus` e `tipo = Erro na tela`.
- **Tipo de demanda Protheus:** usar as 7 opções reais da base — Parametrização/cadastro, Erro na tela (SmartClient), Acesso/criação/bloqueio de usuário, Relatório, Melhoria/Customização, Workflow/processo, Outros.

## 2. Infraestrutura: Computador, Rede e Periféricos — construído, ID 6

7 perguntas. Validado com 2 chamados de teste (IDs 4 e 5), excluídos.

Incidente registrado na construção: o rascunho nasceu com o toggle **Ativo** ligado e a descrição do catálogo foi para o campo de título. Ambos corrigidos antes de qualquer teste ir ao ar.

> **Lição operacional que vale para os 5 formulários restantes:** conferir e desligar o toggle **Ativo** imediatamente após o GLPI criar o rascunho. Ele pode vir ligado por padrão.

**Ajuste a aplicar:** a coluna 23 do Forms ("Se o problema for de INTERNET/REDE, você verificou se: — Somente o meu equipamento / O meu e de mais pessoas") já era uma pergunta de impacto disfarçada. Ela é absorvida pela pergunta comum "Quantas pessoas foram afetadas?" e não deve ser duplicada.

## 3. Microsoft 365 e Automação — em andamento

| # | Pergunta | Tipo | Obrigatória |
|---|---|---|---|
| 1 | Tipo de requisição | nativo | sim |
| 2 | Qual ferramenta está envolvida? | Outlook / Teams / OneDrive / SharePoint / E-mail / Power Automate / Microsoft Forms / Planner / Power BI / GLPI / Outra | sim |
| 3 | Descreva o que está acontecendo | texto longo | sim |
| 4 | Seu trabalho está totalmente parado? | Sim / Não | sim |
| 5 | Quantas pessoas foram afetadas? | 4 opções | sim |
| 6 | Anexo de evidência | arquivo | não |

Destino: categoria ITIL `Microsoft 365 e Automação`, grupo `TI | Microsoft 365 e Automação`.

**Não incluir aqui** os campos de "precisa de e-mail corporativo / licença M365 / acesso à rede F:". Eles pertencem ao formulário 5 (Ciclo de Vida) e ao 4 (Acessos).

## 4. Acessos e Permissões — a criar · **com aprovação**

Cobre 8,2% do volume, hoje espalhado entre duas categorias do Forms.

| # | Pergunta | Tipo | Condição | Obrigatória |
|---|---|---|---|---|
| 1 | Tipo de requisição | nativo, pré-fixado em Requisição | — | sim |
| 2 | O acesso é para quem? | Para mim / Para outro colaborador | — | sim |
| 3 | Nome do colaborador | texto | Q2 = outro colaborador | sim |
| 4 | Qual acesso você precisa? | Conta/senha/MFA · Rede de arquivos (F:) · Protheus · Fluig · Transmite · Outro | múltipla escolha | sim |
| 5 | Como configurar o acesso? | Copiar perfil de outro colaborador / Descrever o que preciso | Q4 contém sistema ou F: | sim |
| 6 | Copiar acessos de qual colaborador? | texto | Q5 = copiar perfil | sim |
| 7 | Pastas específicas que precisa acessar | texto longo | Q4 contém "Rede F:" | não |
| 8 | Descreva o que precisa e por quê | texto longo | — | sim |
| 9 | Seu trabalho está totalmente parado? | Sim / Não | — | sim |
| 10 | Quantas pessoas foram afetadas? | 4 opções | — | sim |
| 11 | Anexo | arquivo | — | não |

Destino: `Acessos e Permissões`, grupo `TI | Acessos e Identidade`, **validação obrigatória** do grupo `Gestores | <setor do solicitante>`.

Por que aprovação em todos os itens: "copiar o perfil de outro colaborador" concede permissão por herança sem ninguém revisar o que está sendo herdado. A base mostra esse padrão em uso real ("Sim, tudo o que o André Luís Borges tem acesso ele terá que ter"). Concessão de acesso sem aprovação registrada é achado de auditoria.

## 5. Admissão, Mudança de Setor e Desligamento — a criar · **com aprovação**

O ramo mais completo do Forms atual (colunas 25–47) e o que não tinha nenhum correspondente no GLPI.

**Seção A — Identificação**

| # | Pergunta | Tipo | Obrigatória |
|---|---|---|---|
| 1 | O que está acontecendo? | Admissão / Mudança de setor / Desligamento | sim |
| 2 | Data de início (ou da mudança/desligamento) | data | sim |
| 3 | Nome completo do colaborador | texto | sim |
| 4 | Departamento de destino | lista dos 26 setores | sim |
| 5 | Cargo | texto | sim |
| 6 | Centro de custo | texto | sim |
| 7 | Conta contábil | texto | sim |

**Seção B — Equipamento** (condicional a Admissão ou Mudança)

| # | Pergunta | Tipo |
|---|---|---|
| 8 | Equipamento principal | Notebook / Desktop / Nenhum |
| 9 | Periféricos necessários | Teclado · Mouse · Monitor · Fone de ouvido · Headset · Outro (múltipla) |
| 10 | Outros itens / necessidades | texto longo |
| 11 | Smartphone (celular corporativo) | Sim / Não |
| 12 | Observações sobre equipamentos | texto longo |

**Seção C — Microsoft 365**

| # | Pergunta | Tipo | Condição |
|---|---|---|---|
| 13 | Precisa de e-mail corporativo? | Sim / Não | — |
| 14 | Sugestão de endereço de e-mail | texto | Q13 = Sim |
| 15 | Licença Microsoft 365 | Office + Teams / Somente Teams / Nenhuma | Q13 = Sim |
| 16 | Precisa de acesso aos e-mails de alguém que saiu? | Sim / Não | — |
| 17 | Nome do colaborador para transferência | texto | Q16 = Sim |

**Seção D — Acessos**

| # | Pergunta | Tipo | Condição |
|---|---|---|---|
| 18 | Precisa de acesso à rede de arquivos (F:)? | Sim / Não | — |
| 19 | Copiar acessos de qual colaborador? | texto | Q18 = Sim |
| 20 | Pastas específicas | texto longo | Q18 = Sim |
| 21 | Precisa de acesso ao Protheus? | Sim / Não | — |
| 22 | Precisa de acesso ao Fluig? | Sim / Não | — |
| 23 | Precisa de acesso ao Transmite? | Sim / Não | — |
| 24 | Anexo | arquivo | — |

**Destino e desdobramento.** Categoria `Ciclo de Vida do Colaborador`, chamado principal em `TI | Triagem`, **validação obrigatória** do gestor do setor de destino (Q4 — não do setor do solicitante, porque quem abre costuma ser o RH).

Aprovado, o chamado gera **tarefas por equipe** dentro do mesmo chamado:

- equipamento e periféricos → `TI | Infraestrutura`
- e-mail, licença e transferência de caixa → `TI | Microsoft 365 e Automação`
- rede F: e cópia de acessos → `TI | Acessos e Identidade`
- Protheus → `TI | Sistemas Protheus`
- Fluig / Transmite → `TI | Sistemas Fluig e Transmite`

Um chamado com tarefas por equipe, e não cinco chamados soltos: preserva a data-alvo única da admissão e permite ver, em uma tela, o que falta para o colaborador começar a trabalhar.

Desligamento inverte o sentido de todas as perguntas de acesso (revogar em vez de conceder) e é o caso em que o prazo é rígido: acesso de quem saiu precisa cair no dia.

## 6. Compras, NF, Rateio e Fornecedores — a criar · **com aprovação**

| # | Pergunta | Tipo | Condição | Obrigatória |
|---|---|---|---|---|
| 1 | Tipo de requisição | nativo, pré-fixado em Requisição | — | sim |
| 2 | Do que se trata? | Compra de equipamento/licença · NF ou rateio · Chamado com fornecedor | — | sim |
| 3 | Qual fornecedor? | lista + Outro | Q2 = fornecedor | sim |
| 4 | Número do ticket do fornecedor | texto | Q2 = fornecedor | não |
| 5 | Descrição | texto longo | — | sim |
| 6 | Centro de custo | texto | Q2 = compra ou NF | sim |
| 7 | Valor estimado | número | Q2 = compra | não |
| 8 | Prazo de negócio | data | — | não |
| 9 | Anexo (orçamento, NF, print) | arquivo | — | não |

Destino: `Compras e Fornecedores`, grupo `TI | Triagem`, **validação do gestor do setor solicitante**.

**Pendência:** foi levantada a possibilidade de escalonar compras acima de um valor de corte para a Diretoria Administrativa. O valor não foi definido — a regra fica pronta e desativada até Duda informar o limite.

## 7. Uso interno do TI — a criar

Substitui a coluna 48 do Forms ("Confirmação — uso exclusivo do TI"), que era uma declaração de honra e não impedia ninguém de usar.

No GLPI o controle passa a ser real: **o formulário só é publicado para o grupo `Setor | TI`**. Quem não é da TI não o vê.

| # | Pergunta | Tipo |
|---|---|---|
| 1 | Tipo de requisição | nativo |
| 2 | Assunto | Manutenção programada · Projeto/melhoria interna · Documentação · Teste/homologação · Outro |
| 3 | Descreva | texto longo |
| 4 | Quantas pessoas seriam afetadas se não for feito? | 4 opções |
| 5 | Prazo de negócio | data |
| 6 | Anexo | arquivo |

Urgência tratada como **Muito baixa** por padrão: trabalho interno planejado não compete com incidente de usuário. Ver a linha P5 em `docs/04`.

## 8. Outro assunto de TI — a criar

Catch-all. Cinco perguntas: tipo de requisição, descrição, impedimento total, pessoas afetadas, anexo. Destino `TI | Triagem`.

**Regra de governança:** revisar o volume mensalmente. "Outro" é 9,7% do volume histórico — se depois do corte continuar acima de 10%, é sinal de que falta um formulário no catálogo, não de que os usuários erram. A revisão mensal está no `docs/08`.

---

## Ordem de construção recomendada

1. **Acessos e Permissões** — maior volume entre os não construídos e destrava o teste de aprovação.
2. **Outro assunto** — catch-all precisa existir antes do corte, senão o que não se encaixa fica sem porta.
3. **Microsoft 365** — concluir o que está em andamento.
4. **Uso interno do TI** — simples, e tira ruído interno da fila real.
5. **Compras e Fornecedores** — baixo volume, aprovação simples.
6. **Ciclo de Vida do Colaborador** — o mais complexo, com desdobramento multi-equipe. Por último, com os outros já estáveis.

Construir em homologação, exportar o JSON nativo após revisão, importar em produção só em 11.0.8+ e após backup verificado.
