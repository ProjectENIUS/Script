#!/bin/bash

# Исправленный скрипт с работающей политикой паролей
# Fixed Password Policy Script for Ubuntu Server

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Скрипт должен запускаться с правами root (sudo)"
        exit 1
    fi
}

# Диагностика текущего состояния
diagnose_current_state() {
    log "=== ДИАГНОСТИКА ТЕКУЩЕГО СОСТОЯНИЯ ==="
    
    echo -e "\n${BLUE}1. Проверка установленных PAM модулей:${NC}"
    dpkg -l | grep -E "(libpam-pwquality|libpam-cracklib)" || echo "PAM модули не установлены"
    
    echo -e "\n${BLUE}2. Текущее содержимое /etc/pam.d/common-password:${NC}"
    cat -n /etc/pam.d/common-password
    
    echo -e "\n${BLUE}3. Настройки в /etc/login.defs:${NC}"
    grep -E "PASS_(MAX|MIN)_" /etc/login.defs || echo "Настройки не найдены"
    
    echo -e "\n${BLUE}4. Версия Ubuntu:${NC}"
    lsb_release -a 2>/dev/null || cat /etc/os-release
}

# Создание резервных копий
backup_files() {
    log "Создание резервных копий..."
    BACKUP_DIR="/root/password_policy_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    cp /etc/login.defs "$BACKUP_DIR/"
    cp /etc/pam.d/common-password "$BACKUP_DIR/"
    cp /etc/pam.d/common-auth "$BACKUP_DIR/" 2>/dev/null || true
    
    log "Резервные копии сохранены в: $BACKUP_DIR"
}

# Установка необходимых пакетов
install_pam_modules() {
    log "=== УСТАНОВКА PAM МОДУЛЕЙ ==="
    
    # Обновляем список пакетов
    apt-get update -qq
    
    # Устанавливаем оба модуля для совместимости
    log "Установка libpam-pwquality и libpam-cracklib..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libpam-pwquality \
        libpam-cracklib \
        libpam-modules \
        passwd >/dev/null 2>&1
    
    log "PAM модули установлены"
}

# Настройка /etc/login.defs
configure_login_defs() {
    log "=== НАСТРОЙКА /etc/login.defs ==="
    
    # Создаем временный файл
    TEMP_FILE=$(mktemp)
    cp /etc/login.defs "$TEMP_FILE"
    
    # Функция для обновления или добавления параметра
    update_param() {
        local param="$1"
        local value="$2"
        
        if grep -q "^${param}" "$TEMP_FILE"; then
            sed -i "s/^${param}.*/${param}\t${value}/" "$TEMP_FILE"
            log "Обновлен параметр: $param $value"
        else
            echo -e "${param}\t${value}" >> "$TEMP_FILE"
            log "Добавлен параметр: $param $value"
        fi
    }
    
    # Настраиваем параметры
    update_param "PASS_MAX_DAYS" "90"
    update_param "PASS_MIN_DAYS" "7" 
    update_param "PASS_MIN_LEN" "12"
    update_param "PASS_WARN_AGE" "7"
    
    # Копируем обратно
    cp "$TEMP_FILE" /etc/login.defs
    rm "$TEMP_FILE"
    
    log "Файл /etc/login.defs настроен"
    
    # Показываем результат
    echo -e "\n${BLUE}Текущие настройки:${NC}"
    grep -E "PASS_(MAX|MIN|WARN)_" /etc/login.defs
}

# Правильная настройка PAM
configure_pam_password() {
    log "=== НАСТРОЙКА PAM ПОЛИТИКИ ПАРОЛЕЙ ==="
    
    # Создаем новый файл common-password
    TEMP_PAM=$(mktemp)
    
    cat > "$TEMP_PAM" << 'EOF'
#
# /etc/pam.d/common-password - password-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of the password-changing modules that define
# the central authentication scheme for use on the system
# (e.g., /etc/shadow, LDAP, Kerberos, etc.).  The default is pam_unix.
#

# here are the per-package modules (the "Primary" block)

# Проверка качества пароля с помощью pwquality
password	requisite		pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 enforce_for_root

# Альтернативная проверка с cracklib (если pwquality не работает)
# password	requisite		pam_cracklib.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1

# Стандартная обработка паролей Unix
password	[success=1 default=ignore]	pam_unix.so obscure use_authtok try_first_pass sha512

# here's the fallback if no module succeeds
password	requisite			pam_deny.so

# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
password	required			pam_permit.so

# and here are more per-package modules (the "Additional" block)
# end of pam-auth-update config
EOF

    # Копируем новую конфигурацию
    cp "$TEMP_PAM" /etc/pam.d/common-password
    rm "$TEMP_PAM"
    
    log "PAM конфигурация обновлена"
    
    # Показываем результат
    echo -e "\n${BLUE}Новая конфигурация /etc/pam.d/common-password:${NC}"
    cat -n /etc/pam.d/common-password
}

