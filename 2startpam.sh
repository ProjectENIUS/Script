#!/bin/bash

# Скрипт установки лучшего PAM модуля с принудительной настройкой
# Advanced PAM Password Policy with pam_passwdqc

set -e

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
        error "Скрипт должен запускаться с правами root"
        exit 1
    fi
}

# Анализ доступных PAM модулей
analyze_pam_modules() {
    log "=== АНАЛИЗ ДОСТУПНЫХ PAM МОДУЛЕЙ ==="
    
    echo -e "\n${BLUE}Доступные модули для политики паролей:${NC}"
    
    echo -e "\n1. ${YELLOW}pam_passwdqc${NC} - ЛУЧШИЙ ВЫБОР"
    echo "   ✓ Очень гибкая настройка"
    echo "   ✓ Продвинутые алгоритмы проверки"
    echo "   ✓ Поддержка сложных политик"
    echo "   ✓ Активно поддерживается"
    
    echo -e "\n2. ${YELLOW}pam_pwquality${NC} - Хороший выбор"
    echo "   ✓ Современный стандарт"
    echo "   ⚠ Менее гибкий чем passwdqc"
    
    echo -e "\n3. ${YELLOW}pam_cracklib${NC} - Устаревший"
    echo "   ⚠ Старый, менее безопасный"
    
    echo -e "\n4. ${YELLOW}pam_pwhistory${NC} - Дополнительный"
    echo "   ✓ Запоминание истории паролей"
    
    echo -e "\n${GREEN}РЕКОМЕНДАЦИЯ: Используем pam_passwdqc${NC}"
}

# Очистка всех конфликтующих PAM модулей
clean_conflicting_pam() {
    log "=== ОЧИСТКА КОНФЛИКТУЮЩИХ PAM МОДУЛЕЙ ==="
    
    # Создаем резервную копию
    BACKUP_DIR="/root/pam_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r /etc/pam.d/ "$BACKUP_DIR/"
    log "Резервная копия создана: $BACKUP_DIR"
    
    # Отключаем автоматическое управление PAM
    warning "Отключение pam-auth-update для предотвращения конфликтов..."
    
    # Помечаем файлы как управляемые вручную
    if [ -f /etc/pam.d/common-password ]; then
        # Удаляем метки pam-auth-update
        sed -i '/# here are the per-package modules/d' /etc/pam.d/common-password
        sed -i '/# and here are more per-package modules/d' /etc/pam.d/common-password
        sed -i '/# end of pam-auth-update config/d' /etc/pam.d/common-password
    fi
    
    # Блокируем автоматические обновления PAM
    cat > /etc/pam.d/.pam-auth-update-disable << 'EOF'
# Automatic PAM updates disabled for manual password policy management
# Created by advanced password policy script
EOF
    
    log "Конфликтующие модули отключены"
}

# Установка pam_passwdqc
install_pam_passwdqc() {
    log "=== УСТАНОВКА PAM_PASSWDQC ==="
    
    # Очищаем блокировки если есть
    pkill -f apt >/dev/null 2>&1 || true
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock /var/cache/apt/archives/lock
    
    # Обновляем репозитории
    log "Обновление репозиториев..."
    apt-get update -qq
    
    # Устанавливаем pam_passwdqc
    log "Установка libpam-passwdqc..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-passwdqc >/dev/null 2>&1
    
    # Проверяем установку
    if [ -f "/lib/x86_64-linux-gnu/security/pam_passwdqc.so" ] || [ -f "/lib/security/pam_passwdqc.so" ]; then
        log "✓ pam_passwdqc успешно установлен"
        
        # Показываем путь к модулю
        find /lib -name "pam_passwdqc.so" 2>/dev/null | head -1
    else
        error "Ошибка установки pam_passwdqc"
        return 1
    fi
    
    # Удаляем конфликтующие пакеты
    log "Удаление конфликтующих PAM модулей..."
    apt-get remove --purge -y libpam-pwquality libpam-cracklib >/dev/null 2>&1 || true
    
    log "pam_passwdqc готов к использованию"
}

