#!/bin/bash

# =============================================================================
# DNS Server Configuration Script (autoconfig.sh)
# Скрипт настройки DNS сервера
# Version: 2.0
# =============================================================================

set -euo pipefail

# Подключение основных функций
source "$(dirname "${BASH_SOURCE[0]}")/installing.sh" 2>/dev/null || {
    # Определение базовых функций, если основной скрипт недоступен
    log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
    log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
    log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }
    log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
}

readonly DNS_CONFIG_DIR="/etc/bind"
readonly ZONES_DIR="/var/lib/bind"

# =============================================================================
# Функции настройки DNS
# =============================================================================

configure_dns_main_options() {
    local config_file="$DNS_CONFIG_DIR/named.conf.options"
    
    log_info "Настройка основных параметров DNS..."
    backup_file "$config_file"
    
    local forwarders=()
    local listen_networks=()
    
    # Сбор forwarders
    while true; do
        local forwarder
        forwarder=$(safe_read "Укажите DNS forwarder (например, 8.8.8.8)" validate_ip)
        forwarders+=("$forwarder")
        
        if ! yes_no_prompt "Добавить еще один forwarder?"; then
            break
        fi
    done
    
    # Сбор разрешенных сетей
    while true; do
        local network
        read -p "Укажите сеть для разрешения запросов (например, 192.168.1.0/24): " network
        if [[ $network =~ ^[0-9.]+/[0-9]+$ ]]; then
            listen_networks+=("$network")
        else
            log_warning "Неверный формат сети"
            continue
        fi
        
        if ! yes_no_prompt "Добавить еще одну сеть?"; then
            break
        fi
    done
    
    # Создание конфигурации
    cat > "$config_file" << EOF
options {
    directory "/var/cache/bind";
    
    // Forwarders
    forwarders {
$(printf "        %s;\n" "${forwarders[@]}")
    };
    
    // Access control
    allow-query {
        localhost;
$(printf "        %s;\n" "${listen_networks[@]}")
    };
    
    // Security settings
    dnssec-validation auto;
    recursion yes;
    allow-recursion {
        localhost;
$(printf "        %s;\n" "${listen_networks[@]}")
    };
    
    // Performance
    max-cache-size 256M;
    cleaning-interval 60;
    
    // Logging
    listen-on-v6 { any; };
    
    // Disable zone transfers by default
    allow-transfer { none; };
};

// Logging configuration
logging {
    channel default_debug {
        file "/var/log/named/default.log";
        severity dynamic;
    };
};
EOF
    
    log_success "Основная конфигурация DNS создана"
}

create_forward_zone() {
    local zone_name domain_name zone_file
    
    zone_name=$(safe_read "Укажите имя прямой зоны (например, example.local)" validate_domain)
    domain_name="$zone_name"
    zone_file="$ZONES_DIR/db.$zone_name"
    
    log_info "Создание прямой зоны: $zone_name"
    
    # Добавление зоны в named.conf.local
    cat >> "$DNS_CONFIG_DIR/named.conf.local" << EOF

zone "$zone_name" {
    type master;
    file "$zone_file";
    allow-update { none; };
    allow-transfer { none; };
};
EOF
    
    # Создание файла зоны
    mkdir -p "$ZONES_DIR"
    
    local serial_number
    serial_number=$(date +%Y%m%d%H)
    
    local primary_ns admin_email
    primary_ns="ns1.$domain_name"
    admin_email="admin.$domain_name"
    
    cat > "$zone_file" << EOF
\$TTL 86400
@   IN  SOA $primary_ns. $admin_email. (
    $serial_number  ; Serial number
    3600            ; Refresh (1 hour)
    1800            ; Retry (30 minutes)
    604800          ; Expire (1 week)
    86400           ; Minimum TTL (1 day)
)

; Name servers
@               IN  NS      $primary_ns.

; Mail exchange (if needed)
; @             IN  MX  10  mail.$domain_name.

EOF
    
    # Добавление A записей
    add_dns_records "$zone_file" "$domain_name"
    
    log_success "Прямая зона $zone_name создана"
}

create_reverse_zone() {
    local network_ip reverse_zone zone_file
    
    network_ip=$(safe_read "Укажите сеть для обратной зоны (например, 192.168.1)" validate_network_prefix)
    
    # Создание имени обратной зоны
    IFS='.' read -ra octets <<< "$network_ip"
    case ${#octets[@]} in
        3) reverse_zone="${octets[2]}.${octets[1]}.${octets[0]}.in-addr.arpa" ;;
        2) reverse_zone="${octets[1]}.${octets[0]}.in-addr.arpa" ;;
        1) reverse_zone="${octets[0]}.in-addr.arpa" ;;
        *) log_error "Неверный формат сети"; return 1 ;;
    esac
    
    zone_file="$ZONES_DIR/db.$reverse_zone"
    
    log_info "Создание обратной зоны: $reverse_zone"
    
    # Добавление зоны в named.conf.local
    cat >> "$DNS_CONFIG_DIR/named.conf.local" << EOF

zone "$reverse_zone" {
    type master;
    file "$zone_file";
    allow-update { none; };
    allow-transfer { none; };
};
EOF
    
    # Создание файла обратной зоны
    local serial_number primary_ns
    serial_number=$(date +%Y%m%d%H)
    primary_ns="ns1.$(safe_read "Укажите основной домен" validate_domain)"
    
    cat > "$zone_file" << EOF
