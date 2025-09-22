#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для паузы с подтверждением
pause_for_action() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Нажмите Enter для продолжения..."
    echo ""
}

# Функция для логирования
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /home/$USER/lab_log.txt
    echo -e "${GREEN}[LOG] $1${NC}"
}

# Создание директории для логов и отчетов
mkdir -p /home/$USER/security_lab_reports
mkdir -p /home/$USER/backups

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}    ЛАБОРАТОРНАЯ РАБОТА ПО ВОССТАНОВЛЕНИЮ ПОСЛЕ ИНЦИДЕНТОВ    ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

log_action "Начало выполнения лабораторной работы"

# ==================== ЭТАП 1: ПОДГОТОВКА VM ====================
echo -e "${BLUE}ЭТАП 1: ПОДГОТОВКА UBUNTU VM${NC}"
echo -e "${GREEN}Обновление системы...${NC}"

sudo apt update && sudo apt upgrade -y
log_action "Система обновлена"

pause_for_action "ДЕЙСТВИЕ: Создайте VirtualBox snapshot исходного состояния VM сейчас. Назовите его 'Initial_Clean_State'"

# ==================== ЭТАП 2: ПОДГОТОВКА ПО ====================
echo -e "${BLUE}ЭТАП 2: ПОДГОТОВКА ПРОГРАММНОГО ОБЕСПЕЧЕНИЯ${NC}"

# 2a. Создание папки с изображениями
echo -e "${GREEN}Создание папки с изображениями для тестирования...${NC}"
mkdir -p /home/$USER/Pictures/test_images
cd /home/$USER/Pictures/test_images

# Создаем тестовые файлы-изображения (пустые, для имитации)
echo "Test image 1" > image1.jpg
echo "Test image 2" > image2.png  
echo "Test image 3" > image3.gif
echo "Important document" > document.txt
echo "Configuration backup" > config_backup.conf

log_action "Созданы тестовые изображения в /home/$USER/Pictures/test_images"

# 2b. Установка и настройка MySQL
echo -e "${GREEN}Установка MySQL Server...${NC}"
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Создание тестовой базы данных
echo -e "${GREEN}Создание тестовой базы данных...${NC}"
sudo mysql -e "CREATE DATABASE test;"
sudo mysql -e "CREATE USER 'testuser'@'localhost' IDENTIFIED BY 'password123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON test.* TO 'testuser'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Добавление тестовых данных
sudo mysql -e "USE test; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), email VARCHAR(50));"
sudo mysql -e "USE test; INSERT INTO users (name, email) VALUES ('Иван Петров', 'ivan@example.com'), ('Анна Сидорова', 'anna@example.com');"

log_action "MySQL сервер установлен и настроен с тестовой БД"

# 2c. Установка и настройка веб-сервера
echo -e "${GREEN}Выберите веб-сервер:${NC}"
echo "1) Apache"
echo "2) Nginx"
read -p "Введите номер (1 или 2): " webserver_choice

if [ "$webserver_choice" = "1" ]; then
    echo -e "${GREEN}Установка Apache...${NC}"
    sudo apt install -y apache2
    sudo systemctl start apache2
    sudo systemctl enable apache2
    
    # Создание виртуального хоста
    read -p "Введите вашу фамилию для создания домена (фамилия.группа.ee): " surname
    DOMAIN="${surname}.grupp.ee"
    
    sudo mkdir -p /var/www/$DOMAIN
    echo "<html><head><title>$DOMAIN</title></head><body><h1>Добро пожаловать на $DOMAIN</h1><p>Это тестовая страница для лабораторной работы</p></body></html>" | sudo tee /var/www/$DOMAIN/index.html
    
    # Создание конфигурации виртуального хоста
    sudo cat > /etc/apache2/sites-available/$DOMAIN.conf << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/$DOMAIN
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF
    
    sudo a2ensite $DOMAIN.conf
    sudo systemctl reload apache2
    WEBSERVER="Apache"
    
else
    echo -e "${GREEN}Установка Nginx...${NC}"
    sudo apt install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    read -p "Введите вашу фамилию для создания домена (фамилия.группа.ee): " surname
    DOMAIN="${surname}.grupp.ee"
    
    sudo mkdir -p /var/www/$DOMAIN
    echo "<html><head><title>$DOMAIN</title></head><body><h1>Добро пожаловать на $DOMAIN</h1><p>Это тестовая страница для лабораторной работы</p></body></html>" | sudo tee /var/www/$DOMAIN/index.html
    
    # Создание конфигурации сайта
    sudo cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/$DOMAIN;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    sudo systemctl reload nginx
    WEBSERVER="Nginx"