# Создание принудительной конфигурации PAM
create_forced_pam_config() {
    log "=== СОЗДАНИЕ ПРИНУДИТЕЛЬНОЙ КОНФИГУРАЦИИ PAM ==="
    
    # Создаем новую конфигурацию с ТОЛЬКО нужным модулем
    cat > /etc/pam.d/common-password << 'EOF'
#
# ПРИНУДИТЕЛЬНАЯ КОНФИГУРАЦИЯ ПОЛИТИКИ ПАРОЛЕЙ
# Управляется вручную - НЕ ИЗМЕНЯТЬ автоматически!
# Advanced Password Policy with pam_passwdqc ONLY
#

# ОСНОВНОЙ МОДУЛЬ: pam_passwdqc (принудительно)
# Очень строгая политика паролей
password	required	pam_passwdqc.so min=disabled,disabled,disabled,12,8 max=40 passphrase=3 match=4 similar=deny random=47 enforce=everyone retry=3

# ДОПОЛНИТЕЛЬНО: История паролей (запрет повтора последних 5 паролей)
password	required	pam_pwhistory.so remember=5 enforce_for_root

# ОСНОВНОЙ: Unix обработка паролей (ОБЯЗАТЕЛЬНО с use_authtok)
password	required	pam_unix.so use_authtok sha512 rounds=65536

# ЗАВЕРШЕНИЕ: Успех всегда (если дошли до этого места)
password	required	pam_permit.so

#
# КОНЕЦ ПРИНУДИТЕЛЬНОЙ КОНФИГУРАЦИИ
# Все модули выполняются ОБЯЗАТЕЛЬНО (required, не requisite)
#
EOF

    log "Принудительная конфигурация создана"
    
    echo -e "\n${BLUE}Объяснение настроек pam_passwdqc:${NC}"
    echo "min=disabled,disabled,disabled,12,8 - минимум 12 символов для сложных паролей, 8 для простых"
    echo "max=40 - максимум 40 символов"
    echo "passphrase=3 - парольные фразы из 3+ слов разрешены"
    echo "match=4 - максимум 4 совпадающих символа подряд"
    echo "similar=deny - запрет похожих на старый пароль"
    echo "random=47 - случайные пароли из 47 символов принимаются"
    echo "enforce=everyone - политика для всех пользователей включая root"
    echo "retry=3 - 3 попытки ввода"
}

# Создание альтернативной строгой конфигурации
create_ultra_strict_config() {
    log "=== СОЗДАНИЕ УЛЬТРА-СТРОГОЙ КОНФИГУРАЦИИ ==="
    
    cat > /etc/pam.d/common-password << 'EOF'
#
# УЛЬТРА-СТРОГАЯ ПОЛИТИКА ПАРОЛЕЙ
# pam_passwdqc + дополнительные ограничения
#

# УЛЬТРА-СТРОГИЙ pam_passwdqc
password	required	pam_passwdqc.so min=disabled,disabled,disabled,16,12 max=128 passphrase=4 match=3 similar=deny random=64 enforce=everyone retry=3

# ИСТОРИЯ: Запрет последних 10 паролей
password	required	pam_pwhistory.so remember=10 enforce_for_root

# UNIX с максимальными rounds для хеширования
password	required	pam_unix.so use_authtok sha512 rounds=100000

# Успех
password	required	pam_permit.so
EOF

    log "Ультра-строгая конфигурация создана"
    
    echo -e "\n${BLUE}Ультра-строгие настройки:${NC}"
    echo "- Минимум 16 символов для сложных паролей"
    echo "- Парольные фразы минимум из 4 слов"
    echo "- Максимум 3 одинаковых символа подряд"
    echo "- Запрет последних 10 паролей"
    echo "- 100,000 rounds хеширования"
}

# Конфигурация /etc/login.defs
configure_login_defs_advanced() {
    log "=== РАСШИРЕННАЯ НАСТРОЙКА /etc/login.defs ==="
    
    # Создаем усиленную конфигурацию
    cp /etc/login.defs /etc/login.defs.backup
    
    # Обновляем параметры
    cat >> /etc/login.defs << 'EOF'

#
# РАСШИРЕННЫЕ НАСТРОЙКИ БЕЗОПАСНОСТИ ПАРОЛЕЙ
#
PASS_MAX_DAYS	60
PASS_MIN_DAYS	1
PASS_MIN_LEN	16
PASS_WARN_AGE	14

# Дополнительные настройки безопасности
LOGIN_RETRIES	3
LOGIN_TIMEOUT	60
UMASK		027
ENCRYPT_METHOD	SHA512
SHA_CRYPT_MIN_ROUNDS	100000
SHA_CRYPT_MAX_ROUNDS	100000
EOF

    log "Расширенные настройки применены"
}

