#!/bin/bash

# Профессиональный скрипт для работы с John the Ripper
# Advanced John the Ripper Management Script v2.0

set -e

# Цвета и стили
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Конфигурация
JOHN_DIR="/opt/john-pro"
WORK_DIR="$(pwd)/john-workspace"
SESSION_DIR="$WORK_DIR/sessions"
WORDLIST_DIR="$WORK_DIR/wordlists"
RESULTS_DIR="$WORK_DIR/results"
LOG_DIR="$WORK_DIR/logs"

# Логирование
log() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/john.log"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/john.log"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/john.log"; }
success() { echo -e "${BOLD}${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/john.log"; }

# Создание рабочих директорий
setup_workspace() {
    log "=== НАСТРОЙКА РАБОЧЕГО ПРОСТРАНСТВА ==="
    
    mkdir -p "$WORK_DIR" "$SESSION_DIR" "$WORDLIST_DIR" "$RESULTS_DIR" "$LOG_DIR"
    
    log "Рабочие директории созданы:"
    echo "  - Рабочая папка: $WORK_DIR"
    echo "  - Сессии: $SESSION_DIR"
    echo "  - Словари: $WORDLIST_DIR"
    echo "  - Результаты: $RESULTS_DIR"
    echo "  - Логи: $LOG_DIR"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Некоторые функции требуют права root"
        warning "Запустите с sudo для полного функционала"
        SUDO_PREFIX=""
    else
        SUDO_PREFIX=""
    fi
}

# Определение John the Ripper
detect_john() {
    log "=== ПОИСК JOHN THE RIPPER ==="
    
    # Возможные пути
    JOHN_PATHS=(
        "/usr/bin/john"
        "/usr/local/bin/john"
        "/opt/john/run/john"
        "/opt/john-the-ripper/run/john"
        "$JOHN_DIR/run/john"
        "./john"
    )
    
    for path in "${JOHN_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            JOHN_BIN="$path"
            success "John найден: $JOHN_BIN"
            
            # Определяем версию
            if $JOHN_BIN --version >/dev/null 2>&1; then
                JOHN_VERSION=$($JOHN_BIN --version 2>/dev/null | head -1)
                log "Версия: $JOHN_VERSION"
            else
                log "Версия: определить не удалось"
            fi
            return 0
        fi
    done
    
    error "John the Ripper не найден!"
    return 1
}

# Установка John the Ripper
install_john_menu() {
    echo -e "${BLUE}=== УСТАНОВКА JOHN THE RIPPER ===${NC}"
    echo ""
    echo "Выберите метод установки:"
    echo "1) Быстрая установка из репозитория"
    echo "2) Компиляция Jumbo Edition (рекомендуется)"
    echo "3) Скачать готовую версию"
    echo "4) Пропустить установку"
    
    read -p "Введите номер (1-4): " install_choice
    
    case $install_choice in
        1) install_john_repo ;;
        2) install_john_jumbo ;;
        3) download_john_prebuilt ;;
        4) log "Установка пропущена" ;;
        *) error "Неверный выбор" ;;
    esac
}

# Быстрая установка из репозитория
install_john_repo() {
    log "Установка John из репозитория..."
    
    if [ "$EUID" -eq 0 ]; then
        apt-get update -qq
        apt-get install -y john
        success "John установлен из репозитория"
    else
        error "Нужны права root для установки"
    fi
}

# Компиляция Jumbo Edition
install_john_jumbo() {
    log "=== КОМПИЛЯЦИЯ JOHN JUMBO EDITION ==="
    
    if [ "$EUID" -ne 0 ]; then
        error "Нужны права root для установки зависимостей"
        return 1
    fi
    
    # Установка зависимостей
    log "Установка зависимостей..."
    apt-get update -qq
    apt-get install -y \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        yasm \
        pkg-config \
        libgmp-dev \
        libpcap-dev \
        libbz2-dev \
        git \
        wget \
        curl >/dev/null 2>&1
    
    # Создание директории
    mkdir -p "$JOHN_DIR"
    cd "$JOHN_DIR"
    
    # Клонирование репозитория
    log "Клонирование John the Ripper Jumbo..."
    if [ -d "john" ]; then
        rm -rf john
    fi
    
    git clone https://github.com/openwall/john.git
    cd john/src
    
    # Конфигурация и компиляция
    log "Конфигурация и компиляция (это может занять время)..."
    ./configure --enable-openmp --enable-mpi
    make -s clean
    make -s -j$(nproc)
    
    # Создание символической ссылки
    ln -sf "$JOHN_DIR/john/run/john" /usr/local/bin/john
    
    success "John Jumbo Edition скомпилирован и установлен!"
    JOHN_BIN="$JOHN_DIR/john/run/john"
}

