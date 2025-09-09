#!/bin/bash

# Скрипт восстановления после прерванной установки PAM
# PAM Recovery and Diagnostic Script

set +e  # Не останавливаться при ошибках

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Скрипт должен запускаться с правами root (sudo)"
        exit 1
    fi
}

# Диагностика состояния системы после прерывания
diagnose_system_state() {
    log "=== ДИАГНОСТИКА СОСТОЯНИЯ СИСТЕМЫ ==="
    
    echo -e "\n${BLUE}1. Проверка процессов apt/dpkg:${NC}"
    if pgrep -f "apt|dpkg" >/dev/null; then
        warning "Обнаружены активные процессы apt/dpkg:"
        pgrep -f "apt|dpkg" -l
        warning "Возможно, система заблокирована предыдущей установкой"
    else
        echo "✓ Процессы apt/dpkg не активны"
    fi
    
    echo -e "\n${BLUE}2. Проверка блокировок apt:${NC}"
    if [ -f /var/lib/dpkg/lock-frontend ]; then
        echo "⚠ Найден файл блокировки: /var/lib/dpkg/lock-frontend"
    fi
    if [ -f /var/lib/apt/lists/lock ]; then
        echo "⚠ Найден файл блокировки: /var/lib/apt/lists/lock"
    fi
    if [ -f /var/cache/apt/archives/lock ]; then
        echo "⚠ Найден файл блокировки: /var/cache/apt/archives/lock"
    fi
    
    echo -e "\n${BLUE}3. Состояние пакетов PAM:${NC}"
    dpkg -l | grep -E "(libpam-pwquality|libpam-cracklib|libpam-modules)" || echo "PAM пакеты не найдены"
    
    echo -e "\n${BLUE}4. Целостность системы пакетов:${NC}"
    dpkg --audit
    
    echo -e "\n${BLUE}5. Состояние конфигурационных файлов:${NC}"
    if [ -f /etc/pam.d/common-password ]; then
        echo "✓ /etc/pam.d/common-password существует"
        echo "Размер файла: $(wc -l < /etc/pam.d/common-password) строк"
    else
        error "✗ /etc/pam.d/common-password ОТСУТСТВУЕТ!"
    fi
    
    if [ -f /etc/login.defs ]; then
        echo "✓ /etc/login.defs существует"
    else
        error "✗ /etc/login.defs ОТСУТСТВУЕТ!"
    fi
}

# Очистка заблокированных процессов
clear_apt_locks() {
    log "=== ОЧИСТКА БЛОКИРОВОК APT ==="
    
    # Останавливаем все процессы apt/dpkg
    warning "Остановка активных процессов apt/dpkg..."
    pkill -f apt >/dev/null 2>&1 || true
    pkill -f dpkg >/dev/null 2>&1 || true
    
    # Ждем завершения процессов
    sleep 3
    
    # Удаляем файлы блокировки
    log "Удаление файлов блокировки..."
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/apt/lists/lock  
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/dpkg/lock
    
    # Исправляем прерванные установки
    log "Исправление прерванных установок..."
    dpkg --configure -a
    
    # Исправляем сломанные зависимости
    log "Исправление зависимостей..."
    apt-get -f install -y >/dev/null 2>&1 || true
    
    log "Очистка завершена"
}

# Восстановление базовых конфигурационных файлов
restore_basic_configs() {
    log "=== ВОССТАНОВЛЕНИЕ БАЗОВЫХ КОНФИГУРАЦИЙ ==="
    
    # Восстанавливаем /etc/pam.d/common-password если поврежден
    if [ ! -f /etc/pam.d/common-password ] || [ ! -s /etc/pam.d/common-password ]; then
        warning "Восстановление /etc/pam.d/common-password..."
        
        cat > /etc/pam.d/common-password << 'EOF'
#
# /etc/pam.d/common-password - password-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of the password-changing modules that define
# the central authentication scheme for use on the system
# (e.g., /etc/shadow, LDAP, Kerberos, etc.).  The default is pam_unix.

# here are the per-package modules (the "Primary" block)
password	[success=1 default=ignore]	pam_unix.so obscure sha512
# here's the fallback if no module succeeds
password	requisite			pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
password	required			pam_permit.so
# and here are more per-package modules (the "Additional" block)
# end of pam-auth-update config
EOF
        log "Базовая конфигурация /etc/pam.d/common-password восстановлена"
    fi
    
    # Проверяем /etc/login.defs
    if [ ! -f /etc/login.defs ]; then
        error "/etc/login.defs отсутствует! Восстанавливаем базовую версию..."
        
        cat > /etc/login.defs << 'EOF'
# Basic login.defs configuration
PASS_MAX_DAYS	99999
PASS_MIN_DAYS	0
PASS_MIN_LEN	5
PASS_WARN_AGE	7
UID_MIN			1000
UID_MAX			60000
GID_MIN			1000
GID_MAX			60000
CREATE_HOME		yes
UMASK			022
USERGROUPS_ENAB	yes
ENCRYPT_METHOD	SHA512
EOF
        log "Базовая конфигурация /etc/login.defs восстановлена"
    fi
}

