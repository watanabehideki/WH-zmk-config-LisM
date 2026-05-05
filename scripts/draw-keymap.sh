#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYMAP_DIR="${ROOT_DIR}/config"
OUT_DIR="${ROOT_DIR}/keymap-drawer"
CFG="${OUT_DIR}/config.yaml"

# keymap-drawer (= keymap CLI) が無ければ自動インストール
# Dockerfile に同梱されている前提だが、既存コンテナでも動くよう保険として持つ
if ! command -v keymap >/dev/null 2>&1; then
  echo "📦 keymap-drawer が未インストールです。インストールします..."
  if ! python3 -m pip --version >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y --no-install-recommends python3-pip
  fi
  python3 -m pip install --break-system-packages --quiet keymap-drawer
  command -v keymap >/dev/null 2>&1 || {
    echo "❌ keymap CLI のインストールに失敗しました" >&2
    exit 1
  }
fi

[ -f "${CFG}" ] || { echo "❌ ${CFG} が見つかりません" >&2; exit 1; }

shopt -s nullglob
keymaps=( "${KEYMAP_DIR}"/*.keymap )
shopt -u nullglob

if [ ${#keymaps[@]} -eq 0 ]; then
  echo "⚠️ ${KEYMAP_DIR} に *.keymap が見つかりません"
  exit 0
fi

for kmap in "${keymaps[@]}"; do
  base="$(basename "${kmap}" .keymap)"
  yaml_path="${OUT_DIR}/${base}.yaml"
  svg_path="${OUT_DIR}/${base}.svg"

  echo "📝 parse: ${base}.keymap → ${base}.yaml"
  keymap -c "${CFG}" parse -z "${kmap}" > "${yaml_path}"

  draw_args=()
  if [ -f "${KEYMAP_DIR}/${base}.json" ]; then
    draw_args+=( -j "${KEYMAP_DIR}/${base}.json" )
  fi

  echo "🎨 draw : ${base}.yaml → ${base}.svg"
  keymap -c "${CFG}" draw "${yaml_path}" "${draw_args[@]}" > "${svg_path}"
  echo "✅ ${svg_path}"
done
