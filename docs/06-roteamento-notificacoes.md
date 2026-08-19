# 06 — Regras de roteamento e notificações

## Ordem de execução das regras

O GLPI avalia regras de negócio de chamado em sequência. A ordem importa: uma regra que define categoria precisa rodar antes da que aplica SLA por categoria.

1. **Normalizar** origem e entidade
2. **Definir categoria e grupo** técnico
3. **Definir impacto e urgência** a partir das respostas do formulário
4. **Recalcular prioridade** (matriz de `docs/04`)
5. **Aplicar SLA**
6. **Disparar validação** quando o formulário exigir
7. **Executar escalonamentos**

## Roteamento categoria → grupo

| Categoria ITIL | Grupo técnico | Condição adicional |
|---|---|---|
| Sistemas > Protheus | `TI \| Sistemas Protheus` | — |
| Sistemas > Fluig | `TI \| Sistemas Fluig e Transmite` | — |
| Sistemas > Transmite | `TI \| Sistemas Fluig e Transmite` | — |
| Sistemas > Outro sistema | `TI \| Triagem` | — |
| Infraestrutura (todas as filhas) | `TI \| Infraestrutura` | — |
| Microsoft 365 e Automação | `TI \| Microsoft 365 e Automação` | — |
| Acessos e Permissões | `TI \| Acessos e Identidade` | + validação |
| Ciclo de Vida do Colaborador | `TI \| Triagem` | + validação + tarefas multi-equipe |
| Compras e Fornecedores | `TI \| Triagem` | + validação |
| Uso interno do TI | conforme assunto | urgência fixada em 1 |
| Outro assunto de TI | `TI \| Triagem` | — |

**Sempre para grupo, nunca direto para pessoa.** O técnico assume depois. Essa é a correção do ponto mais frágil do desenho de origem, em que "INFRA → Eduarda" e "SISTEMAS → Bárbara" faziam o sistema inteiro depender de duas pessoas nomeadas estarem disponíveis.

## Regras de prioridade

Uma regra por combinação da matriz de `docs/04`. Todas leem as duas perguntas comuns:

- `Seu trabalho está totalmente parado?` + tipo de requisição → **urgência**
- `Quantas pessoas foram afetadas?` → **impacto**

O GLPI então calcula a prioridade pela matriz configurada. Não escrever a prioridade direto: escrever urgência e impacto e deixar o cálculo nativo trabalhar. Assim, se a matriz for ajustada depois, os chamados antigos continuam coerentes.

**Exceção:** formulário 7 (Uso interno do TI) fixa urgência em 1 — Muito baixa, independentemente das respostas. Trabalho interno planejado não compete com incidente de usuário.

## Regra de fallback

Chamado que chegar sem categoria ou sem grupo definido vai para `TI | Triagem`. Nenhum chamado pode ficar órfão.

**Governança:** revisar mensalmente o volume que cai em Triagem. Historicamente "Outro" é 9,7%. Se depois do corte continuar acima de 10%, falta formulário no catálogo — não é erro do usuário.

## Matriz de notificações

| Evento | Destinatários | Nunca notificar |
|---|---|---|
| Novo chamado | Solicitante + grupo atribuído | Toda a TI |
| Nova atribuição | Técnico ou grupo que recebeu | Solicitante |
| Acompanhamento **público** | Solicitante, observadores, equipe relevante | — |
| Nota **privada** | Somente equipe autorizada | **Solicitante** |
| Validação solicitada | Grupo `Gestores \| <setor>` | Grupo técnico |
| Validação decidida | Solicitante + grupo técnico | — |
| Solução registrada | Solicitante + grupo | — |
| Fechamento | Solicitante | Toda a TI |
| SLA a 50% / 75% / 100% | Grupo, Duda, `TI \| Gestão` | **Solicitante, sempre** |

**Não notificar toda a TI a cada alteração.** O sistema anterior notificava o canal de TI a cada mudança de bucket, com fluxo recorrente a cada 3 minutos. Isso treina a equipe a ignorar notificação — que é o oposto do objetivo.

## Identidade visual do e-mail

Ativos já publicados e validados (HTTP 200, MIME correto):

- Logo: `https://chamados.homyquimica.com.br/email-assets/logo-homy.png`
- Banner: `https://chamados.homyquimica.com.br/email-assets/banner-homy.gif`
- Servidor: `/var/www/glpi/public/email-assets/`

Regras:

- Assinatura acrescentada **ao fim** do corpo HTML. Nunca substituir o conteúdo existente.
- Preservar todas as tags dinâmicas `##...##`.
- Fontes de e-mail: Arial / Helvetica / sans-serif (Barlow não é confiável no Outlook clássico).
- Prefixo de assunto `[Homy TI]` só depois de validar a prévia — não inventar tag que a versão não oferece.
- O primeiro quadro do GIF precisa ser completo: parte dos clientes não anima.

**Validação obrigatória antes do aceite:** prévia com chamado real, envio para caixa controlada, conferência no Outlook Web **e** no Outlook clássico, verificação de remetente, links, logo, responsividade e versão texto simples. Prévia vazia sem chamado não demonstra nada.

## Pendências

- Endereço remetente e caixa coletora definitivos — ainda não confirmados.
- Estado do cron / ações automáticas — não reconfirmado. **Sem cron funcionando não há notificação, não há escalonamento de SLA e não há fechamento automático.** Verificar antes do corte.
