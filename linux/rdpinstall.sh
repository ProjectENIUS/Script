#!/bin/bash

#########################################################################
# Название: Скрипт настройки брандмауэра Ubuntu Server
# Описание: Комплексная настройка iptables с использованием ipset
# Автор: [Ваше имя]
# Дата: 2025
# Версия: 1.0
#########################################################################

# ВНИМАНИЕ: Запускать только с правами root!
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root" 
   exit 1
fi

set -e  # Остановка при ошибке

#########################################################################
# КОНФИГУРАЦИОННЫЕ ПАРАМЕТРЫ
#########################################################################

# Замените X на последние 2 цифры вашего номера компьютера (например, 99)
COMPUTER_NUM="206"  # ИЗМЕНИТЕ ЭТО!

# Сетевые параметры
INTERNAL_NET="192.168.${COMPUTER_NUM}.0/24"
INTERNAL_IP="192.168.${COMPUTER_NUM}.1"
EXTERNAL_IF="enp0s8"  # Внешний интерфейс - измените при необходимости
INTERNAL_IF="enp0s3"  # Внутренний интерфейс - измените при необходимости

# SSH параметры
SSH_PORT="22"
SSH_FAIL_ATTEMPTS=5
SSH_BAN_TIME=3600  # 1 час в секундах

# Port knocking параметры (размеры ICMP пакетов)
KNOCK_SIZE_1=92
KNOCK_SIZE_2=42
KNOCK_SIZE_3=107
KNOCK_TIMEOUT=60  # 1 минута

# RDP перенаправление
RDP_EXTERNAL_PORT=55123
RDP_INTERNAL_IP="192.168.${COMPUTER_NUM}.5"  # IP Windows Server в локальной сети
RDP_INTERNAL_PORT=3389

# ICMP flood защита
ICMP_FLOOD_LIMIT=20  # пакетов в минуту
ICMP_FLOOD_BAN_TIME=3600  # 1 час

#########################################################################
# ФУНКЦИИ
#########################################################################

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

#########################################################################
# 1. УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ
#########################################################################

log_action "Установка необходимых пакетов..."
apt-get update
apt-get install -y iptables iptables-persistent ipset

#########################################################################
# 2. ОЧИСТКА СУЩЕСТВУЮЩИХ ПРАВИЛ
#########################################################################

log_action "Очистка существующих правил..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Удаление существующих ipset
ipset destroy 2>/dev/null || true

#########################################################################
# 3. СОЗДАНИЕ IPSET НАБОРОВ
#########################################################################

log_action "Создание ipset наборов..."

# Набор для SSH брутфорс атак (бан на 1 час)
ipset create ssh_bruteforce hash:ip timeout $SSH_BAN_TIME

# Набор для ICMP flood атак (бан на 1 час)
ipset create icmp_flood hash:ip timeout $ICMP_FLOOD_BAN_TIME

# Наборы для port knocking через ICMP
ipset create knock_stage1 hash:ip timeout $KNOCK_TIMEOUT
ipset create knock_stage2 hash:ip timeout $KNOCK_TIMEOUT
ipset create knock_stage3 hash:ip timeout $KNOCK_TIMEOUT
ipset create ssh_allowed hash:ip timeout $KNOCK_TIMEOUT

#########################################################################
# 4. БАЗОВЫЕ ПОЛИТИКИ (ЗАПРЕТ ВСЕГО)
#########################################################################

log_action "Установка базовых политик (запрет всего)..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#########################################################################
# 5. РАЗРЕШЕНИЕ ESTABLISHED И RELATED СОЕДИНЕНИЙ
#########################################################################

log_action "Разрешение ESTABLISHED и RELATED соединений..."
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#########################################################################
# 6. РАЗРЕШЕНИЕ LOOPBACK
#########################################################################

log_action "Разрешение loopback интерфейса..."
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#########################################################################
# 7. ЗАЩИТА ОТ ЗАБЛОКИРОВАННЫХ IP (ipset)
#########################################################################

log_action "Настройка защиты от заблокированных IP..."