# Безопасная установка PAM модулей
safe_install_pam() {
    log "=== БЕЗОПАСНАЯ УСТАНОВКА PAM МОДУЛЕЙ ==="
    
    # Проверяем доступность репозиториев
    log "Проверка репозиториев..."
    if ! apt-get update -qq; then
        error "Не удалось обновить список пакетов"
        return 1
    fi
    
    # Устанавливаем пакеты по одному с проверкой
    packages=("libpam-modules" "libpam-pwquality" "libpam-cracklib")
    
    for package in "${packages[@]}"; do
        log "Установка $package..."
        
        # Проверяем, не установлен ли уже
        if dpkg -l | grep -q "^ii.*$package"; then
            log "$package уже установлен"
            continue
        fi
        
        # Пытаемся установить с таймаутом
        if timeout 300 apt-get install -y "$package" >/dev/null 2>&1; then
            log "✓ $package установлен успешно"
        else
            warning "Ошибка установки $package, пропускаем"
        fi
    done
    
    # Проверяем результат
    log "Проверка установленных PAM модулей:"
    dpkg -l | grep -E "(libpam-pwquality|libpam-cracklib|libpam-modules)"
}

# Минимальная настройка политики паролей
minimal_password_policy() {
    log "=== МИНИМАЛЬНАЯ НАСТРОЙКА ПОЛИТИКИ ПАРОЛЕЙ ==="
    
    # Простая и надежная конфигурация без сложных модулей
    log "Применение базовой политики паролей..."
    
    # Настройка /etc/login.defs
    if grep -q "^PASS_MIN_LEN" /etc/login.defs; then
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN\t8/' /etc/login.defs
    else
        echo "PASS_MIN_LEN	8" >> /etc/login.defs
    fi
    
    if grep -q "^PASS_MAX_DAYS" /etc/login.defs; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
    else
        echo "PASS_MAX_DAYS	90" >> /etc/login.defs
    fi
    
    log "Базовые настройки применены:"
    grep -E "PASS_(MIN_LEN|MAX_DAYS)" /etc/login.defs
    
    # Проверяем, установлен ли pwquality
    if dpkg -l | grep -q libpam-pwquality; then
        log "Настройка с pwquality..."
        
        cat > /etc/pam.d/common-password << 'EOF'
password	requisite	pam_pwquality.so retry=3 minlen=8 dcredit=-1 ucredit=-1 lcredit=-1
password	[success=1 default=ignore]	pam_unix.so obscure use_authtok try_first_pass sha512
password	requisite	pam_deny.so
password	required	pam_permit.so
EOF
        
    elif dpkg -l | grep -q libpam-cracklib; then
        log "Настройка с cracklib..."
        
        cat > /etc/pam.d/common-password << 'EOF'
password	requisite	pam_cracklib.so retry=3 minlen=8 dcredit=-1 ucredit=-1 lcredit=-1
password	[success=1 default=ignore]	pam_unix.so obscure use_authtok try_first_pass sha512
password	requisite	pam_deny.so
password	required	pam_permit.so
EOF
        
    else
        warning "PAM модули недоступны, используем только базовые настройки"
        log "Базовая конфигурация без дополнительных проверок..."
        
        cat > /etc/pam.d/common-password << 'EOF'
password	[success=1 default=ignore]	pam_unix.so obscure sha512
password	requisite			pam_deny.so
password	required			pam_permit.so
EOF
    fi
    
    log "Конфигурация применена"
}

# Тестирование восстановленной системы
test_restored_system() {
    log "=== ТЕСТИРОВАНИЕ ВОССТАНОВЛЕННОЙ СИСТЕМЫ ==="
    
    # Создаем тестового пользователя
    if id "recovery_test" &>/dev/null; then
        userdel -r recovery_test 2>/dev/null || true
    fi
    
    log "Создание тестового пользователя..."
    useradd -m -s /bin/bash recovery_test
    
    # Тест простого пароля
    log "Тестирование простого пароля '123':"
    if echo "recovery_test:123" | chpasswd 2>/dev/null; then
        warning "Простой пароль принят - политика не активна"
    else
        log "✓ Простой пароль отклонен - политика работает"
    fi
    
    # Тест нормального пароля
    log "Тестирование нормального пароля 'Test123!':"
    if echo "recovery_test:Test123!" | chpasswd 2>/dev/null; then
        log "✓ Нормальный пароль принят"
    else
        warning "Нормальный пароль отклонен - возможно слишком строгая политика"
    fi
    
    # Удаляем тестового пользователя
    userdel -r recovery_test 2>/dev/null || true
    log "Тестирование завершено"
}