\$TTL 86400
@   IN  SOA $primary_ns. admin.$(echo "$primary_ns" | cut -d. -f2-). (
    $serial_number  ; Serial number
    3600            ; Refresh
    1800            ; Retry
    604800          ; Expire
    86400           ; Minimum TTL
)

@               IN  NS      $primary_ns.

EOF
    
    # Добавление PTR записей
    add_reverse_records "$zone_file" "$network_ip"
    
    log_success "Обратная зона $reverse_zone создана"
}

add_dns_records() {
    local zone_file=$1
    local domain_name=$2
    
    log_info "Добавление DNS записей"
    
    while true; do
        local hostname ip_address record_type
        
        echo "Выберите тип записи:"
        echo "1) A (IPv4 адрес)"
        echo "2) AAAA (IPv6 адрес)"
        echo "3) CNAME (псевдоним)"
        echo "4) MX (почтовый сервер)"
        echo "5) Завершить добавление"
        
        read -p "Ваш выбор [1-5]: " record_type
        
        case "$record_type" in
            1)
                hostname=$(safe_read "Имя хоста" validate_hostname)
                ip_address=$(safe_read "IP адрес" validate_ip)
                echo "$hostname        IN  A       $ip_address" >> "$zone_file"
                ;;
            2)
                hostname=$(safe_read "Имя хоста" validate_hostname)
                read -p "IPv6 адрес: " ip_address
                echo "$hostname        IN  AAAA    $ip_address" >> "$zone_file"
                ;;
            3)
                hostname=$(safe_read "Имя псевдонима" validate_hostname)
                local target
                target=$(safe_read "Целевое имя" validate_hostname)
                echo "$hostname        IN  CNAME   $target.$domain_name." >> "$zone_file"
                ;;
            4)
                local priority mail_server
                read -p "Приоритет (например, 10): " priority
                mail_server=$(safe_read "Почтовый сервер" validate_hostname)
                echo "@               IN  MX  $priority   $mail_server.$domain_name." >> "$zone_file"
                ;;
            5)
                break
                ;;
            *)
                log_warning "Неверный выбор"
                ;;
        esac
    done
}

add_reverse_records() {
    local zone_file=$1
    local network_prefix=$2
    
    while true; do
        local last_octet hostname
        
        read -p "Последний октет IP адреса: " last_octet
        if ! [[ "$last_octet" =~ ^[0-9]+$ ]] || ((last_octet > 255)); then
            log_warning "Неверный октет IP адреса"
            continue
        fi
        
        hostname=$(safe_read "Полное имя хоста (FQDN)" validate_domain)
        echo "$last_octet      IN  PTR     $hostname." >> "$zone_file"
        
        if ! yes_no_prompt "Добавить еще одну PTR запись?"; then
            break
        fi
    done
}

# =============================================================================
# Функции валидации для DNS
# =============================================================================

validate_hostname() {
    local hostname=$1
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    fi
    return 1
}

validate_network_prefix() {
    local network=$1
    if [[ $network =~ ^[0-9]{1,3}(\.[0-9]{1,3}){0,2}$ ]]; then
        return 0
    fi
    return 1
}

# =============================================================================
# Главная функция настройки DNS
# =============================================================================

main_dns_config() {
    log_info "=== НАСТРОЙКА DNS СЕРВЕРА (BIND9) ==="
    
    if ! yes_no_prompt "Запустить настройку DNS сервера?"; then
        return 0
    fi
    
    # Проверка установки BIND9
    if ! command -v named &> /dev/null; then
        log_error "BIND9 не установлен. Установите его сначала."
        return 1
    fi
    
    # Создание резервных копий
    backup_file "$DNS_CONFIG_DIR/named.conf.options"
    backup_file "$DNS_CONFIG_DIR/named.conf.local"
    
    # Очистка конфигурации
    echo "// Local zones configuration" > "$DNS_CONFIG_DIR/named.conf.local"
    
    # Основная настройка
    configure_dns_main_options
    
    # Создание зон
    while true; do
        echo
        log_info "Создание DNS зон:"
        echo "1) Создать прямую зону"
        echo "2) Создать обратную зону"
        echo "3) Завершить настройку"
        
        local choice
        read -p "Ваш выбор [1-3]: " choice
        
        case "$choice" in
            1) create_forward_zone ;;
            2) create_reverse_zone ;;
            3) break ;;
            *) log_warning "Неверный выбор" ;;
        esac
    done
    
    # Проверка конфигурации
    log_info "Проверка конфигурации BIND9..."
    if named-checkconf; then
        log_success "Конфигурация корректна"
    else
        log_error "Ошибка в конфигурации"
        return 1
    fi
    
    # Перезапуск сервиса
    systemctl restart bind9
    systemctl enable bind9
    
    if systemctl is-active --quiet bind9; then
        log_success "DNS сервер успешно запущен"
    else
        log_error "Не удалось запустить DNS сервер"
        return 1
    fi
    
    # Тестирование
    test_dns_configuration
}

test_dns_configuration() {
    log_info "Тестирование DNS конфигурации..."
    
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    
    # Тест локального разрешения
    if nslookup localhost "$local_ip" &> /dev/null; then
        log_success "Локальное разрешение работает"
    else
        log_warning "Проблемы с локальным разрешением"
    fi
    
    # Тест внешнего разрешения
    if nslookup google.com "$local_ip" &> /dev/null; then
        log_success "Внешнее разрешение работает"
    else
        log_warning "Проблемы с внешним разрешением"
    fi
    
    log_info "Тестирование завершено"
}

# Запуск, если скрипт вызывается напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_dns_config "$@"
fi