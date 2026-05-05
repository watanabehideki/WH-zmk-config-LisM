#!/bin/bash
set -euo pipefail

if [ -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code is already installed: $($HOME/.local/bin/claude --version)"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Installing curl..."
  apt-get update
  apt-get install -y --no-install-recommends curl ca-certificates
fi

echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

BASHRC="$HOME/.bashrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [ -f "$BASHRC" ] && ! grep -qF "$PATH_LINE" "$BASHRC"; then
  echo "" >> "$BASHRC"
  echo "# Added by setup-claude.sh" >> "$BASHRC"
  echo "$PATH_LINE" >> "$BASHRC"
fi

if [ -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code installed successfully: $($HOME/.local/bin/claude --version)"
else
  echo "Claude Code installation failed" >&2
  exit 1
fi