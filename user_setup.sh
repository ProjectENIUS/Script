#!/bin/bash

# =============================================================================
# User Profile Configuration Script (user_setup.sh)
# Скрипт подробной настройки профилей пользователей
# Version: 1.0
# =============================================================================

set -euo pipefail

# Подключение основных функций из главного скрипта
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/installing.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/installing.sh"
else
    # Базовые функции если главный скрипт недоступен
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
readonly USER_CONFIG_DIR="/etc/skel"
readonly ADMIN_SCRIPTS_DIR="/usr/local/admin-scripts"

# Проверка автоматического режима
if [[ "${USER_SETUP_MODE:-}" == "auto" ]]; then
    log_info "Автоматический режим настройки пользователей"
    
    # Автоматическая настройка root с базовыми параметрами
    configure_root_profile() {
        log_info "Автоматическая настройка профиля root..."
        local root_home="/root"
        backup_user_configs "$root_home"
        configure_root_bashrc "$root_home"
        configure_root_bash_profile "$root_home"
        configure_root_environment "$root_home"
        configure_root_aliases "$root_home"
        configure_root_history "$root_home"
        configure_root_vim "$root_home"
        create_admin_scripts
        configure_root_ssh "$root_home"
        configure_sudo_settings
        log_success "Профиль root настроен автоматически"
    }
    
    # Автоматическая настройка текущего пользователя
    configure_current_user_profile() {
        local current_user=$(logname 2>/dev/null || echo $SUDO_USER)
        local user_home=$(getent passwd "$current_user" | cut -d: -f6)
        
        if [[ -n "$current_user" && "$current_user" != "root" ]]; then
            log_info "Автоматическая настройка профиля пользователя $current_user..."
            backup_user_configs "$user_home"
            configure_user_bashrc "$user_home" "$current_user"
            configure_user_bash_profile "$user_home" "$current_user"
            configure_user_environment "$user_home"
            configure_user_aliases "$user_home"
            configure_user_functions "$user_home"
            configure_user_vim "$user_home"
            configure_user_ssh "$user_home" "$current_user"
            create_user_directories "$user_home" "$current_user"
            chown -R "$current_user:$current_user" "$user_home"
            log_success "Профиль пользователя $current_user настроен автоматически"
        fi
    }
    
    # Выполнение автоматической настройки
    configure_root_profile
    configure_current_user_profile
    exit 0
fi

# =============================================================================
# Функции настройки профиля root
# =============================================================================

configure_root_profile() {
    log_info "=== НАСТРОЙКА ПРОФИЛЯ СУПЕРПОЛЬЗОВАТЕЛЯ (ROOT) ==="
    
    if ! yes_no_prompt "Настроить профиль root?"; then
        return 0
    fi
    
    local root_home="/root"
    
    # Резервное копирование существующих файлов
    backup_user_configs "$root_home"
    
    # Настройка .bashrc для root
    configure_root_bashrc "$root_home"
    
    # Настройка .bash_profile для root
    configure_root_bash_profile "$root_home"
    
    # Настройка переменных окружения
    configure_root_environment "$root_home"
    
    # Настройка алиасов для администрирования
    configure_root_aliases "$root_home"
    
    # Настройка истории команд
    configure_root_history "$root_home"
    
    # Настройка vim для root
    configure_root_vim "$root_home"
    
    # Создание административных скриптов
    create_admin_scripts
    
    # Настройка SSH для root
    configure_root_ssh "$root_home"
    
    # Настройка sudo конфигурации
    configure_sudo_settings
    
    log_success "Профиль root настроен"
}

configure_root_bashrc() {
    local home_dir=$1
    local bashrc_file="$home_dir/.bashrc"
    
    log_info "Настройка .bashrc для root..."
    
    cat > "$bashrc_file" << 'EOF'
# Root .bashrc configuration
# Generated by user setup script

# Если не в интерактивном режиме, не делать ничего
case $- in
    *i*) ;;
      *) return;;
esac

# История команд
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=5000
HISTFILESIZE=10000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
shopt -s histappend
shopt -s checkwinsize

# Цветной вывод для ls
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Улучшенный prompt для root
export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Включение автодополнения
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Загрузка пользовательских алиасов
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Загрузка пользовательских функций
if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi

# Безопасность для root
umask 077

# Предупреждение о работе под root
echo -e "\033[1;31m⚠️  ВНИМАНИЕ: Вы работаете под пользователем ROOT\033[0m"
echo -e "\033[1;33m💡 Рекомендуется использовать sudo для выполнения административных задач\033[0m"

# Отображение системной информации при входе
if [ -f /usr/local/admin-scripts/system-info.sh ]; then
    /usr/local/admin-scripts/system-info.sh --brief
fi
EOF

    chmod 644 "$bashrc_file"
    log_success ".bashrc для root настроен"
}