# Скачивание готовой версии
download_john_prebuilt() {
    log "=== СКАЧИВАНИЕ ГОТОВОЙ ВЕРСИИ JOHN ==="
    
    mkdir -p "$JOHN_DIR"
    cd "$JOHN_DIR"
    
    # Определяем архитектуру
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) JOHN_ARCH="linux-x86-64" ;;
        i*86) JOHN_ARCH="linux-x86" ;;
        *) error "Неподдерживаемая архитектура: $ARCH"; return 1 ;;
    esac
    
    log "Скачивание для архитектуры: $JOHN_ARCH"
    
    # Скачиваем последнюю версию
    JOHN_URL="https://www.openwall.com/john/k/john-1.9.0-jumbo-1-$JOHN_ARCH.tar.xz"
    
    if wget -q "$JOHN_URL"; then
        log "Распаковка..."
        tar -xf "john-1.9.0-jumbo-1-$JOHN_ARCH.tar.xz"
        
        # Находим исполняемый файл
        JOHN_BIN=$(find . -name "john" -type f -executable | head -1)
        
        if [ -n "$JOHN_BIN" ]; then
            chmod +x "$JOHN_BIN"
            ln -sf "$(realpath $JOHN_BIN)" /usr/local/bin/john
            success "John скачан и установлен!"
        else
            error "Исполняемый файл john не найден"
        fi
    else
        error "Не удалось скачать John"
    fi
}

# Подготовка хэшей
prepare_hashes() {
    echo -e "${BLUE}=== ПОДГОТОВКА ХЭШЕЙ ДЛЯ ВЗЛОМА ===${NC}"
    echo ""
    echo "Выберите источник хэшей:"
    echo "1) Извлечь из /etc/shadow (требует root)"
    echo "2) Создать тестовые хэши"
    echo "3) Загрузить из файла"
    echo "4) Извлечь хэши конкретных пользователей"
    echo "5) Назад"
    
    read -p "Введите номер (1-5): " hash_choice
    
    case $hash_choice in
        1) extract_shadow_hashes ;;
        2) create_test_hashes ;;
        3) load_hash_file ;;
        4) extract_specific_users ;;
        5) return ;;
        *) error "Неверный выбор" ;;
    esac
}

# Извлечение из shadow
extract_shadow_hashes() {
    if [ "$EUID" -ne 0 ]; then
        error "Требуются права root для чтения /etc/shadow"
        return 1
    fi
    
    log "Извлечение хэшей из /etc/shadow..."
    
    # Исключаем системные аккаунты
    awk -F: '($3 >= 1000) && ($2 !~ /^[!*]/) {print $1":"$2}' /etc/shadow > "$WORK_DIR/shadow_hashes.txt"
    
    local count=$(wc -l < "$WORK_DIR/shadow_hashes.txt")
    success "Извлечено $count хэшей пользователей в shadow_hashes.txt"
    
    # Показываем пользователей
    echo -e "\n${YELLOW}Найденные пользователи:${NC}"
    awk -F: '{print "  - " $1}' "$WORK_DIR/shadow_hashes.txt"
}

