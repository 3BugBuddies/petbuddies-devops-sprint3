#!/bin/bash
# 04 — ACI do Oracle XE: uma instância, dois schemas isolados
#
# Um instance e não dois porque a assinatura tem limite de 6 Standard Cores na
# região (ver 00_preflight): dois Oracle a 2 cores deixariam zero folga para
# recriar um app. O invariante do ADR s3-25 se mantém — nenhum objeto de um
# serviço vive no schema do outro.
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
      APP_USER="$(segredo oracle-user-cuidado)" \
      APP_USER_2="$(segredo oracle-user-backoffice)" \
  --secure-environment-variables \
      ORACLE_PASSWORD="$(segredo oracle-sys-password)" \
      APP_USER_PASSWORD="$(segredo oracle-password-cuidado)" \
      APP_USER_2_PASSWORD="$(segredo oracle-password-backoffice)" \
  --restart-policy Always -o none

echo "FQDN: $FQDN_ORACLE:1521/XEPDB1"
espera_oracle
