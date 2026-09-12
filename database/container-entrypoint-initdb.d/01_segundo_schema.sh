#!/bin/bash
# Cria o schema do back-office. O createAppUser é o helper da própria imagem e
# aplica os mesmos grants que o primeiro usuário recebe.
set -e
createAppUser "$APP_USER_2" "$APP_USER_2_PASSWORD" XEPDB1
echo "schema $APP_USER_2 criado em XEPDB1"
