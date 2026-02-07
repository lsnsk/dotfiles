# ============================================================================
# Дополнения к .bashrc
# Оптимизировано для: tmux + Claude Code CLI + Termius (desktop & mobile)
# Добавляется в конец существующего .bashrc
# ============================================================================

# --- ИСТОРИЯ (оптимизировано для tmux + Claude Code) ---
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T  "
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history"
shopt -s histappend cmdhist

# Немедленная запись истории (критично для tmux с несколькими панелями)
# Защита от дублирования при повторном source ~/.bashrc
if [[ "${PROMPT_COMMAND}" != *"history -a"* ]]; then
    PROMPT_COMMAND='history -a; history -n; '"${PROMPT_COMMAND}"
fi

# --- LOCALE ---
export LANG=en_US.UTF-8

# --- PAGER / EDITOR ---
export PAGER='less -R'
export LESS='-FRX'
export EDITOR=vim

# --- TMUX УТИЛИТЫ ---

# Быстрое сохранение scrollback
alias tmux-save='tmux capture-pane -pS -50000 > ~/tmux-logs/capture_$(date +%Y%m%d_%H%M%S).txt && echo "Saved to ~/tmux-logs/"'

# Авто-подключение к tmux при SSH (с защитой от scp/sftp)
if [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]] && [[ "$SSH_TTY" ]] && command -v tmux &>/dev/null; then
    tmux new-session -A -s main
fi
