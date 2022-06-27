#!/bin/bash
USER_ID=$(id -u)
sed -i "s/USER_ID=1000/USER_ID=${USER_ID}/g" Dockerfile
read -p "Введите порт для laravel: " LARAVEL_PORT
sed -i "s/80:80/${LARAVEL_PORT}:80/g" docker-compose.yml
sed -i "s/1000:1000/${USER_ID}:${USER_ID}/g" docker-compose.yml
composer create-project laravel/laravel laravel
cd laravel
composer update
cd ../
docker-compose up -d --build