configure_root_bash_profile() {
    local home_dir=$1
    local profile_file="$home_dir/.bash_profile"
    
    log_info "Настройка .bash_profile для root..."
    
    cat > "$profile_file" << 'EOF'
# Root .bash_profile
# Generated by user setup script

# Загрузка .bashrc если он существует
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Настройка PATH для административных инструментов
export PATH="/usr/local/admin-scripts:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Настройка переменных окружения для администрирования
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"
export LESS="-R"

# Настройка для systemd
export SYSTEMD_PAGER=""

# Логирование команд root
export PROMPT_COMMAND='history -a; logger -t "ROOT_CMD" "$(whoami) [$$]: $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")"'

# Проверка обновлений при входе
if command -v apt &> /dev/null; then
    if [ ! -f /tmp/.update_check_$(date +%Y%m%d) ]; then
        echo "🔄 Проверка обновлений..."
        apt list --upgradable 2>/dev/null | grep -c "upgradable" | xargs -I {} echo "📦 Доступно {} обновлений"
        touch /tmp/.update_check_$(date +%Y%m%d)
    fi
fi
EOF

    chmod 644 "$profile_file"
    log_success ".bash_profile для root настроен"
}

configure_root_environment() {
    local home_dir=$1
    local env_file="$home_dir/.bash_environment"
    
    log_info "Настройка переменных окружения для root..."
    
    cat > "$env_file" << 'EOF'
# Root Environment Variables
# Generated by user setup script

# Локализация
export LC_ALL=ru_RU.UTF-8
export LANG=ru_RU.UTF-8
export LANGUAGE=ru_RU:ru:en

# Настройки терминала
export TERM=xterm-256color
export COLORTERM=truecolor

# Настройки для различных утилит
export GREP_OPTIONS='--color=auto'
export LESS_TERMCAP_mb=$'\E[1;31m'     # начало мигания
export LESS_TERMCAP_md=$'\E[1;36m'     # начало жирного
export LESS_TERMCAP_me=$'\E[0m'        # конец режима
export LESS_TERMCAP_se=$'\E[0m'        # конец выделения
export LESS_TERMCAP_so=$'\E[01;44;33m' # начало выделения
export LESS_TERMCAP_ue=$'\E[0m'        # конец подчеркивания
export LESS_TERMCAP_us=$'\E[1;32m'     # начало подчеркивания

# Настройки для администрирования
export ANSIBLE_HOST_KEY_CHECKING=False
export DEBIAN_FRONTEND=noninteractive

# Настройки безопасности
export TMOUT=1800  # Автоматический выход через 30 минут бездействия
EOF

    chmod 644 "$env_file"
    
    # Добавление загрузки переменных в .bashrc
    echo "" >> "$home_dir/.bashrc"
    echo "# Загрузка переменных окружения" >> "$home_dir/.bashrc"
    echo "if [ -f ~/.bash_environment ]; then" >> "$home_dir/.bashrc"
    echo "    . ~/.bash_environment" >> "$home_dir/.bashrc"
    echo "fi" >> "$home_dir/.bashrc"
    
    log_success "Переменные окружения для root настроены"
}

configure_root_aliases() {
    local home_dir=$1
    local aliases_file="$home_dir/.bash_aliases"
    
    log_info "Настройка алиасов для root..."
    
    cat > "$aliases_file" << 'EOF'
# Root Aliases
# Generated by user setup script

# === БАЗОВЫЕ КОМАНДЫ ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# === БЕЗОПАСНОСТЬ ===
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'

# === СИСТЕМНОЕ АДМИНИСТРИРОВАНИЕ ===
alias syslog='tail -f /var/log/syslog'
alias messages='tail -f /var/log/messages'
alias auth='tail -f /var/log/auth.log'
alias ports='netstat -tuln'
alias listening='ss -tuln'
alias psg='ps aux | grep'
alias topcpu='ps auxf | sort -nr -k 3 | head -10'
alias topmem='ps auxf | sort -nr -k 4 | head -10'

# === УПРАВЛЕНИЕ СЕРВИСАМИ ===
alias sctl='systemctl'
alias scstatus='systemctl status'
alias screstart='systemctl restart'
alias scstop='systemctl stop'
alias scstart='systemctl start'
alias screload='systemctl reload'
alias scenable='systemctl enable'
alias scdisable='systemctl disable'
alias jctl='journalctl'
alias jctlf='journalctl -f'

# === СЕТЕВОЕ АДМИНИСТРИРОВАНИЕ ===
alias iptlist='iptables -L -n -v --line-numbers'
alias iptflush='iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X'
alias netcons='ss -tuln'
alias ping='ping -c 5'
alias fastping='ping -c 100 -s.2'

# === МОНИТОРИНГ СИСТЕМЫ ===
alias df='df -h'
alias du='du -ch'
alias free='free -m'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'
alias cpuinfo='lscpu'
alias meminfo='cat /proc/meminfo'
alias diskspace='du -Sh | sort -rh | head -20'
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'

# === ПОИСК И ФАЙЛЫ ===
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias zgrep='zgrep --color=auto'
alias findname='find . -name'
alias findsize='find . -type f -size'

# === АРХИВЫ ===
alias tarc='tar -czf'
alias tarx='tar -xzf'
alias tart='tar -tzf'

# === ПАКЕТНОЕ УПРАВЛЕНИЕ ===
alias aptupdate='apt update'
alias aptupgrade='apt upgrade'
alias aptinstall='apt install'
alias aptremove='apt remove'
alias aptsearch='apt search'
alias aptshow='apt show'
alias aptlist='apt list --installed'

# === БЫСТРЫЕ КОМАНДЫ ===
alias h='history'
alias c='clear'
alias x='exit'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'

# === АДМИНИСТРИРОВАНИЕ ПОЛЬЗОВАТЕЛЕЙ ===
alias userlist='cut -d: -f1 /etc/passwd | sort'
alias grouplist='cut -d: -f1 /etc/group | sort'
alias whoami='id'

# === БЫСТРЫЕ ПЕРЕХОДЫ ===
alias logs='cd /var/log'
alias etc='cd /etc'
alias var='cd /var'
alias tmp='cd /tmp'
alias opt='cd /opt'
alias home='cd /home'

# === ФУНКЦИИ КАК АЛИАСЫ ===
# Быстрая проверка статуса сервисов
alias checkservices='systemctl list-units --type=service --state=failed'
alias allservices='systemctl list-units --type=service'

# Информация о системе
alias sysinfo='/usr/local/admin-scripts/system-info.sh'
alias diskinfo='lsblk -f'
alias usbinfo='lsusb'
alias pciinfo='lspci'

# Очистка системы
alias cleanup='apt autoremove && apt autoclean'
alias cleanlogs='journalctl --vacuum-time=7d'

# Бэкап важных конфигураций
alias backupconfigs='/usr/local/admin-scripts/backup-configs.sh'
EOF

    chmod 644 "$aliases_file"
    log_success "Алиасы для root настроены"
}

