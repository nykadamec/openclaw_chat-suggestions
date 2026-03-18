#!/bin/bash
set -euo pipefail

# OpenClaw Chat Suggestions Downloader+Installer
# Target OpenClaw version: v2026.3.13-beta.1
# Downloads patch payload from GitHub branch/tag: v2026.3.13-beta.1

PATCH_REPO_URL="https://github.com/nykadamec/openclaw_chat-suggestions.git"
PATCH_REF="v2026.3.13-beta.1"
WORK_DIR="$(mktemp -d)"
PATCH_DIR="$WORK_DIR/openclaw_chat-suggestions"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

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

require_cmd git
require_cmd bash

echo "⬇️ OpenClaw Chat Suggestions Patch Downloader"
echo "============================================="
echo "Repo: $PATCH_REPO_URL"
echo "Ref:  $PATCH_REF"
echo ""

echo "Cloning patch payload..."
git clone --depth 1 --branch "$PATCH_REF" "$PATCH_REPO_URL" "$PATCH_DIR"

echo ""
echo "Running patch installer..."
exec bash "$PATCH_DIR/patch-chat-suggestions.sh" "$@"
