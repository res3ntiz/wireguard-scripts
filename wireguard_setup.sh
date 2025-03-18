#!/bin/bash

# Главный автоматизационный скрипт для установки и настройки WireGuard VPN
# Объединяет все компоненты в единое решение

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

# Определение переменных
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WG_INTERFACE="wg0"
CLIENT_CONFIG_DIR="/root/wireguard-clients"
WG_CONFIG_DIR="/etc/wireguard"

# Функция для установки WireGuard и зависимостей
install_wireguard() {
    log "Установка WireGuard и зависимостей..."
    
    if [ -f "${SCRIPT_DIR}/install_wireguard.sh" ]; then
        bash "${SCRIPT_DIR}/install_wireguard.sh" || error "Ошибка при установке WireGuard."
    else
        # Встроенная установка, если скрипт не найден
        log "Обновление списка пакетов..."
        apt update -y || error "Не удалось обновить список пакетов."
        
        log "Установка необходимых пакетов..."
        apt install -y wireguard qrencode iptables-persistent || error "Не удалось установить необходимые пакеты."
        
        # Создание директорий
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard
        mkdir -p /root/wireguard-clients
    fi
    
    success "WireGuard и зависимости установлены."
}

# Функция для настройки WireGuard сервера
configure_server() {
    log "Настройка WireGuard сервера..."
    
    if [ -f "${SCRIPT_DIR}/configure_wireguard_server.sh" ]; then
        bash "${SCRIPT_DIR}/configure_wireguard_server.sh" || error "Ошибка при настройке сервера WireGuard."
    else
        error "Скрипт настройки сервера не найден: ${SCRIPT_DIR}/configure_wireguard_server.sh"
    fi
    
    success "WireGuard сервер настроен."
}

# Функция для создания клиентской конфигурации
create_client() {
    log "Создание клиентской конфигурации..."
    
    if [ -f "${SCRIPT_DIR}/create_client_config.sh" ]; then
        bash "${SCRIPT_DIR}/create_client_config.sh" || error "Ошибка при создании клиентской конфигурации."
    else
        error "Скрипт создания клиентской конфигурации не найден: ${SCRIPT_DIR}/create_client_config.sh"
    fi
    
    success "Клиентская конфигурация создана."
}

# Функция для запуска WireGuard
start_wireguard() {
    log "Запуск WireGuard..."
    
    systemctl enable wg-quick@${WG_INTERFACE}
    systemctl start wg-quick@${WG_INTERFACE}
    
    # Проверка статуса
    if systemctl is-active --quiet wg-quick@${WG_INTERFACE}; then
        success "WireGuard запущен и добавлен в автозагрузку."
    else
        error "Не удалось запустить WireGuard."
    fi
}

# Функция для создания скрипта добавления новых клиентов
create_management_scripts() {
    log "Создание скриптов управления WireGuard..."
    
    # Скрипт для добавления новых клиентов
    cat > /usr/local/bin/add-wg-client << 'EOSCRIPT'
#!/bin/bash

# Скрипт для добавления новых клиентов WireGuard

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
   exit 1
fi

# Проверка аргументов
if [ $# -ne 2 ]; then
    echo -e "${RED}[ERROR]${NC} Использование: $0 <имя_клиента> <IP-адрес>"
    echo -e "Пример: $0 phone 10.0.0.2"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP=$2
WG_INTERFACE="wg0"
WG_CONFIG_DIR="/etc/wireguard"
CLIENT_CONFIG_DIR="/root/wireguard-clients"
SERVER_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
WG_PORT=51820

# Проверка существования конфигурации сервера
if [ ! -f "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf" ]; then
    echo -e "${RED}[ERROR]${NC} Конфигурация сервера не найдена."
    exit 1
fi

# Проверка существования клиента с таким именем
if grep -q "# ${CLIENT_NAME} begin" "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"; then
    echo -e "${RED}[ERROR]${NC} Клиент с именем ${CLIENT_NAME} уже существует."
    exit 1
fi

# Проверка существования клиента с таким IP
if grep -q "AllowedIPs = ${CLIENT_IP}/32" "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"; then
    echo -e "${RED}[ERROR]${NC} Клиент с IP-адресом ${CLIENT_IP} уже существует."
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Создание конфигурации для клиента ${CLIENT_NAME}..."

mkdir -p ${CLIENT_CONFIG_DIR}

# Генерация ключей клиента
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo ${CLIENT_PRIVATE_KEY} | wg pubkey)

# Создание конфигурационного файла клиента
CLIENT_CONFIG="${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.conf"
cat > ${CLIENT_CONFIG} << EOCFG
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $(grep PrivateKey ${WG_CONFIG_DIR}/${WG_INTERFACE}.conf | cut -d ' ' -f 3 | wg pubkey)
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:${WG_PORT}
PersistentKeepalive = 25
EOCFG

# Добавление клиента в конфигурацию сервера
cat >> ${WG_CONFIG_DIR}/${WG_INTERFACE}.conf << EOCFG

# ${CLIENT_NAME} begin
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
# ${CLIENT_NAME} end
EOCFG

# Генерация QR-кода
qrencode -t png -o "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.png" < "${CLIENT_CONFIG}"
qrencode -t ansiutf8 < "${CLIENT_CONFIG}" > "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.qrcode.txt"

# Применение изменений
wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})

