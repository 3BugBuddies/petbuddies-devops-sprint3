#!/bin/bash
# 99 — Remove TUDO. O grupo de recursos é o limite do blast radius.
set -e
source "$(dirname "$0")/_comum.sh"
mostra_alvo
echo "Isto apaga o grupo '$RESOURCE_GROUP' e todos os recursos dentro dele."
read -p "Digite o nome do grupo para confirmar: " c
[ "$c" = "$RESOURCE_GROUP" ] || { echo "abortado"; exit 1; }
az group delete -n "$RESOURCE_GROUP" --yes --no-wait
echo "remoção disparada. Acompanhe com: az group list -o table"
