#!/usr/bin/env bash
# Global Azure Hamburg 2026 — Agents & Yolo-Mode Demo Setup
# Usage:
#   ./setup.sh                 # Full setup + verify + clone
#   ./setup.sh --reset         # Just reset the demo repo to clean state
#   ./setup.sh --check         # Only verify, don't install anything
#   WORKSHOP_DIR=~/code/demo ./setup.sh   # Override clone location

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
WORKSHOP_DIR="${WORKSHOP_DIR:-$HOME/demo-global-azure-2026}"
REPO_URL="https://github.com/TheTrustedAdvisor/global-azure-2026-agents-yolo.git"

MODE="${1:-full}"   # full | --reset | --check

# ─── Colors & helpers ──────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[0;31m'; GRN=$'\033[0;32m'
  YLW=$'\033[0;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
else
  BOLD='' RED='' GRN='' YLW='' BLU='' NC=''
fi

step() { printf "\n${BLU}▶${NC} ${BOLD}%s${NC}\n" "$1"; }
ok()   { printf "  ${GRN}✓${NC} %s\n" "$1"; }
warn() { printf "  ${YLW}⚠${NC} %s\n" "$1"; }
fail() { printf "  ${RED}✗${NC} %s\n" "$1"; exit 1; }

header() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Global Azure Hamburg 2026 — Demo Setup"
  echo "  Mode: $MODE"
  echo "  Target: $WORKSHOP_DIR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── OS & package manager ──────────────────────────────────────────────────
check_os() {
  step "OS check"
  OS="$(uname -s)"
  case "$OS" in
    Darwin) ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?')" ; PKG="brew" ;;
    Linux)  ok "Linux $(uname -r)" ; PKG="apt" ;;
    *)      fail "Unsupported OS: $OS" ;;
  esac

  if [[ "$PKG" == "brew" ]] && ! command -v brew >/dev/null; then
    fail "Homebrew required. Install from https://brew.sh"
  fi
}

# ─── GitHub CLI ────────────────────────────────────────────────────────────
check_gh() {
  step "GitHub CLI (gh)"
  if command -v gh >/dev/null; then
    ok "$(gh --version | head -1)"
  else
    [[ "$MODE" == "--check" ]] && { warn "Not installed — run without --check to install"; return; }
    warn "Installing gh..."
    if [[ "$PKG" == "brew" ]]; then brew install gh; else sudo apt install -y gh; fi
    ok "Installed"
  fi

  if gh auth status 2>&1 | grep -q "Logged in"; then
    ok "Authenticated as $(gh api user --jq .login 2>/dev/null || echo '?')"
  else
    warn "Not authenticated — run: gh auth login"
  fi
}

# ─── Copilot CLI ───────────────────────────────────────────────────────────
check_copilot() {
  step "Copilot CLI"
  if command -v copilot >/dev/null; then
    ok "$(copilot --version 2>&1 | head -1)"
  else
    [[ "$MODE" == "--check" ]] && { warn "Not installed"; return; }
    warn "Installing copilot CLI..."
    npm install -g @github/copilot
    ok "Installed"
  fi
}

# ─── Copilot plugins ───────────────────────────────────────────────────────
check_plugins() {
  step "Copilot plugins"
  local plugins
  plugins="$(copilot plugin list 2>/dev/null || echo '')"

  if echo "$plugins" | grep -q "omg"; then
    ok "OMG plugin installed"
  else
    [[ "$MODE" == "--check" ]] && { warn "OMG plugin missing"; return; }
    warn "Installing OMG plugin..."
    copilot plugin install TheTrustedAdvisor/omg || warn "Install failed — try manually inside copilot: /plugin install TheTrustedAdvisor/omg"
  fi

  if echo "$plugins" | grep -q "skills-for-fabric"; then
    ok "skills-for-fabric installed"
  else
    warn "skills-for-fabric needs manual install inside copilot:"
    echo "      /plugin install skills-for-fabric@fabric-collection"
  fi
}

# ─── Azure CLI ─────────────────────────────────────────────────────────────
check_azure() {
  step "Azure CLI (az)"
  if command -v az >/dev/null; then
    ok "$(az version --query '\"azure-cli\"' -o tsv 2>/dev/null || echo 'installed')"
  else
    [[ "$MODE" == "--check" ]] && { warn "Not installed"; return; }
    warn "Installing Azure CLI..."
    if [[ "$PKG" == "brew" ]]; then brew install azure-cli; else curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; fi
    ok "Installed"
  fi

  if az account show >/dev/null 2>&1; then
    local sub; sub="$(az account show --query name -o tsv 2>/dev/null)"
    ok "Logged in — subscription: $sub"
  else
    warn "Not logged in — run: az login"
  fi
}

# ─── Workshop repo ─────────────────────────────────────────────────────────
setup_repo() {
  step "Workshop repo at $WORKSHOP_DIR"

  if [[ -d "$WORKSHOP_DIR/.git" ]]; then
    ok "Repo exists — resetting to clean state"
    (cd "$WORKSHOP_DIR" && git fetch origin main --quiet && git reset --hard origin/main --quiet && git clean -fd --quiet)
  else
    [[ "$MODE" == "--check" ]] && { warn "Not cloned yet"; return; }
    ok "Cloning fresh..."
    mkdir -p "$(dirname "$WORKSHOP_DIR")"
    git clone --quiet "$REPO_URL" "$WORKSHOP_DIR"
  fi

  # Demo invariants
  if [[ -d "$WORKSHOP_DIR/.github" ]]; then
    warn "Stale .github/ found — removing (Agent creates live in Akt 1)"
    rm -rf "$WORKSHOP_DIR/.github"
  fi
  ok "No .github/ — clean demo start"

  local fact="$WORKSHOP_DIR/src/sales.semanticmodel/definition/tables/internet sales.tmdl"
  if [[ -f "$fact" ]]; then
    local count; count="$(grep -c "^[[:space:]]*measure" "$fact" || true)"
    if [[ "$count" -eq 0 ]]; then
      ok "Fact-Tables clean — no measures (Agent baut sie in Akt 3+4)"
    else
      warn "Found $count measures in internet sales.tmdl — expected 0 for demo start"
    fi
  fi
}

# ─── Summary ───────────────────────────────────────────────────────────────
summary() {
  step "Ready for demo"
  cat <<EOF

  ${BOLD}Repo ready at:${NC} $WORKSHOP_DIR
  ${BOLD}QR-Code:${NC}        https://github.com/TheTrustedAdvisor/global-azure-2026-agents-yolo
  ${BOLD}Bootstrap-Prompt${NC} (copy to clipboard, siehe README.md ▶ Akt 1)

  Start the demo:
    ${BOLD}cd "$WORKSHOP_DIR" && copilot${NC}

  Reset between dry-runs:
    ${BOLD}$(readlink -f "$0" 2>/dev/null || echo "$0") --reset${NC}

EOF
}

# ─── Main ──────────────────────────────────────────────────────────────────
main() {
  header

  if [[ "$MODE" == "--reset" ]]; then
    setup_repo
    summary
    exit 0
  fi

  check_os
  check_gh
  check_copilot
  check_plugins
  check_azure
  setup_repo
  summary
}

main "$@"
