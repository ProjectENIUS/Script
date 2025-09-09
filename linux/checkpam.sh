#!/bin/bash

# Диагностика PAM конфигурации
# PAM Configuration Diagnostic Script

echo "=== ДИАГНОСТИКА PAM КОНФИГУРАЦИИ ==="

echo -e "\n1. Версия системы:"
cat /etc/os-release | grep -E "(NAME|VERSION)"

echo -e "\n2. Установленные PAM пакеты:"
dpkg -l | grep -E "pam.*password|pwquality|cracklib"

echo -e "\n3. Расположение PAM модулей:"
find /lib -name "*pam_pwquality*" 2>/dev/null
find /lib -name "*pam_cracklib*" 2>/dev/null
find /lib -name "*pam_unix*" 2>/dev/null

echo -e "\n4. Содержимое /etc/pam.d/common-password:"
cat -n /etc/pam.d/common-password

echo -e "\n5. Проверка настроек pwquality:"
if [ -f /etc/security/pwquality.conf ]; then
    echo "Файл /etc/security/pwquality.conf найден:"
    grep -v "^#" /etc/security/pwquality.conf | grep -v "^$"
else
    echo "Файл /etc/security/pwquality.conf НЕ найден"
fi

echo -e "\n6. Тест команды pwquality-check:"
if command -v pwquality-check >/dev/null; then
    echo "pwquality-check доступен"
    echo "Тестирование простого пароля:"
    echo "123" | pwquality-check 2>&1 || echo "Простой пароль отклонен (это хорошо)"
else
    echo "pwquality-check НЕ доступен"
fi

echo -e "\n7. Проверка процесса аутентификации:"
echo "Для проверки запустите: sudo passwd [username]"
echo "И попробуйте ввести простой пароль"