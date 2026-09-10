#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.7.2"
USE_HUSHLOGIN="${1:-1}"
BASHRC="$HOME/.bashrc"
START="# >>> utm-shell >>>"
END="# <<< utm-shell <<<"
LOGIN_START="# >>> utm-shell login >>>"
LOGIN_END="# <<< utm-shell login <<<"
STATE_DIR="$HOME/.config/utm-shell"
SHELL_FILE="$STATE_DIR/shell.sh"
STATE_FILE="$STATE_DIR/state"
BACKUP_FILE="$STATE_DIR/bashrc.before-utm-shell"

mkdir -p "$STATE_DIR"
touch "$BASHRC"

remove_block() {
  local file="$1" start="$2" end="$3" tmp
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# Keep one copy of the user's pre-migration .bashrc. utm-shell only replaces
# blocks carrying its own markers; everything else remains untouched.
if [[ -s "$BASHRC" && ! -e "$BACKUP_FILE" ]]; then
  cp "$BASHRC" "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE"
fi

# Remove every older inline utm-shell block before installing the loader.
# This repairs early versions that defined functions directly in .bashrc and
# could conflict with pre-existing aliases such as `usage` or `path`.
remove_block "$BASHRC" "$START" "$END"

cat > "$SHELL_FILE" <<'SHELL_EOF'
# Managed by UTM Shell. Run `utm update` on your computer to update this file.

# Older/manual setups may already define aliases with these names. Remove
# aliases before Bash parses the function definitions below.
unalias c cls usage py gs gd gl path mkcd ff utm-help utm-version 2>/dev/null || true
[[ $- == *i* ]] || return 0

if [[ -n ${TERM:-} ]] && command -v infocmp >/dev/null 2>&1 && ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize cdspell globstar

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias reload='source ~/.bashrc'
alias disk='df -h'
alias bye='exit'

function c { printf '\033[H\033[2J\033[3J'; }
function cls { c; }

function usage {
  local -a items=()
  local item
  while IFS= read -r -d '' item; do items+=("$item"); done < <(find . -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  if ((${#items[@]} == 0)); then printf 'No files in %s\n' "$PWD"; return 0; fi
  du -sh -- "${items[@]}" 2>/dev/null | sort -h
}

function py {
  if ! command -v python3 >/dev/null 2>&1; then printf 'python3 is not available on this lab machine.\n' >&2; return 127; fi
  python3 "$@"
}

function _utm_git_need_repo {
  if ! command -v git >/dev/null 2>&1; then printf 'git is not available on this lab machine.\n' >&2; return 127; fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then printf 'Not in a Git repository: %s\n' "$PWD" >&2; return 1; fi
}
function gs { _utm_git_need_repo || return; git status "$@"; }
function gd { _utm_git_need_repo || return; git diff "$@"; }
function gl { _utm_git_need_repo || return; git log --oneline --graph --decorate -15 "$@"; }

function mkcd { [[ $# -eq 1 ]] || { printf 'usage: mkcd <directory>\n' >&2; return 2; }; mkdir -p -- "$1" && cd -- "$1"; }
function ff { [[ $# -ge 1 ]] || { printf 'usage: ff <name>\n' >&2; return 2; }; find . -iname "*$1*" 2>/dev/null; }
function path { printf '%s\n' "$PATH" | tr ':' '\n'; }
function utm-version { printf 'UTM Shell 1.7.2\n'; }

function utm-help {
  cat <<'HELP_EOF'
UTM Shell commands

  ll / la       detailed / hidden-file listings
  .. / ...      move up one / two directories
  c / cls       clear terminal + scrollback
  reload        reload shell setup
  bye           leave SSH
  mkcd DIR      create + enter directory
  ff NAME       find files/directories
  disk          filesystem usage
  usage         sizes of items here
  path          print PATH
  py [ARGS]     run python3
  gs / gd / gl  Git status / diff / log
  utm-version   show version
  utm-help      show this help
HELP_EOF
}

if command -v bind >/dev/null 2>&1; then
  bind '"\e[A": history-search-backward' 2>/dev/null || true
  bind '"\e[B": history-search-forward' 2>/dev/null || true
fi

PS1='\[\e[1;34m\]UTM\[\e[0m\] \[\e[90m\]\u@\h\[\e[0m\] \[\e[1;37m\]\w\[\e[0m\]\n\[\e[1;34m\]❯\[\e[0m\] '
SHELL_EOF
chmod 600 "$SHELL_FILE"
bash --noprofile --norc -n "$SHELL_FILE"

cat >> "$BASHRC" <<'BASHRC_EOF'

# >>> utm-shell >>>
if [ -r "$HOME/.config/utm-shell/shell.sh" ]; then
  builtin source "$HOME/.config/utm-shell/shell.sh"
fi
# <<< utm-shell <<<
BASHRC_EOF

if ! bash --noprofile --norc -n "$BASHRC"; then
  printf 'UTM Shell: ~/.bashrc still has a syntax error outside the managed block.\n' >&2
  printf 'Backup: %s\n' "$BACKUP_FILE" >&2
  exit 2
fi

if [[ -f "$HOME/.bash_profile" ]]; then LOGIN_FILE="$HOME/.bash_profile"
elif [[ -f "$HOME/.bash_login" ]]; then LOGIN_FILE="$HOME/.bash_login"
else LOGIN_FILE="$HOME/.profile"; touch "$LOGIN_FILE"; fi

remove_block "$LOGIN_FILE" "$LOGIN_START" "$LOGIN_END"
LOGIN_MANAGED=0
if ! grep -Eq '(^|[[:space:]])(\.|source|builtin[[:space:]]+source)[[:space:]].*\.bashrc' "$LOGIN_FILE" 2>/dev/null; then
  cat >> "$LOGIN_FILE" <<'LOGIN_EOF'

# >>> utm-shell login >>>
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
# <<< utm-shell login <<<
LOGIN_EOF
  LOGIN_MANAGED=1
fi

HUSH_CREATED=0
if [[ "$USE_HUSHLOGIN" == "1" && ! -e "$HOME/.hushlogin" ]]; then touch "$HOME/.hushlogin"; HUSH_CREATED=1; fi

{
  printf 'VERSION=%q\n' "$VERSION"
  printf 'LOGIN_FILE=%q\n' "$LOGIN_FILE"
  printf 'LOGIN_MANAGED=%q\n' "$LOGIN_MANAGED"
  printf 'HUSH_CREATED=%q\n' "$HUSH_CREATED"
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
printf 'UTM Shell %s installed\n' "$VERSION"
