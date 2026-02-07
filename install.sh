#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Установщик dotfiles: tmux + bashrc для Claude Code + Termius
# Использование: curl -sL <url>/install.sh | bash
#            или: ./install.sh
# ============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/config-backups/$(date +%Y%m%d-%H%M%S)"
MARKER="# >>> dotfiles-tmux-claude <<<"
MARKER_END="# <<< dotfiles-tmux-claude >>>"

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

# --- Проверка tmux ---
if ! command -v tmux &>/dev/null; then
    yellow "tmux не найден. Устанавливаю..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq tmux
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y tmux
    elif command -v brew &>/dev/null; then
        brew install tmux
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm tmux
    else
        red "Не удалось установить tmux. Установите вручную."
        exit 1
    fi
fi

TMUX_VER=$(tmux -V | grep -oP '[0-9]+\.[0-9]+')
green "tmux $TMUX_VER найден"

if awk "BEGIN{exit !($TMUX_VER < 3.2)}"; then
    yellow "ВНИМАНИЕ: tmux $TMUX_VER < 3.2. Popup-окна не будут работать."
    yellow "Рекомендуется tmux 3.4+. Остальное будет работать."
fi

# --- Проверка git ---
if ! command -v git &>/dev/null; then
    red "git не найден. Установите git и повторите."
    exit 1
fi

# --- Бекапы ---
mkdir -p "$BACKUP_DIR"
green "Бекапы в $BACKUP_DIR"

if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$BACKUP_DIR/.tmux.conf.bak"
    green "  .tmux.conf — сохранён"
fi
# XDG location
if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    cp "$HOME/.config/tmux/tmux.conf" "$BACKUP_DIR/tmux.conf.xdg.bak"
    green "  .config/tmux/tmux.conf — сохранён"
fi
if [[ -f "$HOME/.bashrc" ]]; then
    cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc.bak"
    green "  .bashrc — сохранён"
fi

# --- Установка .tmux.conf ---
cp "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
green ".tmux.conf установлен"

# --- Установка bashrc-additions ---
# Удаляем старый блок если был
if [[ -f "$HOME/.bashrc" ]] && grep -q "$MARKER" "$HOME/.bashrc"; then
    yellow "Обнаружен предыдущий блок dotfiles в .bashrc — заменяю"
    # Удаляем старый блок между маркерами
    sed -i "/$MARKER/,/$MARKER_END/d" "$HOME/.bashrc"
fi

# Патчим существующие настройки (комментируем, чтобы наши были приоритетнее)
if [[ -f "$HOME/.bashrc" ]]; then
    # История
    sed -i 's/^HISTSIZE=/#DOTFILES_REPLACED# HISTSIZE=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^HISTFILESIZE=/#DOTFILES_REPLACED# HISTFILESIZE=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^HISTCONTROL=/#DOTFILES_REPLACED# HISTCONTROL=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^HISTTIMEFORMAT=/#DOTFILES_REPLACED# HISTTIMEFORMAT=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^HISTIGNORE=/#DOTFILES_REPLACED# HISTIGNORE=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^export HISTSIZE=/#DOTFILES_REPLACED# export HISTSIZE=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^export HISTFILESIZE=/#DOTFILES_REPLACED# export HISTFILESIZE=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^export HISTCONTROL=/#DOTFILES_REPLACED# export HISTCONTROL=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^export HISTTIMEFORMAT=/#DOTFILES_REPLACED# export HISTTIMEFORMAT=/' "$HOME/.bashrc" 2>/dev/null || true

    # LANG/LC_ALL: комментируем все существующие — наш блок выставит корректно
    # LC_ALL переопределяет все locale-категории, что создаёт проблемы; оставляем только LANG
    sed -i 's/^export LANG=/#DOTFILES_REPLACED# export LANG=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^export LC_ALL=/#DOTFILES_REPLACED# export LC_ALL=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^LANG=/#DOTFILES_REPLACED# LANG=/' "$HOME/.bashrc" 2>/dev/null || true
    sed -i 's/^LC_ALL=/#DOTFILES_REPLACED# LC_ALL=/' "$HOME/.bashrc" 2>/dev/null || true

    # Считаем сколько было закомментировано
    REPLACED=$(grep -c '#DOTFILES_REPLACED#' "$HOME/.bashrc" 2>/dev/null || echo 0)
    if [[ "$REPLACED" -gt 0 ]]; then
        yellow "Закомментировано $REPLACED оригинальных строк (HIST*/LANG/LC_ALL)"
    fi
fi

# Добавляем наш блок
{
    echo ""
    echo "$MARKER"
    cat "$DOTFILES_DIR/bashrc-additions.sh"
    echo "$MARKER_END"
} >> "$HOME/.bashrc"
green "bashrc-additions добавлен в .bashrc"

# --- Создаём директории ---
mkdir -p "$HOME/tmux-logs"
green "~/tmux-logs создана"

# --- TPM ---
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    yellow "TPM не найден. Устанавливаю..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    green "TPM установлен"
else
    green "TPM уже установлен"
fi

# --- Установка плагинов ---
yellow "Устанавливаю tmux-плагины..."
TMUX='' "$HOME/.tmux/plugins/tpm/bin/install_plugins" 2>&1 | while read -r line; do
    echo "  $line"
done
green "Плагины установлены"

# --- Итог ---
echo ""
green "============================================"
green "  Установка завершена!"
green "============================================"
echo ""
echo "Что сделано:"
echo "  1. .tmux.conf — установлен (бекап в $BACKUP_DIR)"
echo "  2. .bashrc — дополнен оптимизациями"
echo "  3. TPM + плагины — установлены"
echo "  4. ~/tmux-logs — создана"
echo ""
echo "Применить:"
echo "  tmux source-file ~/.tmux.conf   # если tmux уже запущен"
echo "  source ~/.bashrc                 # для текущего shell"
echo ""
echo "Новые хоткеи tmux:"
echo "  PageUp          — скролл вверх"
echo "  Alt+Space       — copy-mode"
echo "  Prefix + /      — поиск в scrollback"
echo "  Prefix + m      — вкл/выкл мышь"
echo "  Prefix + F      — tmux-thumbs (копирование URL/путей)"
echo "  Prefix + Shift+P — логирование панели"
echo "  Prefix + Alt+Shift+P — сохранить весь scrollback"
echo "  Prefix + g      — lazygit popup"
echo "  Prefix + G      — htop popup"
echo "  Ctrl+a          — вторичный prefix"
echo "  K / J (copy-mode) — полстраницы вверх/вниз"
echo ""
echo "Bash:"
echo "  tmux-save       — сохранить scrollback в файл"
echo ""
