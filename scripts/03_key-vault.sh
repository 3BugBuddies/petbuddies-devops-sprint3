#!/bin/bash
# 03 — Key Vault e segredos
#
# Os valores vêm do .env (fora do Git) e nunca são impressos: as conferências
# listam só nome de segredo. Diferenças em relação ao script da aula, ambas
# necessárias nesta assinatura:
#
#   1. O role assignment usa --assignee-object-id, não o UPN. Com UPN o comando
#      falha em conta cujo Graph não resolve por nome, e com "set -e" nenhum
#      segredo chega a ser gravado.
#   2. O "sleep 15" da aula virou laço de tentativa. A propagação do RBAC leva
#      de 1 a 5 minutos e 15s falha na maioria das vezes.
set -e
source "$(dirname "$0")/_comum.sh"
carrega_env

SUB=$(az account show --query id -o tsv)
OBJ=$(az ad signed-in-user show --query id -o tsv)

az keyvault show -n "$KEY_VAULT" -g "$RESOURCE_GROUP" &>/dev/null \
  || az keyvault create -n "$KEY_VAULT" -g "$RESOURCE_GROUP" -l "$LOCATION" \
       --enable-rbac-authorization true -o none

az role assignment create \
  --assignee-object-id "$OBJ" --assignee-principal-type User \
  --role "Key Vault Administrator" \
  --scope "/subscriptions/$SUB/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT" \
  -o none 2>/dev/null || echo "  (atribuição já existia)"

ACR_USER=$(az acr credential show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query username -o tsv)
ACR_PASS=$(az acr credential show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query 'passwords[0].value' -o tsv)

# Recusa valor vazio em vez de repassá-lo ao az.
#
# Sem esta conferência, um "az" embutido que falha (o caso clássico é o CLI
# apontado para uma subscription inválida, que responde MissingSubscription em
# tudo) devolve string vazia, e o erro que aparece é
# "incorrect usage: [Required] --value VALUE" — que não diz nada sobre a causa
# real e manda procurar no lugar errado.
guarda() {
  [ -n "$2" ] || { echo "ERRO: o valor de '$1' veio vazio. A origem falhou — confira 'az account show' e rode 00_preflight.sh." >&2; exit 1; }
  az keyvault secret set --vault-name "$KEY_VAULT" --name "$1" --value "$2" -o none
}

# A primeira gravação serve de sonda da propagação do RBAC, que leva de 1 a 5
# minutos. Ela é um segredo de verdade, não um descartável: apagar um segredo o
# deixa em soft-delete, e recriá-lo com o mesmo nome falha na execução seguinte
# — a sonda quebrava exatamente quando o ambiente era recriado.
echo "aguardando propagação do RBAC..."
for i in $(seq 1 30); do
  if az keyvault secret set --vault-name "$KEY_VAULT" --name oracle-sys-password \
       --value "$ORACLE_SYS_PASSWORD" -o none 2>/dev/null; then
    echo "  liberado na tentativa $i"; break
  fi
  [ "$i" = 30 ] && { echo "ERRO: RBAC não propagou em 5 min."; exit 1; }
  sleep 10
done
guarda oracle-user-cuidado        "$ORACLE_USER_CUIDADO"
guarda oracle-password-cuidado    "$ORACLE_PASSWORD_CUIDADO"
guarda jwt-secret                 "$PETBUDDIES_JWT_SECRET"
guarda gemini-api-key             "$GEMINI_API_KEY"
guarda acr-username               "$ACR_USER"
guarda acr-password               "$ACR_PASS"

echo ""
echo "segredos no cofre (nomes apenas):"
az keyvault secret list --vault-name "$KEY_VAULT" --query "[].name" -o tsv | sort
