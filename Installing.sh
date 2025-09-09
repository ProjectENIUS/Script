#!/bin/bash

# =============================================================================
# Ubuntu/Debian Server Auto-Deployment Script
# Автоматическое развертывание сервера Ubuntu/Debian
# Version: 2.0
# =============================================================================

set -euo pipefail  # Строгий режим выполнения

# Константы и конфигурация
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/server-deployment.log"
readonly BACKUP_DIR="/tmp/config-backup-$(date +%Y%m%d-%H%M%S)"
readonly CONFIG_DIR="${SCRIPT_DIR}/configs"

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Поддерживаемые дистрибутивы
declare -A SUPPORTED_DISTROS=(
    ["ubuntu"]="apt-get"
    ["debian"]="apt-get"
    ["centos"]="yum"
    ["fedora"]="dnf"
)

# =============================================================================
# Утилиты и функции логирования
# =============================================================================

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "${RED}[ERROR]${NC} $*"
}

# Функция для отображения прогресса
show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    printf "\r${BLUE}[%d/%d] (%d%%) %s${NC}" "$current" "$total" "$percent" "$task"
}

# =============================================================================
# Функции проверки системы
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами суперпользователя"
        log_info "Используйте: sudo $0"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        local distro_id="${ID,,}"
        
        if [[ -v SUPPORTED_DISTROS["$distro_id"] ]]; then
            echo "$distro_id"
        else
            log_error "Неподдерживаемый дистрибутив: $ID"
            log_info "Поддерживаемые дистрибутивы: ${!SUPPORTED_DISTROS[*]}"
            exit 1
        fi
    else
        log_error "Не удалось определить дистрибутив"
        exit 1
    fi
}

get_package_manager() {
    local distro=$1
    echo "${SUPPORTED_DISTROS[$distro]}"
}

# Проверка сетевого подключения
check_network() {
    log_info "Проверка сетевого подключения..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "Отсутствует сетевое подключение"
        return 1
    fi
    log_success "Сетевое подключение активно"
}

# =============================================================================
# Функции управления пакетами
# =============================================================================

update_system() {
    local pkg_manager=$1
    log_info "Обновление системы..."
    
    case "$pkg_manager" in
        "apt-get")
            apt-get update -qq
            apt-get upgrade -y -qq
            ;;
        "yum")
            yum update -y -q
            ;;
        "dnf")
            dnf update -y -q
            ;;
    esac
    
    log_success "Система обновлена"
}

install_package() {
    local pkg_manager=$1
    local package_name=$2
    local display_name=$3
    
    # Проверка установлен ли пакет
    local is_installed=false
    case "$pkg_manager" in
        "apt-get")
            if dpkg -l | grep -q "^ii  $package_name "; then
                is_installed=true
            fi
            ;;
        "yum"|"dnf")
            if rpm -q "$package_name" &> /dev/null; then
                is_installed=true
            fi
            ;;
    esac
    
    if [[ "$is_installed" == "true" ]]; then
        log_info "$display_name уже установлен"
        return 0
    fi
    
    # Установка пакета
    log_info "Установка $display_name..."
    case "$pkg_manager" in
        "apt-get")
            if apt-get install -y -qq "$package_name"; then
                log_success "$display_name установлен"
                return 0
            fi
            ;;
        "yum")
            if yum install -y -q "$package_name"; then
                log_success "$display_name установлен"
                return 0
            fi
            ;;
        "dnf")
            if dnf install -y -q "$package_name"; then
                log_success "$display_name установлен"
                return 0
            fi
            ;;
    esac
    
    log_error "Не удалось установить $display_name"
    return 1
}

# =============================================================================
# Функции валидации ввода
# =============================================================================

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

validate_mac() {
    local mac=$1
    if [[ $mac =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
        return 0
    fi
    return 1
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    return 1
}

# Безопасный ввод с валидацией
safe_read() {
    local prompt=$1
    local validation_func=$2
    local result
    
    while true; do
        read -p "$prompt: " result
        if [[ -n "$result" ]] && $validation_func "$result"; then
            echo "$result"
            return 0
        else
            log_warning "Некорректный ввод. Попробуйте снова."
        fi
    done
}

yes_no_prompt() {
    local prompt=$1
    local default=${2:-""}
    local response
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " response
            response=${response:-$default}
        else
            read -p "$prompt (yes/no): " response
        fi
        
        case "${response,,}" in
            yes|y|да|д) return 0 ;;
            no|n|нет|н) return 1 ;;
            *) log_warning "Введите 'yes' или 'no'" ;;
        esac
    done
}

