#!/bin/bash
set -euo pipefail

# OpenClaw Chat Suggestions Patch Installer
# Target: OpenClaw v2026.3.13-beta.1
# One-shot patch: runtime dist/*.js + static dist/control-ui/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIST_JS_DIR="$SCRIPT_DIR/files/dist-js"
PATCH_CONTROL_UI_DIR="$SCRIPT_DIR/files/control-ui"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}Missing required command: $1${NC}"
    exit 1
  }
}

detect_openclaw_dist() {
  if [[ -d "/opt/homebrew/lib/node_modules/openclaw/dist" ]]; then
    echo "/opt/homebrew/lib/node_modules/openclaw/dist"
  elif [[ -d "$HOME/.openclaw/node_modules/openclaw/dist" ]]; then
    echo "$HOME/.openclaw/node_modules/openclaw/dist"
  else
    echo ""
  fi
}

restart_gateway() {
  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway restart || true
    echo -e "${GREEN}Gateway restart initiated${NC}"
  else
    echo -e "${YELLOW}Warning: 'openclaw' not found in PATH${NC}"
    echo "Restart manually: openclaw gateway restart"
  fi
}

revert_patch() {
  local OPENCLAW_DIST BACKUP_DIR
  OPENCLAW_DIST="$(detect_openclaw_dist)"
  if [[ -z "$OPENCLAW_DIST" ]]; then
    echo -e "${RED}Error: OpenClaw installation not found${NC}"
    exit 1
  fi

  BACKUP_DIR=""
  if [[ -f "$HOME/.openclaw/.last-chat-patch-backup" ]]; then
    BACKUP_DIR="$(cat "$HOME/.openclaw/.last-chat-patch-backup")"
  fi
  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$(ls -td "$HOME/.openclaw/backups/chat-suggestions-patch-"* 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: No backup found${NC}"
    exit 1
  fi

  echo "🪄 Reverting patch from: $BACKUP_DIR"

  if compgen -G "$BACKUP_DIR/dist-js/*.js" >/dev/null; then
    cp "$BACKUP_DIR/dist-js"/*.js "$OPENCLAW_DIST/"
    echo "  ✓ Restored dist/*.js"
  fi

  if [[ -d "$BACKUP_DIR/control-ui" ]]; then
    rm -rf "$OPENCLAW_DIST/control-ui"
    cp -R "$BACKUP_DIR/control-ui" "$OPENCLAW_DIST/control-ui"
    echo "  ✓ Restored dist/control-ui/"
  fi

  restart_gateway
  rm -f "$HOME/.openclaw/.last-chat-patch-backup"
  echo -e "${GREEN}✅ Patch reverted successfully${NC}"
  exit 0
}

if [[ "${1:-}" == "--revert" ]]; then
  revert_patch
fi

require_cmd node

echo "🧩 OpenClaw Chat Suggestions Patch Installer"
echo "=============================================="
echo ""

OPENCLAW_DIST="$(detect_openclaw_dist)"
if [[ -z "$OPENCLAW_DIST" ]]; then
  echo -e "${RED}Error: OpenClaw installation not found${NC}"
  exit 1
fi

if [[ ! -d "$PATCH_DIST_JS_DIR" || ! -d "$PATCH_CONTROL_UI_DIR" ]]; then
  echo -e "${RED}Error: Patch payload is incomplete${NC}"
  echo "Expected:"
  echo "  $PATCH_DIST_JS_DIR"
  echo "  $PATCH_CONTROL_UI_DIR"
  exit 1
fi

echo "Found OpenClaw at: $OPENCLAW_DIST"

CURRENT_VERSION="unknown"
if [[ -f "$OPENCLAW_DIST/../package.json" ]]; then
  CURRENT_VERSION=$(node -p "require('$OPENCLAW_DIST/../package.json').version" 2>/dev/null || echo "unknown")
fi
echo "Current OpenClaw version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" != "2026.3.13-beta.1" ]]; then
  echo -e "${YELLOW}Warning: This patch targets v2026.3.13-beta.1${NC}"
  read -r -p "Continue anyway? (y/N) " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

BACKUP_DIR="$HOME/.openclaw/backups/chat-suggestions-patch-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR/dist-js"

echo ""
echo "Step 1: Backing up current files..."
cp "$OPENCLAW_DIST"/*.js "$BACKUP_DIR/dist-js/"
if [[ -d "$OPENCLAW_DIST/control-ui" ]]; then
  cp -R "$OPENCLAW_DIST/control-ui" "$BACKUP_DIR/control-ui"
fi
echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"

echo ""
echo "Step 2: Installing dist runtime files..."
cp "$PATCH_DIST_JS_DIR"/*.js "$OPENCLAW_DIST/"
DIST_COUNT=$(find "$PATCH_DIST_JS_DIR" -maxdepth 1 -type f -name '*.js' | wc -l | tr -d ' ')
echo "  ✓ Installed $DIST_COUNT dist JS files"

echo ""
echo "Step 3: Installing Control UI assets..."
rm -rf "$OPENCLAW_DIST/control-ui"
cp -R "$PATCH_CONTROL_UI_DIR" "$OPENCLAW_DIST/control-ui"
echo "  ✓ Replaced dist/control-ui/"

echo ""
echo "Step 4: Restarting OpenClaw Gateway..."
restart_gateway

echo "$BACKUP_DIR" > "$HOME/.openclaw/.last-chat-patch-backup"

echo ""
echo -e "${GREEN}✅ Patch installation complete!${NC}"
echo ""
echo "Installed:"
echo "  - dist/*.js"
echo "  - dist/control-ui/"
echo ""
echo "To revert:"
echo "  $0 --revert"
echo ""
echo "Backup location: $BACKUP_DIR"