# Создание тестовых хэшей
create_test_hashes() {
    log "=== СОЗДАНИЕ ТЕСТОВЫХ ХЭШЕЙ ==="
    
    # Создаем тестовых пользователей если нужно
    if [ "$EUID" -eq 0 ]; then
        log "Создание тестовых пользователей..."
        
        # Создаем пользователей с разными паролями
        declare -A test_users=(
            ["weak_user"]="123"
            ["medium_user"]="Password123"
            ["strong_user"]="Sup3r!Str0ng#P@ssw0rd"
            ["phrase_user"]="correct horse battery staple"
        )
        
        for user in "${!test_users[@]}"; do
            password="${test_users[$user]}"
            
            # Удаляем если существует
            userdel -r "$user" 2>/dev/null || true
            
            # Создаем пользователя
            useradd -m -s /bin/bash "$user"
            echo "$user:$password" | chpasswd
            
            log "Создан пользователь: $user (пароль: $password)"
        done
        
        # Извлекаем хэши
        for user in "${!test_users[@]}"; do
            grep "^$user:" /etc/shadow >> "$WORK_DIR/test_hashes.txt"
        done
        
        success "Тестовые хэши созданы в test_hashes.txt"
    else
        # Создаем примеры хэшей вручную
        log "Создание примеров хэшей..."
        
        cat > "$WORK_DIR/test_hashes.txt" << 'EOF'
weak_user:$6$salt$IxDD3jeSOb5eB1CX5LBsqZFVkJdido3OUILO5Ifz5iwMuTS4XMS130MTSuDDl3aCI6WouIL9AjRbLCelDCy.g.:18849:0:99999:7:::
medium_user:$6$salt$Jf8z3Qb9L3kM5n7P1s4T6u8V2w5X9y1A3c6E8f0H2j5K7l9M1n4P6r8S0t3U5v7W9x1Y3z5A7b9C1d3E5f7G9h1I:18849:0:99999:7:::
EOF
        
        log "Примеры хэшей созданы в test_hashes.txt"
    fi
}

# Загрузка из файла
load_hash_file() {
    echo -n "Введите путь к файлу с хэшами: "
    read hash_file
    
    if [ -f "$hash_file" ]; then
        cp "$hash_file" "$WORK_DIR/loaded_hashes.txt"
        local count=$(wc -l < "$WORK_DIR/loaded_hashes.txt")
        success "Загружено $count хэшей из $hash_file"
    else
        error "Файл не найден: $hash_file"
    fi
}

# Извлечение конкретных пользователей
extract_specific_users() {
    if [ "$EUID" -ne 0 ]; then
        error "Требуются права root"
        return 1
    fi
    
    echo -n "Введите имена пользователей через пробел: "
    read -a users
    
    > "$WORK_DIR/specific_hashes.txt"
    
    for user in "${users[@]}"; do
        if grep "^$user:" /etc/shadow >> "$WORK_DIR/specific_hashes.txt"; then
            log "Добавлен пользователь: $user"
        else
            warning "Пользователь не найден: $user"
        fi
    done
    
    local count=$(wc -l < "$WORK_DIR/specific_hashes.txt")
    success "Извлечено $count хэшей в specific_hashes.txt"
}

# Скачивание словарей
download_wordlists() {
    log "=== СКАЧИВАНИЕ СЛОВАРЕЙ ==="
    
    echo "Выберите словари для скачивания:"
    echo "1) RockYou (популярные пароли)"
    echo "2) SecLists (различные списки)"
    echo "3) Crackstation (большая коллекция)"
    echo "4) Все основные словари"
    echo "5) Пропустить"
    
    read -p "Введите номер (1-5): " wordlist_choice
    
    case $wordlist_choice in
        1) download_rockyou ;;
        2) download_seclists ;;
        3) download_crackstation ;;
        4) download_all_wordlists ;;
        5) log "Скачивание словарей пропущено" ;;
        *) error "Неверный выбор" ;;
    esac
}

# Скачивание RockYou
download_rockyou() {
    log "Скачивание словаря RockYou..."
    cd "$WORDLIST_DIR"
    
    if [ ! -f "rockyou.txt" ]; then
        # Скачиваем с нескольких источников
        ROCKYOU_URLS=(
            "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
            "https://github.com/danielmiessler/SecLists/raw/master/Passwords/Leaked-Databases/rockyou.txt.tar.gz"
        )
        
        for url in "${ROCKYOU_URLS[@]}"; do
            if wget -q "$url"; then
                if [[ "$url" == *.tar.gz ]]; then
                    tar -xzf rockyou.txt.tar.gz
                    rm rockyou.txt.tar.gz
                fi
                success "RockYou словарь скачан"
                return 0
            fi
        done
        
        warning "Не удалось скачать RockYou, создаем базовый словарь..."
        create_basic_wordlist
    else
        log "RockYou уже существует"
    fi
}