configure_root_history() {
    local home_dir=$1
    local inputrc_file="$home_dir/.inputrc"
    
    log_info "Настройка истории команд для root..."
    
    # Настройка .inputrc для улучшенной работы с историей
    cat > "$inputrc_file" << 'EOF'
# Root .inputrc configuration
# Generated by user setup script

# Улучшенная навигация по истории
"\e[A": history-search-backward
"\e[B": history-search-forward
"\e[C": forward-char
"\e[D": backward-char

# Ctrl+стрелки для перемещения по словам
"\e[1;5C": forward-word
"\e[1;5D": backward-word

# Автодополнение без учета регистра
set completion-ignore-case on

# Показать все возможные дополнения сразу
set show-all-if-ambiguous on
set show-all-if-unmodified on

# Отключить звуковой сигнал
set bell-style none

# Включить редактирование в стиле vi (опционально)
# set editing-mode vi

# Показать режим редактирования
set show-mode-in-prompt on

# Цветное дополнение
set colored-stats on
set colored-completion-prefix on
EOF

    chmod 644 "$inputrc_file"
    
    # Настройка дополнительных параметров истории в .bashrc
    cat >> "$home_dir/.bashrc" << 'EOF'

# === РАСШИРЕННАЯ НАСТРОЙКА ИСТОРИИ ===
# Сохранение истории при каждой команде
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Игнорирование определенных команд в истории
HISTIGNORE="ls:ll:la:cd:pwd:exit:clear:history"

# Формат времени в истории
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "

# Немедленное сохранение истории
shopt -s histappend
shopt -s histverify
shopt -s histreedit

# Функция для поиска в истории
hist() {
    if [ $# -eq 0 ]; then
        history | tail -20
    else
        history | grep "$@"
    fi
}
EOF

    log_success "История команд для root настроена"
}

configure_root_vim() {
    local home_dir=$1
    local vimrc_file="$home_dir/.vimrc"
    
    log_info "Настройка vim для root..."
    
    cat > "$vimrc_file" << 'EOF'
" Root vim configuration
" Generated by user setup script

" === ОСНОВНЫЕ НАСТРОЙКИ ===
set nocompatible
set backspace=indent,eol,start
set history=1000
set undolevels=1000

" === ИНТЕРФЕЙС ===
syntax on
set number
set ruler
set showcmd
set showmode
set wildmenu
set wildmode=longest:full,full

" === ПОИСК ===
set hlsearch
set incsearch
set ignorecase
set smartcase

" === ОТСТУПЫ И ТАБУЛЯЦИЯ ===
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab

" === ФАЙЛЫ ===
set backup
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undodir=~/.vim/undo//
set undofile

" Создание директорий если они не существуют
if !isdirectory($HOME.'/.vim/backup')
    call mkdir($HOME.'/.vim/backup', 'p')
endif
if !isdirectory($HOME.'/.vim/swap')
    call mkdir($HOME.'/.vim/swap', 'p')
endif
if !isdirectory($HOME.'/.vim/undo')
    call mkdir($HOME.'/.vim/undo', 'p')
endif

" === ЦВЕТОВАЯ СХЕМА ===
set t_Co=256
colorscheme default
set background=dark

" === СТАТУСНАЯ СТРОКА ===
set laststatus=2
set statusline=%F%m%r%h%w\ [%l,%v][%p%%]\ %{strftime('%H:%M')}

" === ГОРЯЧИЕ КЛАВИШИ ===
" Лидер клавиша
let mapleader = ","

" Быстрое сохранение
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" Навигация между буферами
nnoremap <leader>n :bnext<CR>
nnoremap <leader>p :bprev<CR>

" Очистка подсветки поиска
nnoremap <leader>h :nohlsearch<CR>

" === НАСТРОЙКИ ДЛЯ АДМИНИСТРИРОВАНИЯ ===
" Подсветка синтаксиса для конфигурационных файлов
autocmd BufNewFile,BufRead *.conf setfiletype conf
autocmd BufNewFile,BufRead *rc setfiletype sh

" Автоматическое создание резервной копии при редактировании системных файлов
autocmd BufWritePre /etc/* let &backup = 1 | let &backupext = '.backup-' . strftime('%Y%m%d-%H%M%S')

" Предупреждение при редактировании важных файлов
autocmd BufRead /etc/passwd,/etc/shadow,/etc/sudoers echo "⚠️  ВНИМАНИЕ: Редактирование критически важного файла!"

" === УДОБСТВА ===
" Показать непечатаемые символы
set listchars=tab:▸\ ,eol:¬,trail:·
nnoremap <leader>l :set list!<CR>

" Автоматическое закрытие скобок
inoremap ( ()<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i
inoremap " ""<Esc>i
inoremap ' ''<Esc>i

" Быстрый переход к началу и концу строки
nnoremap H ^
nnoremap L $
EOF

    chmod 644 "$vimrc_file"
    log_success "Vim для root настроен"
}

# =============================================================================
# Функции настройки активного пользователя
# =============================================================================

configure_current_user_profile() {
    log_info "=== НАСТРОЙКА ПРОФИЛЯ ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ ==="
    
    local current_user=$(logname 2>/dev/null || echo $SUDO_USER)
    local user_home=$(getent passwd "$current_user" | cut -d: -f6)
    
    if [[ -z "$current_user" || "$current_user" == "root" ]]; then
        log_warning "Текущий пользователь не определен или является root"
        return 0
    fi
    
    if ! yes_no_prompt "Настроить профиль пользователя $current_user?"; then
        return 0
    fi
    
    log_info "Настройка профиля для пользователя: $current_user"
    log_info "Домашняя директория: $user_home"
    
    # Резервное копирование
    backup_user_configs "$user_home"
    
    # Основные настройки профиля
    configure_user_bashrc "$user_home" "$current_user"
    configure_user_bash_profile "$user_home" "$current_user"
    configure_user_environment "$user_home"
    configure_user_aliases "$user_home"
    configure_user_functions "$user_home"
    configure_user_vim "$user_home"
    
    # SSH настройки
    configure_user_ssh "$user_home" "$current_user"
    
    # Git настройки
    configure_user_git "$user_home" "$current_user"
    
    # Создание полезных директорий
    create_user_directories "$user_home" "$current_user"
    
    # Установка правильных прав
    chown -R "$current_user:$current_user" "$user_home"
    
    log_success "Профиль пользователя $current_user настроен"
}

configure_user_bashrc() {
    local home_dir=$1
    local username=$2
    local bashrc_file="$home_dir/.bashrc"
    
    log_info "Настройка .bashrc для пользователя $username..."
    
    cat > "$bashrc_file" << EOF
# User .bashrc configuration for $username
# Generated by user setup script

# Если не в интерактивном режиме, не делать ничего
case \$- in
    *i*) ;;
      *) return;;
esac

# === ИСТОРИЯ КОМАНД ===
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=2000
HISTFILESIZE=4000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell

# === ЦВЕТНОЙ ВЫВОД ===
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# === PROMPT ===
# Функция для отображения git ветки
git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Цветной prompt с git информацией
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;31m\]\$(git_branch)\[\033[00m\]\$ '

# === АВТОДОПОЛНЕНИЕ ===
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# === ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ ===
# Загрузка алиасов
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Загрузка функций
if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi

# Загрузка переменных окружения
if [ -f ~/.bash_environment ]; then
    . ~/.bash_environment
fi

# === ПРИВЕТСТВИЕ ===
echo -e "\033[1;36m🚀 Добро пожаловать, $username!\033[0m"
echo -e "\033[1;32m📅 \$(date '+%A, %d %B %Y - %H:%M:%S')\033[0m"

# Отображение полезной информации
if command -v fortune &> /dev/null; then
    echo ""
    fortune -s
fi

# Проверка места на диске при входе
df -h / | awk 'NR==2 {print "💾 Свободно на диске: " \$4 " из " \$2 " (" \$5 " используется)"}'

# Количество запущенных процессов пользователя
echo "🔧 Ваших процессов: \$(ps aux | grep ^$username | wc -l)"
EOF

    log_success ".bashrc для пользователя $username настроен"
}

configure_user_bash_profile() {
    local home_dir=$1
    local username=$2
    local profile_file="$home_dir/.bash_profile"
    
    log_info "Настройка .bash_profile для пользователя $username..."
    
    cat > "$profile_file" << 'EOF'
# User .bash_profile
# Generated by user setup script

# Загрузка .bashrc если он существует
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Пользовательские пути
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Основные редакторы
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"

# Настройки для разработки
export BROWSER="firefox"

# Настройки локализации
export LC_ALL=ru_RU.UTF-8
export LANG=ru_RU.UTF-8

# Создание необходимых директорий
[ ! -d "$HOME/bin" ] && mkdir -p "$HOME/bin"
[ ! -d "$HOME/.local/bin" ] && mkdir -p "$HOME/.local/bin"
EOF

    log_success ".bash_profile для пользователя $username настроен"
}

configure_user_environment() {
    local home_dir=$1
    local env_file="$home_dir/.bash_environment"
    
    log_info "Настройка переменных окружения для пользователя..."
    
    cat > "$env_file" << 'EOF'
# User Environment Variables
# Generated by user setup script

# === ОСНОВНЫЕ ПЕРЕМЕННЫЕ ===
export TERM=xterm-256color
export COLORTERM=truecolor

# === НАСТРОЙКИ LESS ===
export LESS="-R"
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

# === НАСТРОЙКИ ДЛЯ РАЗРАБОТКИ ===
export NODE_PATH="$HOME/.local/lib/node_modules"
export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"

# === НАСТРОЙКИ PYTHON ===
export PYTHONPATH="$HOME/.local/lib/python3/site-packages:$PYTHONPATH"
export PIP_USER=true

# === НАСТРОЙКИ GIT ===
export GIT_EDITOR="vim"

# === БЕЗОПАСНОСТЬ ===
export GNUPGHOME="$HOME/.gnupg"
chmod 700 "$GNUPGHOME" 2>/dev/null || true
EOF

    log_success "Переменные окружения для пользователя настроены"
}

configure_user_aliases() {
    local home_dir=$1
    local aliases_file="$home_dir/.bash_aliases"
    
    log_info "Настройка алиасов для пользователя..."
    
    cat > "$aliases_file" << 'EOF'
# User Aliases
# Generated by user setup script

# === БАЗОВЫЕ КОМАНДЫ ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cd..='cd ..'

# === БЕЗОПАСНОСТЬ ===
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# === СИСТЕМНАЯ ИНФОРМАЦИЯ ===
alias df='df -h'
alias du='du -ch'
alias free='free -m'
alias ps='ps auxf'
alias psg='ps aux | grep'
alias ports='ss -tuln'

# === GIT АЛИАСЫ ===
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# === ПОИСК И ФАЙЛЫ ===
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias findname='find . -name'
alias findtext='grep -r'

# === АРХИВЫ ===
alias tarc='tar -czf'
alias tarx='tar -xzf'
alias tart='tar -tzf'
alias unzip='unzip -q'

# === СЕТЬ ===
alias ping='ping -c 5'
alias wget='wget -c'
alias myip='curl -s ifconfig.me'
alias localip='hostname -I'

# === БЫСТРЫЕ КОМАНДЫ ===
alias h='history'
alias c='clear'
alias x='exit'
alias reload='source ~/.bashrc'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowdate='date +"%d-%m-%Y"'

# === РЕДАКТИРОВАНИЕ ===
alias bashrc='vim ~/.bashrc'
alias vimrc='vim ~/.vimrc'
alias aliases='vim ~/.bash_aliases'

# === PYTHON ===
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# === ПОЛЕЗНЫЕ ФУНКЦИИ КАК АЛИАСЫ ===
alias weather='curl wttr.in'
alias cheat='curl cheat.sh/'
alias qr='qrencode -t ansiutf8'

# === РАБОТА С ТЕКСТОМ ===
alias wc='wc -l'
alias head='head -n 20'
alias tail='tail -n 20'

# === МУЛЬТИМЕДИА ===
alias mp3info='id3info'
alias imginfo='identify'

# === ПРОЦЕССЫ ===
alias topcpu='ps auxf | sort -nr -k 3 | head -10'
alias topmem='ps auxf | sort -nr -k 4 | head -10'
EOF

    log_success "Алиасы для пользователя настроены"
}

configure_user_functions() {
    local home_dir=$1
    local functions_file="$home_dir/.bash_functions"
    
    log_info "Создание полезных функций для пользователя..."
    
    cat > "$functions_file" << 'EOF'
# User Functions
# Generated by user setup script

# === ФУНКЦИИ ПОИСКА ===
# Поиск файлов по имени
ff() {
    find . -type f -name "*$1*" 2>/dev/null
}

# Поиск в содержимом файлов
ftext() {
    grep -r "$1" . 2>/dev/null
}

# === ФУНКЦИИ АРХИВАЦИИ ===
# Создание архива
extract() {
    if [ -f "$1" ]; then
        case $1 in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' нельзя извлечь с помощью extract()" ;;
        esac
    else
        echo "'$1' не является корректным файлом!"
    fi
}

# Создание архива из директории
mktar() {
    tar czf "${1%%/}.tar.gz" "${1%%/}/"
}

# === СЕТЕВЫЕ ФУНКЦИИ ===
# Проверка доступности хоста
isup() {
    if ping -c 1 "$1" &> /dev/null; then
        echo "$1 доступен"
    else
        echo "$1 недоступен"
    fi
}

# Информация о домене
whoisinfo() {
    whois "$1" | grep -E "(Registrar|Creation Date|Expiry Date)"
}

# === ФУНКЦИИ РАЗРАБОТЧИКА ===
# Создание и переход в директорию
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Быстрое создание backup файла
backup() {
    cp "$1" "$1.backup-$(date +%Y%m%d-%H%M%S)"
}

# Поиск и замена в файлах
replace() {
    find . -type f -name "*.$3" -exec sed -i "s/$1/$2/g" {} +
}

# === ФУНКЦИИ СИСТЕМЫ ===
# Размер директории
dirsize() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# Топ файлов по размеру
bigfiles() {
    find . -type f -exec ls -la {} \; | sort -k5 -nr | head -20
}

# Поиск пустых файлов
emptyfiles() {
    find . -type f -empty
}

# === ФУНКЦИИ GIT ===
# Быстрый commit
gitquick() {
    git add .
    git commit -m "$1"
    git push
}

# Статистика git репозитория
gitstats() {
    echo "=== Git Repository Statistics ==="
    echo "Commits: $(git rev-list --all --count)"
    echo "Branches: $(git branch -r | wc -l)"
    echo "Contributors: $(git shortlog -sn | wc -l)"
    echo "Files: $(git ls-files | wc -l)"
}

# === ФУНКЦИИ МОНИТОРИНГА ===
# Использование порта
port() {
    ss -tuln | grep ":$1 "
}

# Процессы по имени
psname() {
    ps aux | grep "$1" | grep -v grep
}

# === ПОЛЕЗНЫЕ УТИЛИТЫ ===
# Генератор паролей
genpass() {
    local length=${1:-16}
    openssl rand -base64 $length | head -c $length
    echo
}

# Конвертер чисел
dec2hex() {
    printf "%x\n" "$1"
}

hex2dec() {
    printf "%d\n" "0x$1"
}

# === ФУНКЦИИ РАБОТЫ С ТЕКСТОМ ===
# Подсчет строк в файле
lines() {
    wc -l "$1"
}

# Удаление пустых строк
nonempty() {
    grep -v '^$' "$1"
}

# === ФУНКЦИЯ ПОМОЩИ ===
# Список всех функций
functions() {
    echo "=== Доступные функции ==="
    grep "^[a-zA-Z].*() {" ~/.bash_functions | sed 's/() {.*//' | sort
}
EOF

    log_success "Полезные функции для пользователя созданы"
}