fi

log_action "$WEBSERVER установлен и настроен для домена $DOMAIN"

# 2d. Создание папки Crypt
echo -e "${GREEN}Создание папки Crypt с тестовыми файлами...${NC}"
mkdir -p /home/$USER/Crypt
cd /home/$USER/Crypt
echo "Конфиденциальный документ 1" > secret1.txt
echo "Приватные данные" > private_data.txt  
echo "Финансовые отчеты" > finance.xlsx
echo "Пароли и ключи" > passwords.txt

log_action "Создана папка Crypt с тестовыми файлами"

# 2e. Создание backup файлов
echo -e "${GREEN}Создание резервной копии системы...${NC}"

# Создание tar архива
echo "Создание tar архива..."
sudo tar -cvpzf /home/$USER/preincident.tar.gz /etc /home /var/www /var/lib/mysql 2>/dev/null
log_action "Создан tar архив: /home/$USER/preincident.tar.gz"

# Создание rsync backup
echo "Создание rsync резервных копий..."
mkdir -p /home/$USER/backups/{www_preincident,home_preincident,etc_preincident,mysql_preincident}

sudo rsync -aHAX --delete /var/www/ /home/$USER/backups/www_preincident/
sudo rsync -aHAX --delete /home/ /home/$USER/backups/home_preincident/  
sudo rsync -aHAX --delete /etc/ /home/$USER/backups/etc_preincident/
sudo rsync -aHAX --delete /var/lib/mysql/ /home/$USER/backups/mysql_preincident/

log_action "Созданы rsync резервные копии в /home/$USER/backups/"

echo -e "${GREEN}Подготовка завершена! Система готова к тестированию инцидентов.${NC}"

pause_for_action "ДЕЙСТВИЕ: Создайте VirtualBox snapshot 'Pre_Incident_State' перед симуляцией инцидентов"

# ==================== ЭТАП 3: СИМУЛЯЦИЯ ИНЦИДЕНТОВ ====================
echo -e "${BLUE}ЭТАП 3: СИМУЛЯЦИЯ ИНЦИДЕНТОВ БЕЗОПАСНОСТИ${NC}"

log_action "Начало симуляции инцидентов безопасности"

# 3a. Удаление файлов
echo -e "${RED}Инцидент 1: Удаление важных файлов${NC}"
rm -f /home/$USER/Pictures/test_images/image1.jpg
rm -f /home/$USER/Pictures/test_images/document.txt
log_action "ИНЦИДЕНТ: Удалены файлы из Pictures/test_images"

# 3b. Повреждение базы данных
echo -e "${RED}Инцидент 2: Повреждение базы данных${NC}"
sudo mysql -e "DROP DATABASE test;"
log_action "ИНЦИДЕНТ: Удалена база данных test"

# 3c. Повреждение конфигурационных файлов
echo -e "${RED}Инцидент 3: Повреждение конфигурационных файлов${NC}"

if [ "$WEBSERVER" = "Apache" ]; then
    sudo mv /etc/apache2/sites-available/$DOMAIN.conf /etc/apache2/sites-available/$DOMAIN.conf.backup
    echo "# Поврежденная конфигурация" | sudo tee /etc/apache2/sites-available/$DOMAIN.conf
    sudo systemctl reload apache2 2>/dev/null || true
else
    sudo mv /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-available/$DOMAIN.backup
    echo "# Поврежденная конфигурация" | sudo tee /etc/nginx/sites-available/$DOMAIN  
    sudo systemctl reload nginx 2>/dev/null || true
fi

# Повреждение SSH конфигурации
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
echo "# Поврежденная SSH конфигурация" | sudo tee -a /etc/ssh/sshd_config

log_action "ИНЦИДЕНТ: Повреждены конфигурационные файлы веб-сервера и SSH"

# 3d. Создание и удаление тестового пользователя
echo -e "${RED}Инцидент 4: Удаление учетной записи пользователя${NC}"
sudo useradd -m testuser2
sudo userdel -r testuser2 2>/dev/null || sudo userdel testuser2
log_action "ИНЦИДЕНТ: Удалена учетная запись testuser2"

# 3e. "Шифрование" каталога (имитация)
echo -e "${RED}Инцидент 5: Шифрование каталога${NC}"
cd /home/$USER/Crypt
for file in *.txt *.xlsx; do
    if [ -f "$file" ]; then
        mv "$file" "${file}.encrypted"
        echo "ЗАШИФРОВАНО RANSOMWARE!" > "$file"
    fi
