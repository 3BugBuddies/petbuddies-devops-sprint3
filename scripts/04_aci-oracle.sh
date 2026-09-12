#!/bin/bash
# 04 — ACI do Oracle XE
#
# O usuário da aplicação nasce pelas variáveis APP_USER/APP_USER_PASSWORD, que a
# própria imagem do gvenzl consome. As tabelas vêm depois, pelo Flyway.
#
# ORACLE_RANDOM_PASSWORD: o SYS ganha uma senha aleatória que ninguém guarda e
# ninguém usa. A imagem exige uma senha administrativa no primeiro boot, mas a
# aplicação conecta como APP_USER — manter a do SYS num cofre seria administrar
# um segredo sem dono.
#
# A porta 1521 é pública de propósito: a rubrica §9.3 exige evidência de cada
# operação do CRUD por SELECT no banco, feito de um cliente SQL externo.
set -e
source "$(dirname "$0")/_comum.sh"
source "$(dirname "$0")/_segredo.sh"

az container create \
  -g "$RESOURCE_GROUP" -n "$ACI_ORACLE" -l "$LOCATION" \
  --image "$ACR_NAME.azurecr.io/$IMG_ORACLE:$TAG" \
  --cpu 2 --memory 4 --os-type Linux \
  --dns-name-label "$DNS_ORACLE" --ports 1521 \
  --registry-login-server "$ACR_NAME.azurecr.io" \
  --registry-username "$(segredo acr-username)" \
  --registry-password "$(segredo acr-password)" \
  --environment-variables \
      ORACLE_CHARACTERSET=AL32UTF8 \
      ORACLE_RANDOM_PASSWORD=yes \
      APP_USER="$(segredo oracle-user-cuidado)" \
  --secure-environment-variables \
      APP_USER_PASSWORD="$(segredo oracle-password-cuidado)" \
  --restart-policy Always -o none

echo "FQDN: $FQDN_ORACLE:1521/XEPDB1"
espera_oracle
