# uhxi-plugins — marketplace pessoal da UHXI_lab

Um único repositório que reúne tudo o que César usa em Claude Code, em qualquer máquina ou ambiente cloud: os plugins próprios, os plugins de terceiros que hoje estão instalados a partir do directório Anthropic, os plugins Anthropic (knowledge-work-plugins, claude-plugins-official) e as ferramentas que não são plugins mas que também têm de existir em cada ambiente, como o graphify.

## Como funciona

Há três camadas, cada uma com o seu mecanismo nativo:

1. **Plugins Claude Code** — `.claude-plugin/marketplace.json` torna este repositório num marketplace chamado `uhxi`. Os plugins próprios vivem em `plugins/`; os de terceiros são referenciados pelo repositório GitHub de origem, sem cópia.
2. **Configuração de utilizador** — `templates/settings.user.json` declara os marketplaces conhecidos e os plugins que devem estar activos em todos os projectos. O bootstrap funde-o em `~/.claude/settings.json`; a partir daí o Claude Code sabe o que instalar sozinho.
3. **Ferramentas externas** — `external/tools.json` lista CLIs e skills instaladas por comando (graphify, uv). Cada entrada tem `check`, `install` por sistema operativo, `register` e `upgrade`.

Os scripts `scripts/bootstrap.sh` (Linux/macOS) e `scripts/bootstrap.ps1` (Windows) percorrem as três camadas e são idempotentes: podem correr-se sempre que se entra numa máquina nova ou se quer actualizar tudo.

## Instalar num ambiente novo

```bash
git clone https://github.com/UHXI/uhxi-plugins ~/uhxi-plugins
bash ~/uhxi-plugins/scripts/bootstrap.sh          # Linux / macOS
pwsh -File ~\uhxi-plugins\scripts\bootstrap.ps1   # Windows
```

Ou, dentro de uma sessão Claude Code, sem clonar à mão:

```
/plugin marketplace add UHXI/uhxi-plugins
/plugin install uhxi-core@uhxi
/uhxi-core:uhxi-sync
```

Actualizar tudo: `bash scripts/bootstrap.sh --update` (Windows: `-Update`).

## Estrutura

```
uhxi-plugins/
├── .claude-plugin/marketplace.json   # o marketplace 'uhxi'
├── plugins/
│   └── uhxi-core/                    # plugin próprio; skill /uhxi-core:uhxi-sync
├── external/tools.json               # graphify, uv, … (ferramentas não-plugin)
├── scripts/bootstrap.sh|.ps1         # instalação/actualização idempotente
└── templates/
    ├── settings.user.json            # fundido em ~/.claude/settings.json
    └── project.settings.json         # copiar para <repo>/.claude/settings.json
```

## Adicionar coisas

Plugin próprio: criar `plugins/<nome>/.claude-plugin/plugin.json` e as pastas `skills/`, `commands/`, `agents/`, `hooks/hooks.json` ou `.mcp.json` conforme precise; acrescentar a entrada em `marketplace.json`; validar com `claude plugin validate plugins/<nome>`.

Plugin de terceiros: acrescentar em `marketplace.json` uma entrada com `{"source":"github","repo":"owner/repo"}`. Se o plugin estiver numa subpasta de um mono-repo, usar `{"source":"git-subdir","url":"https://github.com/owner/repo","path":"plugins/x"}`. Depois activar em `templates/settings.user.json` com `"<nome>@uhxi": true`.

Repositório que já é um marketplace (caso do `addyosmani/agent-skills`, marketplace `addy-agent-skills` com o plugin `agent-skills`): não o duplicar no `marketplace.json`; acrescentar o marketplace a `extraKnownMarketplaces` e o plugin a `enabledPlugins` em `templates/settings.user.json`, na forma `"<plugin>@<marketplace>": true`. As actualizações continuam a vir do autor.

Ferramenta externa: acrescentar um objecto em `external/tools.json` com `id`, `check`, `install` por SO e, se existir, `register`. Ferramentas que mudam o comportamento global do Claude Code (caso do OmniRoute, um gateway que redirecciona todo o tráfego via `ANTHROPIC_BASE_URL`) levam `"optional": true`: só se instalam com `--all-tools` / `-AllTools` e nunca têm `register`; a activação faz-se por sessão, à mão, conforme as `notes` da entrada.

Plugin personalizado a partir da conta claude.ai (caso do `small-business` adaptado à UHXI_lab, que só existe em "My Uploads"): exportar a pasta do plugin e colocá-la em `plugins/small-business-uhxi/`, para que passe a viajar com o repositório.

## Notas

- Os plugins instalados na conta claude.ai (Cowork e sessões cloud) sincronizam-se sozinhos com a conta; este repositório trata dos ambientes locais e do que a conta não cobre.
- As entradas de terceiros em `marketplace.json` foram derivadas do campo `repository` do `plugin.json` de cada plugin instalado. Alguns repositórios são mono-repos; o bootstrap reporta a falha e o `uhxi-sync` propõe a correcção para `git-subdir`.
- O graphify instala-se com `uv tool install graphifyy` (o pacote tem duplo y) e regista a skill com `graphify install`; para registar apenas no projecto actual, correr o bootstrap com `--project`. Em PowerShell escreve-se `graphify .` e não `/graphify .`.
- O bootstrap faz cópia de segurança de `~/.claude/settings.json` antes de o alterar e só toca nas chaves `extraKnownMarketplaces` e `enabledPlugins`.