# Создание базового словаря
create_basic_wordlist() {
    log "Создание базового словаря..."
    
    cat > "$WORDLIST_DIR/basic.txt" << 'EOF'
123456
password
123456789
qwerty
abc123
Password
123123
admin
letmein
welcome
monkey
1234567890
123
password123
Password123
admin123
root
user
test
guest
123qwe
qwerty123
1q2w3e4r
asdfgh
zxcvbn
111111
000000
password1
123321
654321
qwertyuiop
1234567
12345678
123456a
Password1
admin1
EOF

    success "Базовый словарь создан: basic.txt"
}

# Скачивание SecLists
download_seclists() {
    log "Скачивание SecLists..."
    cd "$WORDLIST_DIR"
    
    if [ ! -d "SecLists" ]; then
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git
        success "SecLists скачан"
    else
        log "SecLists уже существует"
    fi
}

# Атаки на пароли
password_attacks() {
    echo -e "${BLUE}=== АТАКИ НА ПАРОЛИ ===${NC}"
    
    # Проверяем наличие John
    if ! detect_john; then
        error "John the Ripper не найден! Установите его сначала."
        return 1
    fi
    
    # Выбираем файл с хэшами
    select_hash_file
    
    if [ -z "$SELECTED_HASH_FILE" ]; then
        error "Файл с хэшами не выбран"
        return 1
    fi
    
    echo -e "\n${YELLOW}Выберите тип атаки:${NC}"
    echo "1) Быстрая атака (словарь + простые правила)"
    echo "2) Атака по словарю"
    echo "3) Перебор (brute force)"
    echo "4) Гибридная атака"
    echo "5) Инкрементальная атака"
    echo "6) Пользовательские правила"
    echo "7) Показать взломанные пароли"
    echo "8) Назад"
    
    read -p "Введите номер (1-8): " attack_choice
    
    case $attack_choice in
        1) quick_attack ;;
        2) dictionary_attack ;;
        3) brute_force_attack ;;
        4) hybrid_attack ;;
        5) incremental_attack ;;
        6) custom_rules_attack ;;
        7) show_cracked ;;
        8) return ;;
        *) error "Неверный выбор" ;;
    esac
}