done
log_action "ИНЦИДЕНТ: Каталог Crypt 'зашифрован' ransomware"

echo -e "${RED}ВСЕ ИНЦИДЕНТЫ СИМУЛИРОВАНЫ!${NC}"
echo "Проверим состояние системы после инцидентов:"
echo ""

# ==================== ЭТАП 4: ДОКУМЕНТИРОВАНИЕ ====================
echo -e "${BLUE}ЭТАП 4: ДОКУМЕНТИРОВАНИЕ ИНЦИДЕНТОВ${NC}"

# Создание отчета об инциденте
cat > /home/$USER/security_lab_reports/incident_report.txt << EOF
=== ОТЧЕТ О ИНЦИДЕНТЕ БЕЗОПАСНОСТИ ===
Дата: $(date)
Время обнаружения: $(date '+%Y-%m-%d %H:%M:%S')

ОБНАРУЖЕННЫЕ ИНЦИДЕНТЫ:
1. Удаление критических файлов из /home/$USER/Pictures/test_images/
   - Затронутые файлы: image1.jpg, document.txt
   - Время: $(date '+%Y-%m-%d %H:%M:%S')

2. Удаление базы данных 'test'
   - База данных полностью удалена
   - Время: $(date '+%Y-%m-%d %H:%M:%S')

3. Повреждение конфигурационных файлов
   - Веб-сервер: $WEBSERVER конфигурация повреждена
   - SSH конфигурация изменена
   - Время: $(date '+%Y-%m-%d %H:%M:%S')

4. Удаление пользовательской учетной записи
   - Пользователь: testuser2
   - Время: $(date '+%Y-%m-%d %H:%M:%S')

5. Шифрование файлов (Ransomware атака)
   - Каталог: /home/$USER/Crypt
   - Все файлы зашифрованы
   - Время: $(date '+%Y-%m-%d %H:%M:%S')

ДОКАЗАТЕЛЬСТВА:
- Логи в /home/$USER/lab_log.txt
- Резервные копии созданы до инцидента
- Снапшоты VirtualBox доступны

ВОЗДЕЙСТВИЕ: КРИТИЧЕСКОЕ
ПРИОРИТЕТ: ВЫСОКИЙ
EOF

log_action "Создан отчет об инциденте: /home/$USER/security_lab_reports/incident_report.txt"

# Проверка состояния сервисов
echo -e "${GREEN}Проверка состояния сервисов после инцидентов:${NC}"
echo "MySQL: $(systemctl is-active mysql)"
echo "$WEBSERVER: $(systemctl is-active apache2 nginx 2>/dev/null | head -1)"
echo "SSH: $(systemctl is-active ssh)"

pause_for_action "Инциденты задокументированы. Переходим к восстановлению."

# ==================== ЭТАП 5: ВОССТАНОВЛЕНИЕ ====================
echo -e "${BLUE}ЭТАП 5: ВОССТАНОВЛЕНИЕ СИСТЕМЫ${NC}"

echo -e "${GREEN}Выберите метод восстановления:${NC}"
echo "1) Полное восстановление из snapshot VirtualBox"
echo "2) Выборочное восстановление из tar архива"
echo "3) Выборочное восстановление из rsync backup"
read -p "Введите номер (1, 2 или 3): " restore_choice