# Блокировка автоматических изменений
lock_pam_config() {
    log "=== БЛОКИРОВКА КОНФИГУРАЦИИ ОТ ИЗМЕНЕНИЙ ==="
    
    # Делаем файлы только для чтения
    chattr +i /etc/pam.d/common-password 2>/dev/null || {
        # Если chattr недоступен, используем chmod
        chmod 444 /etc/pam.d/common-password
        warning "chattr недоступен, используем chmod 444"
    }
    
    # Создаем защитный скрипт
    cat > /usr/local/bin/protect-pam-config << 'EOF'
#!/bin/bash
# Защита конфигурации PAM от автоматических изменений

if [ "$1" == "unlock" ]; then
    chattr -i /etc/pam.d/common-password 2>/dev/null || chmod 644 /etc/pam.d/common-password
    echo "PAM конфигурация разблокирована для редактирования"
elif [ "$1" == "lock" ]; then
    chattr +i /etc/pam.d/common-password 2>/dev/null || chmod 444 /etc/pam.d/common-password
    echo "PAM конфигурация заблокирована от изменений"
else
    echo "Использование: $0 {lock|unlock}"
    echo "lock   - заблокировать конфигурацию"
    echo "unlock - разблокировать для редактирования"
fi
EOF

    chmod +x /usr/local/bin/protect-pam-config
    
    log "Конфигурация заблокирована от автоматических изменений"
    log "Для разблокировки: /usr/local/bin/protect-pam-config unlock"
}

# Тестирование принудительной политики
test_forced_policy() {
    log "=== ТЕСТИРОВАНИЕ ПРИНУДИТЕЛЬНОЙ ПОЛИТИКИ ==="
    
    # Создаем тестового пользователя
    if id "policy_test" &>/dev/null; then
        userdel -r policy_test 2>/dev/null || true
    fi
    
    useradd -m -s /bin/bash policy_test
    
    # Массив тестовых паролей
    declare -A test_passwords=(
        ["123"]="простой цифровой"
        ["password"]="словарное слово"
        ["Password1"]="простой с заглавной"
        ["MyPassword123"]="средней сложности"
        ["MyStr0ng!P@ssw0rd"]="сильный короткий"
        ["This_Is_My_Very_Secure_Password_2024!"]="очень сильный длинный"
        ["correct horse battery staple"]="парольная фраза"
    )
    
    echo -e "\n${BLUE}Тестирование различных паролей:${NC}"
    
    for password in "${!test_passwords[@]}"; do
        description="${test_passwords[$password]}"
        echo -n "[$description] '$password': "
        
        if echo "policy_test:$password" | chpasswd 2>/dev/null; then
            echo -e "${GREEN}✓ ПРИНЯТ${NC}"
        else
            echo -e "${RED}✗ ОТКЛОНЕН${NC}"
        fi
    done
    
    # Удаляем тестового пользователя
    userdel -r policy_test 2>/dev/null || true
}

# Создание демонстрационных пользователей для John
create_demo_users_advanced() {
    log "=== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ ДЛЯ JOHN THE RIPPER ==="
    
    # Временно разблокируем конфигурацию
    /usr/local/bin/protect-pam-config unlock >/dev/null 2>&1 || chmod 644 /etc/pam.d/common-password
    
    # Сохраняем текущую конфигурацию
    cp /etc/pam.d/common-password /etc/pam.d/common-password.strict
    
    # Создаем временную упрощенную конфигурацию для создания демо-пользователей
    cat > /etc/pam.d/common-password << 'EOF'
password	[success=1 default=ignore]	pam_unix.so obscure sha512
password	requisite			pam_deny.so
password	required			pam_permit.so
EOF

    # Создаем пользователей
    for user in testuser secuser; do
        if id "$user" &>/dev/null; then
            userdel -r "$user" 2>/dev/null || true
        fi
        useradd -m -s /bin/bash "$user"
    done
    
    # Устанавливаем пароли
    echo "testuser:1234" | chpasswd
    echo "secuser:This_Is_Ultra_Secure_Password_2024!" | chpasswd
    
    # Восстанавливаем строгую конфигурацию
    cp /etc/pam.d/common-password.strict /etc/pam.d/common-password
    rm /etc/pam.d/common-password.strict
    
    # Блокируем обратно
    /usr/local/bin/protect-pam-config lock >/dev/null 2>&1 || chmod 444 /etc/pam.d/common-password
    
    # Сохраняем хэши
    grep testuser /etc/shadow > hash.txt
    grep secuser /etc/shadow > strong_hash.txt
    
    log "Демонстрационные пользователи созданы:"
    log "- testuser: простой пароль '1234'"
    log "- secuser: сложный пароль 'This_Is_Ultra_Secure_Password_2024!'"
}