echo -e "${GREEN}[SUCCESS]${NC} Конфигурация для клиента ${CLIENT_NAME} создана."
echo -e "${BLUE}[INFO]${NC} Конфигурационный файл: ${CLIENT_CONFIG}"
echo -e "${BLUE}[INFO]${NC} QR-код (PNG): ${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.png"
echo -e "${BLUE}[INFO]${NC} QR-код (текст): ${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.qrcode.txt"

# Вывод QR-кода в терминал
echo "QR-код для сканирования:"
cat "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.qrcode.txt"
EOSCRIPT
    
    chmod +x /usr/local/bin/add-wg-client
    
    # Скрипт для удаления клиентов
    cat > /usr/local/bin/remove-wg-client << 'EOSCRIPT'
#!/bin/bash

# Скрипт для удаления клиентов WireGuard

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
   exit 1
fi

# Проверка аргументов
if [ $# -ne 1 ]; then
    echo -e "${RED}[ERROR]${NC} Использование: $0 <имя_клиента>"
    echo -e "Пример: $0 phone"
    exit 1
fi

CLIENT_NAME=$1
WG_INTERFACE="wg0"
WG_CONFIG_DIR="/etc/wireguard"
CLIENT_CONFIG_DIR="/root/wireguard-clients"

# Проверка существования конфигурации сервера
if [ ! -f "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf" ]; then
    echo -e "${RED}[ERROR]${NC} Конфигурация сервера не найдена."
    exit 1
fi

# Проверка существования клиента с таким именем
if ! grep -q "# ${CLIENT_NAME} begin" "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"; then
    echo -e "${RED}[ERROR]${NC} Клиент с именем ${CLIENT_NAME} не найден."
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Удаление клиента ${CLIENT_NAME}..."

# Удаление конфигурации клиента из конфигурации сервера
sed -i "/# ${CLIENT_NAME} begin/,/# ${CLIENT_NAME} end/d" "${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"

# Удаление файлов клиента
rm -f "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.conf" "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.png" "${CLIENT_CONFIG_DIR}/${CLIENT_NAME}.qrcode.txt"

# Применение изменений
wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})

echo -e "${GREEN}[SUCCESS]${NC} Клиент ${CLIENT_NAME} успешно удален."
EOSCRIPT
    
    chmod +x /usr/local/bin/remove-wg-client
    
    # Скрипт для просмотра статуса
    cat > /usr/local/bin/wg-status << 'EOSCRIPT'
#!/bin/bash

# Скрипт для просмотра статуса WireGuard

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
   exit 1
fi

WG_INTERFACE="wg0"

# Проверка статуса WireGuard
if ! systemctl is-active --quiet wg-quick@${WG_INTERFACE}; then
    echo -e "${RED}[ERROR]${NC} WireGuard не запущен."
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Статус WireGuard:"
echo ""
wg show ${WG_INTERFACE}
echo ""
echo -e "${BLUE}[INFO]${NC} Список клиентов:"
echo ""

# Получение списка клиентов
CLIENT_LIST=$(grep -n "# .* begin" /etc/wireguard/${WG_INTERFACE}.conf | sed 's/:.* # \(.*\) begin/\1/')

if [ -z "$CLIENT_LIST" ]; then
    echo -e "${YELLOW}[WARNING]${NC} Клиенты не найдены."
else
    for CLIENT in $CLIENT_LIST; do
        CLIENT_PUBLIC_KEY=$(grep -A 2 "# ${CLIENT} begin" /etc/wireguard/${WG_INTERFACE}.conf | grep "PublicKey" | cut -d ' ' -f 3)
        CLIENT_IP=$(grep -A 2 "# ${CLIENT} begin" /etc/wireguard/${WG_INTERFACE}.conf | grep "AllowedIPs" | cut -d ' ' -f 3 | sed 's/\/32//')
        
        # Проверка активности клиента
        if wg show ${WG_INTERFACE} | grep -q "${CLIENT_PUBLIC_KEY}"; then
            LAST_HANDSHAKE=$(wg show ${WG_INTERFACE} | grep -A 3 "${CLIENT_PUBLIC_KEY}" | grep "latest handshake" | sed 's/.*latest handshake: \(.*\)/\1/')
            TRANSFER=$(wg show ${WG_INTERFACE} | grep -A 3 "${CLIENT_PUBLIC_KEY}" | grep "transfer" | sed 's/.*transfer: \(.*\)/\1/')
            echo -e "${GREEN}[ACTIVE]${NC} ${CLIENT} (${CLIENT_IP})"
            echo -e "  Последний хэндшейк: ${LAST_HANDSHAKE}"
            echo -e "  Передано данных: ${TRANSFER}"
        else
            echo -e "${YELLOW}[INACTIVE]${NC} ${CLIENT} (${CLIENT_IP})"
        fi
    done