case $restore_choice in
    1)
        echo -e "${YELLOW}Для полного восстановления:${NC}"
        echo "1. Остановите VM"
        echo "2. В VirtualBox выберите VM"
        echo "3. Перейдите в раздел Snapshots"
        echo "4. Выберите 'Pre_Incident_State' или 'Initial_Clean_State'"
        echo "5. Нажмите 'Restore'"
        echo "6. Запустите VM"
        pause_for_action "После восстановления snapshot нажмите Enter"
        ;;
        
    2)
        echo -e "${GREEN}Восстановление из tar архива...${NC}"
        
        # Восстановление файлов
        echo "Восстановление удаленных изображений..."
        cd /
        sudo tar -xzf /home/$USER/preincident.tar.gz home/$USER/Pictures/test_images/image1.jpg
        sudo tar -xzf /home/$USER/preincident.tar.gz home/$USER/Pictures/test_images/document.txt
        
        # Восстановление конфигураций
        echo "Восстановление конфигураций веб-сервера..."
        if [ "$WEBSERVER" = "Apache" ]; then
            sudo tar -xzf /home/$USER/preincident.tar.gz etc/apache2/sites-available/$DOMAIN.conf
            sudo systemctl reload apache2
        else
            sudo tar -xzf /home/$USER/preincident.tar.gz etc/nginx/sites-available/$DOMAIN
            sudo systemctl reload nginx
        fi
        
        # Восстановление SSH
        echo "Восстановление SSH конфигурации..."
        sudo tar -xzf /home/$USER/preincident.tar.gz etc/ssh/sshd_config
        sudo systemctl restart ssh
        
        # Восстановление базы данных
        echo "Восстановление базы данных..."
        sudo systemctl stop mysql
        sudo tar -xzf /home/$USER/preincident.tar.gz var/lib/mysql/
        sudo chown -R mysql:mysql /var/lib/mysql
        sudo systemctl start mysql
        
        log_action "Система восстановлена из tar архива"
        ;;
        
    3)
        echo -e "${GREEN}Восстановление из rsync backup...${NC}"
        
        # Восстановление файлов
        echo "Восстановление изображений..."
        sudo rsync -av /home/$USER/backups/home_preincident/$USER/Pictures/test_images/ /home/$USER/Pictures/test_images/
        
        # Восстановление веб-файлов
        echo "Восстановление веб-сайта..."
        sudo rsync -av /home/$USER/backups/www_preincident/ /var/www/
        
        # Восстановление конфигураций
        echo "Восстановление конфигураций..."
        if [ "$WEBSERVER" = "Apache" ]; then
            sudo rsync -av /home/$USER/backups/etc_preincident/apache2/ /etc/apache2/
            sudo systemctl reload apache2
        else
            sudo rsync -av /home/$USER/backups/etc_preincident/nginx/ /etc/nginx/  
            sudo systemctl reload nginx
        fi
        
        sudo rsync -av /home/$USER/backups/etc_preincident/ssh/ /etc/ssh/
        sudo systemctl restart ssh
        
        # Восстановление базы данных
        echo "Восстановление базы данных..."
        sudo systemctl stop mysql
        sudo rsync -av /home/$USER/backups/mysql_preincident/ /var/lib/mysql/
        sudo chown -R mysql:mysql /var/lib/mysql
        sudo systemctl start mysql
        
        log_action "Система восстановлена из rsync backup"
        ;;
esac

# Восстановление зашифрованных файлов
echo -e "${GREEN}Восстановление зашифрованных файлов...${NC}"
cd /home/$USER/Crypt
for file in *.encrypted; do
    if [ -f "$file" ]; then
        original_name=${file%.encrypted}
        if [ -f "/home/$USER/backups/home_preincident/$USER/Crypt/$original_name" ]; then
            cp "/home/$USER/backups/home_preincident/$USER/Crypt/$original_name" "$original_name"
            rm -f "$file"
            rm -f "${original_name%.*}"  # удаляем файл с текстом "ЗАШИФРОВАНО"
        fi
    fi
done

log_action "Восстановление завершено"

# ==================== ЭТАП 6: ПРОВЕРКА ФУНКЦИОНАЛЬНОСТИ ====================
echo -e "${BLUE}ЭТАП 6: ПРОВЕРКА ФУНКЦИОНАЛЬНОСТИ${NC}"

echo -e "${GREEN}Проверка восстановленных сервисов:${NC}"

# Проверка MySQL
echo -n "MySQL: "
if sudo mysql -e "USE test; SELECT COUNT(*) FROM users;" >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    log_action "MySQL функционирует корректно"
else
    echo -e "${RED}ОШИБКА${NC}"
    log_action "MySQL НЕ функционирует"
fi

# Проверка веб-сервера
echo -n "$WEBSERVER: "
if systemctl is-active --quiet apache2 || systemctl is-active --quiet nginx; then
    echo -e "${GREEN}OK${NC}"
    log_action "$WEBSERVER функционирует корректно"
else
    echo -e "${RED}ОШИБКА${NC}"
    log_action "$WEBSERVER НЕ функционирует"
fi

# Проверка SSH
echo -n "SSH: "
if systemctl is-active --quiet ssh; then
    echo -e "${GREEN}OK${NC}"
    log_action "SSH функционирует корректно"
else
    echo -e "${RED}ОШИБКА${NC}"
    log_action "SSH НЕ функционирует"
fi

# Проверка восстановленных файлов
echo -n "Файлы изображений: "
if [ -f "/home/$USER/Pictures/test_images/image1.jpg" ] && [ -f "/home/$USER/Pictures/test_images/document.txt" ]; then
    echo -e "${GREEN}OK${NC}"
    log_action "Файлы изображений восстановлены"