# =============================================================================
# Функции резервного копирования
# =============================================================================

backup_file() {
    local file_path=$1
    
    if [[ -f "$file_path" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_name="${BACKUP_DIR}/$(basename "$file_path").backup"
        cp "$file_path" "$backup_name"
        log_info "Создана резервная копия: $backup_name"
    fi
}

restore_backup() {
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Восстановление резервных копий из $BACKUP_DIR"
        # Логика восстановления
    fi
}

# =============================================================================
# Функции настройки сервисов
# =============================================================================

configure_dhcp_server() {
    local pkg_manager=$1
    
    log_info "Настройка DHCP сервера..."
    
    # Установка пакета
    case "$pkg_manager" in
        "apt-get")
            install_package "$pkg_manager" "isc-dhcp-server" "ISC DHCP Server"
            ;;
        "yum"|"dnf")
            install_package "$pkg_manager" "dhcp-server" "DHCP Server"
            ;;
    esac
    
    if ! yes_no_prompt "Настроить DHCP сервер?"; then
        return 0
    fi
    
    # Резервное копирование
    backup_file "/etc/dhcp/dhcpd.conf"
    backup_file "/etc/default/isc-dhcp-server"
    
    # Интерактивная настройка
    configure_dhcp_pools
    configure_dhcp_interfaces
    
    # Перезапуск сервиса
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    log_success "DHCP сервер настроен и запущен"
}

configure_dhcp_pools() {
    local config_file="/etc/dhcp/dhcpd.conf"
    
    cat > "$config_file" << 'EOF'
# DHCP Server Configuration
# Generated by auto-deployment script

authoritative;
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;

EOF
    
    while true; do
        log_info "Настройка пула DHCP адресов"
        
        local subnet=$(safe_read "Укажите подсеть (например, 192.168.1.0)" validate_ip)
        local netmask=$(safe_read "Укажите маску подсети (например, 255.255.255.0)" validate_ip)
        local range_start=$(safe_read "Начальный IP диапазона" validate_ip)
        local range_end=$(safe_read "Конечный IP диапазона" validate_ip)
        local gateway=$(safe_read "IP шлюза" validate_ip)
        local dns_servers=$(safe_read "DNS серверы (через запятую)" validate_ip)
        
        cat >> "$config_file" << EOF

subnet $subnet netmask $netmask {
    range $range_start $range_end;
    option routers $gateway;
    option domain-name-servers $dns_servers;
    option broadcast-address $(calculate_broadcast "$subnet" "$netmask");
    default-lease-time 600;
    max-lease-time 7200;
}
EOF
        
        if ! yes_no_prompt "Добавить еще один пул?"; then
            break
        fi
    done
}

configure_dhcp_interfaces() {
    log_info "Доступные сетевые интерфейсы:"
    ip -o -4 addr show | awk '{print $2, $4}' | while read -r interface ip; do
        printf "  %-10s %s\n" "$interface" "$ip"
    done
    
    local interface
    interface=$(safe_read "Выберите интерфейс для DHCP" validate_interface)
    
    cat > "/etc/default/isc-dhcp-server" << EOF
# Configuration for ISC DHCP server
INTERFACESv4="$interface"
INTERFACESv6=""
EOF
}

# Функция для проверки корректности интерфейса
validate_interface() {
    local interface=$1
    if ip link show "$interface" &> /dev/null; then
        return 0
    fi
    return 1
}

# Вычисление broadcast адреса
calculate_broadcast() {
    local network=$1
    local netmask=$2
    # Здесь должна быть логика вычисления broadcast адреса
    echo "192.168.1.255"  # Заглушка
}

configure_dns_server() {
    local pkg_manager=$1
    
    if ! yes_no_prompt "Установить и настроить DNS сервер (BIND9)?"; then
        return 0
    fi
    
    log_info "Настройка DNS сервера..."
    install_package "$pkg_manager" "bind9" "BIND9 DNS Server"
    
    # Запуск отдельного скрипта настройки DNS
    if [[ -f "${SCRIPT_DIR}/autoconfig.sh" ]]; then
        bash "${SCRIPT_DIR}/autoconfig.sh"
    else
        configure_dns_interactive
    fi
}

