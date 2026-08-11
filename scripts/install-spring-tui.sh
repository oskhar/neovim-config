#!/usr/bin/env bash

set -euo pipefail

repository="danvega/spring-initializr-tui"
binary="spring-initializr-tui-linux-x86_64"
install_dir="${INSTALL_DIR:-$HOME/.local/bin}"
target="$install_dir/spring-tui"

if [[ ! -f /etc/arch-release ]]; then
  printf 'Error: installer ini ditujukan untuk Arch Linux.\n' >&2
  exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
  printf 'Error: binary upstream hanya tersedia untuk Linux x86_64.\n' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'Error: curl belum terpasang. Jalankan: sudo pacman -S curl\n' >&2
  exit 1
fi

mkdir -p "$install_dir"
temporary=$(mktemp "$install_dir/.spring-tui.XXXXXX")
cleanup() { unlink "$temporary" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

url="https://github.com/$repository/releases/latest/download/$binary"
printf 'Mengunduh Spring Initializr TUI terbaru...\n'
curl --fail --location --retry 3 --progress-bar "$url" --output "$temporary"

chmod 755 "$temporary"
mv -f "$temporary" "$target"
trap - EXIT INT TERM

printf 'Terpasang: %s\n' "$target"
if [[ ":$PATH:" != *":$install_dir:"* ]]; then
  printf 'Tambahkan %s ke PATH sebelum menjalankan spring-tui.\n' "$install_dir"
else
  printf 'Jalankan dari direktori tujuan proyek dengan: spring-tui\n'
fi
