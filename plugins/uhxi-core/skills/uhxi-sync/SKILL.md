---
name: uhxi-sync
description: Sincroniza o ambiente actual com o marketplace 'uhxi' da UHXI_lab — instala ou actualiza os plugins listados e as ferramentas externas (graphify e outras definidas em external/tools.json). Usar quando o utilizador disser "sincroniza os plugins", "instala o meu setup", "uhxi sync", "faltam-me plugins" ou ao entrar num ambiente novo.
---

# uhxi-sync

Objectivo: deixar este ambiente com o mesmo conjunto de plugins e ferramentas que César usa em todos os outros.

## Passos

1. Localizar o repositório do marketplace. Se `${CLAUDE_PLUGIN_ROOT}` estiver definido, o repositório é `${CLAUDE_PLUGIN_ROOT}/../..`. Caso contrário, clonar `https://github.com/UHXI/uhxi-plugins` para uma pasta temporária.
2. Executar o script de bootstrap adequado ao sistema:
   - Linux / macOS: `bash scripts/bootstrap.sh`
   - Windows (PowerShell): `pwsh -File scripts/bootstrap.ps1` (ou `powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1`)
   O script é idempotente: regista o marketplace, instala os plugins que faltam, actualiza os já instalados e instala as ferramentas externas.
3. Ler a saída do script e relatar ao utilizador, em prosa, o que foi instalado, o que já estava e o que falhou, com o comando exacto para repetir manualmente cada falha.
4. Se algum plugin de terceiros falhar por "plugin.json not found", o repositório é um mono-repo: propor a correcção da entrada em `.claude-plugin/marketplace.json` para `{"source": "git-subdir", "url": "...", "path": "<pasta do plugin>"}`.
5. Nunca alterar `~/.claude/settings.json` além do que o script faz (chaves `extraKnownMarketplaces` e `enabledPlugins`). Nunca instalar ferramentas fora de `external/tools.json` sem confirmação.

## Actualização

Para actualizar tudo: `claude plugin marketplace update uhxi && bash scripts/bootstrap.sh --update` (Windows: `-Update`). Para graphify: `uv tool upgrade graphifyy && graphify install`.
