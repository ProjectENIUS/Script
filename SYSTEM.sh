#!/bin/bash

# =============================================================================
# Ubuntu Master Configuration & Management Script
# Мастер-скрипт для полного управления и настройки Ubuntu
# Version: 2.0
# =============================================================================

set -euo pipefail

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$HOME/.ubuntu-master"
readonly BACKUP_DIR="$CONFIG_DIR/backups/$(date +%Y%m%d-%H%M%S)"
readonly LOG_FILE="$CONFIG_DIR/logs/ubuntu-master.log"
readonly THEMES_DIR="$CONFIG_DIR/themes"
readonly SCRIPTS_DIR="$CONFIG_DIR/scripts"

# Цвета для красивого вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Эмодзи для интерфейса
readonly EMOJI_ROCKET="🚀"
readonly EMOJI_GEAR="⚙️"
readonly EMOJI_STAR="⭐"
readonly EMOJI_FIRE="🔥"
readonly EMOJI_DIAMOND="💎"
readonly EMOJI_MAGIC="✨"
readonly EMOJI_CROWN="👑"
readonly EMOJI_LIGHTNING="⚡"

# =============================================================================
# Функции логирования и интерфейса
# =============================================================================

setup_environment() {
    # Создание необходимых директорий
    mkdir -p "$CONFIG_DIR"/{logs,backups,themes,scripts,configs}
    mkdir -p "$BACKUP_DIR"
    
    # Настройка логирования
    exec 19>&2
    exec 2> >(tee -a "$LOG_FILE")
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Ubuntu Master Script v$SCRIPT_VERSION started" >> "$LOG_FILE"
}

log() {
    echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                    ${EMOJI_CROWN} UBUNTU MASTER CONFIGURATION ${EMOJI_CROWN}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${WHITE}                          Полное управление системой                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${WHITE}                                Version $SCRIPT_VERSION                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    local title="$1"
    local emoji="$2"
    echo ""
    echo -e "${CYAN}${BOLD}$emoji ═══ $title ═══${NC}"
    echo ""
}

success() {
    echo -e "${GREEN}✅ $*${NC}"
    log "SUCCESS: $*"
}

error() {
    echo -e "${RED}❌ $*${NC}"
    log "ERROR: $*"
}

warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
    log "WARNING: $*"
}

info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
    log "INFO: $*"
}

prompt() {
    echo -e "${YELLOW}❓ $1${NC}"
    read -p "$(echo -e "${WHITE}➤ ${NC}")" response
    echo "$response"
}

yes_no() {
    local question="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$(echo -e "${YELLOW}❓ $question [Y/n]: ${NC}")" response
            response=${response:-y}
        else
            read -p "$(echo -e "${YELLOW}❓ $question [y/N]: ${NC}")" response
            response=${response:-n}
        fi
        
        case "${response,,}" in
            y|yes|да|д) return 0 ;;
            n|no|нет|н) return 1 ;;
            *) echo -e "${RED}Пожалуйста, введите y или n${NC}" ;;
        esac
    done
}

show_progress() {
    local current=$1
    local total=$2
    local task="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[${GREEN}"
    printf "%*s" $filled | tr ' ' '█'
    printf "${GRAY}"
    printf "%*s" $empty | tr ' ' '░'
    printf "${BLUE}] ${WHITE}%d%% ${CYAN}%s${NC}" $percent "$task"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# =============================================================================
# Главное меню
# =============================================================================

show_main_menu() {
    print_header
    
    echo -e "${WHITE}Выберите категорию настроек:${NC}"
    echo ""
    echo -e "${CYAN} 1)${NC} ${EMOJI_MAGIC} Красивый терминал и интерфейс"
    echo -e "${CYAN} 2)${NC} ${EMOJI_GEAR} Системные настройки и оптимизация"
    echo -e "${CYAN} 3)${NC} ${EMOJI_FIRE} Разработческая среда"
    echo -e "${CYAN} 4)${NC} ${EMOJI_DIAMOND} Мультимедиа и графика"
    echo -e "${CYAN} 5)${NC} ${EMOJI_LIGHTNING} Сеть и безопасность"
    echo -e "${CYAN} 6)${NC} ${EMOJI_STAR} Полезные утилиты и инструменты"
    echo -e "${CYAN} 7)${NC} ${EMOJI_ROCKET} Автоматизация и скрипты"
    echo -e "${CYAN} 8)${NC} ${EMOJI_CROWN} Игры и развлечения"
    echo -e "${CYAN} 9)${NC} ${GRAY} Восстановление и резервные копии"
    echo -e "${CYAN}10)${NC} ${RED} Диагностика и мониторинг"
    echo ""
    echo -e "${GRAY} 0)${NC} Выход"
    echo ""
    
    local choice
    choice=$(prompt "Ваш выбор")
    
    case "$choice" in
        1) terminal_beautification_menu ;;
        2) system_optimization_menu ;;
        3) development_environment_menu ;;
        4) multimedia_graphics_menu ;;
        5) network_security_menu ;;
        6) utilities_tools_menu ;;
        7) automation_scripts_menu ;;
        8) games_entertainment_menu ;;
        9) backup_recovery_menu ;;
        10) diagnostics_monitoring_menu ;;
        0) exit_script ;;
        *) 
            error "Неверный выбор"
            sleep 2
            show_main_menu
            ;;
    esac
}

