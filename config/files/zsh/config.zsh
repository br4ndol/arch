# ---------- Aliases ----------
alias ls='eza -a --icons=auto --group-directories-first'
alias ll='eza -lah --icons=auto --group-directories-first --git'
alias tree='eza --tree --icons=auto --level=2'
alias grep='grep --color=auto'
alias ff='fastfetch'
alias fonts="fc-list : family | sort -u"
alias kernel-update='sudo mkinitcpio -p {{KERNEL}}'

# ---------- History ----------
HISTFILE=~/.local/state/zsh/history
HISTSIZE=50000
SAVEHIST=50000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_SPACE

# ---------- Completion ----------
autoload -Uz compinit
ZSH_COMPDUMP=~/.cache/zsh/zcompdump-$ZSH_VERSION
compinit -d "$ZSH_COMPDUMP"

# LS_COLORS para colorear archivos en el completado
[[ -z $LS_COLORS ]] && (( $+commands[dircolors] )) && eval "$(dircolors -b)"

zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# ---------- fzf ----------
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

# ---------- fzf-tab (después de compinit y antes de autosuggestions / syntax-highlighting) ----------
[[ -r ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]] && source ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh

zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

# ---------- autosuggestions ----------
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---------- Starship ----------
(( $+commands[starship] )) && eval "$(starship init zsh)"

# ---------- Zoxide ----------
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# ---------- syntax highlighting (siempre el último) ----------
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
