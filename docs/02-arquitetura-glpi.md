# 02 — Arquitetura de acesso: entidades, perfis, grupos e localizações

## Entidades

```
Homy Química                     (raiz — configuração global, auditoria)
└── Service Desk - TI            (entidade prestadora — fila, SLA e dados da TI)
    └── Service Desk - RH        (futura — só quando houver equipe, dados e fluxo próprios)
```

Os 26 setores da base **não** viram entidades. Nenhum deles presta atendimento; todos apenas solicitam. Entidade só se justifica com equipe, isolamento de dados, regras e SLA próprios.

Isso já está previsto no `DECISÃO 14` do documento de 27/02/2026, que definiu segregação lógica por domínio para o RH em vez de estrutura duplicada — o equivalente no GLPI é a segunda entidade prestadora, criada só quando o RH tiver fila real.

## Perfis

| Perfil | Escopo | Direitos | Quem |
|---|---|---|---|
| Super-Admin nominativo | Raiz, recursivo | Configuração, entidades, perfis, integrações, auditoria | Duda |
| Supervisor TI | Service Desk - TI | Fila completa, atribuição, SLA, validação, relatórios | Fabia Garcia, Ricardo |
| Técnico TI | Service Desk - TI | Atender, planejar, acompanhar, solucionar | Mateus, André |
| Self-Service | Raiz, recursivo | Abrir e acompanhar os próprios chamados | Todos os 133 colaboradores |
| Auditor / Diretoria | Escopo aprovado, leitura | Indicadores, sem alterar atendimento | Diretorias |
| Técnico/Supervisor de Área | Entidade da própria área | Atender só a própria área | Key-user de RH (futuro) |

Regras que não se negociam:

- Conta operacional de Duda separada da conta Super-Admin sempre que viável.
- Conta de emergência corporativa protegida e auditada.
- Usuário de fábrica `glpi` desativado — **já confirmado desativado** no contexto herdado; revalidar em tela.
- MFA ativo para todo perfil administrativo. A 11.0.8 corrigiu dois desvios de MFA (CVE-2026-49470, CVE-2026-52848); MFA só protege de fato na versão corrigida.
- Recursividade concedida apenas onde há necessidade demonstrável.

## Grupos técnicos

Sete grupos, contra os cinco do desenho anterior. As duas adições vêm direto do volume real.

| Grupo | Membros | Finalidade | Por que existe |
|---|---|---|---|
| `TI \| Triagem` | Duda, Fabia | Entrada genérica, reclassificação, fallback | Recebe o formulário "Outro" (9,7% do volume) |
| `TI \| Infraestrutura` | Mateus | Computador, periférico, rede, VPN, predial, CFTV | 11,6% do volume somado |
| `TI \| Sistemas Protheus` | André | Protheus: erro, parametrização, relatório, customização | 157 de 164 chamados de Sistemas |
| `TI \| Sistemas Fluig e Transmite` | André, Duda | Fluig e Transmite | **Novo.** Competência distinta do Protheus, ainda que volume baixo — separa a fila sem separar o formulário |
| `TI \| Microsoft 365 e Automação` | Duda | M365, Power Platform, GLPI | 9,7% do volume |
| `TI \| Acessos e Identidade` | Duda, Mateus | Conta, senha, MFA, rede F:, permissão em sistema | **Novo.** 8,2% do volume e é a única fila com aprovação obrigatória em todos os itens |
| `TI \| Gestão` | Fabia, Ricardo, Duda | Escalonamento, indicadores, aprovação técnica | Destino do escalonamento de SLA a 75% e 100% |

Chamado é atribuído **a grupo**, nunca direto a pessoa. O técnico assume depois. Isso resolve o ponto frágil do desenho de origem, em que "INFRA → Eduarda" e "SISTEMAS → Bárbara" amarravam o fluxo inteiro a duas pessoas nomeadas.

**Pendência:** confirmar quem é "Bárbara" antes de popular `TI | Sistemas Protheus`.

## Grupos organizacionais — `Setor | <nome>`

Um por setor real da base, 26 no total. Preenchidos no cadastro de cada usuário. São a base de duas coisas:

1. o roteamento e os relatórios por área;
2. **a aprovação** — a validação vai ao gestor do setor do solicitante (`docs/05`).

Lista completa e volume em `blueprint/setores-gestores.csv`.

Grupo técnico nunca é usado como grupo organizacional, e vice-versa.

## Grupos de aprovação — `Gestores | <nome>`

Um por setor, contendo o gestor daquele setor. A validação nativa do GLPI é dirigida ao **grupo**, não à pessoa: assim qualquer membro pode aprovar e férias ou ausência não travam a fila.

`blueprint/setores-gestores.csv` está gerado com os 26 setores e as colunas `gestor_nome` e `gestor_email` **em branco, para Duda preencher**. Sem isso a validação não pode ser ativada.

## Localizações

Criar para unidades, prédios, salas e áreas físicas reais. Ainda não levantadas — a base de chamados tem setor, não localização física. Necessárias antes de qualquer regra que dependa de local (ex.: chamado de CFTV, predial ou rede por prédio).

**Pendência aberta:** levantar a planta de localizações da Homy.

## Contas individuais — pré-requisito bloqueante

O desenho inteiro depende de o GLPI capturar requerente e setor **do usuário autenticado**. Isso só funciona se cada colaborador tiver conta individual com o grupo `Setor | ...` preenchido.

A base mostra **133 colaboradores distintos** abrindo chamados. Hoje há 4 pessoas confirmadas no GLPI. Antes do corte:

- decidir a fonte de identidade — local, LDAP/AD ou Entra ID/SSO (**pendência ainda em aberto**);
- se for Entra ID, a importação já traz departamento e resolve o grupo `Setor |` de uma vez;
- se for local, a criação das 133 contas com setor correto entra como tarefa de projeto, não como detalhe.

Enquanto isso não estiver resolvido, os formulários funcionam mas o roteamento por setor e a aprovação por gestor **não**.

## Sequência segura de criação

1. Entidades.
2. Perfis derivados do mínimo necessário.
3. Grupos técnicos, organizacionais e de aprovação.
4. Usuários e vínculos perfil-entidade.
5. Localizações.
6. Calendário e feriados.
7. Categorias ITIL e do catálogo.
8. Formulários.
9. Regras de roteamento e prioridade.
10. SLA.
11. Validação/aprovação.
12. Notificações.
13. Teste com contas representativas.

Não pular etapa porque a tela seguinte parece disponível. SLA sem calendário e feriados produz prazo errado com aparência de certo.