# Установка John the Ripper оптимизированная
install_john_optimized() {
    log "=== УСТАНОВКА ОПТИМИЗИРОВАННОГО JOHN THE RIPPER ==="
    
    # Сначала пробуем из репозитория
    if apt-get install -y john >/dev/null 2>&1; then
        log "✓ John установлен из репозитория"
        
        # Проверяем работу
        if john --test=0 >/dev/null 2>&1; then
            log "✓ John работает корректно"
        else
            log "John установлен, возможны ограничения"
        fi
    else
        warning "Не удалось установить John из репозитория"
    fi
}

# Демонстрация взлома
demonstrate_cracking() {
    log "=== ДЕМОНСТРАЦИЯ ВЗЛОМА ПАРОЛЕЙ ==="
    
    if [ ! -f "hash.txt" ] || [ ! -f "strong_hash.txt" ]; then
        error "Файлы с хэшами не найдены. Создайте пользователей сначала."
        return 1
    fi
    
    if ! command -v john >/dev/null; then
        error "John the Ripper не установлен"
        return 1
    fi
    
    echo -e "\n${BLUE}Взлом простого пароля:${NC}"
    timeout 60 john hash.txt || true
    john --show hash.txt 2>/dev/null || echo "Результаты недоступны"
    
    echo -e "\n${BLUE}Попытка взлома сложного пароля (30 сек):${NC}"
    timeout 30 john strong_hash.txt || true
    john --show strong_hash.txt 2>/dev/null || echo "Сложный пароль не взломан (ожидаемо)"
}

# Главное меню
main_menu() {
    echo -e "${BLUE}=== УСТАНОВКА ЛУЧШЕГО PAM МОДУЛЯ (ПРИНУДИТЕЛЬНО) ===${NC}"
    echo ""
    echo "Выберите конфигурацию:"
    echo "1) Полная установка с анализом (рекомендуется)"
    echo "2) Быстрая установка строгой политики"
    echo "3) Ультра-строгая политика (максимальная безопасность)"
    echo "4) Только анализ модулей"
    echo "5) Создать демо-пользователей для John"
    echo "6) Запустить демонстрацию взлома"
    echo "7) Разблокировать/заблокировать конфигурацию"
    
    read -p "Введите номер (1-7): " choice
    
    case $choice in
        1)
            analyze_pam_modules
            clean_conflicting_pam
            install_pam_passwdqc
            create_forced_pam_config
            configure_login_defs_advanced
            lock_pam_config
            test_forced_policy
            create_demo_users_advanced
            install_john_optimized
            ;;
        2)
            clean_conflicting_pam
            install_pam_passwdqc
            create_forced_pam_config
            lock_pam_config
            test_forced_policy
            ;;
        3)
            clean_conflicting_pam
            install_pam_passwdqc
            create_ultra_strict_config
            configure_login_defs_advanced
            lock_pam_config
            test_forced_policy
            ;;
        4)
            analyze_pam_modules
            ;;
        5)
            create_demo_users_advanced
            ;;
        6)
            demonstrate_cracking
            ;;
        7)
            echo "1) Разблокировать конфигурацию"
            echo "2) Заблокировать конфигурацию"
            read -p "Выбор: " subchoice
            if [ "$subchoice" == "1" ]; then
                /usr/local/bin/protect-pam-config unlock
            elif [ "$subchoice" == "2" ]; then
                /usr/local/bin/protect-pam-config lock
            fi
            ;;
        *)
            error "Неверный выбор"
            main_menu
            ;;
    esac
}

# Главная функция
main() {
    check_root
    main_menu
    
    echo -e "\n${GREEN}=== НАСТРОЙКА ЗАВЕРШЕНА ===${NC}"
    echo -e "\n${YELLOW}Важные файлы:${NC}"
    echo "- Конфигурация: /etc/pam.d/common-password"
    echo "- Защита: /usr/local/bin/protect-pam-config"
    echo "- Хэши для John: hash.txt, strong_hash.txt"
    
    echo -e "\n${YELLOW}Команды для управления:${NC}"
    echo "- Разблокировать PAM: /usr/local/bin/protect-pam-config unlock"
    echo "- Заблокировать PAM: /usr/local/bin/protect-pam-config lock"
    echo "- Запуск John: john hash.txt"
}

# Запуск
main "$@"