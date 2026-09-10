#!/bin/sh
set -eu

RAW='https://raw.githubusercontent.com/andrewmuratov/utm-shell/main/setup.sh'

script_dir=''
case "$0" in
  */*) script_dir=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd || true) ;;
  *) script_dir=$(pwd) ;;
esac

if [ -n "$script_dir" ] && [ -f "$script_dir/setup.sh" ]; then
  exec sh "$script_dir/setup.sh" "$@"
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$RAW" -o "$tmp"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp" "$RAW"
elif command -v fetch >/dev/null 2>&1; then
  fetch -qo "$tmp" "$RAW"
elif command -v ftp >/dev/null 2>&1; then
  ftp -Vo "$tmp" "$RAW"
else
  printf 'utm-shell: need curl, wget, fetch, or ftp\n' >&2
  exit 1
fi

sh "$tmp" "$@"
