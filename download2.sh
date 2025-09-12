#!/bin/bash
# Исправленный скрипт загрузки файлов

# Получаем параметры командной строки (если они переданы)
DOWNLOAD_URL="$1"
DOWNLOADER_NAME="$2" 
OUTPUT_FILE="/tmp/$DOWNLOADER_NAME"

echo "=== Скрипт загрузки файлов ==="

# Если URL не был передан как параметр, запрашиваем его у пользователя
if [ -z "$DOWNLOAD_URL" ]; then
    echo "Введите URL для загрузки файла"
    read -p "URL: " DOWNLOAD_URL
fi

# Проверяем, что URL не пустой
if [ -z "$DOWNLOAD_URL" ]; then
    echo "ОШИБКА: URL не может быть пустым!"
    exit 1
fi

echo "Есть ли у вас предпочитаемое имя файла?"
echo "Ответьте: YES (да) или NO (нет)"

# Правильно структурированный цикл для получения ответа
while true; do
    read -p "Ваш ответ: " user_response
    
    # Используем case для обработки различных вариантов ответа
    case "$user_response" in
        [Yy]* | "YES" | "yes" )
            # Пользователь хочет задать собственное имя
            read -p "Введите желаемое имя файла: " DOWNLOADER_NAME
            
            # Если пользователь передумал и не ввел имя
            if [ -z "$DOWNLOADER_NAME" ]; then
                echo "Имя файла не введено. Будет использовано автоматическое имя."
                DOWNLOADER_NAME=""
            else
                echo "Файл будет сохранен как: $DOWNLOADER_NAME"
            fi
            break
            ;;
        [Nn]* | "NO" | "no" )
            # Пользователь хочет автоматическое имя
            echo "Файл будет сохранен с автоматическим именем!"
            DOWNLOADER_NAME=""
            break
            ;;
        * )
            # Любой другой ответ считается неверным
            echo "Пожалуйста, введите YES или NO"
            ;;
    esac
done

# Выполняем загрузку с соответствующими параметрами
echo "Начинаем загрузку..."

if [ -n "$DOWNLOADER_NAME" ]; then
    # Загрузка с пользовательским именем файла
    wget -q -O "$DOWNLOADER_NAME" "$DOWNLOAD_URL"
    final_filename="$DOWNLOADER_NAME"
else
    # Загрузка с автоматическим именем (wget сам определит из URL)
    wget -q "$DOWNLOAD_URL"
    # Пытаемся определить имя файла, который был загружен
    final_filename=$(basename "$DOWNLOAD_URL")
fi

# Проверяем успешность загрузки
if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось загрузить файл"
    echo "Возможные причины: неверный URL, нет соединения с интернетом, файл не существует"
    exit 1
else
    echo "Загрузка завершена успешно!"
    echo "Файл: $final_filename"
    echo "Расположение: $(pwd)/$final_filename"
fi