configure_user_vim() {
    local home_dir=$1
    local vimrc_file="$home_dir/.vimrc"
    
    log_info "Настройка vim для пользователя..."
    
    cat > "$vimrc_file" << 'EOF'
" User vim configuration
" Generated by user setup script

" === ОСНОВНЫЕ НАСТРОЙКИ ===
set nocompatible
set backspace=indent,eol,start
set history=500
set undolevels=500

" === ИНТЕРФЕЙС ===
syntax on
set number
set relativenumber
set ruler
set showcmd
set showmode
set wildmenu
set wildmode=longest:full,full
set laststatus=2

" === ПОИСК ===
set hlsearch
set incsearch
set ignorecase
set smartcase

" === ОТСТУПЫ ===
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab

" === ЦВЕТА ===
set t_Co=256
colorscheme default
set background=dark

" === СТАТУСНАЯ СТРОКА ===
set statusline=%F%m%r%h%w\ [%l,%v][%p%%]\ %{strftime('%H:%M')}

" === ГОРЯЧИЕ КЛАВИШИ ===
let mapleader = ","

" Быстрые команды
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohlsearch<CR>

" Навигация между окнами
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" === УДОБСТВА ===
" Автозакрытие скобок
inoremap ( ()<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i

" Быстрое перемещение
nnoremap H ^
nnoremap L $
EOF

    log_success "Vim для пользователя настроен"
}

configure_user_ssh() {
    local home_dir=$1
    local username=$2
    local ssh_dir="$home_dir/.ssh"
    
    log_info "Настройка SSH для пользователя $username..."
    
    # Создание SSH директории
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Создание SSH ключей если их нет
    if [[ ! -f "$ssh_dir/id_rsa" ]]; then
        if yes_no_prompt "Создать SSH ключи для пользователя $username?"; then
            sudo -u "$username" ssh-keygen -t rsa -b 4096 -f "$ssh_dir/id_rsa" -N ""
            log_success "SSH ключи созданы"
        fi
    fi
    
    # Настройка SSH config
    local ssh_config="$ssh_dir/config"
    cat > "$ssh_config" << 'EOF'
# SSH Client Configuration
# Generated by user setup script

# Общие настройки
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    TCPKeepAlive yes
    Compression yes
    
    # Безопасность
    PasswordAuthentication no
    PubkeyAuthentication yes
    ChallengeResponseAuthentication no
    
    # Предпочтительные алгоритмы
    Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# Пример настройки для сервера
# Host myserver
#     HostName server.example.com
#     User myuser
#     Port 22
#     IdentityFile ~/.ssh/id_rsa
EOF

    chmod 644 "$ssh_config"
    
    # Создание файла authorized_keys
    touch "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    # Установка правильных владельцев
    chown -R "$username:$username" "$ssh_dir"
    
    log_success "SSH для пользователя $username настроен"
}

configure_user_git() {
    local home_dir=$1
    local username=$2
    
    log_info "Настройка Git для пользователя $username..."
    
    # Получение информации от пользователя
    read -p "Введите имя для Git (Enter для пропуска): " git_name
    read -p "Введите email для Git (Enter для пропуска): " git_email
    
    if [[ -n "$git_name" && -n "$git_email" ]]; then
        sudo -u "$username" git config --global user.name "$git_name"
        sudo -u "$username" git config --global user.email "$git_email"
        
        # Дополнительные настройки Git
        sudo -u "$username" git config --global init.defaultBranch main
        sudo -u "$username" git config --global core.editor vim
        sudo -u "$username" git config --global pull.rebase false
        sudo -u "$username" git config --global core.autocrlf input
        sudo -u "$username" git config --global color.ui auto
        
        log_success "Git настроен для пользователя $username"
    else
        log_info "Настройка Git пропущена"
    fi
}

create_user_directories() {
    local home_dir=$1
    local username=$2
    
    log_info "Создание полезных директорий для пользователя $username..."
    
    local directories=(
        "$home_dir/bin"
        "$home_dir/.local/bin"
        "$home_dir/scripts"
        "$home_dir/projects"
        "$home_dir/downloads"
        "$home_dir/documents"
        "$home_dir/backup"
        "$home_dir/tmp"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Создана директория: $dir"
        fi
    done
    
    # Создание полезного скрипта в ~/bin
    cat > "$home_dir/bin/myinfo" << 'EOF'
#!/bin/bash
# Скрипт отображения информации о пользователе

echo "=== ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ ==="
echo "Пользователь: $(whoami)"
echo "Группы: $(groups)"
echo "Домашняя директория: $HOME"
echo "Текущая директория: $(pwd)"
echo "Оболочка: $SHELL"
echo ""
echo "=== СИСТЕМА ==="
echo "Операционная система: $(lsb_release -d | cut -f2)"
echo "Ядро: $(uname -r)"
echo "Архитектура: $(uname -m)"
echo ""
echo "=== РЕСУРСЫ ==="
echo "Свободная память: $(free -h | awk 'NR==2{print $7}')"
echo "Место на диске: $(df -h / | awk 'NR==2{print $4" доступно из "$2}')"
echo "Загрузка системы: $(uptime | awk -F'load average:' '{print $2}')"
EOF

    chmod +x "$home_dir/bin/myinfo"
    
    log_success "Полезные директории созданы"
}

# =============================================================================
# Создание административных скриптов
# =============================================================================

create_admin_scripts() {
    log_info "Создание административных скриптов..."
    
    mkdir -p "$ADMIN_SCRIPTS_DIR"
    
    # Скрипт системной информации
    create_system_info_script
    
    # Скрипт резервного копирования конфигураций
    create_backup_configs_script
    
    # Скрипт мониторинга системы
    create_system_monitor_script
    
    # Скрипт очистки системы
    create_cleanup_script
    
    log_success "Административные скрипты созданы"
}

create_system_info_script() {
    local script_file="$ADMIN_SCRIPTS_DIR/system-info.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Скрипт отображения информации о системе

show_brief() {
    echo "🖥️  $(hostname) | 💾 $(free -h | awk 'NR==2{print $7}') свободно | 💿 $(df -h / | awk 'NR==2{print $4}') на диске | ⏱️  $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}') работы"
}

show_full() {
    echo "========================================"
    echo "        ИНФОРМАЦИЯ О СИСТЕМЕ"
    echo "========================================"
    echo "Хост: $(hostname -f)"
    echo "ОС: $(lsb_release -d | cut -f2)"
    echo "Ядро: $(uname -r)"
    echo "Архитектура: $(uname -m)"
    echo "Время работы: $(uptime -p)"
    echo ""
    echo "=== ПАМЯТЬ ==="
    free -h
    echo ""
    echo "=== ДИСКИ ==="
    df -h
    echo ""
    echo "=== СЕТЬ ==="
    ip addr show | grep "inet " | grep -v "127.0.0.1"
    echo ""
    echo "=== ЗАГРУЗКА ==="
    uptime
    echo ""
    echo "=== АКТИВНЫЕ СЕРВИСЫ ==="
    systemctl list-units --type=service --state=active | head -10
}

case "${1:-full}" in
    --brief|-b) show_brief ;;
    --full|-f|*) show_full ;;
esac
EOF

    chmod +x "$script_file"
}

