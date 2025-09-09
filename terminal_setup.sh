#!/bin/bash

# =============================================================================
# Fixed Advanced Terminal Configuration Script (terminal_setup.sh)
# Исправленная версия продвинутой настройки терминала
# Version: 1.1
# =============================================================================

set -euo pipefail

# Подключение основных функций
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/installing.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/installing.sh"
else
    # Базовые функции
    log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
    log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
    log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }
    log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
    yes_no_prompt() {
        local prompt=$1
        local response
        while true; do
            read -p "$prompt (yes/no): " response
            case "${response,,}" in
                yes|y|да|д) return 0 ;;
                no|n|нет|н) return 1 ;;
                *) echo "Введите 'yes' или 'no'" ;;
            esac
        done
    }
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERMINAL_CONFIG_DIR="/usr/local/terminal-config"
readonly USER_TERMINAL_DIR="$HOME/.terminal-config"
readonly LOG_FILE="/var/log/terminal-setup.log"

# =============================================================================
# Улучшенная функция установки компонентов
# =============================================================================

install_terminal_components() {
    log_info "=== УСТАНОВКА КОМПОНЕНТОВ ТЕРМИНАЛА ==="
    
    # Обновление списка пакетов
    log_info "Обновление списка пакетов..."
    if ! apt update 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Не удалось обновить список пакетов"
        return 1
    fi
    
    # Определение пакетов по категориям
    declare -A package_categories=(
        ["essential"]="tmux screen vim nano curl wget git htop tree ncdu"
        ["file_managers"]="ranger mc"
        ["search_tools"]="fzf ripgrep fd-find"
        ["system_info"]="neofetch screenfetch lsb-release"
        ["text_processing"]="bat exa colordiff highlight jq"
        ["entertainment"]="figlet lolcat cowsay fortune"
        ["development"]="zsh fish"
        ["network"]="httpie netcat-openbsd"
        ["additional"]="autojump thefuck tldr"
    )
    
    log_info "Доступные категории пакетов:"
    for category in "${!package_categories[@]}"; do
        echo "  $category: ${package_categories[$category]}"
    done
    echo ""
    
    # Установка по категориям
    local total_installed=0
    local total_failed=0
    
    for category in "${!package_categories[@]}"; do
        log_info "Установка категории: $category"
        
        for package in ${package_categories[$category]}; do
            if safe_install_package "$package" "$package"; then
                ((total_installed++))
            else
                ((total_failed++))
                # Попытка установки альтернативного пакета
                case "$package" in
                    "bat")
                        safe_install_package "batcat" "bat (альтернативное имя)" && ((total_installed++)) || ((total_failed++))
                        ;;
                    "exa")
                        safe_install_package "eza" "exa (новая версия)" && ((total_installed++)) || ((total_failed++))
                        ;;
                    "fd-find")
                        safe_install_package "fd" "fd-find (альтернативное имя)" && ((total_installed++)) || ((total_failed++))
                        ;;
                esac
            fi
        done
        
        echo "Категория $category завершена"
        echo ""
    done
    
    # Специальная установка пакетов, которые могут потребовать дополнительных действий
    install_special_packages
    
    # Настройка альтернативных команд
    setup_command_alternatives
    
    log_success "Установка завершена. Установлено: $total_installed, Ошибок: $total_failed"
    
    if [[ $total_failed -gt 0 ]]; then
        log_warning "Некоторые пакеты не удалось установить. Проверьте лог: $LOG_FILE"
    fi
}

install_special_packages() {
    log_info "Установка специальных пакетов..."
    
    # Установка fzf из исходников если не доступен в репозиториях
    if ! command -v fzf &> /dev/null && ! package_exists "fzf"; then
        log_info "Установка fzf из исходников..."
        if command -v git &> /dev/null; then
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>&1 | tee -a "$LOG_FILE"
            ~/.fzf/install --all 2>&1 | tee -a "$LOG_FILE"
            log_success "fzf установлен из исходников"
        fi
    fi
    
    # Установка thefuck через pip если недоступен через apt
    if ! command -v thefuck &> /dev/null && ! package_exists "thefuck"; then
        if command -v pip3 &> /dev/null; then
            log_info "Установка thefuck через pip3..."
            pip3 install thefuck 2>&1 | tee -a "$LOG_FILE" && log_success "thefuck установлен через pip3"
        fi
    fi
    
    # Установка bat как batcat на старых системах
    if ! command -v bat &> /dev/null && command -v batcat &> /dev/null; then
        ln -sf /usr/bin/batcat /usr/local/bin/bat
        log_info "Создана ссылка bat -> batcat"
    fi
}

setup_command_alternatives() {
    log_info "Настройка альтернативных команд..."
    
    # Создание символических ссылок для удобства
    local alternatives=(
        "batcat:bat"
        "fdfind:fd"
        "eza:exa"
    )
    
    for alt in "${alternatives[@]}"; do
        IFS=':' read -r source target <<< "$alt"
        if command -v "$source" &> /dev/null && ! command -v "$target" &> /dev/null; then
            ln -sf "$(which "$source")" "/usr/local/bin/$target"
            log_info "Создана ссылка $target -> $source"
        fi
    done
}
# =============================================================================
# Функции диагностики и проверки
# =============================================================================

check_prerequisites() {
    log_info "Проверка предварительных требований..."
    
    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root"
        log_info "Запустите: sudo $0"
        exit 1
    fi
    
    # Проверка подключения к интернету
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "Отсутствует подключение к интернету"
        exit 1
    fi
    
    # Проверка дистрибутива
    if ! command -v apt &> /dev/null; then
        log_error "Данный скрипт поддерживает только Ubuntu/Debian"
        exit 1
    fi
    
    # Создание лог-файла
    touch "$LOG_FILE"
    exec 19>&2
    exec 2> >(tee -a "$LOG_FILE")
    
    log_success "Предварительные проверки пройдены"
}

# Функция проверки доступности пакета
package_exists() {
    local package="$1"
    apt-cache show "$package" &> /dev/null
}

# Функция безопасной установки пакета
safe_install_package() {
    local package="$1"
    local description="${2:-$package}"
    
    log_info "Проверка пакета: $package"
    
    # Проверка, установлен ли уже пакет
    if dpkg -l | grep -q "^ii  $package "; then
        log_info "$description уже установлен"
        return 0
    fi
    
    # Проверка доступности пакета
    if ! package_exists "$package"; then
        log_warning "Пакет $package недоступен в репозиториях"
        return 1
    fi
    
    log_info "Установка $description..."
    if apt install -y "$package" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "$description установлен"
        return 0
    else
        log_error "Не удалось установить $description"
        return 1
    fi
}

# =============================================================================
# Интерактивная установка с выбором
# =============================================================================

interactive_package_selection() {
    log_info "=== ИНТЕРАКТИВНЫЙ ВЫБОР ПАКЕТОВ ==="
    
    declare -A selected_packages
    
    echo "Выберите категории пакетов для установки:"
    echo "1) Все пакеты (рекомендуется)"
    echo "2) Только основные пакеты"
    echo "3) Выборочная установка"
    echo "4) Пропустить установку пакетов"
    
    local choice
    read -p "Ваш выбор [1-4]: " choice
    
    case "$choice" in
        1)
            install_terminal_components
            ;;
        2)
            install_essential_packages
            ;;
        3)
            custom_package_selection
            ;;
        4)
            log_info "Установка пакетов пропущена"
            ;;
        *)
            log_error "Неверный выбор, использую установку основных пакетов"
            install_essential_packages
            ;;
    esac
}

install_essential_packages() {
    log_info "Установка только основных пакетов..."
    
    local essential_packages=(
        "tmux"
        "vim"
        "curl"
        "wget"
        "htop"
        "tree"
        "git"
        "nano"
    )
    
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    for package in "${essential_packages[@]}"; do
        safe_install_package "$package"
    done
    
    log_success "Основные пакеты установлены"
}

custom_package_selection() {
    log_info "Выборочная установка пакетов..."
    
    declare -A package_categories=(
        ["Терминальные мультиплексоры"]="tmux screen"
        ["Файловые менеджеры"]="ranger mc"
        ["Поиск и фильтрация"]="fzf ripgrep fd-find"
        ["Просмотр файлов"]="bat exa tree"
        ["Системная информация"]="htop neofetch screenfetch"
        ["Разработка"]="git vim nano"
        ["Сеть"]="curl wget httpie"
        ["Развлечения"]="figlet lolcat cowsay fortune"
    )
    
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    for category in "${!package_categories[@]}"; do
        if yes_no_prompt "Установить $category (${package_categories[$category]})?"; then
            for package in ${package_categories[$category]}; do
                safe_install_package "$package"
            done
        fi
    done
}

# =============================================================================
# Настройка умного автодополнения и поиска
# =============================================================================

setup_smart_completion() {
    log_info "Настройка умного автодополнения команд..."
    
    # Создание директории для скриптов автодополнения
    mkdir -p "$TERMINAL_CONFIG_DIR/completion"
    
    # Улучшенный bash completion
    create_smart_bash_completion
    
    # Настройка fzf для интерактивного поиска
    setup_fzf_integration
    
    # Создание системы подсказок команд
    create_command_hints_system
    
    # Настройка истории команд с поиском
    setup_advanced_history
    
    log_success "Умное автодополнение настроено"
}

