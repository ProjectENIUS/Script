#!/bin/bash

# Password Policy and Security Testing Script for Ubuntu Server
# Скрипт для тестирования парольной политики и безопасности на Ubuntu Server
# ВНИМАНИЕ: Используйте только в учебных целях и контролируемой среде!

echo "=== Ubuntu Server Password Policy and Security Testing ==="
echo "ВНИМАНИЕ: Этот скрипт предназначен только для обучения!"
echo "Убедитесь, что вы работаете в изолированной тестовой среде."
echo ""

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен запускаться с правами root (sudo)"
   exit 1
fi

# Создание резервных копий конфигурационных файлов
echo "1. Создание резервных копий конфигурационных файлов..."
cp /etc/login.defs /etc/login.defs.backup.$(date +%Y%m%d_%H%M%S)
cp /etc/pam.d/common-password /etc/pam.d/common-password.backup.$(date +%Y%m%d_%H%M%S)
echo "Резервные копии созданы"

# Настройка парольной политики в /etc/login.defs
echo ""
echo "2. Настройка парольной политики в /etc/login.defs..."
sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS\t7/' /etc/login.defs
sed -i 's/PASS_MIN_LEN.*/PASS_MIN_LEN\t12/' /etc/login.defs

# Проверяем, что изменения применились
echo "Проверка настроек в /etc/login.defs:"
grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN" /etc/login.defs

# Установка libpam-pwquality если не установлен
echo ""
echo "3. Установка libpam-pwquality..."
apt-get update -qq
apt-get install -y libpam-pwquality

# Настройка сложности паролей в PAM
echo ""
echo "4. Настройка сложности паролей в /etc/pam.d/common-password..."
# Резервная копия и изменение файла
if grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
    sed -i 's/password.*requisite.*pam_pwquality.so.*/password requisite pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1/' /etc/pam.d/common-password
else
    sed -i '/password.*requisite.*pam_unix.so/i password requisite pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1' /etc/pam.d/common-password
fi

echo "Настройки PAM обновлены"

# Создание тестового пользователя со слабым паролем
echo ""
echo "5. Создание тестового пользователя..."
read -p "Введите имя для тестового пользователя (например, testuser): " testuser
if [[ -z "$testuser" ]]; then
    testuser="testuser"
fi

# Попытка создать пользователя со слабым паролем
echo "Попытка создания пользователя со слабым паролем '1234':"
echo -e "1234\n1234" | passwd $testuser 2>/dev/null || {
    echo "Слабый пароль отклонен (это хорошо!)"
    echo "Создаем пользователя с временным паролем..."
    useradd -m $testuser
    echo -e "TempPass123!\nTempPass123!" | passwd $testuser
}

# Создание пользователя с сильным паролем
echo ""
echo "6. Создание пользователя с сильным паролем..."
secuser="secuser"
useradd -m $secuser
echo -e "Xr!92_aL#5nM\nXr!92_aL#5nM" | passwd $secuser
echo "Пользователь $secuser создан с сильным паролем"

# Экспорт хешей паролей
echo ""
echo "7. Экспорт хешей паролей..."
echo "Хеш пароля для $testuser:"
grep "^$testuser:" /etc/shadow
echo ""
echo "Хеш пароля для $secuser:"
grep "^$secuser:" /etc/shadow

# Создание файла с хешами для John the Ripper
grep -E "^($testuser|$secuser):" /etc/shadow > /tmp/hashes.txt
echo "Хеши сохранены в /tmp/hashes.txt"

# Установка John the Ripper
echo ""
echo "8. Установка John the Ripper..."
apt-get install -y john

# Тестирование взлома паролей
echo ""
echo "9. Тестирование взлома паролей с помощью John the Ripper..."
echo "Запуск John the Ripper против слабых паролей..."
timeout 60 john /tmp/hashes.txt --wordlist=/usr/share/john/password.lst

echo ""
echo "Показ результатов взлома:"
john --show /tmp/hashes.txt

echo ""
echo "=== РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
echo ""
echo "ОТВЕТЫ НА ВОПРОСЫ:"
echo ""
echo "a. Почему важна парольная политика?"
echo "   - PASS_MIN_LEN обеспечивает минимальную длину пароля"
echo "   - PASS_MAX_DAYS заставляет регулярно менять пароли"
echo "   - PASS_MIN_DAYS предотвращает слишком частую смену паролей"
echo "   - Сложность пароля защищает от атак по словарю"
echo ""
echo "b. Если John быстро взломал пароль:"
echo "   - Это показывает, что пароль слишком простой"
echo "   - Пароль находится в общих словарях"
echo "   - Необходимо использовать более сложные пароли"
echo ""
echo "c. Сильный пароль должен:"
echo "   - Противостоять атакам по словарю"
echo "   - Требовать значительно больше времени для взлома"
echo "   - Или вообще остаться невзломанным в разумные сроки"
echo ""
echo "ВАЖНО: Удалите тестовых пользователей после завершения тестирования!"
echo "userdel -r $testuser"
echo "userdel -r $secuser"