configure_web_server() {
    local pkg_manager=$1
    
    if ! yes_no_prompt "Установить веб-сервер?"; then
        return 0
    fi
    
    log_info "Выберите веб-сервер:"
    echo "1) Nginx"
    echo "2) Apache2"
    echo "3) Пропустить"
    
    local choice
    read -p "Ваш выбор [1-3]: " choice
    
    case "$choice" in
        1)
            install_package "$pkg_manager" "nginx" "Nginx"
            systemctl enable nginx
            systemctl start nginx
            ;;
        2)
            install_package "$pkg_manager" "apache2" "Apache2"
            systemctl enable apache2
            systemctl start apache2
            ;;
        3)
            log_info "Установка веб-сервера пропущена"
            ;;
        *)
            log_warning "Неверный выбор, пропуск установки веб-сервера"
            ;;
    esac
}

configure_database() {
    local pkg_manager=$1
    
    if ! yes_no_prompt "Установить базу данных?"; then
        return 0
    fi
    
    log_info "Выберите СУБД:"
    echo "1) MariaDB"
    echo "2) PostgreSQL"
    echo "3) SQLite"
    echo "4) Пропустить"
    
    local choice
    read -p "Ваш выбор [1-4]: " choice
    
    case "$choice" in
        1)
            install_package "$pkg_manager" "mariadb-server" "MariaDB"
            systemctl enable mariadb
            systemctl start mariadb
            log_info "Запустите 'mysql_secure_installation' для безопасной настройки"
            ;;
        2)
            install_package "$pkg_manager" "postgresql" "PostgreSQL"
            systemctl enable postgresql
            systemctl start postgresql
            ;;
        3)
            install_package "$pkg_manager" "sqlite3" "SQLite"
            ;;
        4)
            log_info "Установка СУБД пропущена"
            ;;
    esac
}
# =============================================================================
# Интеграция настройки терминала в главный скрипт
# =============================================================================

configure_advanced_terminal() {
    if ! yes_no_prompt "Настроить продвинутый терминал?"; then
        return 0
    fi
    
    log_info "Запуск настройки продвинутого терминала..."
    
    local terminal_setup_script="${SCRIPT_DIR}/terminal_setup.sh"
    
    if [[ -f "$terminal_setup_script" ]]; then
        bash "$terminal_setup_script"
    else
        log_error "Скрипт настройки терминала не найден: $terminal_setup_script"
        log_info "Создание базовой настройки терминала..."
        
        # Базовая настройка если скрипт недоступен
        apt install -y tmux ranger fzf bat exa htop neofetch
        echo "alias fb='ranger'" >> "$HOME/.bashrc"
        log_success "Базовая настройка терминала завершена"
    fi
}

# =============================================================================
# Функции быстрой установки
# =============================================================================

quick_install() {
    log_info "=== РЕЖИМ БЫСТРОЙ УСТАНОВКИ ==="
    log_info "Будут установлены: DHCP, DNS, Nginx, основные утилиты"
    
    if ! yes_no_prompt "Продолжить быструю установку?"; then
        return 1
    fi
    
    local distro pkg_manager
    distro=$(detect_distro)
    pkg_manager=$(get_package_manager "$distro")
    
    # Список пакетов для быстрой установки
    local packages=(
        "isc-dhcp-server:DHCP Server"
        "bind9:DNS Server"
        "nginx:Web Server"
        "iptables-persistent:Firewall"
        "htop:System Monitor"
        "curl:HTTP Client"
        "wget:Downloader"
        "vim:Text Editor"
    )
    
    local total=${#packages[@]}
    local current=0
    
    for package_info in "${packages[@]}"; do
        ((current++))
        IFS=':' read -r package display_name <<< "$package_info"
        show_progress "$current" "$total" "Установка $display_name"
        install_package "$pkg_manager" "$package" "$display_name" || true
    done
    
	    # НОВОЕ: Автоматическая базовая настройка пользователей
    log_info "Настройка базовых профилей пользователей..."
    
    if [[ -f "${SCRIPT_DIR}/user_setup.sh" ]]; then
        # Автоматический режим с базовыми настройками
        export USER_SETUP_MODE="auto"
        bash "${SCRIPT_DIR}/user_setup.sh"
    fi
	
	    # Базовая настройка терминала в быстром режиме
    if [[ -f "${SCRIPT_DIR}/terminal_setup.sh" ]]; then
        log_info "Установка базовых терминальных утилит..."
        export TERMINAL_SETUP_MODE="basic"
        bash "${SCRIPT_DIR}/terminal_setup.sh"
    fi
	
    echo  # Новая строка после прогресса
    log_success "Быстрая установка завершена"
}

# =============================================================================
# Главная функция
# =============================================================================

main() {
    # Инициализация
    check_root
    
    # Создание лог-файла
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    
    log_info "=== ЗАПУСК СКРИПТА АВТОМАТИЧЕСКОГО РАЗВЕРТЫВАНИЯ СЕРВЕРА ==="
    log_info "Время запуска: $(date)"
    log_info "Пользователь: $(whoami)"
    log_info "Система: $(uname -a)"
    
    # Определение дистрибутива
    local distro pkg_manager
    distro=$(detect_distro)
    pkg_manager=$(get_package_manager "$distro")
    
    log_info "Обнаружен дистрибутив: $distro"
    log_info "Пакетный менеджер: $pkg_manager"
    
    # Проверка сети
    check_network || exit 1
    
    # Выбор режима установки
    echo
    log_info "Выберите режим установки:"
    echo "1) Быстрая установка (рекомендуемые пакеты)"
    echo "2) Интерактивная установка (выбор компонентов)"
    echo "3) Выход"
    
    local mode
    read -p "Ваш выбор [1-3]: " mode
    
    case "$mode" in
        1)
            quick_install
            ;;
        2)
            interactive_install "$distro" "$pkg_manager"
            ;;
        3)
            log_info "Выход из программы"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            exit 1
            ;;
    esac
    
    # Финальные действия
    log_success "=== УСТАНОВКА ЗАВЕРШЕНА ==="
    log_info "Лог сохранен в: $LOG_FILE"
    log_info "Резервные копии в: $BACKUP_DIR"
    
    if yes_no_prompt "Перезагрузить систему сейчас?"; then
        log_info "Перезагрузка системы..."
        reboot
    fi
}

