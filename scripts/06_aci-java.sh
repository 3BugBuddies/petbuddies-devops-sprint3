#!/bin/bash
# 06 — ACI da API de cuidado (Java)
#
# PETNETAPI_URL é injetada com o FQDN real do .NET. O ACI não tem DNS de rede
# compartilhada como o docker compose: cada grupo de container tem FQDN próprio,
# e o application-docker.properties aponta para um nome que só existe na rede do
# compose. Variável de ambiente tem precedência sobre application-*.properties
# no Spring, então ela vence sem precisar de profile novo.
set -e
source "$(dirname "$0")/_comum.sh"
source "$(dirname "$0")/_segredo.sh"

az container create \
  -g "$RESOURCE_GROUP" -n "$ACI_JAVA" -l "$LOCATION" \
  --image "$ACR_NAME.azurecr.io/$IMG_JAVA:$TAG" \
  --cpu 1 --memory 2 --os-type Linux \
  --dns-name-label "$DNS_JAVA" --ports 8080 \
  --registry-login-server "$ACR_NAME.azurecr.io" \
  --registry-username "$(segredo acr-username)" \
  --registry-password "$(segredo acr-password)" \
  --environment-variables \
      SPRING_PROFILES_ACTIVE=docker \
      PETNETAPI_URL="http://$FQDN_NET:8080" \
      ORACLE_URL="jdbc:oracle:thin:@$FQDN_ORACLE:1521/XEPDB1" \
      ORACLE_USER="$(segredo oracle-user-cuidado)" \
  --secure-environment-variables \
      ORACLE_PASSWORD="$(segredo oracle-password-cuidado)" \
      PETBUDDIES_JWT_SECRET="$(segredo jwt-secret)" \
      GEMINI_API_KEY="$(segredo gemini-api-key)" \
  --restart-policy Always -o none

echo "cuidado: http://$FQDN_JAVA:8080/swagger-ui.html"