# Выбор файла с хэшами
select_hash_file() {
    echo -e "\n${YELLOW}Доступные файлы с хэшами:${NC}"
    
    local hash_files=()
    local counter=1
    
    for file in "$WORK_DIR"/*.txt; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file")
            local count=$(wc -l < "$file" 2>/dev/null || echo "0")
            echo "$counter) $basename ($count хэшей)"
            hash_files+=("$file")
            ((counter++))
        fi
    done
    
    if [ ${#hash_files[@]} -eq 0 ]; then
        error "Файлы с хэшами не найдены. Создайте их сначала."
        return 1
    fi
    
    echo "$counter) Указать другой файл"
    
    read -p "Выберите файл: " file_choice
    
    if [ "$file_choice" -gt 0 ] && [ "$file_choice" -le ${#hash_files[@]} ]; then
        SELECTED_HASH_FILE="${hash_files[$((file_choice-1))]}"
        success "Выбран файл: $(basename "$SELECTED_HASH_FILE")"
    elif [ "$file_choice" -eq "$counter" ]; then
        echo -n "Введите путь к файлу: "
        read custom_file
        if [ -f "$custom_file" ]; then
            SELECTED_HASH_FILE="$custom_file"
            success "Выбран файл: $custom_file"
        else
            error "Файл не найден"
            return 1
        fi
    else
        error "Неверный выбор"
        return 1
    fi
}

# Быстрая атака
quick_attack() {
    log "=== БЫСТРАЯ АТАКА ==="
    
    local session_name="quick_$(date +%Y%m%d_%H%M%S)"
    local output_file="$RESULTS_DIR/${session_name}_results.txt"
    
    log "Запуск быстрой атаки..."
    log "Сессия: $session_name"
    log "Файл результатов: $output_file"
    
    # Создаем команду
    local cmd="$JOHN_BIN --wordlist=$WORDLIST_DIR/basic.txt --rules=single --session=$session_name $SELECTED_HASH_FILE"
    
    echo -e "\n${CYAN}Команда:${NC} $cmd"
    echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}"
    echo ""
    
    # Запускаем атаку с таймаутом
    timeout 300 $cmd || {
        log "Атака завершена или прервана"
    }
    
    # Показываем результаты
    show_attack_results "$session_name"
}

# Атака по словарю
dictionary_attack() {
    log "=== АТАКА ПО СЛОВАРЮ ==="
    
    # Выбираем словарь
    select_wordlist
    
    if [ -z "$SELECTED_WORDLIST" ]; then
        error "Словарь не выбран"
        return 1
    fi
    
    local session_name="dict_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\nДополнительные параметры:"
    echo "1) Только словарь"
    echo "2) Словарь + базовые правила"
    echo "3) Словарь + все правила"
    
    read -p "Выберите (1-3): " dict_option
    
    local rules_param=""
    case $dict_option in
        2) rules_param="--rules=single" ;;
        3) rules_param="--rules" ;;
    esac
    
    local cmd="$JOHN_BIN --wordlist=$SELECTED_WORDLIST $rules_param --session=$session_name $SELECTED_HASH_FILE"
    
    echo -e "\n${CYAN}Команда:${NC} $cmd"
    echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}"
    echo ""
    
    # Запускаем атаку
    $cmd || {
        log "Атака завершена или прервана"
    }
    
    show_attack_results "$session_name"
}

# Выбор словаря
select_wordlist() {
    echo -e "\n${YELLOW}Доступные словари:${NC}"
    
    local wordlists=()
    local counter=1
    
    # Ищем в директории словарей
    for file in "$WORDLIST_DIR"/*.txt; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file")
            local size=$(wc -l < "$file" 2>/dev/null || echo "0")
            echo "$counter) $basename ($size слов)"
            wordlists+=("$file")
            ((counter++))
        fi
    done
    
    # Ищем встроенные словари John
    if [ -d "$(dirname $JOHN_BIN)/../run" ]; then
        for file in "$(dirname $JOHN_BIN)"/*.lst; do
            if [ -f "$file" ]; then
                local basename=$(basename "$file")
                echo "$counter) $basename (встроенный)"
                wordlists+=("$file")
                ((counter++))
            fi
        done
    fi
    
    if [ ${#wordlists[@]} -eq 0 ]; then
        warning "Словари не найдены, создаем базовый..."
        create_basic_wordlist
        SELECTED_WORDLIST="$WORDLIST_DIR/basic.txt"
        return 0
    fi
    
    echo "$counter) Указать другой файл"
    
    read -p "Выберите словарь: " wl_choice
    
    if [ "$wl_choice" -gt 0 ] && [ "$wl_choice" -le ${#wordlists[@]} ]; then
        SELECTED_WORDLIST="${wordlists[$((wl_choice-1))]}"
        success "Выбран словарь: $(basename "$SELECTED_WORDLIST")"
    elif [ "$wl_choice" -eq "$counter" ]; then
        echo -n "Введите путь к словарю: "
        read custom_wordlist
        if [ -f "$custom_wordlist" ]; then
            SELECTED_WORDLIST="$custom_wordlist"
            success "Выбран словарь: $custom_wordlist"
        else
            error "Файл не найден"
            return 1
        fi
    else
        error "Неверный выбор"
        return 1
    fi
}

# Перебор
brute_force_attack() {
    log "=== АТАКА ПЕРЕБОРОМ ==="
    
    echo "Параметры перебора:"
    echo -n "Минимальная длина пароля (по умолчанию 1): "
    read min_len
    min_len=${min_len:-1}
    
    echo -n "Максимальная длина пароля (по умолчанию 8): "
    read max_len
    max_len=${max_len:-8}
    
    echo "Набор символов:"
    echo "1) Только цифры (0-9)"
    echo "2) Буквы нижнего регистра (a-z)"
    echo "3) Буквы и цифры (a-z, 0-9)"
    echo "4) Все ASCII символы"
    
    read -p "Выберите (1-4): " charset_choice
    
    local charset=""
    case $charset_choice in
        1) charset="digits" ;;
        2) charset="alpha" ;;
        3) charset="alnum" ;;
        4) charset="all" ;;
        *) charset="alnum" ;;
    esac
    
    local session_name="brute_$(date +%Y%m%d_%H%M%S)"
    
    local cmd="$JOHN_BIN --incremental=$charset --session=$session_name $SELECTED_HASH_FILE"
    
    warning "ВНИМАНИЕ: Перебор может занять очень много времени!"
    echo -e "${CYAN}Команда:${NC} $cmd"
    echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}"
    echo ""
    
    read -p "Продолжить? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "Атака отменена"
        return 0
    fi
    
    $cmd || {
        log "Атака завершена или прервана"
    }
    
    show_attack_results "$session_name"
}

# Показ результатов атаки
show_attack_results() {
    local session_name="$1"
    
    log "=== РЕЗУЛЬТАТЫ АТАКИ: $session_name ==="
    
    # Показываем взломанные пароли
    echo -e "\n${GREEN}Взломанные пароли:${NC}"
    if $JOHN_BIN --show "$SELECTED_HASH_FILE" 2>/dev/null; then
        success "Пароли найдены!"
        
        # Сохраняем результаты
        $JOHN_BIN --show "$SELECTED_HASH_FILE" > "$RESULTS_DIR/${session_name}_cracked.txt" 2>/dev/null
        
        # Статистика
        local total_hashes=$(wc -l < "$SELECTED_HASH_FILE")
        local cracked_count=$($JOHN_BIN --show "$SELECTED_HASH_FILE" 2>/dev/null | wc -l)
        
        echo -e "\n${BLUE}Статистика:${NC}"
        echo "Всего хэшей: $total_hashes"
        echo "Взломано: $cracked_count"
        echo "Процент: $(( cracked_count * 100 / total_hashes ))%"
        
    else
        warning "Пароли не найдены"
    fi
    
    # Показываем статус сессии
    echo -e "\n${BLUE}Статус сессии:${NC}"
    $JOHN_BIN --status="$session_name" 2>/dev/null || echo "Информация о сессии недоступна"
}

# Показ всех взломанных паролей
show_cracked() {
    log "=== ВСЕ ВЗЛОМАННЫЕ ПАРОЛИ ==="
    
    if $JOHN_BIN --show "$SELECTED_HASH_FILE" 2>/dev/null; then
        echo -e "\n${GREEN}Детальная информация:${NC}"
        
        # Анализируем пароли
        local temp_file=$(mktemp)
        $JOHN_BIN --show "$SELECTED_HASH_FILE" 2>/dev/null | cut -d: -f2 > "$temp_file"
        
        echo "Статистика паролей:"
        echo "- Средняя длина: $(awk '{total += length($0); count++} END {print int(total/count)}' "$temp_file")"
        echo "- Самый короткий: $(awk '{print length($0)}' "$temp_file" | sort -n | head -1) символов"
        echo "- Самый длинный: $(awk '{print length($0)}' "$temp_file" | sort -n | tail -1) символов"
        
        echo -e "\nТоп-5 самых популярных паролей:"
        sort "$temp_file" | uniq -c | sort -nr | head -5
        
        rm "$temp_file"
    else
        warning "Взломанные пароли не найдены"
    fi
}

# Управление сессиями
session_management() {
    echo -e "${BLUE}=== УПРАВЛЕНИЕ СЕССИЯМИ ===${NC}"
    echo ""
    echo "1) Список активных сессий"
    echo "2) Восстановить сессию"
    echo "3) Удалить сессию"
    echo "4) Статус сессии"
    echo "5) Назад"
    
    read -p "Введите номер (1-5): " session_choice
    
    case $session_choice in
        1) list_sessions ;;
        2) restore_session ;;
        3) delete_session ;;
        4) session_status ;;
        5) return ;;
        *) error "Неверный выбор" ;;
    esac
}

# Список сессий
list_sessions() {
    log "=== АКТИВНЫЕ СЕССИИ ==="
    
    if [ -d "$(dirname $JOHN_BIN)/../run" ]; then
        local session_dir="$(dirname $JOHN_BIN)/../run"
    else
        local session_dir="$HOME/.john"
    fi
    
    echo -e "\n${YELLOW}Файлы сессий:${NC}"
    find "$session_dir" -name "*.rec" 2>/dev/null | while read session_file; do
        local session_name=$(basename "$session_file" .rec)
        echo "- $session_name"
    done
}

# Генерация отчетов
generate_reports() {
    echo -e "${BLUE}=== ГЕНЕРАЦИЯ ОТЧЕТОВ ===${NC}"
    
    local report_file="$RESULTS_DIR/john_report_$(date +%Y%m%d_%H%M%S).html"
    
    log "Создание HTML отчета..."
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>John the Ripper - Отчет о тестировании</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>John the Ripper - Отчет о тестировании паролей</h1>
        <p>Дата создания: $(date)</p>
        <p>Система: $(uname -a)</p>
    </div>

    <div class="section">
        <h2>Сводка результатов</h2>
EOF

    # Добавляем статистику
    for hash_file in "$WORK_DIR"/*.txt; do
        if [ -f "$hash_file" ]; then
            local basename=$(basename "$hash_file")
            local total=$(wc -l < "$hash_file")
            local cracked=0
            
            if $JOHN_BIN --show "$hash_file" >/dev/null 2>&1; then
                cracked=$($JOHN_BIN --show "$hash_file" 2>/dev/null | wc -l)
            fi
            
            cat >> "$report_file" << EOF
        <h3>Файл: $basename</h3>
        <ul>
            <li>Всего хэшей: $total</li>
            <li>Взломано: $cracked</li>
            <li>Процент: $(( total > 0 ? cracked * 100 / total : 0 ))%</li>
        </ul>
EOF
        fi
    done
    
    cat >> "$report_file" << EOF
    </div>

    <div class="section">
        <h2>Рекомендации по безопасности</h2>
        <ul>
            <li>Используйте пароли длиной не менее 12 символов</li>
            <li>Включайте разные типы символов (буквы, цифры, спецсимволы)</li>
            <li>Избегайте словарных слов и персональной информации</li>
            <li>Регулярно меняйте пароли</li>
            <li>Используйте двухфакторную аутентификацию</li>
        </ul>
    </div>

    <div class="section">
        <h2>Взломанные пароли</h2>
        <table>
            <tr><th>Пользователь</th><th>Пароль</th><th>Длина</th><th>Сложность</th></tr>
EOF

    # Добавляем взломанные пароли (без реальных паролей для безопасности)
    for hash_file in "$WORK_DIR"/*.txt; do
        if [ -f "$hash_file" ] && $JOHN_BIN --show "$hash_file" >/dev/null 2>&1; then
            $JOHN_BIN --show "$hash_file" 2>/dev/null | while IFS=: read user password; do
                local length=${#password}
                local complexity="Слабый"
                
                if [ $length -ge 12 ]; then
                    complexity="Средний"
                fi
                
                if [[ "$password" =~ [A-Z] ]] && [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [0-9] ]] && [[ "$password" =~ [^a-zA-Z0-9] ]]; then
                    complexity="Сильный"
                fi
                
                echo "            <tr><td>$user</td><td>***</td><td>$length</td><td>$complexity</td></tr>" >> "$report_file"
            done
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
</body>
</html>
EOF

    success "Отчет создан: $report_file"
    
    # Создаем также текстовый отчет
    local text_report="$RESULTS_DIR/john_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$text_report" << EOF
JOHN THE RIPPER - ОТЧЕТ О ТЕСТИРОВАНИИ ПАРОЛЕЙ
===============================================

Дата: $(date)
Система: $(uname -a)

РЕЗУЛЬТАТЫ:
EOF

    for hash_file in "$WORK_DIR"/*.txt; do
        if [ -f "$hash_file" ]; then
            local basename=$(basename "$hash_file")
            local total=$(wc -l < "$hash_file")
            local cracked=0
            
            if $JOHN_BIN --show "$hash_file" >/dev/null 2>&1; then
                cracked=$($JOHN_BIN --show "$hash_file" 2>/dev/null | wc -l)
            fi
            
            cat >> "$text_report" << EOF

Файл: $basename
- Всего хэшей: $total
- Взломано: $cracked
- Процент: $(( total > 0 ? cracked * 100 / total : 0 ))%
EOF
        fi
    done
    
    success "Текстовый отчет создан: $text_report"
}

# Главное меню
main_menu() {
    while true; do
        clear
        echo -e "${BOLD}${BLUE}"
        echo "╔══════════════════════════════════════════════╗"
        echo "║       JOHN THE RIPPER PROFESSIONAL          ║"
        echo "║         Advanced Management Script           ║"
        echo "╚══════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        if [ -n "$JOHN_BIN" ]; then
            echo -e "${GREEN}✓ John найден: $JOHN_BIN${NC}"
        else
            echo -e "${RED}✗ John не найден${NC}"
        fi
        
        echo -e "\n${YELLOW}Основные функции:${NC}"
        echo "1)  Установка John the Ripper"
        echo "2)  Подготовка хэшей для взлома"
        echo "3)  Скачивание словарей"
        echo "4)  Атаки на пароли"
        echo "5)  Управление сессиями"
        echo "6)  Генерация отчетов"
        echo ""
        echo -e "${YELLOW}Дополнительные функции:${NC}"
        echo "7)  Настройка рабочего пространства"
        echo "8)  Просмотр логов"
        echo "9)  Очистка временных файлов"
        echo "10) Помощь и документация"
        echo "11) Выход"
        
        echo -e "\n${CYAN}Статистика рабочего пространства:${NC}"
        if [ -d "$WORK_DIR" ]; then
            local hash_count=$(find "$WORK_DIR" -name "*.txt" -type f | wc -l)
            local wordlist_count=$(find "$WORDLIST_DIR" -name "*.txt" -type f 2>/dev/null | wc -l)
            local results_count=$(find "$RESULTS_DIR" -type f 2>/dev/null | wc -l)
            
            echo "- Файлы с хэшами: $hash_count"
            echo "- Словари: $wordlist_count"
            echo "- Результаты: $results_count"
        else
            echo "- Рабочее пространство не настроено"
        fi
        
        echo ""
        read -p "Выберите опцию (1-11): " choice
        
        case $choice in
            1) install_john_menu ;;
            2) prepare_hashes ;;
            3) download_wordlists ;;
            4) password_attacks ;;
            5) session_management ;;
            6) generate_reports ;;
            7) setup_workspace ;;
            8) view_logs ;;
            9) cleanup_workspace ;;
            10) show_help ;;
            11) exit_script ;;
            *) error "Неверный выбор. Попробуйте снова." ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Просмотр логов
view_logs() {
    if [ -f "$LOG_DIR/john.log" ]; then
        echo -e "${BLUE}=== ПОСЛЕДНИЕ 50 ЗАПИСЕЙ ЛОГА ===${NC}"
        tail -50 "$LOG_DIR/john.log"
    else
        warning "Лог файл не найден"
    fi
}

# Очистка рабочего пространства
cleanup_workspace() {
    warning "Это удалит все временные файлы, сессии и результаты!"
    read -p "Вы уверены? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -rf "$WORK_DIR"
        success "Рабочее пространство очищено"
    else
        log "Очистка отменена"
    fi
}

# Помощь
show_help() {
    echo -e "${BLUE}=== СПРАВКА ===${NC}"
    
    cat << 'EOF'

ОСНОВНЫЕ КОМАНДЫ JOHN THE RIPPER:

Базовые атаки:
  john hashfile.txt                    # Автоматический режим
  john --wordlist=dict.txt hashfile    # Атака по словарю
  john --incremental hashfile          # Перебор
  john --rules hashfile                # С правилами

Управление сессиями:
  john --session=name hashfile         # Именованная сессия
  john --restore=name                  # Восстановление сессии
  john --status=name                   # Статус сессии

Просмотр результатов:
  john --show hashfile                 # Показать взломанные
  john --show=left hashfile            # Показать не взломанные

Форматы:
  john --list=formats                  # Список форматов
  john --format=md5 hashfile           # Указать формат

СОВЕТЫ ПО ИСПОЛЬЗОВАНИЮ:

1. Всегда начинайте с быстрой атаки
2. Используйте качественные словари
3. Настройте правила для лучших результатов
4. Мониторьте прогресс через --status
5. Сохраняйте сессии для длительных атак

БЕЗОПАСНОСТЬ:

- Используйте только на собственных системах
- Получите разрешение перед тестированием
- Соблюдайте законодательство
- Не сохраняйте чужие пароли

EOF
}

# Выход
exit_script() {
    log "Завершение работы John the Ripper Manager"
    echo -e "\n${GREEN}Спасибо за использование John the Ripper Professional!${NC}"
    exit 0
}

# Инициализация
init_script() {
    check_root
    setup_workspace
    detect_john || warning "John the Ripper не найден. Используйте опцию установки."
}

# Запуск
main() {
    init_script
    main_menu
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Прерывание получено. Выход...${NC}"; exit 1' INT TERM

# Запуск скрипта
main "$@"