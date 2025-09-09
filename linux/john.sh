#!/bin/bash

# Отдельный скрипт для установки John the Ripper
# Separate John the Ripper Installation Script

log() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

install_john_manual() {
    log "=== РУЧНАЯ УСТАНОВКА JOHN THE RIPPER ==="
    
    # Проверяем права root
    if [ "$EUID" -ne 0 ]; then
        error "Требуются права root"
        exit 1
    fi
    
    # Устанавливаем зависимости
    log "Установка зависимостей..."
    apt-get update -qq
    apt-get install -y build-essential libssl-dev zlib1g-dev git
    
    # Переходим в /opt для установки
    cd /opt
    
    # Клонируем репозиторий
    log "Клонирование John the Ripper..."
    git clone https://github.com/openwall/john.git john-the-ripper
    cd john-the-ripper/src
    
    # Компилируем
    log "Компиляция..."
    ./configure
    make -s
    
    # Создаем символическую ссылку
    ln -sf /opt/john-the-ripper/run/john /usr/local/bin/john
    
    log "John the Ripper установлен в /opt/john-the-ripper/"
    log "Символическая ссылка создана в /usr/local/bin/john"
    
    # Проверяем установку
    /usr/local/bin/john --test=0
}

# Альтернативная простая установка
install_john_simple() {
    log "=== ПРОСТАЯ УСТАНОВКА JOHN (ИЗ РЕПОЗИТОРИЯ) ==="
    
    apt-get update -qq
    apt-get install -y john
    
    log "John установлен. Проверка:"
    
    # Проверяем доступные опции
    if john --help >/dev/null 2>&1; then
        john --help | head -10
    elif john -h >/dev/null 2>&1; then
        john -h | head -10
    else
        log "John установлен, но справка недоступна"
    fi
}

# Выбор метода установки
echo "Выберите метод установки John the Ripper:"
echo "1) Простая установка из репозитория (рекомендуется для начинающих)"
echo "2) Компиляция из исходников (больше функций)"
read -p "Введите 1 или 2: " choice

case $choice in
    1) install_john_simple ;;
    2) install_john_manual ;;
    *) echo "Неверный выбор" ;;
esac