# Альтернативная настройка с cracklib
configure_pam_cracklib() {
    log "=== АЛЬТЕРНАТИВНАЯ НАСТРОЙКА С CRACKLIB ==="
    
    TEMP_PAM=$(mktemp)
    
    cat > "$TEMP_PAM" << 'EOF'
#
# /etc/pam.d/common-password
#

# Проверка качества пароля с помощью cracklib
password	requisite		pam_cracklib.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 reject_username

# Стандартная обработка паролей Unix
password	[success=1 default=ignore]	pam_unix.so obscure use_authtok try_first_pass sha512

password	requisite			pam_deny.so
password	required			pam_permit.so
EOF

    cp "$TEMP_PAM" /etc/pam.d/common-password
    rm "$TEMP_PAM"
    
    log "Конфигурация cracklib применена"
}

# Тестирование политики паролей
test_password_policy() {
    log "=== ТЕСТИРОВАНИЕ ПОЛИТИКИ ПАРОЛЕЙ ==="
    
    # Удаляем тестового пользователя если существует
    if id "testpolicy" &>/dev/null; then
        userdel -r testpolicy 2>/dev/null || true
    fi
    
    # Создаем тестового пользователя
    log "Создание тестового пользователя 'testpolicy'..."
    useradd -m -s /bin/bash testpolicy
    
    # Массив слабых паролей для тестирования
    weak_passwords=(
        "123"
        "1234"
        "password"
        "testpolicy"
        "qwerty"
        "admin"
        "12345678"
        "Password1"
    )
    
    echo -e "\n${BLUE}Тестирование слабых паролей:${NC}"
    
    for weak_pass in "${weak_passwords[@]}"; do
        echo -n "Тест пароля '$weak_pass': "
        
        # Пытаемся установить пароль через chpasswd
        if echo "testpolicy:$weak_pass" | chpasswd 2>/dev/null; then
            echo -e "${RED}✗ ПРИНЯТ (политика НЕ работает!)${NC}"
        else
            echo -e "${GREEN}✓ ОТКЛОНЕН (политика работает)${NC}"
        fi
        
        # Также тестируем через passwd (более надежно)
        echo -n "  через passwd: "
        if echo -e "$weak_pass\n$weak_pass" | passwd testpolicy >/dev/null 2>&1; then
            echo -e "${RED}✗ ПРИНЯТ${NC}"
        else
            echo -e "${GREEN}✓ ОТКЛОНЕН${NC}"
        fi
    done
    
    # Тест сильного пароля
    echo -e "\n${BLUE}Тестирование сильного пароля:${NC}"
    strong_password="MyStr0ng!P@ssw0rd"
    echo -n "Тест пароля '$strong_password': "
    
    if echo "testpolicy:$strong_password" | chpasswd 2>/dev/null; then
        echo -e "${GREEN}✓ ПРИНЯТ (политика работает корректно)${NC}"
    else
        echo -e "${YELLOW}? Отклонен (возможно слишком строгая политика)${NC}"
    fi
}

# Ручное тестирование
manual_password_test() {
    log "=== РУЧНОЕ ТЕСТИРОВАНИЕ ==="
    
    echo -e "\n${YELLOW}Для ручного тестирования выполните:${NC}"
    echo "1. sudo passwd testpolicy"
    echo "2. Попробуйте ввести простой пароль (например: 123)"
    echo "3. Система должна отклонить его с сообщением об ошибке"
    echo "4. Попробуйте сильный пароль (например: MyStr0ng!P@ss2024)"
    echo ""
    
    read -p "Хотите протестировать сейчас? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Запуск passwd для пользователя testpolicy..."
        log "Попробуйте сначала простой пароль, затем сложный"
        passwd testpolicy || log "Тестирование завершено"
    fi
}

# Диагностика проблем
diagnose_issues() {
    log "=== ДИАГНОСТИКА ПРОБЛЕМ ==="
    
    echo -e "\n${BLUE}Проверка PAM модулей:${NC}"
    
    # Проверяем наличие библиотек
    if [ -f "/lib/x86_64-linux-gnu/security/pam_pwquality.so" ] || [ -f "/lib/security/pam_pwquality.so" ]; then
        echo "✓ pam_pwquality.so найден"
    else
        echo "✗ pam_pwquality.so НЕ найден"
    fi
    
    if [ -f "/lib/x86_64-linux-gnu/security/pam_cracklib.so" ] || [ -f "/lib/security/pam_cracklib.so" ]; then
        echo "✓ pam_cracklib.so найден"
    else
        echo "✗ pam_cracklib.so НЕ найден"
    fi
    
    # Проверяем синтаксис PAM файла
    echo -e "\n${BLUE}Проверка синтаксиса PAM:${NC}"
    if pam-auth-update --check 2>/dev/null; then
        echo "✓ Синтаксис PAM корректен"
    else
        echo "✗ Ошибки в конфигурации PAM"
    fi
    
    # Проверяем процесс смены пароля
    echo -e "\n${BLUE}Тестирование процесса смены пароля:${NC}"
    echo "Запуск: echo 'testpassword' | pwquality-check"
    echo "testpassword" | pwquality-check 2>/dev/null || echo "pwquality-check недоступен или пароль не прошел проверку"
}

