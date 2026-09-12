#!/bin/bash
# 05 — ACI da API de cuidado (Java)
#
# O endereço do Oracle vem do FQDN previsto, não de uma consulta: o ACI monta
# sempre <dns-label>.<região>.azurecontainer.io.
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
      ORACLE_URL="jdbc:oracle:thin:@$FQDN_ORACLE:1521/XEPDB1" \
      ORACLE_USER="$(segredo oracle-user-cuidado)" \
  --secure-environment-variables \
      ORACLE_PASSWORD="$(segredo oracle-password-cuidado)" \
      PETBUDDIES_JWT_SECRET="$(segredo jwt-secret)" \
      GEMINI_API_KEY="$(segredo gemini-api-key)" \
  --restart-policy Always -o none

echo "cuidado: http://$FQDN_JAVA:8080/swagger-ui.html"