# =============================================================================
# 1. Красивый терминал и интерфейс
# =============================================================================

terminal_beautification_menu() {
    print_section "КРАСИВЫЙ ТЕРМИНАЛ И ИНТЕРФЕЙС" "$EMOJI_MAGIC"
    
    echo -e "${WHITE}Настройка внешнего вида терминала:${NC}"
    echo ""
    echo -e "${CYAN} 1)${NC} Установка и настройка Oh My Zsh"
    echo -e "${CYAN} 2)${NC} Установка PowerLevel10k theme"
    echo -e "${CYAN} 3)${NC} Настройка цветовых схем терминала"
    echo -e "${CYAN} 4)${NC} Установка Nerd Fonts"
    echo -e "${CYAN} 5)${NC} Настройка tmux с красивым интерфейсом"
    echo -e "${CYAN} 6)${NC} Кастомизация GNOME/KDE"
    echo -e "${CYAN} 7)${NC} Установка conky (системный монитор)"
    echo -e "${CYAN} 8)${NC} Анимации и эффекты терминала"
    echo -e "${CYAN} 9)${NC} Полная кастомизация (все сразу)"
    echo ""
    echo -e "${GRAY} 0)${NC} Назад в главное меню"
    
    local choice
    choice=$(prompt "Ваш выбор")
    
    case "$choice" in
        1) install_oh_my_zsh ;;
        2) install_powerlevel10k ;;
        3) setup_color_schemes ;;
        4) install_nerd_fonts ;;
        5) setup_beautiful_tmux ;;
        6) customize_desktop_environment ;;
        7) install_conky ;;
        8) setup_terminal_animations ;;
        9) full_terminal_customization ;;
        0) show_main_menu ;;
        *) 
            error "Неверный выбор"
            sleep 2
            terminal_beautification_menu
            ;;
    esac
}

install_oh_my_zsh() {
    print_section "УСТАНОВКА OH MY ZSH" "🐚"
    
    # Установка zsh
    info "Установка Zsh..."
    sudo apt update && sudo apt install -y zsh curl git
    
    # Установка Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Установка Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Установка популярных плагинов
    install_zsh_plugins
    
    # Настройка .zshrc
    setup_zshrc_config
    
    # Смена оболочки по умолчанию
    if yes_no "Сменить оболочку по умолчанию на Zsh?"; then
        sudo chsh -s $(which zsh) $(whoami)
        success "Zsh установлен как оболочка по умолчанию"
    fi
    
    success "Oh My Zsh установлен и настроен!"
    
    if yes_no "Перезапустить терминал для применения изменений?"; then
        exec zsh
    fi
    
    terminal_beautification_menu
}

