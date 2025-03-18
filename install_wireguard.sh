#!/bin/bash

# Скрипт для установки WireGuard и необходимых зависимостей
# Часть 1: Установка пакетов

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

# Установка необходимых пакетов
log "Обновление списка пакетов..."
apt update -y || error "Не удалось обновить список пакетов."

log "Установка необходимых пакетов..."
apt install -y wireguard qrencode iptables-persistent || error "Не удалось установить необходимые пакеты."

success "WireGuard и зависимости успешно установлены."

# Создание директорий
log "Создание директорий для конфигурации..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard
mkdir -p /root/wireguard-clients

success "Установка WireGuard и зависимостей завершена."
