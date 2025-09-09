#!/bin/bash

# Скрипт проверки текущей политики паролей
# Password Policy Check Script

echo "=== ПРОВЕРКА ТЕКУЩЕЙ ПОЛИТИКИ ПАРОЛЕЙ ==="

echo -e "\n1. Настройки в /etc/login.defs:"
grep -E "PASS_(MAX|MIN)_" /etc/login.defs

echo -e "\n2. Настройки PAM в /etc/pam.d/common-password:"
grep -E "pam_(pwquality|unix)" /etc/pam.d/common-password

echo -e "\n3. Проверка установленных пакетов:"
dpkg -l | grep -E "(libpam-pwquality|john)"

echo -e "\n4. Тестирование создания пользователя с простым паролем:"
echo "Попробуйте: sudo useradd testpass && echo 'testpass:123' | sudo chpasswd"

echo -e "\n=== РЕКОМЕНДАЦИИ ==="
echo "- Используйте пароли длиной не менее 12 символов"
echo "- Включайте цифры, заглавные, строчные буквы и спецсимволы"
echo "- Регулярно меняйте пароли"
echo "- Не используйте словарные слова или личную информацию"