#!/bin/bash

# Скрипт для тестирования WireGuard VPN соединения
# Часть 5: Тестирование соединения

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

WG_INTERFACE="wg0"

# Запуск WireGuard
log "Запуск WireGuard..."
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

# Проверка статуса
if systemctl is-active --quiet wg-quick@${WG_INTERFACE}; then
    success "WireGuard успешно запущен и добавлен в автозагрузку."
else
    error "Не удалось запустить WireGuard."
fi

# Вывод информации о сервере
log "Информация о WireGuard сервере:"
wg show ${WG_INTERFACE}

# Проверка сетевых настроек
log "Проверка сетевых настроек..."
if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.d/99-wireguard.conf; then
    success "IP-форвардинг включен."
else
    warning "IP-форвардинг не настроен должным образом."
fi

# Проверка правил iptables
log "Проверка правил iptables..."
if iptables -t nat -C POSTROUTING -s 10.0.0.0/24 -o $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)') -j MASQUERADE 2>/dev/null; then
    success "Правила iptables настроены корректно."
else
    warning "Правила iptables не настроены должным образом."
fi

# Вывод информации о клиентах
log "Информация о клиентах:"
CLIENT_LIST=$(grep -n "# .* begin" /etc/wireguard/${WG_INTERFACE}.conf | sed 's/:.* # \(.*\) begin/\1/')

if [ -z "$CLIENT_LIST" ]; then
    warning "Клиенты не найдены."
else
    for CLIENT in $CLIENT_LIST; do
        CLIENT_PUBLIC_KEY=$(grep -A 2 "# ${CLIENT} begin" /etc/wireguard/${WG_INTERFACE}.conf | grep "PublicKey" | cut -d ' ' -f 3)
        CLIENT_IP=$(grep -A 2 "# ${CLIENT} begin" /etc/wireguard/${WG_INTERFACE}.conf | grep "AllowedIPs" | cut -d ' ' -f 3 | sed 's/\/32//')
        
        log "Клиент: ${CLIENT}, IP: ${CLIENT_IP}, Публичный ключ: ${CLIENT_PUBLIC_KEY}"
    done
fi

success "Тестирование WireGuard VPN завершено успешно."
log "WireGuard VPN сервер готов к использованию."
