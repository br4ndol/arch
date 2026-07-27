# ---------- Aliases ----------
alias ls='eza -a --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias tree='eza --tree --icons --level=2'
alias grep='grep --color=auto'
alias ff='fastfetch'
alias ff-live="watch -ctn 0.5 'fastfetch --pipe false'"
alias fonts="fc-list : family | sort -u"
alias kernel-update='sudo mkinitcpio -P; sudo kernel-install add $(uname -r) /usr/lib/modules/$(uname -r)/vmlinuz'
# alias windows='sudo efibootmgr -n 0000 && sudo reboot'

if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  export TERM=xterm-256color
fi

# ---------- History ----------
mkdir -p ~/.local/state/zsh
HISTFILE=~/.local/state/zsh/history
HISTSIZE=50000
SAVEHIST=50000

[[ -f "$HISTFILE" ]] || : >| "$HISTFILE"
chmod 600 "$HISTFILE" 2>/dev/null

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# ---------- Completion ----------
fpath=(/usr/share/zsh/site-functions $fpath)

autoload -Uz compinit
mkdir -p ~/.cache/zsh
ZSH_COMPDUMP=~/.cache/zsh/zcompdump-$ZSH_VERSION
compinit -d "$ZSH_COMPDUMP"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh

# ---------- fzf ----------
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

# ---------- fzf-tab ----------
[[ -r ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]] && source ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh

zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -A --color=always $realpath 2>/dev/null'

# ---------- autosuggestions ----------
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---------- Starship ----------
(( $+commands[starship] )) && eval "$(starship init zsh)"

# ---------- Zoxide ----------
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# ---------- syntax highlighting ----------
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh