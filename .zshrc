# ── History ────────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS       # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE      # don't record commands starting with a space
setopt HIST_REDUCE_BLANKS     # strip extra whitespace before saving
setopt SHARE_HISTORY          # share history across all open zsh sessions
setopt EXTENDED_HISTORY       # save timestamps in history

# ── Completion ─────────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
setopt MENU_COMPLETE           # tab-cycles through completions

# ── Key bindings ───────────────────────────────────────────────────────────────
bindkey -e                     # emacs-style keys (Ctrl+A/E, etc.)
bindkey '^[[A' history-search-backward   # up arrow = history search by prefix
bindkey '^[[B' history-search-forward

# ── fzf history search (Ctrl+R) ────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)          # sets up Ctrl+R, Ctrl+T, Alt+C
fi

# ── Antidote plugins ───────────────────────────────────────────────────────────
source ~/.antidote/antidote.zsh
antidote load ~/.zsh_plugins.txt

# ── Starship prompt ────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ── Source your aliases/functions ──────────────────────────────────────────────
# If you keep shared aliases in a separate file (recommended for multi-machine):
[[ -f ~/.aliases ]] && source ~/.aliases
alias backup-export='~/scripts/backup-export-laptop.sh'

# ── Machine-local overrides ────────────────────────────────────────────────────
# Anything that differs per-machine (e.g. egghead-specific paths, desktop GPU
# env vars) goes in ~/.zshrc.local and is NOT committed to your dotfiles repo.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ── pywal ──────────────────────────────────────────────────────────────────────
(cat ~/.cache/wal/sequences &)
source ~/.cache/wal/colors-tty.sh