create_smart_bash_completion() {
    local completion_file="$TERMINAL_CONFIG_DIR/completion/smart_completion.sh"
    
    cat > "$completion_file" << 'EOF'
#!/bin/bash
# Умная система автодополнения команд

# =============================================================================
# Функции умного автодополнения
# =============================================================================

# Поиск команд с частичным совпадением
_smart_command_search() {
    local current_word="$1"
    local commands=""
    
    # Поиск в истории команд
    if [[ -f "$HOME/.bash_history" ]]; then
        commands+=$(grep -h "^$current_word" "$HOME/.bash_history" 2>/dev/null | sort -u)$'\n'
    fi
    
    # Поиск исполняемых файлов
    commands+=$(compgen -c "$current_word" | head -20)$'\n'
    
    # Поиск алиасов
    commands+=$(alias | grep "^$current_word" | cut -d'=' -f1 | sed 's/alias //')$'\n'
    
    # Поиск функций
    commands+=$(declare -F | grep "declare -f $current_word" | awk '{print $3}')$'\n'
    
    echo "$commands" | grep -v "^$" | sort -u
}

# Автодополнение файлов с предпросмотром
_smart_file_completion() {
    local current_word="$1"
    local base_dir="${current_word%/*}"
    
    if [[ "$current_word" == */* ]]; then
        base_dir="${current_word%/*}"
        [[ -d "$base_dir" ]] || return 1
    else
        base_dir="."
    fi
    
    # Используем fd для быстрого поиска файлов
    if command -v fd &> /dev/null; then
        fd -t f -t d . "$base_dir" 2>/dev/null | head -50
    else
        find "$base_dir" -maxdepth 2 \( -type f -o -type d \) 2>/dev/null | head -50
    fi
}

# Интеллектуальное автодополнение аргументов команд
_smart_args_completion() {
    local command="$1"
    local current_arg="$2"
    
    case "$command" in
        "cd"|"pushd"|"rmdir")
            # Только директории
            compgen -d "$current_arg"
            ;;
        "vim"|"nano"|"cat"|"less"|"head"|"tail")
            # Только файлы
            compgen -f "$current_arg"
            ;;
        "systemctl")
            # Сервисы systemd
            systemctl list-unit-files --type=service | awk '{print $1}' | grep "^$current_arg"
            ;;
        "git")
            # Git команды и ветки
            if [[ -d .git ]]; then
                git branch | sed 's/\* //' | grep "^$current_arg"
            fi
            git help -a | grep "^  $current_arg" | awk '{print $1}'
            ;;
        "docker")
            # Docker контейнеры и образы
            if command -v docker &> /dev/null; then
                docker ps -a --format "table {{.Names}}" | grep "^$current_arg"
            fi
            ;;
        "ssh")
            # SSH хосты из config
            if [[ -f "$HOME/.ssh/config" ]]; then
                grep "^Host " "$HOME/.ssh/config" | awk '{print $2}' | grep "^$current_arg"
            fi
            ;;
        *)
            # Стандартное автодополнение файлов
            compgen -f "$current_arg"
            ;;
    esac
}

# =============================================================================
# Интерактивное меню выбора
# =============================================================================

show_completion_menu() {
    local options=("$@")
    local num_options=${#options[@]}
    
    if [[ $num_options -eq 0 ]]; then
        return 1
    fi
    
    if [[ $num_options -eq 1 ]]; then
        echo "${options[0]}"
        return 0
    fi
    
    # Показ меню с номерами
    echo -e "\n\033[1;36m🔍 Найденные варианты:\033[0m"
    for i in "${!options[@]}"; do
        printf "\033[1;33m%2d)\033[0m %s\n" $((i+1)) "${options[i]}"
    done
    
    echo -e "\033[1;32mВыберите номер (1-$num_options) или нажмите Enter для отмены:\033[0m"
    
    local choice
    read -p "> " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le $num_options ]]; then
        echo "${options[$((choice-1))]}"
        return 0
    fi
    
    return 1
}

# =============================================================================
# Основная функция автодополнения
# =============================================================================

_smart_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local command="${COMP_WORDS[0]}"
    
    # Очистка предыдущих вариантов
    COMPREPLY=()
    
    # Если это первое слово (команда)
    if [[ $COMP_CWORD -eq 0 ]]; then
        local commands
        readarray -t commands < <(_smart_command_search "$cur")
        
        if [[ ${#commands[@]} -gt 10 ]]; then
            # Слишком много вариантов, показываем топ 10
            COMPREPLY=("${commands[@]:0:10}")
        else
            COMPREPLY=("${commands[@]}")
        fi
    else
        # Автодополнение аргументов
        local args
        readarray -t args < <(_smart_args_completion "$command" "$cur")
        COMPREPLY=("${args[@]}")
    fi
    
    # Если найден только один вариант, автоматически дополняем
    if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
        COMPREPLY[0]+=" "
    fi
}

# Привязка к TAB
complete -F _smart_completion -o default cd ls cat vim nano git docker systemctl ssh
EOF

    chmod +x "$completion_file"
    
    # Добавление в bashrc
    local bashrc_addition="
# Умное автодополнение команд
if [[ -f '$completion_file' ]]; then
    source '$completion_file'
fi"
    
    echo "$bashrc_addition" >> "$HOME/.bashrc"
}

setup_fzf_integration() {
    log_info "Настройка FZF для интерактивного поиска..."
    
    # Настройка fzf для истории команд (Ctrl+R)
    cat >> "$HOME/.bashrc" << 'EOF'

# =============================================================================
# FZF Integration для умного поиска
# =============================================================================

# Настройка внешнего вида fzf
export FZF_DEFAULT_OPTS="
    --height 40% 
    --layout=reverse 
    --border 
    --preview 'echo {} | head -500'
    --preview-window right:50%:wrap
    --bind 'ctrl-/:toggle-preview'
    --color='fg:#f8f8f2,bg:#282a36,hl:#bd93f9'
    --color='fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9'
    --color='info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6'
    --color='marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
"

# Интеграция с историей команд
if command -v fzf &> /dev/null; then
    # Ctrl+R для поиска в истории
    bind '"\C-r": "\C-u\C-afzf_history\C-m"'
    
    # Ctrl+T для поиска файлов
    bind '"\C-t": "\C-u\C-afzf_file_search\C-m"'
    
    # Alt+C для поиска директорий
    bind '"\ec": "\C-u\C-afzf_dir_search\C-m"'
fi

# Функция поиска в истории
fzf_history() {
    local selected
    selected=$(history | awk '{$1=""; print substr($0,2)}' | fzf --query="$READLINE_LINE")
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# Функция поиска файлов
fzf_file_search() {
    local selected
    if command -v fd &> /dev/null; then
        selected=$(fd -t f | fzf --preview 'bat --color=always --style=numbers {}' 2>/dev/null)
    else
        selected=$(find . -type f 2>/dev/null | fzf --preview 'head -100 {}')
    fi
    
    if [[ -n "$selected" ]]; then
        READLINE_LINE="${READLINE_LINE}$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# Функция поиска директорий
fzf_dir_search() {
    local selected
    if command -v fd &> /dev/null; then
        selected=$(fd -t d | fzf --preview 'ls -la {}')
    else
        selected=$(find . -type d 2>/dev/null | fzf --preview 'ls -la {}')
    fi
    
    if [[ -n "$selected" ]]; then
        cd "$selected"
        pwd
    fi
}
EOF
}

create_command_hints_system() {
    log_info "Создание системы подсказок команд..."
    
    local hints_file="$TERMINAL_CONFIG_DIR/command_hints.sh"
    
    cat > "$hints_file" << 'EOF'
#!/bin/bash
# Система подсказок команд в реальном времени

# =============================================================================
# База данных подсказок команд
# =============================================================================

declare -A COMMAND_HINTS=(
    # Основные команды
    ["ls"]="Опции: -la (подробно), -h (размеры), -t (по времени), -S (по размеру)"
    ["cd"]="Используйте: cd - (предыдущая папка), cd ~ (домой), cd .. (вверх)"
    ["cp"]="Опции: -r (рекурсивно), -i (подтверждение), -v (подробно)"
    ["mv"]="Опции: -i (подтверждение), -v (подробно)"
    ["rm"]="Опции: -r (рекурсивно), -i (подтверждение), -f (принудительно)"
    ["find"]="Примеры: find . -name '*.txt', find / -size +100M"
    ["grep"]="Опции: -r (рекурсивно), -i (игнорировать регистр), -n (номера строк)"
    
    # Системные команды
    ["ps"]="Опции: aux (все процессы), -ef (полная информация)"
    ["top"]="Горячие клавиши: q (выход), k (убить процесс), M (сортировка по памяти)"
    ["systemctl"]="Команды: start, stop, restart, status, enable, disable"
    ["journalctl"]="Опции: -f (следить), -u service (конкретный сервис)"
    
    # Сетевые команды
    ["ssh"]="Опции: -p port, -i keyfile, -L port_forward"
    ["scp"]="Синтаксис: scp file user@host:/path/"
    ["wget"]="Опции: -c (продолжить), -r (рекурсивно), -O filename"
    ["curl"]="Опции: -o file, -L (следовать редиректам), -H 'header'"
    
    # Git команды
    ["git"]="Основные: add, commit, push, pull, status, log, diff"
    ["git add"]="Опции: . (все), -A (все изменения), -p (интерактивно)"
    ["git commit"]="Опции: -m 'message', -a (все изменения), --amend"
    ["git push"]="Опции: origin branch, -u (установить upstream)"
    
    # Docker команды
    ["docker"]="Команды: run, ps, images, build, exec, logs"
    ["docker run"]="Опции: -d (фон), -it (интерактивно), -p port:port"
    ["docker ps"]="Опции: -a (все контейнеры), -q (только ID)"
    
    # Архивы
    ["tar"]="Создать: tar -czf archive.tar.gz files, Извлечь: tar -xzf archive.tar.gz"
    ["zip"]="Создать: zip -r archive.zip folder/"
    ["unzip"]="Опции: -l (список), -d dir (в папку)"
)

# Функция показа подсказки
show_command_hint() {
    local command="$1"
    
    # Проверяем точное совпадение
    if [[ -n "${COMMAND_HINTS[$command]:-}" ]]; then
        echo -e "\n\033[1;36m💡 Подсказка для '$command':\033[0m"
        echo -e "\033[1;33m${COMMAND_HINTS[$command]}\033[0m\n"
        return 0
    fi
    
    # Поиск частичных совпадений
    local matches=()
    for cmd in "${!COMMAND_HINTS[@]}"; do
        if [[ "$cmd" == *"$command"* ]]; then
            matches+=("$cmd")
        fi
    done
    
    if [[ ${#matches[@]} -gt 0 ]]; then
        echo -e "\n\033[1;36m💡 Найденные подсказки:\033[0m"
        for match in "${matches[@]}"; do
            echo -e "\033[1;32m$match:\033[0m ${COMMAND_HINTS[$match]}"
        done
        echo ""
    fi
}

# Функция автоматической подсказки при вводе
auto_hint() {
    local current_command
    current_command=$(history 1 | awk '{print $2}')
    
    if [[ -n "$current_command" && -n "${COMMAND_HINTS[$current_command]:-}" ]]; then
        echo -e "\033[2K\r\033[1;36m💡 ${COMMAND_HINTS[$current_command]}\033[0m"
    fi
}

# Команда для получения подсказки
hint() {
    if [[ $# -eq 0 ]]; then
        echo "Использование: hint <команда>"
        echo "Доступные команды с подсказками:"
        printf "%s\n" "${!COMMAND_HINTS[@]}" | sort | column -c 80
        return 0
    fi
    
    show_command_hint "$1"
}

# Функция поиска команд по описанию
search_commands() {
    local query="$1"
    echo -e "\033[1;36m🔍 Поиск команд по запросу '$query':\033[0m"
    
    for cmd in "${!COMMAND_HINTS[@]}"; do
        if [[ "${COMMAND_HINTS[$cmd]}" == *"$query"* ]]; then
            echo -e "\033[1;32m$cmd:\033[0m ${COMMAND_HINTS[$cmd]}"
        fi
    done
}

# Экспорт функций
export -f show_command_hint auto_hint hint search_commands
EOF

    chmod +x "$hints_file"
    
    # Добавление в bashrc
    echo "source '$hints_file'" >> "$HOME/.bashrc"
}

setup_advanced_history() {
    log_info "Настройка продвинутой системы истории команд..."
    
    cat >> "$HOME/.bashrc" << 'EOF'

# =============================================================================
# Продвинутая система истории команд
# =============================================================================

# Увеличиваем размер истории
export HISTSIZE=50000
export HISTFILESIZE=100000

# Настройки истории
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
export HISTIGNORE="ls:ll:la:cd:pwd:exit:clear:history:bg:fg:jobs"

# Добавляем команды в историю сразу
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Функция поиска в истории
hist() {
    if [[ $# -eq 0 ]]; then
        # Показать последние 20 команд
        history | tail -20
    else
        # Поиск по паттерну
        history | grep -i "$*"
    fi
}

# Функция для часто используемых команд
frequent() {
    echo -e "\033[1;36m📊 Наиболее часто используемые команды:\033[0m"
    history | awk '{print $4}' | sort | uniq -c | sort -rn | head -20 | \
    awk '{printf "\033[1;33m%3d:\033[0m %s\n", $1, $2}'
}

# Функция статистики истории
histstats() {
    echo -e "\033[1;36m📈 Статистика истории команд:\033[0m"
    echo "Всего команд: $(history | wc -l)"
    echo "Уникальных команд: $(history | awk '{print $4}' | sort -u | wc -l)"
    echo "Команд за сегодня: $(history | grep "$(date '+%Y-%m-%d')" | wc -l)"
    echo ""
    frequent
}

# Экспорт функций
export -f hist frequent histstats
EOF
}

# =============================================================================
# Настройка кликабельных директорий и файлов
# =============================================================================

setup_clickable_terminal() {
    log_info "Настройка кликабельного терминала с контекстными меню..."
    
    # Установка и настройка tmux для мышиной поддержки
    setup_tmux_mouse_support
    
    # Создание файлового браузера с мышиной поддержкой
    create_file_browser
    
    # Настройка контекстных меню
    setup_context_menus
    
    # Интеграция с ranger
    setup_ranger_integration
    
    log_success "Кликабельный терминал настроен"
}

setup_tmux_mouse_support() {
    log_info "Настройка tmux с поддержкой мыши..."
    
    local tmux_config="$HOME/.tmux.conf"
    
    cat > "$tmux_config" << 'EOF'
# =============================================================================
# Tmux Configuration with Mouse Support
# =============================================================================

# Основные настройки
set -g default-terminal "screen-256color"
set -g history-limit 50000
set -g display-time 4000
set -g status-interval 5
set -g focus-events on
set -sg escape-time 10

# Поддержка мыши
set -g mouse on

# Привязки клавиш
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Разделение окон
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Навигация между панелями
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Изменение размера панелей
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Копирование и вставка
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'

# Перезагрузка конфигурации
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# =============================================================================
# Статусная строка
# =============================================================================

set -g status-bg colour235
set -g status-fg colour136
set -g status-position bottom
set -g status-justify left
set -g status-left-length 20
set -g status-right-length 80

set -g status-left '#[fg=colour166,bold]#h #[fg=colour245]» '
set -g status-right '#[fg=colour245]#(whoami)@#h #[fg=colour166]%H:%M:%S #[fg=colour245]%Y-%m-%d'

# Настройки окон
setw -g window-status-current-format '#[fg=colour166,bold][#I:#W]'
setw -g window-status-format '#[fg=colour245][#I:#W]'

# =============================================================================
# Интеграция с файловым браузером
# =============================================================================

# Открытие файлового браузера
bind f new-window -n "Files" "bash -c 'source ~/.terminal-config/file_browser.sh; file_browser'"

# Быстрый доступ к системным директориям
bind g new-window -n "System" "bash -c 'cd /; exec bash'"
bind h new-window -n "Home" "bash -c 'cd ~; exec bash'"
bind v new-window -n "Var" "bash -c 'cd /var; exec bash'"
bind e new-window -n "Etc" "bash -c 'cd /etc; exec bash'"

# =============================================================================
# Скрипты и плагины
# =============================================================================

# Автоматический запуск скриптов при создании панели
set-hook -g after-new-session 'run-shell "echo Welcome to Enhanced Terminal!"'
EOF

    log_success "Tmux настроен с поддержкой мыши"
}

create_file_browser() {
    log_info "Создание интерактивного файлового браузера..."
    
    mkdir -p "$USER_TERMINAL_DIR"
    local browser_script="$USER_TERMINAL_DIR/file_browser.sh"
    
    cat > "$browser_script" << 'EOF'
#!/bin/bash
# Интерактивный файловый браузер с мышиной поддержкой

# =============================================================================
# Файловый браузер с контекстными меню
# =============================================================================

declare -g CURRENT_DIR="$(pwd)"
declare -g SELECTED_FILE=""
declare -g BROWSER_MODE="normal"  # normal, select, search

# Функция отображения файлов и директорий
show_files() {
    local dir="${1:-$CURRENT_DIR}"
    local page="${2:-0}"
    local items_per_page=20
    
    clear
    echo -e "\033[1;36m📁 Файловый браузер - $dir\033[0m"
    echo -e "\033[1;33m" + "=" * 80 + "\033[0m"
    
    # Навигационные подсказки
    echo -e "\033[1;32m🖱️  Клавиши:\033[0m q=выход, enter=открыть, space=выбрать, /=поиск, ?=помощь"
    echo -e "\033[1;32m📝 Мышь:\033[0m щелчок=выбор, двойной щелчок=открыть, правый щелчок=меню"
    echo ""
    
    # Показать родительскую директорию
    if [[ "$dir" != "/" ]]; then
        echo -e "\033[1;34m📁 [..] Родительская директория\033[0m"
    fi
    
    # Получить список файлов и директорий
    local items=()
    local counter=1
    
    # Директории сначала
    while IFS= read -r -d '' item; do
        if [[ -d "$item" ]]; then
            local basename=$(basename "$item")
            local size=$(du -sh "$item" 2>/dev/null | cut -f1 || echo "---")
            local permissions=$(ls -ld "$item" | awk '{print $1}')
            local modified=$(stat -c %y "$item" | cut -d' ' -f1)
            
            printf "\033[1;34m%2d) 📁 %-30s %8s %10s %s\033[0m\n" \
                "$counter" "$basename" "$size" "$permissions" "$modified"
            items+=("$item")
            ((counter++))
        fi
    done < <(find "$dir" -maxdepth 1 -type d -not -path "$dir" -print0 2>/dev/null | sort -z)
    
    # Затем файлы
    while IFS= read -r -d '' item; do
        if [[ -f "$item" ]]; then
            local basename=$(basename "$item")
            local size=$(du -sh "$item" 2>/dev/null | cut -f1 || echo "---")
            local permissions=$(ls -ld "$item" | awk '{print $1}')
            local modified=$(stat -c %y "$item" | cut -d' ' -f1)
            
            # Иконка в зависимости от типа файла
            local icon="📄"
            case "${basename,,}" in
                *.jpg|*.jpeg|*.png|*.gif|*.bmp) icon="🖼️" ;;
                *.mp3|*.wav|*.flac|*.ogg) icon="🎵" ;;
                *.mp4|*.avi|*.mkv|*.mov) icon="🎬" ;;
                *.pdf) icon="📕" ;;
                *.txt|*.md) icon="📝" ;;
                *.zip|*.tar|*.gz|*.rar) icon="📦" ;;
                *.sh|*.py|*.js|*.php) icon="⚙️" ;;
                *.conf|*.cfg|*.ini) icon="🔧" ;;
            esac
            
            printf "\033[1;37m%2d) %s %-30s %8s %10s %s\033[0m\n" \
                "$counter" "$icon" "$basename" "$size" "$permissions" "$modified"
            items+=("$item")
            ((counter++))
        fi
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
    
    echo ""
    echo -e "\033[1;33mВыберите элемент (номер или название):\033[0m"
    
    # Интерактивный выбор
    read -p "> " choice
    
    handle_selection "$choice" "${items[@]}"
}

# Обработка выбора пользователя
handle_selection() {
    local choice="$1"
    shift
    local items=("$@")
    
    case "$choice" in
        "q"|"Q"|"quit"|"exit")
            echo "До свидания!"
            return 1
            ;;
        "..")
            CURRENT_DIR=$(dirname "$CURRENT_DIR")
            show_files "$CURRENT_DIR"
            ;;
        "/")
            search_files
            ;;
        "?"|"help")
            show_help
            ;;
        "")
            show_files "$CURRENT_DIR"
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                # Выбор по номеру
                local index=$((choice - 1))
                if [[ $index -ge 0 && $index -lt ${#items[@]} ]]; then
                    open_item "${items[$index]}"
                else
                    echo "Неверный номер"
                    sleep 1
                    show_files "$CURRENT_DIR"
                fi
            else
                # Поиск по имени
                local found=""
                for item in "${items[@]}"; do
                    if [[ "$(basename "$item")" == *"$choice"* ]]; then
                        found="$item"
                        break
                    fi
                done
                
                if [[ -n "$found" ]]; then
                    open_item "$found"
                else
                    echo "Файл или директория не найдены"
                    sleep 1
                    show_files "$CURRENT_DIR"
                fi
            fi
            ;;
    esac
}

# Открытие файла или директории
open_item() {
    local item="$1"
    
    if [[ -d "$item" ]]; then
        CURRENT_DIR="$item"
        show_files "$CURRENT_DIR"
    elif [[ -f "$item" ]]; then
        show_file_menu "$item"
    fi
}

# Контекстное меню для файла
show_file_menu() {
    local file="$1"
    local filename=$(basename "$file")
    
    clear
    echo -e "\033[1;36m📄 Файл: $filename\033[0m"
    echo -e "\033[1;33m" + "=" * 50 + "\033[0m"
    
    # Информация о файле
    local size=$(du -sh "$file" | cut -f1)
    local permissions=$(ls -ld "$file" | awk '{print $1}')
    local modified=$(stat -c %y "$file" | cut -d' ' -f1,2)
    local mime_type=$(file -b --mime-type "$file" 2>/dev/null || echo "unknown")
    
    echo -e "📏 Размер: $size"
    echo -e "🔐 Права: $permissions"
    echo -e "📅 Изменен: $modified"
    echo -e "🏷️  Тип: $mime_type"
    echo ""
    
    # Меню действий
    echo -e "\033[1;32mДоступные действия:\033[0m"
    echo "1) 👁️  Просмотреть содержимое"
    echo "2) ✏️  Редактировать"
    echo "3) 📋 Копировать"
    echo "4) ✂️  Переместить"
    echo "5) 🗑️  Удалить"
    echo "6) 📊 Подробная информация"
    echo "7) 🔗 Создать ссылку"
    echo "8) 🔒 Изменить права"
    echo "9) 📤 Отправить по сети"
    echo "0) ⬅️  Назад"
    
    echo ""
    read -p "Выберите действие: " action
    
    case "$action" in
        1) view_file "$file" ;;
        2) edit_file "$file" ;;
        3) copy_file "$file" ;;
        4) move_file "$file" ;;
        5) delete_file "$file" ;;
        6) file_info "$file" ;;
        7) create_link "$file" ;;
        8) change_permissions "$file" ;;
        9) send_file "$file" ;;
        0|"") show_files "$CURRENT_DIR" ;;
        *) 
            echo "Неверный выбор"
            sleep 1
            show_file_menu "$file"
            ;;
    esac
}

# Функции работы с файлами
view_file() {
    local file="$1"
    
    if command -v bat &> /dev/null; then
        bat --paging=always "$file"
    else
        less "$file"
    fi
    
    read -p "Нажмите Enter для продолжения..."
    show_file_menu "$file"
}

edit_file() {
    local file="$1"
    
    if [[ -w "$file" ]]; then
        "${EDITOR:-vim}" "$file"
    else
        echo "Нет прав на запись. Открыть только для чтения? (y/n)"
        read -p "> " confirm
        if [[ "$confirm" == "y" ]]; then
            "${EDITOR:-vim}" -R "$file"
        fi
    fi
    
    show_file_menu "$file"
}

copy_file() {
    local file="$1"
    
    echo "Введите путь назначения:"
    read -p "> " destination
    
    if [[ -n "$destination" ]]; then
        if cp "$file" "$destination"; then
            echo "Файл скопирован в $destination"
        else
            echo "Ошибка копирования"
        fi
    fi
    
    read -p "Нажмите Enter для продолжения..."
    show_file_menu "$file"
}

delete_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    echo -e "\033[1;31m⚠️  Вы уверены, что хотите удалить '$filename'? (yes/no)\033[0m"
    read -p "> " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        if rm "$file"; then
            echo "Файл удален"
            read -p "Нажмите Enter для продолжения..."
            show_files "$CURRENT_DIR"
        else
            echo "Ошибка удаления"
            read -p "Нажмите Enter для продолжения..."
            show_file_menu "$file"
        fi
    else
        show_file_menu "$file"
    fi
}

file_info() {
    local file="$1"
    
    clear
    echo -e "\033[1;36m📊 Подробная информация о файле\033[0m"
    echo -e "\033[1;33m" + "=" * 50 + "\033[0m"
    
    ls -la "$file"
    echo ""
    file "$file"
    echo ""
    
    if command -v stat &> /dev/null; then
        stat "$file"
    fi
    
    read -p "Нажмите Enter для продолжения..."
    show_file_menu "$file"
}

# Функция поиска файлов
search_files() {
    clear
    echo -e "\033[1;36m🔍 Поиск файлов\033[0m"
    echo -e "\033[1;33m" + "=" * 50 + "\033[0m"
    
    echo "Введите имя файла или паттерн для поиска:"
    read -p "> " pattern
    
    if [[ -n "$pattern" ]]; then
        echo -e "\n\033[1;32mРезультаты поиска:\033[0m"
        
        local results=()
        while IFS= read -r -d '' result; do
            results+=("$result")
        done < <(find "$CURRENT_DIR" -name "*$pattern*" -print0 2>/dev/null)
        
        if [[ ${#results[@]} -eq 0 ]]; then
            echo "Ничего не найдено"
        else
            for i in "${!results[@]}"; do
                local item="${results[i]}"
                local basename=$(basename "$item")
                local icon="📄"
                [[ -d "$item" ]] && icon="📁"
                
                printf "%2d) %s %s\n" $((i+1)) "$icon" "$basename"
            done
            
            echo ""
            echo "Выберите файл (номер) или нажмите Enter для возврата:"
            read -p "> " choice
            
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                local index=$((choice - 1))
                if [[ $index -ge 0 && $index -lt ${#results[@]} ]]; then
                    open_item "${results[$index]}"
                fi
            fi
        fi
    fi
    
    read -p "Нажмите Enter для продолжения..."
    show_files "$CURRENT_DIR"
}

# Справка
show_help() {
    clear
    echo -e "\033[1;36m❓ Справка по файловому браузеру\033[0m"
    echo -e "\033[1;33m" + "=" * 50 + "\033[0m"
    
    cat << 'HELP'
🖱️  УПРАВЛЕНИЕ МЫШЬЮ:
   • Одинарный щелчок - выбор элемента
   • Двойной щелчок - открытие файла/папки
   • Правый щелчок - контекстное меню
   • Колесо мыши - прокрутка

⌨️  УПРАВЛЕНИЕ КЛАВИАТУРОЙ:
   • q - выход из браузера
   • Enter - открыть выбранный элемент
   • / - поиск файлов
   • ? - эта справка
   • .. - подняться на уровень вверх
   • Номер - выбрать элемент по номеру

📁 НАВИГАЦИЯ:
   • Используйте номера для быстрого выбора
   • Начните вводить имя файла для поиска
   • Используйте .. для возврата в родительскую папку

📄 РАБОТА С ФАЙЛАМИ:
   • Просмотр содержимого
   • Редактирование
   • Копирование и перемещение
   • Удаление (с подтверждением)
   • Изменение прав доступа

🔍 ПОИСК:
   • Нажмите / для поиска
   • Введите часть имени файла
   • Поиск ведется в текущей папке и подпапках
HELP

    read -p "Нажмите Enter для продолжения..."
    show_files "$CURRENT_DIR"
}

# Основная функция запуска браузера
file_browser() {
    # Включение мыши в терминале если возможно
    if [[ "$TERM" == *"xterm"* ]] || [[ "$TERM" == *"screen"* ]]; then
        printf '\e[?1000h'  # Включить отчеты о нажатиях мыши
        printf '\e[?1002h'  # Включить отчеты о движении мыши с нажатой кнопкой
        printf '\e[?1015h'  # Включить режим urxvt
        printf '\e[?1006h'  # Включить режим SGR
    fi
    
    # Установка обработчика выхода
    trap 'printf "\e[?1000l\e[?1002l\e[?1015l\e[?1006l"; clear' EXIT
    
    # Запуск браузера
    show_files "$CURRENT_DIR"
}

# Экспорт функций
export -f file_browser show_files handle_selection open_item show_file_menu
export -f view_file edit_file copy_file delete_file file_info search_files show_help
EOF

    chmod +x "$browser_script"
    
    # Создание команды для запуска браузера
    echo "alias fb='source ~/.terminal-config/file_browser.sh; file_browser'" >> "$HOME/.bashrc"
    
    log_success "Файловый браузер создан (команда: fb)"
}

setup_context_menus() {
    log_info "Настройка контекстных меню..."
    
    local context_menu_script="$USER_TERMINAL_DIR/context_menu.sh"
    
    cat > "$context_menu_script" << 'EOF'
#!/bin/bash
# Система контекстных меню для терминала

# =============================================================================
# Контекстное меню для файлов и директорий
# =============================================================================

show_context_menu() {
    local item="$1"
    local x="${2:-10}"
    local y="${3:-5}"
    
    # Определение типа элемента
    if [[ -d "$item" ]]; then
        show_directory_menu "$item" "$x" "$y"
    elif [[ -f "$item" ]]; then
        show_file_menu "$item" "$x" "$y"
    fi
}

show_directory_menu() {
    local dir="$1"
    local x="$2"
    local y="$3"
    
    # Создание временного файла для меню
    local menu_file="/tmp/context_menu_$$"
    
    cat > "$menu_file" << MENU
📁 $(basename "$dir")
─────────────────
📂 Открыть
📋 Копировать путь
✂️  Вырезать
📁 Создать папку
📄 Создать файл
🔍 Поиск в папке
📊 Размер папки
🗑️  Удалить
🔧 Свойства
───────────────── 
❌ Закрыть
MENU

    # Показ меню в позиции курсора
    show_popup_menu "$menu_file" "$x" "$y"
    
    # Обработка выбора
    local choice
    read -p "Выбор: " choice
    
    case "$choice" in
        1) cd "$dir" ;;
        2) echo -n "$dir" | xclip -selection clipboard 2>/dev/null || echo "Путь: $dir" ;;
        3) cut_item="$dir" ;;
        4) create_directory "$dir" ;;
        5) create_file "$dir" ;;
        6) search_in_directory "$dir" ;;
        7) directory_size "$dir" ;;
        8) delete_directory "$dir" ;;
        9) directory_properties "$dir" ;;
        *) ;;
    esac
    
    rm -f "$menu_file"
}

show_file_menu() {
    local file="$1"
    local x="$2"
    local y="$3"
    
    local menu_file="/tmp/context_menu_$$"
    
    # Определение иконки по типу файла
    local icon="📄"
    case "${file,,}" in
        *.jpg|*.jpeg|*.png|*.gif) icon="🖼️" ;;
        *.mp3|*.wav|*.flac) icon="🎵" ;;
        *.mp4|*.avi|*.mkv) icon="🎬" ;;
        *.pdf) icon="📕" ;;
        *.txt|*.md) icon="📝" ;;
        *.zip|*.tar|*.gz) icon="📦" ;;
        *.sh|*.py|*.js) icon="⚙️" ;;
    esac
    
    cat > "$menu_file" << MENU
$icon $(basename "$file")
─────────────────
👁️  Открыть
✏️  Редактировать
📋 Копировать
✂️  Вырезать
📤 Отправить
🔗 Создать ссылку
🔒 Права доступа
📊 Свойства
🗑️  Удалить
─────────────────
❌ Закрыть
MENU

    show_popup_menu "$menu_file" "$x" "$y"
    
    local choice
    read -p "Выбор: " choice
    
    case "$choice" in
        1) open_file "$file" ;;
        2) edit_file "$file" ;;
        3) copy_file "$file" ;;
        4) cut_item="$file" ;;
        5) send_file "$file" ;;
        6) create_link "$file" ;;
        7) change_permissions "$file" ;;
        8) file_properties "$file" ;;
        9) delete_file "$file" ;;
        *) ;;
    esac
    
    rm -f "$menu_file"
}

show_popup_menu() {
    local menu_file="$1"
    local x="$2"
    local y="$3"
    
    # Очистка экрана и позиционирование
    tput clear
    tput cup "$y" "$x"
    
    # Рамка меню
    echo -e "\033[1;36m┌─────────────────────┐\033[0m"
    
    local line_num=1
    while IFS= read -r line; do
        tput cup $((y + line_num)) "$x"
        echo -e "\033[1;36m│\033[0m $line \033[1;36m│\033[0m"
        ((line_num++))
    done < "$menu_file"
    
    tput cup $((y + line_num)) "$x"
    echo -e "\033[1;36m└─────────────────────┘\033[0m"
    
    tput cup $((y + line_num + 1)) "$x"
}

# Функции действий
create_directory() {
    local parent_dir="$1"
    echo -n "Имя новой папки: "
    read -r dirname
    if [[ -n "$dirname" ]]; then
        mkdir -p "$parent_dir/$dirname"
        echo "Папка создана: $parent_dir/$dirname"
    fi
}

create_file() {
    local parent_dir="$1"
    echo -n "Имя нового файла: "
    read -r filename
    if [[ -n "$filename" ]]; then
        touch "$parent_dir/$filename"
        echo "Файл создан: $parent_dir/$filename"
    fi
}

directory_size() {
    local dir="$1"
    echo "Подсчет размера папки..."
    du -sh "$dir"
}

# Экспорт функций
export -f show_context_menu show_directory_menu show_file_menu show_popup_menu
export -f create_directory create_file directory_size
EOF

    chmod +x "$context_menu_script"
    echo "source '$context_menu_script'" >> "$HOME/.bashrc"
}

setup_ranger_integration() {
    log_info "Настройка Ranger с расширенной функциональностью..."
    
    local ranger_config_dir="$HOME/.config/ranger"
    mkdir -p "$ranger_config_dir"
    
    # Основная конфигурация ranger
    cat > "$ranger_config_dir/rc.conf" << 'EOF'
# Ranger Configuration with Advanced Features

# Основные настройки
set column_ratios 1,3,4
set hidden_filter ^\.|\.(?:pyc|pyo|bak|swp)$|^lost\+found$|^__(pycache)__$
set show_hidden false
set confirm_on_delete multiple
set use_preview_script true
set automatically_count_files true
set open_all_images true
set vcs_aware false
set vcs_backend_git enabled
set vcs_backend_hg disabled
set vcs_backend_bzr disabled
set vcs_backend_svn disabled
set preview_images true
set preview_images_method w3m
set unicode_ellipsis false
set show_selection_in_titlebar true
set update_title false
set update_tmux_title true
set shorten_title 3
set hostname_in_titlebar true
set tilde_in_titlebar false
set max_history_size 20
set max_console_history_size 50
set scroll_offset 8
set flushinput true
set padding_right true
set autosave_bookmarks true
set save_backtick_bookmark true
set autoupdate_cumulative_size false
set show_cursor false
set sort natural
set sort_reverse false
set sort_case_insensitive true
set sort_directories_first true
set sort_unicode false
set xterm_alt_key false
set mouse_enabled true

# Привязки клавиш
map yp yank path
map yd yank dir
map yn yank name
map y. yank name_without_extension

# Пользовательские команды
map cw console rename%space
map cW eval fm.execute_console("bulkrename") if fm.thisdir.marked_items else fm.open_console("rename ")
map A  eval fm.open_console('rename ' + fm.thisfile.relative_path.replace("%", "%%"))
map I  eval fm.open_console('rename ' + fm.thisfile.relative_path.replace("%", "%%"), position=7)

# Извлечение архивов
map ,x shell atool --extract --subdir %f
map ,z shell tar -czf %f.tar.gz %s
map ,t shell tar -czf ../$(basename %d).tar.gz %s

# Git интеграция
map ,g shell git add %s
map ,G shell git commit -m "Updated %s"
map ,p shell git push

# Быстрый доступ к редакторам
map E shell vim %f
map ,e shell code %f
map ,n shell nano %f

# Поиск и фильтрация
map F console find%space
map / console search%space
map n search_next
map N search_next forward=False
map ct search_next order=tag
map cs search_next order=size
map ci search_next order=mimetype
map cc search_next order=ctime
map cm search_next order=mtime
map ca search_next order=atime

# Закладки
map `<any> enter_bookmark %any
map '<any> enter_bookmark %any
map m<any>  set_bookmark %any
map um<any> unset_bookmark %any

# Быстрые переходы
map gh cd ~
map ge cd /etc
map gv cd /var
map gm cd /media
map gM cd /mnt
map gs cd /srv
map go cd /opt
map gr cd /
map gR eval fm.cd(ranger.RANGERDIR)
map g? cd /usr/share/doc/ranger

# Вкладки
map <C-n>     tab_new
map <C-w>     tab_close
map <TAB>     tab_move 1
map <S-TAB>   tab_move -1
map <A-Right> tab_move 1
map <A-Left>  tab_move -1
map gt        tab_move 1
map gT        tab_move -1
map gn        tab_new
map gc        tab_close
map uq        tab_restore
map <a-1>     tab_open 1
map <a-2>     tab_open 2
map <a-3>     tab_open 3
map <a-4>     tab_open 4
map <a-5>     tab_open 5
map <a-6>     tab_open 6
map <a-7>     tab_open 7
map <a-8>     tab_open 8
map <a-9>     tab_open 9

# Действия с файлами
map DD shell mv %s ~/.Trash/
map dD shell rm -rf %s
map ,d shell mkdir -p %s-backup && cp -r %s %s-backup
map ,D shell diff -u %f %s

# Системная информация
map ,i shell file %f | less
map ,I shell mediainfo %f | less
map ,s shell stat %f | less

# Сеть
map ,w shell wget -P %d %s
map ,W shell wget -P %d -r -l 3 %s
map ,u shell curl -O %s

# Изображения
map ,r shell convert %f -rotate 90 %f
map ,R shell convert %f -rotate -90 %f
map ,f shell convert %f -flop %f
map ,F shell convert %f -flip %f

# Мультимедиа
map ,p shell mpv %f
map ,P shell mpv --shuffle %s
map ,m shell mplayer %f
EOF

    # Конфигурация приложений по умолчанию
    cat > "$ranger_config_dir/rifle.conf" << 'EOF'
# Rifle Configuration - приложения по умолчанию

# Текстовые файлы
mime ^text, label editor = vim "$@"
mime ^text, label pager  = less "$@"
!mime ^text, label editor, ext xml|json|csv|tex|py|pl|rb|js|sh|php = vim "$@"

# Изображения
mime ^image, has feh, X, flag f = feh -- "$@"
mime ^image, has eog, X, flag f = eog -- "$@"
mime ^image, has gimp, X, flag f = gimp -- "$@"

# Видео
mime ^video, has mpv, X, flag f = mpv -- "$@"
mime ^video, has vlc, X, flag f = vlc -- "$@"

# Аудио
mime ^audio, has mpv, X, flag f = mpv -- "$@"
mime ^audio, has audacious, X, flag f = audacious -- "$@"

# PDF
ext pdf, has zathura, X, flag f = zathura -- "$@"
ext pdf, has evince, X, flag f = evince -- "$@"

# Архивы
ext tar|gz|bz2|xz, has atool = atool --extract --subdir "$@"
ext zip, has unzip = unzip -l "$@" | less
ext rar, has unrar = unrar l "$@" | less

# Документы
ext doc|docx|odt, has libreoffice, X, flag f = libreoffice "$@"
ext xls|xlsx|ods, has libreoffice, X, flag f = libreoffice "$@"

# Веб-файлы
ext html|htm, has firefox, X, flag f = firefox "$@"

# Исполняемые файлы
mime application/x-executable = "$1"
EOF

    # Команды для ranger
    cat > "$ranger_config_dir/commands.py" << 'EOF'
from ranger.api.commands import Command
import os

class fzf_select(Command):
    """
    :fzf_select
    Найти файл с помощью fzf и перейти к нему.
    """
    def execute(self):
        import subprocess
        command = "find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune -o -type f -print 2> /dev/null | cut -b3- | fzf +m"
        fzf = self.fm.execute_command(command, universal_newlines=True, stdout=subprocess.PIPE)
        stdout, stderr = fzf.communicate()
        if fzf.returncode == 0:
            fzf_file = os.path.abspath(stdout.rstrip('\n'))
            self.fm.select_file(fzf_file)

class fzf_locate(Command):
    """
    :fzf_locate
    Найти файл с помощью locate и fzf, затем перейти к нему.
    """
    def execute(self):
        import subprocess
        command = "locate home media | fzf -e -i"
        fzf = self.fm.execute_command(command, universal_newlines=True, stdout=subprocess.PIPE)
        stdout, stderr = fzf.communicate()
        if fzf.returncode == 0:
            fzf_file = os.path.abspath(stdout.rstrip('\n'))
            self.fm.select_file(fzf_file)

class compress(Command):
    def execute(self):
        """ Compress marked files to current directory """
        cwd = self.fm.thisdir
        marked_files = cwd.get_selection()

        if not marked_files:
            return

        def refresh(_):
            cwd = self.fm.get_directory(original_path)
            cwd.load_content()

        original_path = cwd.path
        parts = self.line.split()
        au_flags = parts[1:]

        descr = "compressing files in: " + os.path.basename(parts[1])
        obj = CommandLoader(args=['apack'] + au_flags + \
                [os.path.relpath(f.path, cwd.path) for f in marked_files], descr=descr)

        obj.signal_bind('after', refresh)
        self.fm.loader.add(obj)

class extracthere(Command):
    def execute(self):
        """ Extract copied files to current directory """
        copied_files = tuple(self.fm.copy_buffer)

        if not copied_files:
            return

        def refresh(_):
            cwd = self.fm.get_directory(original_path)
            cwd.load_content()

        one_file = copied_files[0]
        cwd = self.fm.thisdir
        original_path = cwd.path
        au_flags = ['-X', cwd.path]
        au_flags += self.line.split()[1:]
        au_flags += ['-e']

        self.fm.copy_buffer.clear()
        self.fm.cut_buffer = False
        if len(copied_files) == 1:
            descr = "extracting: " + os.path.basename(one_file.path)
        else:
            descr = "extracting files from: " + os.path.basename(one_file.dirname)
        obj = CommandLoader(args=['aunpack'] + au_flags \
                + [f.path for f in copied_files], descr=descr)

        obj.signal_bind('after', refresh)
        self.fm.loader.add(obj)
EOF

    log_success "Ranger настроен с расширенной функциональностью"
}

# =============================================================================
# Настройка операционной системы
# =============================================================================

setup_system_customization() {
    log_info "Настройка операционной системы..."
    
    # Настройка приветственных сообщений
    setup_welcome_messages
    
    # Настройка MOTD (Message of the Day)
    setup_motd
    
    # Настройка загрузчика GRUB
    setup_grub_customization
    
    # Настройка системных алиасов
    setup_system_aliases
    
    # Настройка автозапуска
    setup_autostart
    
    log_success "Операционная система настроена"
}

setup_welcome_messages() {
    log_info "Настройка приветственных сообщений..."
    
    # Создание скрипта приветствия
    local welcome_script="/usr/local/bin/welcome.sh"
    
    cat > "$welcome_script" << 'EOF'
#!/bin/bash
# Система приветственных сообщений

# =============================================================================
# Функция отображения системной информации
# =============================================================================

show_system_banner() {
    local hostname=$(hostname)
    local uptime=$(uptime -p | sed 's/up //')
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local users=$(who | wc -l)
    local date=$(date '+%A, %d %B %Y - %H:%M:%S')
    
    # ASCII арт с именем хоста
    if command -v figlet &> /dev/null; then
        figlet -f small "$hostname" | lolcat 2>/dev/null || figlet -f small "$hostname"
    else
        echo "=== $hostname ==="
    fi
    
    echo ""
    echo -e "\033[1;36m🖥️  Система:\033[0m $(lsb_release -d | cut -f2) ($(uname -m))"
    echo -e "\033[1;36m⏰ Время:\033[0m $date"
    echo -e "\033[1;36m⚡ Работает:\033[0m $uptime"
    echo -e "\033[1;36m📊 Загрузка:\033[0m $load"
    echo -e "\033[1;36m👥 Пользователей:\033[0m $users"
    
    # Информация о дисках
    echo -e "\033[1;36m💾 Диски:\033[0m"
    df -h / /home 2>/dev/null | grep -v "Filesystem" | while read line; do
        echo "   $line"
    done
    
    # Информация о памяти
    local mem_info=$(free -h | grep "Mem:")
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_total=$(echo $mem_info | awk '{print $2}')
    echo -e "\033[1;36m🧠 Память:\033[0m $mem_used из $mem_total используется"
    
    # Сетевые интерфейсы
    echo -e "\033[1;36m🌐 Сеть:\033[0m"
    ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "   " $2}' | head -3
    
    echo ""
}

show_tips() {
    local tips=(
        "💡 Используйте 'fb' для запуска файлового браузера"
        "💡 Нажмите Ctrl+R для поиска в истории команд"
        "💡 Команда 'hint <команда>' покажет подсказки"
        "💡 Используйте 'tmux' для многооконного терминала"
        "💡 Команда 'frequent' покажет часто используемые команды"
        "💡 Alt+C для быстрого поиска директорий"
        "💡 Ctrl+T для поиска файлов через fzf"
        "💡 Команда 'ranger' запустит файловый менеджер"
        "💡 Используйте 'weather' для прогноза погоды"
        "💡 Команда 'sysinfo' покажет информацию о системе"
    )
    
    # Случайная подсказка
    local random_tip=${tips[$RANDOM % ${#tips[@]}]}
    echo -e "\033[1;33m$random_tip\033[0m"
    echo ""
}

show_fortune() {
    if command -v fortune &> /dev/null && command -v cowsay &> /dev/null; then
        echo -e "\033[1;32m"
        fortune -s | cowsay -f tux 2>/dev/null || fortune -s
        echo -e "\033[0m"
    elif command -v fortune &> /dev/null; then
        echo -e "\033[1;32m$(fortune -s)\033[0m"
        echo ""
    fi
}

# Проверка обновлений
check_updates() {
    if command -v apt &> /dev/null; then
        local updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
        if [[ "$updates" -gt 0 ]]; then
            echo -e "\033[1;31m📦 Доступно обновлений: $updates\033[0m"
            echo -e "\033[1;33m   Запустите 'sudo apt update && sudo apt upgrade' для обновления\033[0m"
            echo ""
        fi
    fi
}

# Проверка важных сервисов
check_services() {
    local important_services=("ssh" "networking" "cron")
    local failed_services=()
    
    for service in "${important_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            continue
        else
            if systemctl list-unit-files --type=service | grep -q "^$service.service"; then
                failed_services+=("$service")
            fi
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        echo -e "\033[1;31m⚠️  Неактивные сервисы: ${failed_services[*]}\033[0m"
        echo ""
    fi
}

# Главная функция
main() {
    clear
    show_system_banner
    show_tips
    show_fortune
    check_updates
    check_services
    
    # Дополнительная информация для администратора
    if [[ $EUID -eq 0 ]]; then
        echo -e "\033[1;31m⚠️  Вы вошли как ROOT. Будьте осторожны!\033[0m"
        echo ""
    fi
}

# Запуск только если скрипт вызывается напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

    chmod +x "$welcome_script"
    
    # Добавление в bashrc для автоматического запуска
    echo "" >> "$HOME/.bashrc"
    echo "# Приветственное сообщение" >> "$HOME/.bashrc"
    echo "if [[ \$- == *i* ]] && [[ -z \"\$WELCOME_SHOWN\" ]]; then" >> "$HOME/.bashrc"
    echo "    export WELCOME_SHOWN=1" >> "$HOME/.bashrc"
    echo "    /usr/local/bin/welcome.sh" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
    
    log_success "Приветственные сообщения настроены"
}

setup_motd() {
    log_info "Настройка MOTD (Message of the Day)..."
    
    # Отключение стандартных MOTD сообщений
    sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
    
    # Создание кастомного MOTD
    local motd_script="/etc/update-motd.d/01-custom"
    
    cat > "$motd_script" << 'EOF'
#!/bin/bash
# Кастомное MOTD сообщение

printf "\n"
printf "\033[1;36m"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║                    🚀 ДОБРО ПОЖАЛОВАТЬ! 🚀                    ║\n"
printf "╚══════════════════════════════════════════════════════════════╝\n"
printf "\033[0m"

# Системная информация
HOSTNAME=$(hostname)
UPTIME=$(uptime -p | sed 's/up //')
MEMORY=$(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3,$2,$3*100/$2}')
DISK=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

printf "\033[1;32m"
printf "🖥️  Хост: %-20s ⏰ Работает: %s\n" "$HOSTNAME" "$UPTIME"
printf "🧠 Память: %-20s 💾 Диск: %s\n" "$MEMORY" "$DISK"
printf "📊 Загрузка: %s\n" "$LOAD"
printf "\033[0m"

# Быстрые команды
printf "\n\033[1;33m"
printf "💡 Быстрые команды:\n"
printf "   fb      - Файловый браузер\n"
printf "   sysinfo - Информация о системе\n"
printf "   htop    - Мониторинг процессов\n"
printf "   ranger  - Файловый менеджер\n"
printf "\033[0m\n"
EOF

    chmod +x "$motd_script"
    
    log_success "MOTD настроен"
}

setup_grub_customization() {
    log_info "Настройка кастомизации загрузчика GRUB..."
    
    if ! yes_no_prompt "Настроить кастомизацию GRUB?"; then
        return 0
    fi
    
    # Резервная копия конфигурации GRUB
    cp /etc/default/grub "/etc/default/grub.backup-$(date +%Y%m%d)"
    
    # Настройки GRUB
    cat >> "/etc/default/grub" << 'EOF'

# =============================================================================
# Кастомные настройки GRUB
# =============================================================================

# Тайм-аут меню загрузки (в секундах)
GRUB_TIMEOUT=10

# Показывать меню даже если только одна ОС
GRUB_TIMEOUT_STYLE=menu

# Разрешение загрузочного экрана
GRUB_GFXMODE=1024x768

# Цветовая тема
GRUB_COLOR_NORMAL="light-gray/black"
GRUB_COLOR_HIGHLIGHT="white/blue"

# Фоновое изображение (если есть)
#GRUB_BACKGROUND="/boot/grub/background.png"

# Дополнительные параметры ядра
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"

# Включить сохранение последнего выбора
GRUB_SAVEDEFAULT=true
GRUB_DEFAULT=saved

# Отключить submenu для recovery опций
GRUB_DISABLE_SUBMENU=y
EOF

    # Создание кастомной темы GRUB
    local grub_themes_dir="/boot/grub/themes/custom"
    mkdir -p "$grub_themes_dir"
    
    cat > "$grub_themes_dir/theme.txt" << 'EOF'
# Кастомная тема GRUB

# Общие настройки
desktop-image: "background.png"
desktop-color: "#000000"
terminal-font: "Unifont Regular 16"

# Настройки меню
+ boot_menu {
    left = 20%
    top = 30%
    width = 60%
    height = 40%
    item_font = "Unifont Regular 16"
    item_color = "#ffffff"
    selected_item_color = "#000000"
    selected_item_background = "#ffffff"
    item_height = 32
    item_padding = 8
    item_spacing = 4
    scrollbar = true
    scrollbar_width = 20
    scrollbar_thumb = "#ffffff"
}

# Заголовок
+ label {
    id = "__timeout__"
    text = "Загрузка через %d секунд"
    font = "Unifont Regular 16"
    color = "#ffffff"
    left = 50%-100
    top = 20%
}

# Информация о системе
+ label {
    text = "🚀 Enhanced Linux Server"
    font = "Unifont Regular 20"
    color = "#00ff00"
    left = 50%-150
    top = 10%
}
EOF

    # Создание простого фона для GRUB
    if command -v convert &> /dev/null; then
        convert -size 1024x768 xc:'#001122' \
                -gravity center -pointsize 72 -fill white \
                -annotate 0 "Enhanced\nLinux Server" \
                "$grub_themes_dir/background.png" 2>/dev/null || true
    fi
    
    # Применение темы
    echo 'GRUB_THEME="/boot/grub/themes/custom/theme.txt"' >> /etc/default/grub
    
    # Обновление GRUB
    if yes_no_prompt "Применить изменения GRUB сейчас?"; then
        update-grub
        log_success "GRUB обновлен с новыми настройками"
    else
        log_info "Для применения изменений запустите: sudo update-grub"
    fi
}

setup_system_aliases() {
    log_info "Настройка системных алиасов..."
    
    # Создание глобальных алиасов
    cat > "/etc/bash.bashrc.d/custom_aliases" << 'EOF'
# Системные алиасы для всех пользователей

# Улучшенные базовые команды
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -la --color=auto --group-directories-first'
alias la='ls -A --color=auto --group-directories-first'
alias l='ls -CF --color=auto'

# Безопасность
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Системный мониторинг
alias df='df -h'
alias du='du -ch'
alias free='free -h'
alias ps='ps auxf'
alias psg='ps aux | grep'
alias top='htop'

# Сеть
alias ports='ss -tuln'
alias myip='curl -s ifconfig.me && echo'
alias localip='hostname -I'
alias ping='ping -c 5'

# Системные сервисы
alias sctl='systemctl'
alias jctl='journalctl'
alias scstatus='systemctl status'
alias screstart='systemctl restart'

# Поиск
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Быстрые команды
alias c='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowdate='date +"%d-%m-%Y"'

# Полезные функции
weather() { curl -s "wttr.in/$1?lang=ru"; }
cheat() { curl -s "cheat.sh/$1"; }
qr() { qrencode -t ansiutf8 "$1"; }
EOF

    # Подключение алиасов для всех пользователей
    echo "source /etc/bash.bashrc.d/custom_aliases" >> /etc/bash.bashrc
    
    log_success "Системные алиасы настроены"
}

setup_autostart() {
    log_info "Настройка автозапуска..."
    
    # Создание сервиса для приветственного сообщения
    cat > "/etc/systemd/system/welcome-message.service" << 'EOF'
[Unit]
Description=Welcome Message Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/welcome.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Создание скрипта автозапуска для пользователей
    local autostart_script="/usr/local/bin/user-autostart.sh"
    
    cat > "$autostart_script" << 'EOF'
#!/bin/bash
# Скрипт автозапуска для пользователей

# Проверка и запуск tmux сессии
if command -v tmux &> /dev/null && [[ -z "$TMUX" ]] && [[ "$TERM" != "screen"* ]]; then
    if ! tmux list-sessions &> /dev/null; then
        # Создание новой сессии
        tmux new-session -d -s main
        tmux send-keys -t main 'echo "🚀 Tmux сессия запущена! Нажмите Ctrl+A,d для отключения"' Enter
    fi
fi

# Проверка места на диске
local disk_usage=$(df / | awk 'NR==2{print substr($5,1,length($5)-1)}')
if [[ $disk_usage -gt 90 ]]; then
    echo -e "\033[1;31m⚠️  ВНИМАНИЕ: Диск заполнен на ${disk_usage}%!\033[0m"
fi

# Проверка обновлений безопасности
if command -v unattended-upgrades &> /dev/null; then
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo "0")
    if [[ $security_updates -gt 0 ]]; then
        echo -e "\033[1;33m🔒 Доступно $security_updates обновлений безопасности\033[0m"
    fi
fi
EOF

    chmod +x "$autostart_script"
    
    # Добавление в профиль пользователя
    echo "" >> /etc/profile
    echo "# Пользовательский автозапуск" >> /etc/profile
    echo "[[ -f /usr/local/bin/user-autostart.sh ]] && source /usr/local/bin/user-autostart.sh" >> /etc/profile
    
    # Включение сервиса
    systemctl enable welcome-message.service 2>/dev/null || true
    
    log_success "Автозапуск настроен"
}
# =============================================================================
# Диагностика после установки
# =============================================================================

verify_installation() {
    log_info "=== ПРОВЕРКА УСТАНОВЛЕННЫХ КОМПОНЕНТОВ ==="
    
    local commands_to_check=(
        "tmux:Терминальный мультиплексор"
        "vim:Текстовый редактор"
        "htop:Мониторинг процессов"
        "tree:Отображение дерева каталогов"
        "git:Система контроля версий"
        "curl:HTTP клиент"
        "wget:Загрузчик файлов"
        "fzf:Fuzzy finder"
        "bat:Улучшенный cat"
        "exa:Улучшенный ls"
        "ranger:Файловый менеджер"
        "mc:Midnight Commander"
        "neofetch:Системная информация"
    )
    
    local available=0
    local missing=0
    
    echo "Проверка доступных команд:"
    echo "=========================="
    
    for cmd_info in "${commands_to_check[@]}"; do
        IFS=':' read -r cmd description <<< "$cmd_info"
        
        if command -v "$cmd" &> /dev/null; then
            printf "✅ %-12s - %s\n" "$cmd" "$description"
            ((available++))
        else
            printf "❌ %-12s - %s (не найден)\n" "$cmd" "$description"
            ((missing++))
        fi
    done
    
    echo ""
    echo "Результат: $available доступно, $missing отсутствует"
    
    if [[ $missing -gt 0 ]]; then
        log_warning "Некоторые команды недоступны. Проверьте установку пакетов."
        if yes_no_prompt "Попробовать переустановить отсутствующие пакеты?"; then
            retry_missing_packages
        fi
    else
        log_success "Все основные компоненты установлены!"
    fi
}

retry_missing_packages() {
    log_info "Повторная попытка установки отсутствующих пакетов..."
    
    # Попытка установки через snap, если apt не сработал
    if command -v snap &> /dev/null; then
        local snap_packages=("bat" "exa" "ripgrep")
        
        for package in "${snap_packages[@]}"; do
            if ! command -v "$package" &> /dev/null; then
                log_info "Попытка установки $package через snap..."
                snap install "$package" 2>&1 | tee -a "$LOG_FILE" || true
            fi
        done
    fi
    
    # Попытка установки через wget/curl
    install_manual_packages
}

install_manual_packages() {
    log_info "Ручная установка недоступных пакетов..."
    
    # Установка fzf
    if ! command -v fzf &> /dev/null; then
        log_info "Ручная установка fzf..."
        wget -O /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/download/0.44.1/fzf-0.44.1-linux_amd64.tar.gz" 2>&1 | tee -a "$LOG_FILE"
        tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin/ 2>&1 | tee -a "$LOG_FILE"
        chmod +x /usr/local/bin/fzf
        rm -f /tmp/fzf.tar.gz
        log_success "fzf установлен вручную"
    fi
    
    # Установка bat
    if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
        log_info "Ручная установка bat..."
        wget -O /tmp/bat.deb "https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb" 2>&1 | tee -a "$LOG_FILE"
        dpkg -i /tmp/bat.deb 2>&1 | tee -a "$LOG_FILE" || apt-get install -f -y
        rm -f /tmp/bat.deb
        log_success "bat установлен вручную"
    fi
}
# =============================================================================
# Функция создания отчета
# =============================================================================

generate_installation_report() {
    local report_file="/tmp/terminal_setup_report.txt"
    
    cat > "$report_file" << EOF
=============================================================================
ОТЧЕТ ОБ УСТАНОВКЕ КОМПОНЕНТОВ ТЕРМИНАЛА
=============================================================================
Дата: $(date)
Пользователь: $(whoami)
Система: $(lsb_release -d | cut -f2) $(uname -m)

УСТАНОВЛЕННЫЕ КОМПОНЕНТЫ:
EOF
    
    local commands=(
        "tmux" "vim" "htop" "tree" "git" "curl" "wget" 
        "fzf" "bat" "exa" "ranger" "mc" "neofetch"
    )
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            local version=$(command -v "$cmd" --version 2>/dev/null | head -1 || echo "версия неизвестна")
            echo "✅ $cmd: $(which "$cmd") - $version" >> "$report_file"
        else
            echo "❌ $cmd: не установлен" >> "$report_file"
        fi
    done
    
    echo "" >> "$report_file"
    echo "РАЗМЕР ЛОГА: $(wc -l < "$LOG_FILE") строк" >> "$report_file"
    echo "ПУТЬ К ЛОГУ: $LOG_FILE" >> "$report_file"
    echo "" >> "$report_file"
    echo "ДОСТУПНЫЕ НОВЫЕ КОМАНДЫ:" >> "$report_file"
    echo "  fb       - Файловый браузер" >> "$report_file"
    echo "  hint     - Система подсказок" >> "$report_file"
    echo "  weather  - Прогноз погоды" >> "$report_file"
    echo "  Ctrl+R   - Поиск в истории" >> "$report_file"
    echo "  Ctrl+T   - Поиск файлов" >> "$report_file"
    
    log_info "Отчет сохранен в: $report_file"
    
    if yes_no_prompt "Показать отчет?"; then
        cat "$report_file"
    fi
}
# =============================================================================
# Модифицированная главная функция
# =============================================================================

main_terminal_setup() {
    log_info "=== ПРОДВИНУТАЯ НАСТРОЙКА ТЕРМИНАЛА v1.1 ==="
    log_info "Время запуска: $(date)"
    
    # Проверка предварительных требований
    check_prerequisites
    
    echo ""
    echo "🚀 Добро пожаловать в систему настройки продвинутого терминала!"
    echo ""
    echo "Выберите режим установки:"
    echo "1) Быстрая установка (все компоненты автоматически)"
    echo "2) Интерактивная установка (выбор компонентов)"
    echo "3) Только настройка (без установки пакетов)"
    echo "4) Диагностика существующей установки"
    echo "5) Выход"
    
    local choice
    read -p "Ваш выбор [1-5]: " choice
    
    case "$choice" in
        1)
            log_info "Запуск быстрой установки..."
            install_terminal_components
            setup_smart_completion
            setup_clickable_terminal
            setup_system_customization
            ;;
        2)
            log_info "Запуск интерактивной установки..."
            interactive_package_selection
            if yes_no_prompt "Настроить умное автодополнение?"; then
                setup_smart_completion
            fi
            if yes_no_prompt "Настроить кликабельный терминал?"; then
                setup_clickable_terminal
            fi
            if yes_no_prompt "Настроить операционную систему?"; then
                setup_system_customization
            fi
            ;;
        3)
            log_info "Только настройка без установки пакетов..."
            setup_smart_completion
            setup_clickable_terminal
            setup_system_customization
            ;;
        4)
            verify_installation
            return 0
            ;;
        5)
            log_info "Выход из программы"
            return 0
            ;;
        *)
            log_error "Неверный выбор"
            return 1
            ;;
    esac
    
    # Проверка результатов установки
    verify_installation
    
    # Генерация отчета
    generate_installation_report
    
    log_success "=== НАСТРОЙКА ТЕРМИНАЛА ЗАВЕРШЕНА ==="
    
    echo ""
    echo "🎉 Настройка завершена! Что дальше?"
    echo ""
    echo "1) Перезайдите в терминал: exit && вход заново"
    echo "2) Или выполните: source ~/.bashrc"
    echo "3) Проверьте новые команды: fb, hint, weather"
    echo "4) Попробуйте Ctrl+R для поиска в истории"
    echo ""
    
    if yes_no_prompt "Перезагрузить систему для применения всех изменений?"; then
        log_info "Перезагрузка системы через 10 секунд..."
        sleep 10
        reboot
    fi
}
custom_setup() {
    log_info "Пользовательская настройка компонентов..."
    
    while true; do
        echo ""
        echo "Доступные опции:"
        echo "1) Установить дополнительные пакеты"
        echo "2) Настроить автодополнение"
        echo "3) Настроить файловый браузер"
        echo "4) Настроить tmux"
        echo "5) Настроить приветственные сообщения"
        echo "6) Настроить GRUB"
        echo "7) Назад"
        
        read -p "Выберите опцию: " option
        
        case "$option" in
            1) install_terminal_components ;;
            2) setup_smart_completion ;;
            3) create_file_browser ;;
            4) setup_tmux_mouse_support ;;
            5) setup_welcome_messages ;;
            6) setup_grub_customization ;;
            7) break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
}

# Запуск главной функции если скрипт вызывается напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_terminal_setup "$@"
fi