# Блокировка SSH брутфорсеров
iptables -A INPUT -p tcp --dport $SSH_PORT -m set --match-set ssh_bruteforce src -j DROP

# Блокировка ICMP флудеров
iptables -A INPUT -p icmp -m set --match-set icmp_flood src -j DROP

#########################################################################
# 8. PORT KNOCKING ДЛЯ SSH (ICMP пакеты специфических размеров)
#########################################################################

log_action "Настройка Port Knocking для SSH..."

# Стадия 1: ICMP пакет размером 92 байта
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m length --length $KNOCK_SIZE_1 \
    -m recent --name KNOCK1 --set \
    -j ACCEPT

# Стадия 2: ICMP пакет размером 42 байта (после стадии 1)
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m length --length $KNOCK_SIZE_2 \
    -m recent --name KNOCK1 --rcheck --seconds $KNOCK_TIMEOUT \
    -m recent --name KNOCK2 --set \
    -j ACCEPT

# Стадия 3: ICMP пакет размером 107 байт (после стадии 2)
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m length --length $KNOCK_SIZE_3 \
    -m recent --name KNOCK2 --rcheck --seconds $KNOCK_TIMEOUT \
    -m recent --name KNOCK3 --set \
    -j ACCEPT

# Открытие SSH на 1 минуту после успешного knocking
iptables -A INPUT -p tcp --dport $SSH_PORT \
    -m recent --name KNOCK3 --rcheck --seconds $KNOCK_TIMEOUT \
    -j ACCEPT

#########################################################################
# 9. SSH ДОСТУП С ЗАЩИТОЙ ОТ БРУТФОРСА
#########################################################################

log_action "Настройка SSH с защитой от брутфорса..."

# Разрешение SSH из локальной сети без ограничений
iptables -A INPUT -p tcp -s $INTERNAL_NET --dport $SSH_PORT -j ACCEPT

# Защита от SSH брутфорса для внешних подключений
# Ограничение новых подключений: максимум 3 попытки за 60 секунд
iptables -A INPUT -p tcp --dport $SSH_PORT \
    -m conntrack --ctstate NEW \
    -m recent --name ssh_attempts --update --seconds 60 --hitcount $SSH_FAIL_ATTEMPTS \
    -j SET --add-set ssh_bruteforce src --exist

iptables -A INPUT -p tcp --dport $SSH_PORT \
    -m conntrack --ctstate NEW \
    -m recent --name ssh_attempts --set \
    -j ACCEPT

#########################################################################
# 10. ICMP (PING) С ЗАЩИТОЙ ОТ FLOOD
#########################################################################

log_action "Настройка ICMP с защитой от flood..."

# Разрешение ping из локальной сети
iptables -A INPUT -p icmp --icmp-type echo-request -s $INTERNAL_NET -j ACCEPT

# Защита от ICMP flood: >20 пакетов в минуту = бан на 1 час
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m recent --name icmp_check --update --seconds 60 --hitcount $ICMP_FLOOD_LIMIT \
    -j SET --add-set icmp_flood src --exist

iptables -A INPUT -p icmp --icmp-type echo-request \
    -m recent --name icmp_check --set \
    -j ACCEPT

# Разрешение исходящих ICMP
iptables -A OUTPUT -p icmp -j ACCEPT

#########################################################################
# 11. NAT ДЛЯ ЛОКАЛЬНОЙ СЕТИ (ДОСТУП В ИНТЕРНЕТ)
#########################################################################

log_action "Настройка NAT для локальной сети..."

# Включение IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# NAT для внутренней сети
iptables -t nat -A POSTROUTING -s $INTERNAL_NET -o $EXTERNAL_IF -j MASQUERADE

# Разрешение forwarding из локальной сети
iptables -A FORWARD -i $INTERNAL_IF -o $EXTERNAL_IF -s $INTERNAL_NET -j ACCEPT

# Разрешение исходящего трафика для локальной сети
iptables -A OUTPUT -o $EXTERNAL_IF -j ACCEPT
iptables -A OUTPUT -o $INTERNAL_IF -j ACCEPT