install_zsh_plugins() {
    info "Установка плагинов Zsh..."
    
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    
    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting"
    fi
    
    # zsh-completions
    if [[ ! -d "$plugins_dir/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions "$plugins_dir/zsh-completions"
    fi
    
    # autojump
    sudo apt install -y autojump
    
    # fzf
    if [[ ! -d "$HOME/.fzf" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
    fi
    
    success "Плагины Zsh установлены"
}

setup_zshrc_config() {
    info "Настройка .zshrc..."
    
    # Резервная копия
    [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$BACKUP_DIR/zshrc.backup"
    
    cat > "$HOME/.zshrc" << 'EOF'
# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"

# Тема
ZSH_THEME="agnoster"

# Плагины
plugins=(
    git
    sudo
    docker
    docker-compose
    npm
    yarn
    pip
    python
    node
    autojump
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    colored-man-pages
    command-not-found
    extract
    web-search
    copyfile
    copydir
    history
    jsontools
)

source $ZSH/oh-my-zsh.sh

# Пользовательские настройки
export EDITOR='vim'
export LANG=en_US.UTF-8

# Алиасы
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias c='clear'
alias h='history'
alias j='jobs -l'
alias which='type -a'
alias grep='grep --color'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Git алиасы
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Системные алиасы
alias df='df -h'
alias du='du -ch'
alias free='free -m'
alias ps='ps auxf'
alias top='htop'
alias ports='netstat -tuln'

# Функции
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# FZF integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Autojump
[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh

# Custom prompt
autoload -U promptinit; promptinit
prompt agnoster

# История
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt incappendhistory

# Автодополнение
autoload -U compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
EOF

    success ".zshrc настроен"
}

install_powerlevel10k() {
    print_section "УСТАНОВКА POWERLEVEL10K" "⚡"
    
    # Установка PowerLevel10k
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
        info "Установка PowerLevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    fi
    
    # Установка Nerd Font
    install_nerd_fonts
    
    # Настройка темы в .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
    fi
    
    # Создание базовой конфигурации p10k
    create_p10k_config
    
    success "PowerLevel10k установлен!"
    info "Запустите 'p10k configure' для настройки темы"
    
    terminal_beautification_menu
}

create_p10k_config() {
    cat > "$HOME/.p10k.zsh" << 'EOF'
# PowerLevel10k Configuration
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'
  autoload -Uz is-at-least && is-at-least 5.1 || return

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon                 # os identifier
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )
  
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
    direnv                  # direnv status
    asdf                    # asdf version manager
    virtualenv              # python virtual environment
    anaconda                # conda environment
    pyenv                   # python environment
    goenv                   # go environment
    nodenv                  # node.js version
    nvm                     # node.js version
    nodeenv                 # node.js environment
    rbenv                   # ruby version
    rvm                     # ruby version manager
    fvm                     # flutter version management
    luaenv                  # lua version
    jenv                    # java version
    plenv                   # perl version
    phpenv                  # php version
    scalaenv                # scala version
    haskell_stack           # haskell tool stack
    kubecontext             # current kubernetes context
    terraform               # terraform workspace
    aws                     # aws profile
    aws_eb_env              # aws elastic beanstalk environment
    azure                   # azure account name
    gcloud                  # google cloud cli account and project
    google_app_cred         # google application credentials
    context                 # user@hostname
    nordvpn                 # nordvpn connection status
    ranger                  # ranger shell
    nnn                     # nnn shell
    vim_shell               # vim shell indicator
    midnight_commander      # midnight commander shell
    nix_shell               # nix shell
    vi_mode                 # vi mode
    todo                    # todo items
    timewarrior             # timewarrior tracking status
    taskwarrior             # taskwarrior task count
    time                    # current time
    newline                 # \n
  )

  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=
  typeset -g POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_BACKGROUND=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_GAP_BACKGROUND=
  if [[ $POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR != ' ' ]]; then
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=242
    typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_FIRST_SEGMENT_END_SYMBOL='%{%}'
    typeset -g POWERLEVEL9K_EMPTY_LINE_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='%{%}'
  fi
  
  # OS identifier color
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=232
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=7
  
  # Prompt character
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  
  # Directory
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=4
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=254
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=250
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=255
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  local anchor_files=(
    .bzr
    .citc
    .git
    .hg
    .node-version
    .python-version
    .go-version
    .ruby-version
    .lua-version
    .java-version
    .perl-version
    .php-version
    .tool-versions
    .shims
    .svn
    .terraform
    CVS
    Cargo.toml
    composer.json
    go.mod
    package.json
    stack.yaml
  )
  typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER="(${(j:|:)anchor_files})"
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v2

  # VCS (Git)
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'
  function my_git_formatter() {
    emulate -L zsh
    if [[ -n $P9K_CONTENT ]]; then
      typeset -g my_git_format=$P9K_CONTENT
      return 0
    fi
    if (( $1 )); then
      P9K_CONTENT+='%76F⇣'${1}'%f'
    fi
    if (( $2 )); then
      P9K_CONTENT+='%76F⇡'${2}'%f'
    fi
    if (( $3 )); then
      P9K_CONTENT+='%196F●'${3}'%f'
    fi
    if (( $4 )); then
      P9K_CONTENT+='%178F●'${4}'%f'
    fi
    if (( $5 )); then
      P9K_CONTENT+='%178F●'${5}'%f'
    fi
    if (( $6 )); then
      P9K_CONTENT+='%196F●'${6}'%f'
    fi
    typeset -g my_git_format=$P9K_CONTENT
  }
  functions -M my_git_formatter 2>/dev/null
  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(${P9K_VCS_COMMITS_BEHIND:-0}, ${P9K_VCS_COMMITS_AHEAD:-0}, ${P9K_VCS_STAGED:-0}, ${P9K_VCS_UNSTAGED:-0}, ${P9K_VCS_UNTRACKED:-0}, ${P9K_VCS_CONFLICTED:-0})))+"${my_git_format}"}${P9K_VCS_CLEAN:+" %76F✓"}'
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR=76
  typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_COLOR=244
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3

  # Status
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND=
  typeset -g POWERLEVEL9K_STATUS_OK_VISUAL_IDENTIFIER_EXPANSION='✓'
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✗'

  # Time
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_BACKGROUND=
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false
}

(( ! p10k_config_opts[(I)no_aliases] )) && 'builtin' 'setopt' 'aliases'
(( ! p10k_config_opts[(I)no_sh_glob] )) && 'builtin' 'setopt' 'sh_glob'
(( ! p10k_config_opts[(I)no_brace_expand] )) && 'builtin' 'setopt' 'brace_expand'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
    
    # Добавление в .zshrc
    echo "" >> "$HOME/.zshrc"
    echo "# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh." >> "$HOME/.zshrc"
    echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$HOME/.zshrc"
    
    success "Конфигурация PowerLevel10k создана"
}

