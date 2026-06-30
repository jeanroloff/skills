# Skills

Repositorio pessoal de skills para instalar e compartilhar via `npx skill`.

## Skills disponiveis

- `jira-rest-integration`: integracao com Jira Cloud usando exclusivamente Jira REST API v3 e credenciais do arquivo `.jira-integration` no projeto atual.

## Instalacao

Instalacao a partir do GitHub, depois de publicar o repositorio:

```bash
SKILL_BASE_URL=https://github.com/jeanroloff/skills/tree/main npx skill skills/jira-rest-integration
```

O pacote npm `skill` atual instala pacotes no formato `skills/<nome>`. Se voce estiver usando uma CLI que expoe o subcomando `add`, o pacote desta skill continua sendo:

```bash
npx skill add skills/jira-rest-integration
```

## Estrutura

```text
skills/
|-- README.md
|-- LICENSE
`-- skills/
    `-- jira-rest-integration/
        |-- SKILL.md
        |-- agents/
        |   `-- openai.yaml
        `-- references/
            `-- jira-rest-integration.sh
```