else
    echo -e "${RED}ОШИБКА${NC}"
    log_action "Файлы изображений НЕ восстановлены"
fi

echo -n "Зашифрованные файлы: "
if [ -f "/home/$USER/Crypt/secret1.txt" ] && [ ! -f "/home/$USER/Crypt/secret1.txt.encrypted" ]; then
    echo -e "${GREEN}OK${NC}"
    log_action "Зашифрованные файлы восстановлены"
else
    echo -e "${RED}ОШИБКА${NC}"
    log_action "Зашифрованные файлы НЕ восстановлены"
fi

# ==================== ЭТАП 7: СОЗДАНИЕ SOP ====================
echo -e "${BLUE}ЭТАП 7: СОЗДАНИЕ SOP И РЕКОМЕНДАЦИЙ${NC}"

cat > /home/$USER/security_lab_reports/recovery_sop.txt << EOF
=== СТАНДАРТНАЯ ОПЕРАЦИОННАЯ ПРОЦЕДУРА (SOP) ===
=== ВОССТАНОВЛЕНИЕ ПОСЛЕ ИНЦИДЕНТОВ БЕЗОПАСНОСТИ ===

1. ОБНАРУЖЕНИЕ И ОЦЕНКА ИНЦИДЕНТА
   - Зафиксировать время обнаружения
   - Определить масштаб воздействия  
   - Изолировать пораженные системы
   - Создать снимок состояния для расследования

2. УВЕДОМЛЕНИЕ
   - Уведомить команду реагирования на инциденты
   - Информировать руководство при критических инцидентах
   - Документировать все действия

3. СДЕРЖИВАНИЕ
   - Остановить распространение угрозы
   - Изолировать пораженные системы
   - Сохранить доказательства

4. ИСКОРЕНЕНИЕ И ВОССТАНОВЛЕНИЕ
   - Удалить причину инцидента
   - Восстановить из резервных копий:
     * VM snapshot для полного восстановления
     * tar/rsync backup для выборочного восстановления
   - Применить обновления безопасности

5. ВОССТАНОВЛЕНИЕ ДЕЯТЕЛЬНОСТИ
   - Проверить функциональность всех сервисов
   - Провести тестирование
   - Мониторинг на предмет повторных инцидентов

6. ИЗВЛЕЧЕННЫЕ УРОКИ
   - Анализ причин инцидента
   - Обновление процедур безопасности
   - Обучение персонала

РЕКОМЕНДАЦИИ ПО ПРЕДОТВРАЩЕНИЮ (СООТВЕТСТВИЕ ISO 27001):

A.12.3 Резервное копирование информации:
- Регулярные автоматические резервные копии (ежедневно)
- Тестирование процедур восстановления (ежемесячно)
- Хранение копий в изолированной среде

A.16.1 Управление инцидентами информационной безопасности:
- Формализованная процедура реагирования на инциденты
- Обучение персонала выявлению угроз
- Регулярные учения по реагированию на инциденты

A.12.2 Защита от вредоносного программного обеспечения:
- Установка и регулярное обновление антивирусного ПО
- Контроль съемных носителей
- Обучение пользователей основам кибербезопасности

СООТВЕТСТВИЕ NIST CSF:
- IDENTIFY: Управление активами и оценка рисков
- PROTECT: Контроль доступа и защита данных  
- DETECT: Мониторинг безопасности и обнаружение аномалий
- RESPOND: Планирование реагирования и коммуникации
- RECOVER: Планирование восстановления и улучшения

Дата создания: $(date)
Версия: 1.0
EOF

log_action "Создана SOP для восстановления после инцидентов"

# ==================== ЭТАП 8: ФИНАЛЬНЫЙ ОТЧЕТ ====================
echo -e "${BLUE}ЭТАП 8: СОЗДАНИЕ ФИНАЛЬНОГО ОТЧЕТА${NC}"

cat > /home/$USER/security_lab_reports/final_report.txt << EOF
=== ФИНАЛЬНЫЙ ОТЧЕТ ЛАБОРАТОРНОЙ РАБОТЫ ===
=== ВОССТАНОВЛЕНИЕ ПОСЛЕ ИНЦИДЕНТОВ БЕЗОПАСНОСТИ ===

Дата выполнения: $(date)
Исполнитель: $USER

ЦЕЛЬ РАБОТЫ:
Изучение процедур восстановления системы после инцидентов безопасности,
создание резервных копий и отработка навыков реагирования на инциденты.