fi
EOSCRIPT
    
    chmod +x /usr/local/bin/wg-status
    
    # Копирование генератора QR-кодов, если он существует
    if [ -f "${SCRIPT_DIR}/generate_qr_code.sh" ]; then
        cp "${SCRIPT_DIR}/generate_qr_code.sh" /usr/local/bin/wg-qrcode
        chmod +x /usr/local/bin/wg-qrcode
    fi
    
    success "Скрипты управления WireGuard созданы."
    log "Доступные команды:"
    log "  add-wg-client - Добавление нового клиента"
    log "  remove-wg-client - Удаление клиента"
    log "  wg-status - Просмотр статуса WireGuard"
    if [ -f "/usr/local/bin/wg-qrcode" ]; then
        log "  wg-qrcode - Генерация QR-кодов для конфигураций"
    fi
}

# Функция для создания документации
create_documentation() {
    log "Создание документации..."
    
    mkdir -p /root/wireguard-docs
    
    cat > /root/wireguard-docs/README.md << 'EODOC'
# Документация по WireGuard VPN

## Общая информация

WireGuard - это современный, быстрый и безопасный VPN-протокол. Данная установка настроена для оптимальной работы на VPS с ограниченными ресурсами.

## Управление сервером

### Проверка статуса

```bash
sudo wg-status
```

### Запуск/остановка/перезапуск сервера

```bash
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0
sudo systemctl restart wg-quick@wg0
```

## Управление клиентами

### Добавление нового клиента

```bash
sudo add-wg-client <имя_клиента> <IP-адрес>
```

Пример:
```bash
sudo add-wg-client phone 10.0.0.2
sudo add-wg-client laptop 10.0.0.3
sudo add-wg-client tablet 10.0.0.4
```

### Удаление клиента

```bash
sudo remove-wg-client <имя_клиента>
```

Пример:
```bash
sudo remove-wg-client phone
```

### Генерация QR-кодов

```bash
sudo wg-qrcode
```

Для генерации QR-кода для конкретного клиента:
```bash
sudo wg-qrcode --file /root/wireguard-clients/<имя_клиента>.conf
```

## Расположение файлов

- Конфигурация сервера: `/etc/wireguard/wg0.conf`
- Конфигурации клиентов: `/root/wireguard-clients/`
- QR-коды для клиентов: `/root/wireguard-clients/<имя_клиента>.png`
- Текстовые QR-коды: `/root/wireguard-clients/<имя_клиента>.qrcode.txt`

## Клиентские приложения

### Android
- [WireGuard](https://play.google.com/store/apps/details?id=com.wireguard.android)

### iOS
- [WireGuard](https://apps.apple.com/us/app/wireguard/id1441195209)

### Windows
- [WireGuard](https://download.wireguard.com/windows-client/wireguard-installer.exe)

### macOS
- [WireGuard](https://apps.apple.com/us/app/wireguard/id1451685025)

### Linux
```bash
sudo apt install wireguard
```

## Подключение клиентов

1. Установите приложение WireGuard на устройство
2. Отсканируйте QR-код или импортируйте конфигурационный файл
3. Активируйте VPN-соединение

## Устранение неполадок

### Проблемы с подключением

1. Проверьте статус сервера: `sudo wg-status`
2. Проверьте правила брандмауэра: `sudo iptables -L -n`
3. Проверьте логи: `sudo journalctl -u wg-quick@wg0`

### Сброс конфигурации

Если вы хотите полностью сбросить конфигурацию WireGuard:

```bash
sudo systemctl stop wg-quick@wg0
sudo rm -rf /etc/wireguard/wg0.conf
sudo rm -rf /root/wireguard-clients/*
```

После этого можно заново запустить скрипт установки.
EODOC
    
    success "Документация создана: /root/wireguard-docs/README.md"
}

# Функция для оптимизации WireGuard
optimize_wireguard() {
    log "Оптимизация WireGuard..."
    
    # Оптимизация сетевых параметров
    cat > /etc/sysctl.d/99-wireguard-optimize.conf << EOF
# Оптимизация сетевых параметров для WireGuard
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding=1

# Увеличение размера буферов
net.core.rmem_max=26214400
net.core.rmem_default=1048576
net.core.wmem_max=26214400
net.core.wmem_default=1048576

# Оптимизация TCP
net.ipv4.tcp_rmem=4096 1048576 2097152
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mtu_probing=1

# Оптимизация для VPS с ограниченными ресурсами
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

    # Применение параметров
    sysctl -p /etc/sysctl.d/99-wireguard-optimize.conf
    
    # Оптимизация MTU
    if [ -f "/etc/wireguard/${WG_INTERFACE}.conf" ]; then
        if ! grep -q "MTU" "/etc/wireguard/${WG_INTERFACE}.conf"; then
            sed -i '/\[Interface\]/a MTU = 1420' "/etc/wireguard/${WG_INTERFACE}.conf"
        fi
        
        # Перезапуск WireGuard для применения изменений
        if systemctl is-active --quiet wg-quick@${WG_INTERFACE}; then
            systemctl restart wg-quick@${WG_INTERFACE}
        fi
    fi
    
    success "Оптимизация WireGuard завершена."
}

# Функция для вывода информации о сервере
show_server_info() {
    SERVER_IP=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
    WG_PORT=51820
    
    echo ""
    log "Информация о сервере WireGuard:"
    log "IP-адрес сервера: ${SERVER_IP}"
    log "Порт WireGuard: ${WG_PORT}"
    log "Интерфейс WireGuard: ${WG_INTERFACE}"
    
    if [ -d "${CLIENT_CONFIG_DIR}" ]; then
        log "Конфигурации клиентов:"
        for client in $(find ${CLIENT_CONFIG_DIR} -name "*.conf" -type f); do
            client_name=$(basename "$client" .conf)
            log "  - ${client_name}: ${client}"
            log "    QR-код: ${CLIENT_CONFIG_DIR}/${client_name}.png"
        done
    fi
    
    echo ""
    log "Для добавления новых клиентов используйте команду:"
    echo "  sudo add-wg-client <имя_клиента> <IP-адрес>"
    echo "  Пример: sudo add-wg-client phone 10.0.0.3"
    
    echo ""
    log "Для просмотра статуса WireGuard используйте команду:"
    echo "  sudo wg-status"
    
    if [ -f "/usr/local/bin/wg-qrcode" ]; then
        echo ""
        log "Для генерации QR-кодов используйте команду:"
        echo "  sudo wg-qrcode"
    fi
    
    echo ""
    log "Документация доступна в: /root/wireguard-docs/README.md"
}

# Функция для полной установки
full_install() {
    log "Начало полной установки WireGuard VPN..."
    
    install_wireguard
    configure_server
    create_client
    create_management_scripts
    create_documentation
    start_wireguard
    optimize_wireguard
    
    success "Полная установка WireGuard VPN завершена!"
    show_server_info
    
    # Вывод QR-кода для первого клиента
    if [ -f "${CLIENT_CONFIG_DIR}/client1.qrcode.txt" ]; then
        echo ""
        log "QR-код для первого клиента:"
        cat "${CLIENT_CONFIG_DIR}/client1.qrcode.txt"
    fi
}

# Проверка аргументов командной строки
if [ $# -eq 0 ]; then
    # Без аргументов - выполняем полную установку
    full_install
elif [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
    # Только установка пакетов
    install_wireguard
elif [ "$1" = "--configure" ] || [ "$1" = "-c" ]; then
    # Только настройка сервера
    configure_server
elif [ "$1" = "--client" ] || [ "$1" = "-cl" ]; then
    # Только создание клиента
    create_client
elif [ "$1" = "--start" ] || [ "$1" = "-s" ]; then
    # Только запуск сервера
    start_wireguard
elif [ "$1" = "--optimize" ] || [ "$1" = "-o" ]; then
    # Только оптимизация
    optimize_wireguard
elif [ "$1" = "--scripts" ] || [ "$1" = "-sc" ]; then
    # Только создание скриптов управления
    create_management_scripts
elif [ "$1" = "--docs" ] || [ "$1" = "-d" ]; then
    # Только создание документации
    create_documentation
elif [ "$1" = "--info" ] || [ "$1" = "-in" ]; then
    # Только вывод информации
    show_server_info
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    # Вывод справки
    echo "Использование:"
    echo "  $0                       - Полная установка WireGuard VPN"
    echo "  $0 --install|-i          - Только установка пакетов"
    echo "  $0 --configure|-c        - Только настройка сервера"
    echo "  $0 --client|-cl          - Только создание клиента"
    echo "  $0 --start|-s            - Только запуск сервера"
    echo "  $0 --optimize|-o         - Только оптимизация"
    echo "  $0 --scripts|-sc         - Только создание скриптов управления"
    echo "  $0 --docs|-d             - Только создание документации"
    echo "  $0 --info|-in            - Вывод информации о сервере"
    echo "  $0 --help|-h             - Вывод этой справки"
else
    error "Неизвестный аргумент: $1. Используйте --help для получения справки."
fi

exit 0
