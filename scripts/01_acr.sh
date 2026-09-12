#!/bin/bash
# 01 — Resource group + Azure Container Registry
set -e
source "$(dirname "$0")/_comum.sh"
mostra_alvo

az group show -n "$RESOURCE_GROUP" &>/dev/null \
  || az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o table

# Basic atende: três imagens, um consumidor. --admin-enabled é obrigatório —
# é com usuário/senha de admin que os ACIs se autenticam no registry.
az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &>/dev/null \
  || az acr create -g "$RESOURCE_GROUP" -n "$ACR_NAME" -l "$ACR_LOCATION" \
       --sku Basic --admin-enabled true -o table

echo "login server: $(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)"