create_backup_configs_script() {
    local script_file="$ADMIN_SCRIPTS_DIR/backup-configs.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Скрипт резервного копирования важных конфигураций

BACKUP_DIR="/backup/configs-$(date +%Y%m%d-%H%M%S)"
CONFIG_DIRS="/etc /var/lib/bind /var/lib/dhcp"

echo "Создание резервной копии конфигураций..."
mkdir -p "$BACKUP_DIR"

for dir in $CONFIG_DIRS; do
    if [ -d "$dir" ]; then
        echo "Копирование $dir..."
        cp -r "$dir" "$BACKUP_DIR/"
    fi
done

# Создание архива
cd /backup
tar czf "configs-$(date +%Y%m%d-%H%M%S).tar.gz" "$(basename "$BACKUP_DIR")"

echo "Резервная копия создана: $BACKUP_DIR"
echo "Архив: /backup/configs-$(date +%Y%m%d-%H%M%S).tar.gz"
EOF

    chmod +x "$script_file"
}

create_system_monitor_script() {
    local script_file="$ADMIN_SCRIPTS_DIR/monitor.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Скрипт мониторинга системы

check_disk_space() {
    echo "=== ПРОВЕРКА ДИСКОВОГО ПРОСТРАНСТВА ==="
    df -h | awk 'NR>1 {
        usage = substr($5, 1, length($5)-1)
        if (usage > 80) 
            print "⚠️  " $6 " заполнен на " $5
    }'
}