# Применение исправлений
apply_fixes() {
    log "=== ПРИМЕНЕНИЕ ИСПРАВЛЕНИЙ ==="
    
    # Вариант 1: Попробуем pwquality
    log "Попытка 1: Конфигурация с pwquality"
    configure_pam_password
    test_password_policy
    
    # Проверяем результат
    echo "testpolicy:123" | chpasswd 2>/dev/null
    if [ $? -eq 0 ]; then
        warning "pwquality не работает, пробуем cracklib..."
        
        # Вариант 2: Используем cracklib
        log "Попытка 2: Конфигурация с cracklib"
        configure_pam_cracklib
        test_password_policy
        
        # Проверяем снова
        echo "testpolicy:123" | chpasswd 2>/dev/null
        if [ $? -eq 0 ]; then
            error "Ни один метод не сработал. Нужна ручная настройка."
            return 1
        else
            log "cracklib работает!"
            return 0
        fi
    else
        log "pwquality работает!"
        return 0
    fi
}

# Создание демонстрационных пользователей
create_demo_users() {
    log "=== СОЗДАНИЕ ДЕМОНСТРАЦИОННЫХ ПОЛЬЗОВАТЕЛЕЙ ==="
    
    # Удаляем если существуют
    for user in testuser secuser; do
        if id "$user" &>/dev/null; then
            userdel -r "$user" 2>/dev/null || true
        fi
    done
    
    # Создаем пользователя с простым паролем (для демонстрации уязвимости)
    log "Создание testuser с простым паролем (принудительно)..."
    useradd -m -s /bin/bash testuser
    
    # Временно отключаем проверку паролей для демонстрации
    cp /etc/pam.d/common-password /etc/pam.d/common-password.temp
    echo "password [success=1 default=ignore] pam_unix.so obscure sha512" > /etc/pam.d/common-password
    echo "testuser:1234" | chpasswd
    cp /etc/pam.d/common-password.temp /etc/pam.d/common-password
    rm /etc/pam.d/common-password.temp
    
    log "testuser создан с паролем '1234'"
    
    # Создаем пользователя с сильным паролем
    log "Создание secuser с сильным паролем..."
    useradd -m -s /bin/bash secuser
    echo "secuser:Xr!92_aL#5nM" | chpasswd
    log "secuser создан с паролем 'Xr!92_aL#5nM'"
    
    # Сохраняем хэши для John the Ripper
    grep testuser /etc/shadow > hash.txt
    grep secuser /etc/shadow > strong_hash.txt
    
    log "Хэши паролей сохранены в hash.txt и strong_hash.txt"
}

# Главная функция
main() {
    echo -e "${BLUE}=== ИСПРАВЛЕННЫЙ СКРИПТ ПОЛИТИКИ ПАРОЛЕЙ ===${NC}"
    echo -e "${BLUE}=== Ubuntu Server Password Policy Fix v3.0 ===${NC}"
    
    check_root
    
    echo -e "\nВыберите действие:"
    echo "1) Полная настройка и тестирование"
    echo "2) Только диагностика текущего состояния"
    echo "3) Только настройка политики паролей"
    echo "4) Только тестирование существующей политики"
    echo "5) Создать демонстрационных пользователей для John the Ripper"
    
    read -p "Введите номер (1-5): " choice
    
    case $choice in
        1)
            diagnose_current_state
            backup_files
            install_pam_modules
            configure_login_defs
            apply_fixes
            manual_password_test
            create_demo_users
            ;;
        2)
            diagnose_current_state
            diagnose_issues
            ;;
        3)
            backup_files
            install_pam_modules
            configure_login_defs
            apply_fixes
            ;;
        4)
            test_password_policy
            manual_password_test
            ;;
        5)
            create_demo_users
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}=== СКРИПТ ЗАВЕРШЕН ===${NC}"
    
    if [ -f "hash.txt" ]; then
        log "Файлы для John the Ripper готовы: hash.txt, strong_hash.txt"
    fi
}

# Запуск
main "$@"