install_nerd_fonts() {
    print_section "УСТАНОВКА NERD FONTS" "🔤"
    
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    
    info "Загрузка популярных Nerd Fonts..."
    
    local fonts=(
        "FiraCode"
        "Hack"
        "JetBrainsMono"
        "SourceCodePro"
        "UbuntuMono"
        "DejaVuSansMono"
    )
    
    for font in "${fonts[@]}"; do
        if [[ ! -d "$fonts_dir/$font" ]]; then
            info "Загрузка $font..."
            wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/$font.zip" -O "/tmp/$font.zip"
            unzip -q "/tmp/$font.zip" -d "$fonts_dir/$font"
            rm "/tmp/$font.zip"
            show_progress $((${#fonts[@]} - ${#fonts[@]})) ${#fonts[@]} "Установка $font"
        fi
    done
    
    # Обновление кэша шрифтов
    fc-cache -fv
    
    success "Nerd Fonts установлены"
    info "Настройте терминал для использования одного из установленных шрифтов:"
    for font in "${fonts[@]}"; do
        echo "  • $font Nerd Font"
    done
    
    terminal_beautification_menu
}

setup_color_schemes() {
    print_section "ЦВЕТОВЫЕ СХЕМЫ ТЕРМИНАЛА" "🎨"
    
    echo -e "${WHITE}Выберите цветовую схему:${NC}"
    echo ""
    echo -e "${CYAN} 1)${NC} Dracula"
    echo -e "${CYAN} 2)${NC} Gruvbox"
    echo -e "${CYAN} 3)${NC} Nord"
    echo -e "${CYAN} 4)${NC} One Dark"
    echo -e "${CYAN} 5)${NC} Solarized Dark"
    echo -e "${CYAN} 6)${NC} Material Theme"
    echo -e "${CYAN} 7)${NC} Все схемы (установить все)"
    echo ""
    echo -e "${GRAY} 0)${NC} Назад"
    
    local choice
    choice=$(prompt "Ваш выбор")
    
    case "$choice" in
        1) install_color_scheme "dracula" ;;
        2) install_color_scheme "gruvbox" ;;
        3) install_color_scheme "nord" ;;
        4) install_color_scheme "onedark" ;;
        5) install_color_scheme "solarized" ;;
        6) install_color_scheme "material" ;;
        7) install_all_color_schemes ;;
        0) terminal_beautification_menu ;;
        *) 
            error "Неверный выбор"
            sleep 2
            setup_color_schemes
            ;;
    esac
}

