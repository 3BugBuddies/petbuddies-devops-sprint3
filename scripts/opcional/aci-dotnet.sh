#!/bin/bash
# ACI do back-office (.NET) — FORA DA ENTREGA DE DEVOPS
#
# A entrega da Sprint 3 cobre uma disciplina só, e a escolhida é Java Advanced:
# o ambiente avaliado é a API de cuidado mais o Oracle. Este script sobe o
# segundo serviço para a apresentação do produto à banca, onde o sistema inteiro
# precisa estar de pé. Rode depois do 05.
#
# MotorApi__BaseUrl usa o FQDN previsto do Java, não o resolvido: o health check
# "motor-java" deste serviço aponta para lá, e o Java aponta para cá — sem o
# endereço previsível um dos dois subiria sempre com o outro desconhecido.
set -e
source "$(dirname "$0")/../_comum.sh"
source "$(dirname "$0")/../_segredo.sh"

USER_NET=$(segredo oracle-user-backoffice)
CADEIA="Data Source=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=$FQDN_ORACLE)(PORT=1521)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=XEPDB1)));User Id=$USER_NET;Password=$(segredo oracle-password-backoffice);Max Pool Size=3;Min Pool Size=1"

az container create \
  -g "$RESOURCE_GROUP" -n "$ACI_NET" -l "$LOCATION" \
  --image "$ACR_NAME.azurecr.io/$IMG_NET:$TAG" \
  --cpu 1 --memory 1.5 --os-type Linux \
  --dns-name-label "$DNS_NET" --ports 8080 \
  --registry-login-server "$ACR_NAME.azurecr.io" \
  --registry-username "$(segredo acr-username)" \
  --registry-password "$(segredo acr-password)" \
  --environment-variables \
      ASPNETCORE_ENVIRONMENT=Production \
      MotorApi__BaseUrl="http://$FQDN_JAVA:8080" \
  --secure-environment-variables \
      ConnectionStrings__Oracle="$CADEIA" \
      PETBUDDIES_JWT_SECRET="$(segredo jwt-secret)" \
  --restart-policy Always -o none

echo "back-office: http://$FQDN_NET:8080/swagger"
