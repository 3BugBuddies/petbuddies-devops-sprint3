#!/bin/bash
# 00 — Conferências antes de criar qualquer recurso. Só leitura.
#
# Existe por causa de uma falha real da entrega anterior: um "az account set"
# para uma subscription que o login não enxergava fez TODO comando az responder
# MissingSubscription, e o erro que apareceu na tela foi
# "incorrect usage: [Required] --value VALUE" — três passos adiante da causa.
source "$(dirname "$0")/_comum.sh"
falhas=0
ok()   { printf "  ok    %s\n" "$1"; }
erro() { printf "  ERRO  %s\n" "$1"; falhas=$((falhas+1)); }

echo "1. Sessão"
CONTA=$(az account show -o json 2>/dev/null) || { erro "não autenticado — rode: az login"; exit 1; }
SUB=$(echo "$CONTA" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
EST=$(echo "$CONTA" | python3 -c "import sys,json;print(json.load(sys.stdin)['state'])")
echo "$CONTA" | python3 -c "import sys,json;d=json.load(sys.stdin);print('  subscription:',d['name']);print('  tenant:',d['tenantId']);print('  usuário:',d['user']['name'])"
[ "$EST" = "Enabled" ] && ok "subscription habilitada" || erro "subscription em estado '$EST'"

echo "2. Identidade no Graph"
OBJ=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
[ -n "$OBJ" ] && ok "object id resolvido (necessário para o RBAC do Key Vault)" \
              || erro "Graph não resolveu o usuário — o role assignment do 03 vai falhar"

echo "3. Permissão"
az role assignment list --assignee-object-id "$OBJ" --scope "/subscriptions/$SUB" --include-inherited \
  --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='Contributor'].roleDefinitionName" -o tsv 2>/dev/null | head -1 \
  | grep -q . && ok "Owner ou Contributor na subscription" || erro "sem papel suficiente para criar recursos"

echo "4. Providers"
for p in Microsoft.ContainerRegistry Microsoft.ContainerInstance Microsoft.KeyVault Microsoft.Storage; do
  e=$(az provider show -n $p --query registrationState -o tsv 2>/dev/null)
  [ "$e" = "Registered" ] && ok "$p" || erro "$p está '$e' — rode: az provider register --namespace $p"
done

echo "5. Quota de ACI em $LOCATION (precisa de 4 cores livres)"
CORES=$(az rest --method get --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.ContainerInstance/locations/$LOCATION/usages?api-version=2021-09-01" \
  --query "value[?name.value=='StandardCores'].[currentValue,limit]" -o tsv 2>/dev/null)
USADO=$(echo "$CORES" | cut -f1); LIMITE=$(echo "$CORES" | cut -f2)
# Desconta o que já é nosso: numa reexecução com o ambiente de pé, esses cores
# voltam quando os containers são recriados, e contá-los como ocupados faria o
# preflight reprovar um ambiente saudável.
NOSSOS=$(az container list -g "$RESOURCE_GROUP" --query "sum([].containers[0].resources.requests.cpu)" -o tsv 2>/dev/null)
NOSSOS=${NOSSOS%.*}; NOSSOS=${NOSSOS:-0}
LIVRE=$(( ${LIMITE:-0} - ${USADO:-0} + NOSSOS ))
[ "$NOSSOS" -gt 0 ] && echo "  nota: $NOSSOS cores já são deste projeto e foram descontados"
[ "$LIVRE" -ge 4 ] && ok "$LIVRE de $LIMITE cores livres" || erro "só $LIVRE cores livres — libere ou reduza o desenho"

echo "6. Colisão de nome por soft-delete"
az keyvault list-deleted --query "[?name=='$KEY_VAULT'].name" -o tsv 2>/dev/null | grep -q . \
  && erro "existe um Key Vault '$KEY_VAULT' apagado; purgue-o antes: az keyvault purge --name $KEY_VAULT" \
  || ok "nome '$KEY_VAULT' livre"

echo "7. Segredos"
[ -f "$ROOT/.env" ] && ok ".env presente" || erro ".env ausente — cp .env.example .env e preencha"

echo ""
[ "$falhas" = 0 ] && echo "Tudo pronto. Próximo: ./scripts/01_acr.sh" || { echo "$falhas problema(s) — resolva antes de seguir."; exit 1; }