install_color_scheme() {
    local scheme="$1"
    
    info "Установка цветовой схемы: $scheme"
    
    # Создание директории для схем
    mkdir -p "$THEMES_DIR/terminal"
    
    case "$scheme" in
        "dracula")
            # Dracula theme
            wget -q "https://raw.githubusercontent.com/dracula/gnome-terminal/master/dracula.sh" -O "/tmp/dracula.sh"
            chmod +x "/tmp/dracula.sh"
            /tmp/dracula.sh
            ;;
        "gruvbox")
            # Gruvbox theme
            git clone https://github.com/Mayccoll/Gogh.git "$THEMES_DIR/terminal/gogh"
            export TERMINAL=gnome-terminal
            bash "$THEMES_DIR/terminal/gogh/themes/gruvbox-dark.sh"
            ;;
        "nord")
            # Nord theme
            git clone https://github.com/arcticicestudio/nord-gnome-terminal.git "$THEMES_DIR/terminal/nord"
            bash "$THEMES_DIR/terminal/nord/src/nord.sh"
            ;;
        "onedark")
            # One Dark theme
            git clone https://github.com/denysdovhan/one-gnome-terminal "$THEMES_DIR/terminal/onedark"
            bash "$THEMES_DIR/terminal/onedark/one-dark.sh"
            ;;
        "solarized")
            # Solarized theme
            git clone https://github.com/Anthony25/gnome-terminal-colors-solarized.git "$THEMES_DIR/terminal/solarized"
            bash "$THEMES_DIR/terminal/solarized/install.sh"
            ;;
        "material")
            # Material theme
            git clone https://github.com/Mayccoll/Gogh.git "$THEMES_DIR/terminal/gogh"
            export TERMINAL=gnome-terminal
            bash "$THEMES_DIR/terminal/gogh/themes/material.sh"
            ;;
    esac
    
    success "Цветовая схема $scheme установлена"
    
    setup_color_schemes
}

setup_beautiful_tmux() {
    print_section "КРАСИВЫЙ TMUX" "🖥️"
    
    # Установка tmux
    sudo apt install -y tmux
    
    # Установка Tmux Plugin Manager
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    
    # Создание красивой конфигурации tmux
    create_tmux_config
    
    success "Красивый tmux настроен!"
    info "Нажмите prefix + I в tmux для установки плагинов"
    
    terminal_beautification_menu
}