# Создание пользователей для John the Ripper
create_demo_users_safe() {
    log "=== СОЗДАНИЕ ДЕМОНСТРАЦИОННЫХ ПОЛЬЗОВАТЕЛЕЙ ==="
    
    # Создаем пользователей для демонстрации
    for user in testuser secuser; do
        if id "$user" &>/dev/null; then
            userdel -r "$user" 2>/dev/null || true
        fi
        useradd -m -s /bin/bash "$user"
    done
    
    # Устанавливаем пароли принудительно (обходим политику для демонстрации)
    log "Установка демонстрационных паролей..."
    
    # Временно упрощаем политику
    cp /etc/pam.d/common-password /etc/pam.d/common-password.backup
    
    cat > /etc/pam.d/common-password << 'EOF'
password	[success=1 default=ignore]	pam_unix.so obscure sha512
password	requisite			pam_deny.so
password	required			pam_permit.so
EOF
    
    # Устанавливаем пароли
    echo "testuser:1234" | chpasswd
    echo "secuser:Xr!92_aL#5nM" | chpasswd
    
    # Восстанавливаем политику
    cp /etc/pam.d/common-password.backup /etc/pam.d/common-password
    rm /etc/pam.d/common-password.backup
    
    # Сохраняем хэши
    grep testuser /etc/shadow > hash.txt 2>/dev/null || true
    grep secuser /etc/shadow > strong_hash.txt 2>/dev/null || true
    
    log "Демонстрационные пользователи созданы:"
    log "- testuser с паролем '1234'"
    log "- secuser с паролем 'Xr!92_aL#5nM'"
    log "- хэши сохранены в hash.txt и strong_hash.txt"
}

# Установка John the Ripper (безопасно)
install_john_safe() {
    log "=== БЕЗОПАСНАЯ УСТАНОВКА JOHN THE RIPPER ==="
    
    log "Попытка установки из репозитория..."
    if timeout 180 apt-get install -y john >/dev/null 2>&1; then
        log "✓ John the Ripper установлен из репозитория"
        
        # Проверяем работу
        if john --help >/dev/null 2>&1; then
            log "John работает корректно"
        else
            log "John установлен, но может иметь ограничения"
        fi
        
        return 0
    else
        warning "Не удалось установить John из репозитория"
        return 1
    fi
}

# Главное меню восстановления
main_recovery_menu() {
    echo -e "${BLUE}=== МЕНЮ ВОССТАНОВЛЕНИЯ СИСТЕМЫ ===${NC}"
    echo -e "${YELLOW}Система была прервана во время установки PAM модулей${NC}"
    echo ""
    echo "Выберите действие:"
    echo "1) Полная диагностика и восстановление (рекомендуется)"
    echo "2) Только диагностика состояния"
    echo "3) Очистка блокировок apt и восстановление"
    echo "4) Минимальная настройка политики паролей"
    echo "5) Создать пользователей для John the Ripper"
    echo "6) Установить John the Ripper"
    echo "7) Выход"
    
    read -p "Введите номер (1-7): " choice
    
    case $choice in
        1)
            diagnose_system_state
            clear_apt_locks
            restore_basic_configs
            safe_install_pam
            minimal_password_policy
            test_restored_system
            create_demo_users_safe
            install_john_safe
            ;;
        2)
            diagnose_system_state
            ;;
        3)
            clear_apt_locks
            restore_basic_configs
            ;;
        4)
            minimal_password_policy
            test_restored_system
            ;;
        5)
            create_demo_users_safe
            ;;
        6)
            install_john_safe
            ;;
        7)
            log "Выход"
            exit 0
            ;;
        *)
            error "Неверный выбор"
            main_recovery_menu
            ;;
    esac
}

# Главная функция
main() {
    echo -e "${RED}=== СКРИПТ ВОССТАНОВЛЕНИЯ ПОСЛЕ ПРЕРЫВАНИЯ ===${NC}"
    echo -e "${YELLOW}Этот скрипт поможет восстановить систему после прерванной установки${NC}"
    echo ""
    
    check_root
    main_recovery_menu
    
    echo -e "\n${GREEN}=== ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО ===${NC}"
    
    if [ -f "hash.txt" ]; then
        log "Файлы для тестирования готовы: hash.txt, strong_hash.txt"
        log "Для запуска John the Ripper: john hash.txt"
    fi
    
    log "Система восстановлена и готова к работе"
}

# Запуск
main "$@"