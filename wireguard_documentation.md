# Руководство по установке и использованию WireGuard VPN на Debian 12

## Содержание

1. [Введение](#введение)
2. [Требования](#требования)
3. [Быстрая установка](#быстрая-установка)
4. [Пошаговая установка](#пошаговая-установка)
5. [Управление клиентами](#управление-клиентами)
6. [Использование QR-кодов](#использование-qr-кодов)
7. [Управление сервером](#управление-сервером)
8. [Устранение неполадок](#устранение-неполадок)
9. [Оптимизация](#оптимизация)

## Введение

WireGuard - это современный, быстрый и безопасный VPN-протокол, который отличается простотой настройки и высокой производительностью. Данное руководство поможет вам установить и настроить WireGuard VPN сервер на Debian 12, оптимизированный для работы на VPS с ограниченными ресурсами (1 ядро, 1 ГБ ОЗУ, 10 ГБ SSD).

## Требования

- VPS с Debian 12
- Права суперпользователя (root)
- Открытый порт UDP 51820 (можно изменить в конфигурации)

## Быстрая установка

Для быстрой установки WireGuard VPN выполните следующие команды:

```bash
# Скачайте все скрипты
wget -O wireguard_setup.sh https://raw.githubusercontent.com/yourusername/wireguard-scripts/main/wireguard_setup.sh
chmod +x wireguard_setup.sh

# Запустите скрипт установки
sudo ./wireguard_setup.sh
```

После завершения установки вы получите готовый к использованию WireGuard VPN сервер с одним клиентом и QR-кодом для быстрого подключения.

## Пошаговая установка

Если вы предпочитаете пошаговую установку или хотите лучше понять процесс, выполните следующие шаги:

### 1. Установка WireGuard и зависимостей

```bash
sudo ./install_wireguard.sh
```

Этот скрипт установит WireGuard, qrencode и другие необходимые пакеты.

### 2. Настройка WireGuard сервера

```bash
sudo ./configure_wireguard_server.sh
```

Этот скрипт создаст ключи сервера, настроит конфигурационный файл и сетевые параметры.

### 3. Создание клиентской конфигурации

```bash
sudo ./create_client_config.sh
```

Этот скрипт создаст конфигурацию для первого клиента с именем "client1" и IP-адресом 10.0.0.2.

### 4. Тестирование VPN соединения

```bash
sudo ./test_wireguard.sh
```

Этот скрипт запустит WireGuard сервер, проверит его статус и выведет информацию о настройках.

## Управление клиентами

### Добавление нового клиента

```bash
sudo add-wg-client <имя_клиента> <IP-адрес>
```

Пример:
```bash
sudo add-wg-client phone 10.0.0.3
sudo add-wg-client laptop 10.0.0.4
sudo add-wg-client tablet 10.0.0.5
```

### Удаление клиента

```bash
sudo remove-wg-client <имя_клиента>
```

Пример:
```bash
sudo remove-wg-client phone
```

### Просмотр списка клиентов и статуса

```bash
sudo wg-status
```

## Использование QR-кодов

WireGuard поддерживает быстрое подключение с помощью QR-кодов. Для генерации QR-кодов используйте следующие команды:

### Генерация QR-кодов для всех клиентов

```bash
sudo wg-qrcode
```

### Генерация QR-кода для конкретного клиента

```bash
sudo wg-qrcode --file /root/wireguard-clients/<имя_клиента>.conf
```

Пример:
```bash
sudo wg-qrcode --file /root/wireguard-clients/phone.conf
```

### Генерация QR-кода из строки конфигурации

```bash
sudo wg-qrcode --string "<содержимое_конфигурации>" <имя_выходного_файла>
```

## Управление сервером

### Запуск/остановка/перезапуск сервера

```bash
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0
sudo systemctl restart wg-quick@wg0
```

### Проверка статуса сервера

```bash
sudo systemctl status wg-quick@wg0
```

### Включение автозапуска

```bash
sudo systemctl enable wg-quick@wg0
```

### Отключение автозапуска

```bash
sudo systemctl disable wg-quick@wg0
```

## Устранение неполадок

### Проблемы с подключением

1. Проверьте статус сервера:
   ```bash
   sudo wg-status
   ```

2. Проверьте правила брандмауэра:
   ```bash
   sudo iptables -L -n
   ```

3. Проверьте логи:
   ```bash
   sudo journalctl -u wg-quick@wg0
   ```

4. Убедитесь, что порт UDP 51820 открыт:
   ```bash
   sudo netstat -tulpn | grep 51820
   ```

### Сброс конфигурации

Если вы хотите полностью сбросить конфигурацию WireGuard:

```bash
sudo systemctl stop wg-quick@wg0
sudo rm -rf /etc/wireguard/wg0.conf
sudo rm -rf /root/wireguard-clients/*
```

После этого можно заново запустить скрипт установки.

## Оптимизация

Для оптимизации производительности WireGuard на VPS с ограниченными ресурсами выполните:

```bash
sudo ./wireguard_setup.sh --optimize
```

или

```bash
sudo optimize-wg
```

Это настроит сетевые параметры для оптимальной работы WireGuard на вашем сервере.

## Расположение файлов

- Конфигурация сервера: `/etc/wireguard/wg0.conf`
- Конфигурации клиентов: `/root/wireguard-clients/`
- QR-коды для клиентов: `/root/wireguard-clients/<имя_клиента>.png`
- Текстовые QR-коды: `/root/wireguard-clients/<имя_клиента>.qrcode.txt`
- Скрипты управления: `/usr/local/bin/`
- Документация: `/root/wireguard-docs/README.md`

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