interactive_install() {
    local distro=$1
    local pkg_manager=$2
    
    log_info "=== ИНТЕРАКТИВНАЯ УСТАНОВКА ==="
    
    # Обновление системы
    if yes_no_prompt "Обновить систему?"; then
        update_system "$pkg_manager"
    fi
    
    # Компоненты для установки
    configure_dhcp_server "$pkg_manager"
    configure_dns_server "$pkg_manager"
    configure_web_server "$pkg_manager"
    configure_database "$pkg_manager"
	
	# НОВОЕ: Настройка профилей пользователей
    configure_user_profiles
	
	configure_advanced_terminal
    
    # Настройка сети
    if yes_no_prompt "Настроить IP forwarding?"; then
        configure_ip_forwarding
    fi
    
    # Настройка firewall
    if yes_no_prompt "Настроить базовые правила firewall?"; then
        configure_firewall
    fi
}
configure_user_profiles() {
    local choice
    
    if ! yes_no_prompt "Настроить профили пользователей?"; then
        return 0
    fi
    
    log_info "Запуск настройки профилей пользователей..."
    
    # Проверка существования скрипта настройки пользователей
    local user_setup_script="${SCRIPT_DIR}/user_setup.sh"
    
    if [[ -f "$user_setup_script" ]]; then
        # Запуск скрипта настройки пользователей
        bash "$user_setup_script"
    else
        log_error "Скрипт настройки пользователей не найден: $user_setup_script"
        log_info "Пропуск настройки пользователей"
        return 1
    fi
}
configure_ip_forwarding() {
    log_info "Включение IP forwarding..."
    
    backup_file "/etc/sysctl.conf"
    
    if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        sed -i 's/#*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    else
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    sysctl -p
    log_success "IP forwarding включен"
}

configure_firewall() {
    log_info "Настройка базовых правил firewall..."
    
    # Показ интерфейсов
    log_info "Доступные сетевые интерфейсы:"
    ip -o -4 addr show | awk '{print $2, $4}'
    
    local wan_interface
    wan_interface=$(safe_read "Укажите WAN интерфейс (подключенный к интернету)" validate_interface)
    
    # Настройка NAT
    iptables -t nat -A POSTROUTING -o "$wan_interface" -j MASQUERADE
    iptables -A FORWARD -i "$wan_interface" -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i eth0 -o "$wan_interface" -j ACCEPT
    
    # Сохранение правил
    if yes_no_prompt "Сохранить правила iptables?"; then
        install_package "apt-get" "iptables-persistent" "iptables-persistent"
        iptables-save > /etc/iptables/rules.v4
        log_success "Правила firewall сохранены"
    fi
}
# НОВОЕ: Настройка продвинутого терминала


# Обработка сигналов
trap 'log_error "Скрипт прерван пользователем"; exit 130' INT
trap 'log_error "Произошла ошибка на строке $LINENO"; restore_backup; exit 1' ERR

# Запуск главной функции, если скрипт выполняется напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi