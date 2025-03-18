#!/bin/bash

# Скрипт для генерации QR-кодов из конфигурационных файлов WireGuard
# Часть 4: Генератор QR-кодов

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
fi

# Проверка установки qrencode
if ! command -v qrencode &> /dev/null; then
    log "Установка qrencode..."
    apt update -y && apt install -y qrencode || error "Не удалось установить qrencode."
fi

CLIENT_CONFIG_DIR="/root/wireguard-clients"
mkdir -p ${CLIENT_CONFIG_DIR}

# Функция для генерации QR-кода из файла конфигурации
generate_qr_from_file() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        error "Файл конфигурации не найден: $config_file"
    fi
    
    local filename=$(basename "$config_file")
    local client_name="${filename%.*}"
    
    log "Генерация QR-кода для клиента $client_name..."
    
    # Генерация QR-кода в формате PNG
    qrencode -t png -o "${CLIENT_CONFIG_DIR}/${client_name}.png" < "$config_file"
    
    # Генерация QR-кода в текстовом формате для вывода в терминал
    qrencode -t ansiutf8 < "$config_file" > "${CLIENT_CONFIG_DIR}/${client_name}.qrcode.txt"
    
    success "QR-код для клиента $client_name создан."
    log "QR-код (PNG): ${CLIENT_CONFIG_DIR}/${client_name}.png"
    log "QR-код (текст): ${CLIENT_CONFIG_DIR}/${client_name}.qrcode.txt"
    
    # Вывод QR-кода в терминал
    echo "QR-код для сканирования:"
    cat "${CLIENT_CONFIG_DIR}/${client_name}.qrcode.txt"
}

# Функция для генерации QR-кода из строки конфигурации
generate_qr_from_string() {
    local config_string=$1
    local output_name=$2
    
    if [ -z "$config_string" ]; then
        error "Строка конфигурации пуста."
    fi
    
    if [ -z "$output_name" ]; then
        error "Не указано имя для выходного файла."
    fi
    
    log "Генерация QR-кода для $output_name..."
    
    # Сохранение строки во временный файл
    echo "$config_string" > "${CLIENT_CONFIG_DIR}/${output_name}.conf.tmp"
    
    # Генерация QR-кода в формате PNG
    qrencode -t png -o "${CLIENT_CONFIG_DIR}/${output_name}.png" < "${CLIENT_CONFIG_DIR}/${output_name}.conf.tmp"
    
    # Генерация QR-кода в текстовом формате для вывода в терминал
    qrencode -t ansiutf8 < "${CLIENT_CONFIG_DIR}/${output_name}.conf.tmp" > "${CLIENT_CONFIG_DIR}/${output_name}.qrcode.txt"
    
    # Удаление временного файла
    rm "${CLIENT_CONFIG_DIR}/${output_name}.conf.tmp"
    
    success "QR-код для $output_name создан."
    log "QR-код (PNG): ${CLIENT_CONFIG_DIR}/${output_name}.png"
    log "QR-код (текст): ${CLIENT_CONFIG_DIR}/${output_name}.qrcode.txt"
    
    # Вывод QR-кода в терминал
    echo "QR-код для сканирования:"
    cat "${CLIENT_CONFIG_DIR}/${output_name}.qrcode.txt"
}

# Функция для генерации QR-кодов для всех конфигураций
generate_all_qr_codes() {
    log "Генерация QR-кодов для всех клиентских конфигураций..."
    
    local configs=$(find ${CLIENT_CONFIG_DIR} -name "*.conf" -type f)
    local count=0
    
    if [ -z "$configs" ]; then
        warning "Клиентские конфигурации не найдены в ${CLIENT_CONFIG_DIR}"
        return
    fi
    
    for config in $configs; do
        generate_qr_from_file "$config"
        ((count++))
    done
    
    success "Сгенерировано QR-кодов: $count"
}

# Проверка аргументов командной строки
if [ $# -eq 0 ]; then
    # Без аргументов - генерируем QR-коды для всех конфигураций
    generate_all_qr_codes
elif [ "$1" = "--file" ] || [ "$1" = "-f" ]; then
    # Генерация QR-кода из файла
    if [ -z "$2" ]; then
        error "Не указан файл конфигурации. Использование: $0 --file <путь_к_файлу>"
    fi
    generate_qr_from_file "$2"
elif [ "$1" = "--string" ] || [ "$1" = "-s" ]; then
    # Генерация QR-кода из строки
    if [ -z "$2" ] || [ -z "$3" ]; then
        error "Не указана строка конфигурации или имя выходного файла. Использование: $0 --string <строка_конфигурации> <имя_выходного_файла>"
    fi
    generate_qr_from_string "$2" "$3"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    # Вывод справки
    echo "Использование:"
    echo "  $0                           - Генерация QR-кодов для всех конфигураций"
    echo "  $0 --file|-f <файл>          - Генерация QR-кода из указанного файла конфигурации"
    echo "  $0 --string|-s <строка> <имя> - Генерация QR-кода из строки конфигурации с указанным именем"
    echo "  $0 --help|-h                 - Вывод этой справки"
else
    error "Неизвестный аргумент: $1. Используйте --help для получения справки."
fi

exit 0