create_tmux_config() {
    cat > "$HOME/.tmux.conf" << 'EOF'
# =============================================================================
# Beautiful Tmux Configuration
# =============================================================================

# Основные настройки
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g history-limit 50000
set -g display-time 4000
set -g status-interval 5
set -g focus-events on
set -sg escape-time 10

# Мышь
set -g mouse on

# Prefix key
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Разделение окон
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# Навигация между панелями (vim-style)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Изменение размера панелей
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Копирование (vim-style)
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
bind -T copy-mode-vi r send-keys -X rectangle-toggle

# Перезагрузка конфигурации
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# =============================================================================
# ДИЗАЙН И СТАТУСНАЯ СТРОКА
# =============================================================================

# Цвета статусной строки
set -g status-bg "#1e1e2e"
set -g status-fg "#cdd6f4"

# Настройки окон
setw -g window-status-current-style "fg=#1e1e2e,bg=#89b4fa,bold"
setw -g window-status-current-format " #I:#W#F "
setw -g window-status-style "fg=#cdd6f4,bg=#313244"
setw -g window-status-format " #I:#W#F "

# Панели
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#89b4fa"

# Сообщения
set -g message-style "fg=#1e1e2e,bg=#f9e2af"
set -g message-command-style "fg=#1e1e2e,bg=#f9e2af"

# Статусная строка
set -g status-position bottom
set -g status-justify left
set -g status-left-length 50
set -g status-right-length 150

# Левая часть статусной строки
set -g status-left "#[fg=#1e1e2e,bg=#89b4fa,bold] ❐ #S #[fg=#89b4fa,bg=#313244]#[fg=#cdd6f4,bg=#313244] #I:#P #[fg=#313244,bg=#1e1e2e]"

# Правая часть статусной строки
set -g status-right "#[fg=#313244,bg=#1e1e2e]#[fg=#cdd6f4,bg=#313244] %Y-%m-%d #[fg=#89b4fa,bg=#313244]#[fg=#1e1e2e,bg=#89b4fa,bold] %H:%M:%S "

# =============================================================================
# ПЛАГИНЫ
# =============================================================================

# Список плагинов
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-open'
set -g @plugin 'tmux-plugins/tmux-copycat'
set -g @plugin 'christoomey/vim-tmux-navigator'

# Настройки плагинов
set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# Инициализация TPM (должно быть в конце файла)
run '~/.tmux/plugins/tpm/tpm'
EOF

    success ".tmux.conf создан с красивым дизайном"
}

full_terminal_customization() {
    print_section "ПОЛНАЯ КАСТОМИЗАЦИЯ ТЕРМИНАЛА" "$EMOJI_CROWN"
    
    info "Начинаем полную кастомизацию терминала..."
    
    local total_steps=8
    local current_step=0
    
    # Шаг 1: Oh My Zsh
    ((current_step++))
    show_progress $current_step $total_steps "Установка Oh My Zsh"
    install_oh_my_zsh_silent
    
    # Шаг 2: PowerLevel10k
    ((current_step++))
    show_progress $current_step $total_steps "Установка PowerLevel10k"
    install_powerlevel10k_silent
    
    # Шаг 3: Nerd Fonts
    ((current_step++))
    show_progress $current_step $total_steps "Установка Nerd Fonts"
    install_nerd_fonts_silent
    
    # Шаг 4: Tmux
    ((current_step++))
    show_progress $current_step $total_steps "Настройка Tmux"
    setup_beautiful_tmux_silent
    
    # Шаг 5: Цветовые схемы
    ((current_step++))
    show_progress $current_step $total_steps "Установка цветовых схем"
    install_all_color_schemes_silent
    
    # Шаг 6: Дополнительные утилиты
    ((current_step++))
    show_progress $current_step $total_steps "Установка утилит"
    install_terminal_utilities
    
    # Шаг 7: Настройка vim
    ((current_step++))
    show_progress $current_step $total_steps "Настройка Vim"
    setup_vim_configuration
    
    # Шаг 8: Финальная настройка
    ((current_step++))
    show_progress $current_step $total_steps "Финальная настройка"
    finalize_terminal_setup
    
    echo ""
    success "Полная кастомизация терминала завершена!"
    
    echo ""
    echo -e "${CYAN}${BOLD}🎉 Поздравляем! Ваш терминал теперь выглядит потрясающе!${NC}"
    echo ""
    echo -e "${WHITE}Установлено:${NC}"
    echo -e "  ✅ Oh My Zsh с плагинами"
    echo -e "  ✅ PowerLevel10k тема"
    echo -e "  ✅ Nerd Fonts"
    echo -e "  ✅ Красивый tmux"
    echo -e "  ✅ Цветовые схемы"
    echo -e "  ✅ Дополнительные утилиты"
    echo -e "  ✅ Настроенный Vim"
    echo ""
    echo -e "${YELLOW}Для применения всех изменений:${NC}"
    echo -e "  1. Перезапустите терминал"
    echo -e "  2. Выберите Nerd Font в настройках терминала"
    echo -e "  3. Запустите 'p10k configure' для настройки темы"
    echo ""
    
    if yes_no "Перезапустить терминал сейчас?" "y"; then
        exec zsh
    fi
    
    terminal_beautification_menu
}

# =============================================================================
# 2. Системные настройки и оптимизация
# =============================================================================

