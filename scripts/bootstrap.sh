#!/usr/bin/env bash
# bootstrap.sh — sincroniza este ambiente com o marketplace 'uhxi' e as ferramentas externas.
# Uso: bash scripts/bootstrap.sh [--update] [--no-tools] [--no-plugins] [--project] [--all-tools]
#   --update      actualiza marketplaces/plugins/ferramentas já instalados
#   --no-tools    salta external/tools.json
#   --no-plugins  salta plugins Claude Code
#   --project     regista as ferramentas no projecto actual (ex.: graphify install --project)
#   --all-tools   inclui as ferramentas marcadas "optional" em tools.json (ex.: omniroute)
set -u
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE=0; DO_TOOLS=1; DO_PLUGINS=1; PROJECT=0; ALL_TOOLS=0
for a in "$@"; do case "$a" in
  --update) UPDATE=1;; --no-tools) DO_TOOLS=0;; --no-plugins) DO_PLUGINS=0;; --project) PROJECT=1;; --all-tools) ALL_TOOLS=1;;
esac; done

OK=(); SKIP=(); FAIL=()
say(){ printf '\n\033[1m== %s\033[0m\n' "$*"; }
need(){ command -v "$1" >/dev/null 2>&1; }
case "$(uname -s)" in Darwin) OS=darwin;; Linux) OS=linux;; *) OS=linux;; esac

need jq || { echo "jq é necessário (apt install jq / brew install jq)."; exit 1; }
need claude || { echo "Claude Code (comando 'claude') não encontrado. Instalar primeiro: https://code.claude.com"; DO_PLUGINS=0; }

# ---------- 1. settings.json do utilizador: fundir marketplaces + plugins activos ----------
SETTINGS="$HOME/.claude/settings.json"; TEMPLATE="$REPO_DIR/templates/settings.user.json"
mkdir -p "$HOME/.claude"; [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
say "A fundir templates/settings.user.json em $SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
jq -s '.[0] * {extraKnownMarketplaces: ((.[0].extraKnownMarketplaces // {}) + .[1].extraKnownMarketplaces),
               enabledPlugins:        ((.[0].enabledPlugins // {})        + .[1].enabledPlugins)}' \
   "$SETTINGS" "$TEMPLATE" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS" && OK+=("settings.json fundido")

# ---------- 2. Marketplaces ----------
if [ "$DO_PLUGINS" = 1 ]; then
  say "Marketplaces"
  KNOWN="$(claude plugin marketplace list 2>/dev/null || true)"
  # 'uhxi' aponta para este próprio repositório quando corrido localmente
  if ! grep -q '^uhxi\b\|uhxi' <<<"$KNOWN"; then
    claude plugin marketplace add "$REPO_DIR" >/dev/null 2>&1 && OK+=("marketplace uhxi (local: $REPO_DIR)") || FAIL+=("marketplace add uhxi ($REPO_DIR)")
  else SKIP+=("marketplace uhxi já registado"); fi
  while read -r name src; do
    if grep -q "$name" <<<"$KNOWN"; then SKIP+=("marketplace $name já registado"); continue; fi
    claude plugin marketplace add "$src" >/dev/null 2>&1 && OK+=("marketplace $name") || FAIL+=("marketplace add $name ($src)")
  done < <(jq -r '.extraKnownMarketplaces | to_entries[] | select(.key!="uhxi") | "\(.key) \(.value.source.repo // .value.source.url)"' "$TEMPLATE")
  [ "$UPDATE" = 1 ] && { claude plugin marketplace update >/dev/null 2>&1 && OK+=("marketplaces actualizados"); }

  # ---------- 3. Plugins ----------
  say "Plugins"
  INSTALLED="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"
  while read -r id; do
    if grep -qx "$id" <<<"$INSTALLED"; then
      if [ "$UPDATE" = 1 ]; then claude plugin update "$id" >/dev/null 2>&1 && OK+=("actualizado $id") || FAIL+=("update $id"); else SKIP+=("$id já instalado"); fi
      continue
    fi
    if claude plugin install "$id" --scope user -y >/dev/null 2>&1; then OK+=("instalado $id"); else FAIL+=("claude plugin install $id --scope user -y"); fi
  done < <(jq -r '.enabledPlugins | to_entries[] | select(.value==true) | .key' "$TEMPLATE")
fi

# ---------- 4. Ferramentas externas ----------
if [ "$DO_TOOLS" = 1 ]; then
  say "Ferramentas externas (external/tools.json)"
  TOOLS="$REPO_DIR/external/tools.json"
  export PATH="$HOME/.local/bin:$PATH"
  for i in $(jq -r '.tools | keys[]' "$TOOLS"); do
    id=$(jq -r ".tools[$i].id" "$TOOLS"); check=$(jq -r ".tools[$i].check" "$TOOLS")
    if [ "$(jq -r ".tools[$i].optional // false" "$TOOLS")" = true ] && [ "$ALL_TOOLS" = 0 ]; then SKIP+=("$id é opcional (usar --all-tools)"); continue; fi
    inst=$(jq -r ".tools[$i].install[\"$OS\"] // empty" "$TOOLS"); upg=$(jq -r ".tools[$i].upgrade // empty" "$TOOLS")
    reg=$(jq -r ".tools[$i].register // empty" "$TOOLS"); regp=$(jq -r ".tools[$i].register_project // empty" "$TOOLS")
    for r in $(jq -r ".tools[$i].requires // [] | .[]" "$TOOLS"); do need "$r" || { FAIL+=("$id: falta o pré-requisito '$r'"); continue 2; }; done
    if sh -c "$check" >/dev/null 2>&1; then
      if [ "$UPDATE" = 1 ] && [ -n "$upg" ]; then sh -c "$upg" >/dev/null 2>&1 && OK+=("actualizado $id") || FAIL+=("$upg"); else SKIP+=("$id já instalado"); fi
    else
      [ -z "$inst" ] && { SKIP+=("$id sem comando de instalação para $OS"); continue; }
      sh -c "$inst" >/dev/null 2>&1 && OK+=("instalado $id") || { FAIL+=("$inst"); continue; }
      note=$(jq -r ".tools[$i].post_install_note // empty" "$TOOLS"); [ -n "$note" ] && echo "  nota: $note"
    fi
    cmd="$reg"; [ "$PROJECT" = 1 ] && [ -n "$regp" ] && cmd="$regp"
    [ -n "$cmd" ] && { sh -c "$cmd" >/dev/null 2>&1 && OK+=("registado: $cmd") || FAIL+=("$cmd"); }
  done
fi

# ---------- 5. Relatório ----------
say "Resumo"
printf '  feito:   %s\n' "${OK[@]:-—}"
printf '  saltado: %s\n' "${SKIP[@]:-—}"
printf '  falhou:  %s\n' "${FAIL[@]:-—}"
[ ${#FAIL[@]} -eq 0 ]
