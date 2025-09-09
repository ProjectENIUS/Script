#!/bin/bash

# Быстрое исправление политики паролей
# Quick Password Policy Fix

# Установка пакетов
apt-get update -qq
apt-get install -y libpam-pwquality libpam-cracklib

# Простая и надежная конфигурация
cat > /etc/pam.d/common-password << 'EOF'
password	requisite	pam_cracklib.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1
password	[success=1 default=ignore]	pam_unix.so obscure use_authtok try_first_pass sha512
password	requisite	pam_deny.so
password	required	pam_permit.so
EOF

echo "Политика паролей настроена. Тестирование:"
echo "sudo passwd testuser"