system_optimization_menu() {
    print_section "СИСТЕМНЫЕ НАСТРОЙКИ И ОПТИМИЗАЦИЯ" "$EMOJI_GEAR"
    
    echo -e "${WHITE}Выберите категорию оптимизации:${NC}"
    echo ""
    echo -e "${CYAN} 1)${NC} Оптимизация производительности"
    echo -e "${CYAN} 2)${NC} Управление службами"
    echo -e "${CYAN} 3)${NC} Настройка swap и памяти"
    echo -e "${CYAN} 4)${NC} Оптимизация SSD"
    echo -e "${CYAN} 5)${NC} Очистка системы"
    echo -e "${CYAN} 6)${NC} Настройка ядра"
    echo -e "${CYAN} 7)${NC} Управление автозапуском"
    echo -e "${CYAN} 8)${NC} Настройка файловой системы"
    echo -e "${CYAN} 9)${NC} Полная оптимизация"
    echo ""
    echo -e "${GRAY} 0)${NC} Назад в главное меню"
    
    local choice
    choice=$(prompt "Ваш выбор")
    
    case "$choice" in
        1) performance_optimization ;;
        2) service_management ;;
        3) memory_swap_optimization ;;
        4) ssd_optimization ;;
        5) system_cleanup ;;
        6) kernel_optimization ;;
        7) startup_management ;;
        8) filesystem_optimization ;;
        9) full_system_optimization ;;
        0) show_main_menu ;;
        *) 
            error "Неверный выбор"
            sleep 2
            system_optimization_menu
            ;;
    esac
}

performance_optimization() {
    print_section "ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ" "🚀"
    
    info "Начинаем оптимизацию производительности системы..."
    
    # Установка пакетов для мониторинга
    sudo apt install -y htop iotop iftop nethogs sysstat
    
    # Настройка swappiness
    setup_swappiness
    
    # Настройка планировщика I/O
    setup_io_scheduler
    
    # Настройка сетевых параметров
    optimize_network_settings
    
    # Настройка файловой системы
    optimize_filesystem_settings
    
    success "Оптимизация производительности завершена"
    system_optimization_menu
}

setup_swappiness() {
    info "Настройка swappiness..."
    
    local current_swappiness=$(cat /proc/sys/vm/swappiness)
    echo "Текущее значение swappiness: $current_swappiness"
    
    local new_swappiness
    new_swappiness=$(prompt "Введите новое значение swappiness (рекомендуется 10 для SSD, 60 для HDD)")
    
    if [[ "$new_swappiness" =~ ^[0-9]+$ ]] && [[ $new_swappiness -ge 0 ]] && [[ $new_swappiness -le 100 ]]; then
        echo "vm.swappiness=$new_swappiness" | sudo tee -a /etc/sysctl.conf
        sudo sysctl vm.swappiness=$new_swappiness
        success "Swappiness установлен в $new_swappiness"
    else
        error "Неверное значение swappiness"
    fi
}

# Продолжу создание остальных функций...

# =============================================================================
# Запуск скрипта
# =============================================================================

main() {
    # Проверка прав
    if [[ $EUID -eq 0 ]]; then
        error "Не запускайте этот скрипт от root!"
        error "Используйте: ./ubuntu_master.sh"
        exit 1
    fi
    
    # Настройка окружения
    setup_environment
    
    # Приветствие
    print_header
    
    echo -e "${WHITE}Добро пожаловать в Ubuntu Master Configuration!${NC}"
    echo ""
    echo -e "${CYAN}Этот скрипт поможет вам:${NC}"
    echo -e "  ${EMOJI_MAGIC} Создать красивый и функциональный терминал"
    echo -e "  ${EMOJI_GEAR} Оптимизировать производительность системы"
    echo -e "  ${EMOJI_FIRE} Настроить среду разработки"
    echo -e "  ${EMOJI_DIAMOND} Установить мультимедиа и графические инструменты"
    echo -e "  ${EMOJI_LIGHTNING} Настроить безопасность и сеть"
    echo -e "  ${EMOJI_STAR} И многое другое!"
    echo ""
    
    if yes_no "Продолжить настройку?" "y"; then
        show_main_menu
    else
        info "До свидания!"
        exit 0
    fi
}

# Запуск основной функции
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi