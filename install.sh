#!/usr/bin/env bash
set -Eeuo pipefail

RAW="https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh"

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [[ -n "$dir" && -f "$dir/setup.sh" ]]; then
    exec bash "$dir/setup.sh" "$@"
  fi
fi

if command -v curl >/dev/null 2>&1; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL "$RAW" -o "$tmp"
elif command -v wget >/dev/null 2>&1; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  wget -qO "$tmp" "$RAW"
else
  printf 'utm-shell: curl or wget is required\n' >&2
  exit 1
fi

bash "$tmp" "$@"
