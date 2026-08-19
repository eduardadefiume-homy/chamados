# 08 — Homologação e critérios de aceite

Nada entra em produção por ausência de erro. Cada item precisa de evidência observável e de **validação por segunda via**: versão + banco, API + interface, regra + chamado de teste, fila + e-mail recebido, backup + restauração.

## Personas obrigatórias

| Persona | Conta | O que precisa provar |
|---|---|---|
| Duda | Super-Admin | Configura tudo, e suas ações ficam auditáveis |
| Duda | perfil operacional | Atende sem precisar do Super-Admin |
| Fabia / Ricardo | Supervisor TI | Vê a fila inteira, atribui, valida, lê indicadores |
| Mateus | Técnico TI | Atende infraestrutura, **não** recebe direitos administrativos |
| André | Técnico TI | Atende Protheus sem acesso desnecessário à configuração |
| Colaborador comum | Self-Service | Abre e acompanha só os próprios chamados |
| Gestor de setor | Self-Service + validação | Aprova e recusa; recusa exige motivo |

## Cenários funcionais

| # | Cenário | Como provar |
|---|---|---|
| 1 | Cada formulário mostra só os campos necessários | Abrir os 8 e conferir que a condicional esconde o que não se aplica |
| 2 | Requerente e setor vêm do usuário autenticado | Abrir chamado com conta de teste e conferir que ninguém digitou nome nem setor |
| 3 | Categoria, entidade e grupo definidos sem triagem manual | Abrir um chamado de cada formulário e conferir o destino |
| 4 | Protheus vai para `TI \| Sistemas Protheus`, Fluig/Transmite para `TI \| Sistemas Fluig e Transmite` | Três chamados, um por sistema |
| 5 | Impacto × urgência geram a prioridade esperada | Testar as 4 combinações extremas da matriz de `docs/04` |
| 6 | Uso interno do TI nasce em P5 mesmo marcando "empresa toda" | Um chamado de teste |
| 7 | TTO e TTR usam o calendário certo | Abrir chamado às 17:00 e conferir que o prazo pula para o dia seguinte, não conta a madrugada |
| 8 | Feriado não conta como dia útil | Abrir chamado na véspera de feriado carregado |
| 9 | Pendente exige motivo e pausa o relógio | Colocar em Pendente e conferir que o SLA parou |
| 10 | Validação vai ao gestor do setor correto | Chamado do Fiscal vai para `Gestores \| Fiscal`, não para a TI |
| 11 | Chamado aguardando aprovação não consome SLA | Conferir o relógio antes e depois da aprovação |
| 12 | Recusa exige motivo e o motivo chega ao solicitante | Recusar um chamado de teste |
| 13 | Admissão gera tarefas para as 5 equipes | Um chamado com todos os "Sim" marcados |
| 14 | Nota privada não aparece ao solicitante | Escrever nota privada e abrir com a conta do solicitante |
| 15 | Acompanhamento público chega por e-mail e fica na linha do tempo | Conferir caixa real |
| 16 | Solução exige descrição; reabertura exige comentário | Tentar solucionar em branco |
| 17 | Anexo acessível só a quem tem direito | Tentar abrir anexo com conta sem direito |
| 18 | Logo, banner, links e assunto funcionam em e-mail real | Outlook Web **e** Outlook clássico |
| 19 | Cron processa notificações e escalonamentos | Conferir a fila e o log, não só a configuração |
| 20 | Dashboard mostra fila, pendências e SLA coerentes | Comparar com a contagem manual |
| 21 | Formulário "Outro" cai em `TI \| Triagem` | Um chamado de teste |

Mínimo de **15 variações** de abertura, rota, prioridade, aprovação e notificação antes do corte.

## Isolamento

- Self-Service vê apenas os próprios chamados.
- Mateus não tem direitos administrativos.
- André atende Protheus sem acesso à configuração.
- Supervisor vê toda a TI e os indicadores.
- Gestor de setor vê o que precisa aprovar, não a fila técnica.
- Quando a entidade de RH existir: key-user de RH não vê TI, e técnico de TI não vê RH sem vínculo explícito.
- Super-Admin tem acesso técnico potencial e isso é dito, não escondido.

## Segurança e operação

| Item | Estado |
|---|---|
| Versão sem alerta crítico conhecido | **11.0.8 confirmada em 19/08/2026** como release corrigida atual. Reconfirmar antes de importar formulário |
| Usuário de fábrica `glpi` desativado | Confirmado no contexto herdado — revalidar em tela |
| MFA ativo para administradores | A confirmar |
| Segredos fora de arquivos e logs | Nenhum token foi criado ou manuseado até aqui |
| HTTPS válido e renovação funcionando | A confirmar |
| Backup de banco e arquivos, recente, **com restauração testada** | Confirmado no contexto herdado — revalidar |
| `php bin/console db:check` sem erro | A executar |
| Ações automáticas (cron) executando no horário | **A confirmar — bloqueante.** Sem cron não há notificação nem escalonamento de SLA |
| Plugins compatíveis e necessários | Não levantados |
| PHP, MariaDB, servidor web | Não reconfirmados |

## Migração e entrada em produção

- Cards ativos reconciliados por contagem, ID e status
- Cards concluídos permanecem consultáveis no Planner como arquivo
- Notificações suspensas durante a carga e religadas depois
- Forms desativado e fluxos do Power Automate desligados
- Dataverse e SharePoint congelados em somente leitura
- Canal oficial de abertura comunicado a todos os 133 colaboradores
- Plano de retorno escrito, com responsável e janela

## Governança contínua

| Ritmo | O que revisar |
|---|---|
| Mensal | Volume do formulário "Outro" — acima de 10% indica formulário faltando no catálogo |
| Mensal | Chamados que estouraram SLA, por grupo e por categoria |
| Trimestral | Matriz de prioridade contra a realidade operacional |
| Trimestral | Mapa `setores-gestores.csv` — gestores mudam de cargo |
| A cada release do GLPI | Reconfirmar a versão corrigida antes de atualizar |

## Evidência final de aceite

Registro compacto contendo: versão instalada, data, objetos criados ou alterados, testes executados, falhas corrigidas, riscos aceitos com dono, backups com data do último teste de restauração e próximo marco.

Não usar "funcionou" sem evidência observável.