#########################################################################
# 12. ПЕРЕНАПРАВЛЕНИЕ RDP ПОРТА
#########################################################################

log_action "Настройка перенаправления RDP порта..."

# DNAT: внешний порт 55123 -> внутренний 3389
iptables -t nat -A PREROUTING -i $EXTERNAL_IF -p tcp --dport $RDP_EXTERNAL_PORT \
    -j DNAT --to-destination ${RDP_INTERNAL_IP}:${RDP_INTERNAL_PORT}

# Разрешение forwarding для RDP
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -p tcp \
    -d $RDP_INTERNAL_IP --dport $RDP_INTERNAL_PORT \
    -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

#########################################################################
# 13. ДОПОЛНИТЕЛЬНАЯ ЗАЩИТА
#########################################################################

log_action "Настройка дополнительной защиты..."

# Защита от SYN flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Блокировка недопустимых пакетов
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Защита от сканирования портов
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

#########################################################################
# 14. ЛОГИРОВАНИЕ
#########################################################################

log_action "Настройка логирования..."

# Логирование заблокированных пакетов (последнее правило)
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPT-INPUT-DROP: " --log-level 7
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "IPT-FORWARD-DROP: " --log-level 7

#########################################################################
# 15. СОХРАНЕНИЕ ПРАВИЛ
#########################################################################

log_action "Сохранение правил iptables и ipset..."

# Сохранение правил iptables
iptables-save > /etc/iptables/rules.v4

# Сохранение ipset наборов
ipset save > /etc/ipset.conf

# Создание systemd сервиса для автозагрузки ipset
cat > /etc/systemd/system/ipset-restore.service << 'EOF'
[Unit]
Description=Restore ipset rules
Before=netfilter-persistent.service

[Service]
Type=oneshot
ExecStart=/sbin/ipset restore -f /etc/ipset.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ipset-restore.service

# Обеспечение автозагрузки iptables
systemctl enable netfilter-persistent

log_action "Настройка завершена успешно!"

#########################################################################
# 16. ВЫВОД ИТОГОВОЙ ИНФОРМАЦИИ
#########################################################################

echo ""
echo "=========================================="
echo "КОНФИГУРАЦИЯ ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "Параметры сети:"
echo "  - Внутренняя сеть: $INTERNAL_NET"
echo "  - IP сервера: $INTERNAL_IP"
echo ""
echo "Port Knocking (ICMP):"
echo "  - Размеры пакетов: $KNOCK_SIZE_1, $KNOCK_SIZE_2, $KNOCK_SIZE_3 байт"
echo "  - Время доступа: $KNOCK_TIMEOUT секунд"
echo ""
echo "Команды для открытия SSH (Linux/Mac):"
echo "  ping -c 1 -s $((KNOCK_SIZE_1-28)) $INTERNAL_IP"
echo "  ping -c 1 -s $((KNOCK_SIZE_2-28)) $INTERNAL_IP"
echo "  ping -c 1 -s $((KNOCK_SIZE_3-28)) $INTERNAL_IP"
echo "  ssh user@$INTERNAL_IP"
echo ""
echo "Команды для открытия SSH (Windows):"
echo "  ping -n 1 -l $((KNOCK_SIZE_1-28)) $INTERNAL_IP"
echo "  ping -n 1 -l $((KNOCK_SIZE_2-28)) $INTERNAL_IP"
echo "  ping -n 1 -l $((KNOCK_SIZE_3-28)) $INTERNAL_IP"
echo "  ssh user@$INTERNAL_IP"
echo ""
echo "RDP перенаправление:"
echo "  - Внешний порт: $RDP_EXTERNAL_PORT"
echo "  - Внутренний: ${RDP_INTERNAL_IP}:${RDP_INTERNAL_PORT}"
echo ""
echo "Защита:"
echo "  - SSH брутфорс: бан на $((SSH_BAN_TIME/3600)) час(а)"
echo "  - ICMP flood: бан на $((ICMP_FLOOD_BAN_TIME/3600)) час(а)"
echo ""
echo "Для проверки правил:"
echo "  iptables -L -v -n"
echo "  ipset list"
echo ""
