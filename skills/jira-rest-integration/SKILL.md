---
name: jira-rest-integration
description: Integração com Jira Cloud usando exclusivamente Jira REST API v3. Use quando precisar buscar, analisar, comentar, criar, editar, vincular ou transicionar issues do Jira, pesquisar por JQL, extrair requisitos de tickets, ou atualizar tickets a partir do fluxo de desenvolvimento. A skill carrega credenciais somente do arquivo .jira-integration na raiz do projeto e exige confirmação do usuário antes de qualquer operação de escrita.
---

# Jira REST Integration

Use esta skill para trabalhar com Jira Cloud usando apenas REST API v3. Não use conectores externos, servidores auxiliares ou credenciais do ambiente. A fonte de configuração obrigatória é o arquivo `.jira-integration` na raiz do projeto atual.

Antes de executar qualquer operação, leia e carregue o helper reutilizável:

```bash
source "<skill-dir>/references/jira-rest-integration.sh"
jira_init
```

Use as funções do helper em `references/jira-rest-integration.sh` para inicialização, autenticação, chamadas REST, busca de issue, JQL, comentários, transitions, criação, edição, vínculo de issues e campos customizados. Não duplique essas funções em comandos avulsos; componha novas operações em cima de `jira_curl`, `jira_api_url` e dos wrappers existentes.

## Configuração

Antes de qualquer chamada, localizar a raiz do projeto e validar a existência de `.jira-integration`.

Formato obrigatório, sem aspas:

```env
JIRA_URL=https://empresa.atlassian.net
JIRA_EMAIL=email@empresa.com
JIRA_API_TOKEN=token
```

Regras:

- Ler o arquivo `.jira-integration` por parsing explícito; não usar `source` para credenciais.
- Falhar cedo se alguma chave estiver ausente ou vazia.
- Remover barra final de `JIRA_URL` antes de montar URLs.
- Não imprimir `JIRA_API_TOKEN`.
- Verificar se `.jira-integration` está coberto por `.gitignore`; se não estiver, avisar o usuário antes de prosseguir.
- Tratar esta skill como Jira Cloud apenas; usar endpoints `/rest/api/3`.

Padrão shell recomendado:

```bash
source "<skill-dir>/references/jira-rest-integration.sh"
jira_init
```

## Fluxo De Trabalho

1. Validar `.jira-integration`.
2. Ler `.jira-memories`, se existir, antes de consultar metadados, montar JQL ou criar payloads.
3. Para leitura de issue, executar diretamente a chamada REST necessária.
4. Para metadados repetitivos, preferir valores conhecidos em `.jira-memories`: project key, tag/label do projeto, issue types, campos customizados, status e transitions.
5. Para escrita, explicar a operação, issue alvo e payload resumido; pedir confirmação explícita do usuário antes de executar.
6. Para transicionar uma issue, usar o ID salvo em `.jira-memories` quando houver correspondência por projeto, tipo da issue, status atual e nome da transition. Se não houver memória ou se a API rejeitar o ID, buscar transitions disponíveis, usar o ID correto e sugerir atualizar `.jira-memories`.
7. Preferir respostas resumidas, com chave da issue, título, status, links e próximos passos.

Operações de escrita incluem criar issue, editar campos, comentar, vincular issues e transicionar status.

## Otimização Do Uso Diário

Evitar chamadas repetidas para metadados que raramente mudam. Antes de chamar `jira_fields`, `jira_transition_names`, metadados de criação ou buscas amplas por labels/status, verificar se `.jira-memories` já contém a informação necessária.

Use `.jira-memories` para:

- montar JQL com o `project_key` e a `project_tag` padrão;
- preencher labels/tags recorrentes em novas issues;
- escolher issue types usados pelo projeto;
- mapear nomes e IDs de status de tasks;
- mapear IDs de transitions por nome;
- localizar campos customizados sem chamar `jira_fields` a cada uso;
- registrar convenções de branch, comentário, PR e filtros comuns.

Quando descobrir um metadado útil durante uma consulta, e ele não existir em `.jira-memories`, avisar de forma curta e sugerir registrar. Se o usuário pedir para otimizar o fluxo ou memorizar a informação, atualizar `.jira-memories` com dados não sensíveis.

Não confiar cegamente em memória quando houver sinal de divergência: erro `400`, `404`, transition indisponível, status atual diferente do esperado, campo ausente ou mudança de workflow. Nesses casos, consultar o Jira, corrigir a operação e propor atualizar a memória.

## Operações REST

Buscar issue:

```bash
jira_issue_summary PROJ-123
```

Pesquisar por JQL:

```bash
jira_search "project = PROJ AND status = 'In Progress' ORDER BY updated DESC" 20
```

Buscar comentários:

```bash
jira_get_comments PROJ-123
```

Adicionar comentário, após confirmação:

```bash
jira_add_comment PROJ-123 "Comentário aqui"
```

Listar transitions:

```bash
jira_transition_names PROJ-123
```

Executar transition, após confirmação:

```bash
jira_transition_issue PROJ-123 TRANSITION_ID
```

Criar issue, após confirmação:

```bash
jira_create_issue PROJ "Resumo da issue" Task "Descrição da issue"
```

Editar issue, após confirmação:

```bash
jira_edit_issue_file PROJ-123 payload.json
```

Vincular issues, após confirmação:

```bash
jira_link_issues PROJ-123 PROJ-456 Relates
```

## Análise Enxuta De Ticket

Ao buscar uma issue para desenvolvimento, extrair apenas o que ajuda a executar:

```text
Ticket: PROJ-123
Resumo: ...
Status: ...
Tipo/Prioridade: ...

Requisitos:
1. ...

Critérios de aceite:
- [ ] ...

Impacto técnico:
- Áreas afetadas
- APIs, telas, jobs ou integrações
- Dados ou permissões relevantes

Testes sugeridos:
- Unitários
- Integração/API
- E2E, se houver fluxo de usuário

Pendências:
- Perguntas bloqueantes ou ambiguidades
```

## Comentários Úteis

Manter comentários curtos, factuais e rastreáveis. Exemplos:

```text
Iniciando implementação.
Branch: feat/PROJ-123-descricao-curta
```

```text
Implementação concluída.
PR: https://github.com/org/repo/pull/123
Testes: passando localmente
```

```text
Testes adicionados:
- caminho/do/teste: cobre cenário X
- caminho/do/teste: cobre cenário Y
```

## Memórias Do Projeto

Se existir `.jira-memories` na raiz do projeto, ler como contexto auxiliar antes de montar payloads, montar JQL, escolher labels/tags, interpretar status ou transicionar issues. Esse arquivo é um cache operacional do projeto e deve reduzir consultas repetidas ao Jira.

Esse arquivo pode guardar apenas informações não secretas, como:

- project key padrão;
- tag/label principal do projeto;
- labels comuns;
- nomes e IDs de campos customizados;
- issue types usados pelo projeto;
- códigos, IDs e nomes de status de tasks;
- nomes e IDs de transitions mais comuns;
- filtros JQL recorrentes;
- convenções de branch, PR e comentários.

Não colocar tokens, senhas ou dados sensíveis em `.jira-memories`.

Formato recomendado:

```yaml
project:
  key: PROJ
  tag: minha-tag
  default_labels:
    - minha-tag
    - backend

issue_types:
  task: Task
  bug: Bug
  story: Story

task_statuses:
  todo:
    id: "10000"
    name: "To Do"
  in_progress:
    id: "10001"
    name: "In Progress"
  review:
    id: "10002"
    name: "Code Review"
  done:
    id: "10003"
    name: "Done"

transitions:
  Task:
    "To Do":
      start_progress:
        id: "21"
        name: "Start Progress"
    "In Progress":
      send_to_review:
        id: "31"
        name: "Code Review"
      done:
        id: "41"
        name: "Done"

custom_fields:
  sprint:
    id: customfield_10020
    name: Sprint
  story_points:
    id: customfield_10016
    name: Story point estimate

jql:
  active_tasks: "project = PROJ AND labels = minha-tag AND statusCategory != Done ORDER BY updated DESC"
  my_open_tasks: "project = PROJ AND assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC"

workflow_notes:
  branch_pattern: "feat/PROJ-123-descricao-curta"
  start_comment: "Iniciando implementacao."
```

Ao atualizar `.jira-memories`, preservar entradas existentes, adicionar apenas dados confirmados pela API ou informados pelo usuário, e manter o arquivo legível para edição manual. Se houver conflito entre memória e API, a API vence.

## Erros Comuns

- `401 Unauthorized`: token inválido, expirado ou email incorreto.
- `403 Forbidden`: usuário sem permissão no projeto ou operação.
- `404 Not Found`: issue inexistente, URL incorreta ou falta de permissão.
- `400 Bad Request`: payload inválido, campo customizado errado ou formato ADF incorreto.

Para campos customizados, buscar metadados antes de editar:

```bash
jira_fields
```
