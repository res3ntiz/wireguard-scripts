#!/bin/bash

# Скрипт для настройки WireGuard сервера
# Часть 2: Настройка сервера и создание ключей

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
WG_SERVER_PRIVATE_KEY="${WG_CONFIG_DIR}/server_private.key"
WG_SERVER_PUBLIC_KEY="${WG_CONFIG_DIR}/server_public.key"
WG_SERVER_CONFIG="${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"
WG_SERVER_SUBNET="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"

# Создание ключей сервера
log "Создание ключей сервера..."
wg genkey | tee ${WG_SERVER_PRIVATE_KEY} | wg pubkey > ${WG_SERVER_PUBLIC_KEY}
chmod 600 ${WG_SERVER_PRIVATE_KEY}
success "Ключи сервера созданы."

# Создание конфигурации сервера
log "Создание конфигурации сервера..."
cat > ${WG_SERVER_CONFIG} << EOCFG
[Interface]
Address = ${WG_SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = $(cat ${WG_SERVER_PRIVATE_KEY})
SaveConfig = true

# Оптимизация для VPS с ограниченными ресурсами
MTU = 1420

# Включение маршрутизации
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)') -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)') -j MASQUERADE
EOCFG

chmod 600 ${WG_SERVER_CONFIG}
success "Конфигурация сервера создана."

# Настройка сетевых параметров
log "Настройка сетевых параметров..."

# Включение IP-форвардинга
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Настройка iptables для маскарадинга
iptables -t nat -A POSTROUTING -s ${WG_SERVER_SUBNET} -o $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)') -j MASQUERADE

# Сохранение правил iptables
netfilter-persistent save

success "Сетевые параметры настроены."
success "Настройка WireGuard сервера завершена."