check_memory() {
    echo "=== ПРОВЕРКА ПАМЯТИ ==="
    free | awk 'NR==2{
        usage = $3/$2 * 100
        if (usage > 80)
            print "⚠️  Память заполнена на " usage "%"
    }'
}

check_services() {
    echo "=== ПРОВЕРКА СЕРВИСОВ ==="
    systemctl list-units --type=service --state=failed --no-pager
}

check_disk_space
check_memory
check_services
EOF

    chmod +x "$script_file"
}

create_cleanup_script() {
    local script_file="$ADMIN_SCRIPTS_DIR/cleanup.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Скрипт очистки системы

echo "🧹 Начинаем очистку системы..."

# Очистка пакетного кэша
echo "📦 Очистка пакетного кэша..."
apt autoremove -y
apt autoclean

# Очистка логов
echo "📋 Очистка старых логов..."
journalctl --vacuum-time=7d

# Очистка временных файлов
echo "🗑️  Очистка временных файлов..."
find /tmp -type f -atime +7 -delete 2>/dev/null

# Очистка кэша пользователей
echo "💾 Очистка пользовательских кэшей..."
find /home -name ".cache" -type d -exec rm -rf {}/* \; 2>/dev/null

echo "✅ Очистка завершена!"
EOF

    chmod +x "$script_file"
}

# =============================================================================
# Функции резервного копирования и настройки безопасности
# =============================================================================

backup_user_configs() {
    local home_dir=$1
    local backup_dir="/tmp/user-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Создание резервной копии пользовательских конфигураций..."
    
    mkdir -p "$backup_dir"
    
    local files_to_backup=(
        ".bashrc"
        ".bash_profile"
        ".bash_aliases"
        ".bash_functions"
        ".vimrc"
        ".gitconfig"
        ".ssh/config"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$home_dir/$file" ]]; then
            cp "$home_dir/$file" "$backup_dir/"
            log_info "Создана резервная копия: $file"
        fi
    done
    
    log_success "Резервные копии сохранены в: $backup_dir"
}

configure_root_ssh() {
    local home_dir=$1
    local ssh_dir="$home_dir/.ssh"
    
    log_info "Настройка SSH для root..."
    
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Создание SSH конфигурации для root
    cat > "$ssh_dir/config" << 'EOF'
# SSH Configuration for root
# Generated by user setup script

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    TCPKeepAlive yes
    Compression yes
    
    # Строгие настройки безопасности для root
    StrictHostKeyChecking ask
    VerifyHostKeyDNS yes
    PasswordAuthentication no
    PubkeyAuthentication yes
EOF

    chmod 644 "$ssh_dir/config"
    touch "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    log_success "SSH для root настроен"
}

configure_sudo_settings() {
    log_info "Настройка sudo конфигурации..."
    
    # Создание кастомных sudo правил
    cat > "/etc/sudoers.d/admin-users" << 'EOF'
# Custom sudo rules
# Generated by user setup script

# Administrators group with full access
%admin ALL=(ALL) ALL

# Allow admin group to restart specific services without password
%admin ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
%admin ALL=(ALL) NOPASSWD: /bin/systemctl restart apache2
%admin ALL=(ALL) NOPASSWD: /bin/systemctl restart ssh
%admin ALL=(ALL) NOPASSWD: /bin/systemctl restart networking

# Allow admin group to view logs
%admin ALL=(ALL) NOPASSWD: /bin/journalctl *

# Secure path
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Sudo timeout
Defaults timestamp_timeout=15

# Require TTY
Defaults requiretty

# Log sudo commands
Defaults logfile="/var/log/sudo.log"
Defaults log_input, log_output
EOF

    chmod 440 "/etc/sudoers.d/admin-users"
    
    # Проверка конфигурации sudo
    if visudo -c; then
        log_success "Sudo конфигурация настроена"
    else
        log_error "Ошибка в sudo конфигурации"
        rm "/etc/sudoers.d/admin-users"
    fi
}

# =============================================================================
# Главная функция
# =============================================================================

main_user_setup() {
    log_info "=== СКРИПТ НАСТРОЙКИ ПОЛЬЗОВАТЕЛЕЙ ==="
    log_info "Время запуска: $(date)"
    
    # Проверка прав
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
    
    echo "Выберите действия для выполнения:"
    echo "1) Настроить профиль root"
    echo "2) Настроить профиль текущего пользователя"
    echo "3) Настроить оба профиля"
    echo "4) Только создать административные скрипты"
    echo "5) Выход"
    
    local choice
    read -p "Ваш выбор [1-5]: " choice
    
    case "$choice" in
        1)
            configure_root_profile
            ;;
        2)
            configure_current_user_profile
            ;;
        3)
            configure_root_profile
            configure_current_user_profile
            ;;
        4)
            create_admin_scripts
            ;;
        5)
            log_info "Выход из программы"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            exit 1
            ;;
    esac
    
    log_success "=== НАСТРОЙКА ПОЛЬЗОВАТЕЛЕЙ ЗАВЕРШЕНА ==="
    log_info "Для применения изменений выйдите и войдите в систему заново"
}

# Запуск главной функции если скрипт вызывается напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_user_setup "$@"
fi