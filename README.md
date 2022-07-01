# Контейнер с конфигурацией КриптоПро для laravel 8

### Используемая ОС: Ubuntu 20.04

Стабильная LTS с актуальным на момент сборки php 7.4

### Версия php: 7.4.3

Актуальная версия php с настроенным php-fpm, openssl и pdo

### Поддержка postgresql

Установлен драйвер pdo для взаимодействия с postgresql

## Установка (работает на серверах и ПК с Linux):

git clone https://github.com/codesshaman/laravel8_cryptopro_onubuntu20_04.git

cd laravel8_cryptopro_onubuntu20_04

chmod +x start.sh && ./start.sh

Далее указываем рабочий порт для бэкенда laravel и наслаждаемся установкой.

На windows можно распаковать laravel из папки и запустить контейнер при помощи docker-compose up -d --build
