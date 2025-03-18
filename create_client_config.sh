#!/bin/bash

# Скрипт для создания клиентской конфигурации WireGuard
# Часть 3: Создание клиентской конфигурации

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

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
fi

# Определение переменных
SERVER_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
if [[ -z "$SERVER_IP" ]]; then
    error "Не удалось определить IP-адрес сервера."
fi

WG_PORT=51820
WG_INTERFACE="wg0"
WG_CONFIG_DIR="/etc/wireguard"
CLIENT_CONFIG_DIR="/root/wireguard-clients"
WG_SERVER_PUBLIC_KEY="${WG_CONFIG_DIR}/server_public.key"
WG_SERVER_CONFIG="${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"

# Проверка наличия ключей сервера
if [ ! -f "${WG_SERVER_PUBLIC_KEY}" ]; then
    error "Публичный ключ сервера не найден. Сначала запустите скрипт настройки сервера."
fi

# Создание клиентской конфигурации
create_client_config() {
    local client_name=$1
    local client_ip=$2
    
    log "Создание конфигурации для клиента ${client_name}..."
    
    mkdir -p ${CLIENT_CONFIG_DIR}
    
    # Генерация ключей клиента
    local client_private_key=$(wg genkey)
    local client_public_key=$(echo ${client_private_key} | wg pubkey)
    
    # Создание конфигурационного файла клиента
    local client_config="${CLIENT_CONFIG_DIR}/${client_name}.conf"
    cat > ${client_config} << EOCFG
[Interface]
PrivateKey = ${client_private_key}
Address = ${client_ip}/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $(cat ${WG_SERVER_PUBLIC_KEY})
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:${WG_PORT}
PersistentKeepalive = 25
EOCFG
    
    # Добавление клиента в конфигурацию сервера
    cat >> ${WG_SERVER_CONFIG} << EOCFG

# ${client_name} begin
[Peer]
PublicKey = ${client_public_key}
AllowedIPs = ${client_ip}/32
# ${client_name} end
EOCFG
    
    # Генерация QR-кода
    qrencode -t png -o "${CLIENT_CONFIG_DIR}/${client_name}.png" < "${client_config}"
    qrencode -t ansiutf8 < "${client_config}" > "${CLIENT_CONFIG_DIR}/${client_name}.qrcode.txt"
    
    success "Конфигурация для клиента ${client_name} создана."
    log "Конфигурационный файл: ${client_config}"
    log "QR-код (PNG): ${CLIENT_CONFIG_DIR}/${client_name}.png"
    log "QR-код (текст): ${CLIENT_CONFIG_DIR}/${client_name}.qrcode.txt"
}

# Создание первого клиента
create_client_config "client1" "10.0.0.2"

success "Создание клиентской конфигурации завершено."
log "Для добавления дополнительных клиентов используйте функцию create_client_config с другими именами и IP-адресами."