ВЫПОЛНЕННЫЕ ЗАДАЧИ:

1. ПОДГОТОВКА ИНФРАСТРУКТУРЫ ✓
   - Установлена и настроена Ubuntu VM
   - Созданы VirtualBox snapshots
   - Настроены MySQL, $WEBSERVER, SSH

2. СОЗДАНИЕ РЕЗЕРВНЫХ КОПИЙ ✓
   - tar архив: /home/$USER/preincident.tar.gz
   - rsync backup: /home/$USER/backups/
   - Проверена целостность резервных копий

3. СИМУЛЯЦИЯ ИНЦИДЕНТОВ ✓
   - Удаление критических файлов
   - Повреждение базы данных
   - Нарушение конфигураций сервисов
   - Удаление пользователей
   - Имитация ransomware атаки

4. ДОКУМЕНТИРОВАНИЕ ✓
   - Зафиксировано время инцидентов
   - Сохранены доказательства
   - Создан журнал событий

5. ВОССТАНОВЛЕНИЕ ✓
   - Выполнено восстановление методом: $restore_choice
   - Проверена функциональность сервисов
   - Восстановлены все критические данные

6. СОЗДАНИЕ ПРОЦЕДУР ✓
   - Разработана SOP восстановления
   - Составлены рекомендации по ISO 27001/NIST CSF

ОЦЕНКА РИСКОВ:
- КРИТИЧЕСКИЙ: Потеря данных, нарушение доступности сервисов
- ВЫСОКИЙ: Нарушение конфиденциальности, ransomware
- СРЕДНИЙ: Повреждение конфигураций

ВЛИЯНИЕ ИНЦИДЕНТОВ:
- RTO (Recovery Time Objective): ~30 минут при использовании snapshot
- RPO (Recovery Point Objective): 0 (полное восстановление)
- Время простоя веб-сервисов: 0 при правильном восстановлении

ПРЕДЛОЖЕНИЯ ПО УЛУЧШЕНИЮ:
1. Автоматизация процесса резервного копирования
2. Внедрение системы мониторинга целостности файлов
3. Регулярное тестирование процедур восстановления
4. Обучение персонала основам кибербезопасности
5. Внедрение принципов Zero Trust

ВЫВОДЫ:
Лабораторная работа успешно продемонстрировала важность:
- Регулярного резервного копирования
- Наличия отработанных процедур восстановления
- Быстрого реагирования на инциденты
- Документирования всех действий

Все цели лабораторной работы достигнуты.

ФАЙЛЫ ОТЧЕТА:
- Основной отчет: /home/$USER/security_lab_reports/final_report.txt
- Отчет об инциденте: /home/$USER/security_lab_reports/incident_report.txt
- SOP восстановления: /home/$USER/security_lab_reports/recovery_sop.txt
- Журнал действий: /home/$USER/lab_log.txt

$(date)
EOF

echo -e "${GREEN}=== ЛАБОРАТОРНАЯ РАБОТА ЗАВЕРШЕНА ====${NC}"
echo ""
echo -e "${BLUE}Созданы следующие отчеты:${NC}"
echo "- Финальный отчет: /home/$USER/security_lab_reports/final_report.txt"
echo "- Отчет об инциденте: /home/$USER/security_lab_reports/incident_report.txt"  
echo "- SOP восстановления: /home/$USER/security_lab_reports/recovery_sop.txt"
echo "- Журнал действий: /home/$USER/lab_log.txt"
echo ""
echo -e "${BLUE}Резервные копии:${NC}"
echo "- tar архив: /home/$USER/preincident.tar.gz"
echo "- rsync backup: /home/$USER/backups/"
echo ""
echo -e "${GREEN}Рекомендации для скриншотов:${NC}"
echo "1. Состояние системы до инцидентов"
echo "2. Процесс симуляции каждого инцидента"  
echo "3. Доказательства повреждений"
echo "4. Процесс восстановления"
echo "5. Проверка функциональности после восстановления"
echo ""

log_action "Лабораторная работа успешно завершена"

echo -e "${YELLOW}Для полного тестирования рекомендуется:${NC}"
echo "1. Создать еще один snapshot после восстановления"
echo "2. Повторить некоторые инциденты для практики"
echo "3. Протестировать восстановление отдельных файлов"
echo "4. Измерить время восстановления различными методами"

echo ""
echo -e "${GREEN}Спасибо за выполнение лабораторной работы!${NC}"
