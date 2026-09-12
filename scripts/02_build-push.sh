#!/bin/bash
# 02 — Build das três imagens e push para o ACR
#
# POR QUE NÃO "az acr build": ACR Tasks é bloqueado nesta assinatura
# (TasksOperationsNotAllowed — restrição do Azure for Students). O build é local,
# que é também o que a rubrica §8.4 pede ("docker build, docker push").
#
# POR QUE --platform linux/amd64: o ACI só executa amd64, e a imagem
# gvenzl/oracle-xe só publica amd64. Sem a flag, um Mac ARM gera imagem que
# sobe no ACI e morre em loop.
#
# O jar é construído com o Maven do host e a imagem apenas o empacota
# (Dockerfile.runtime). Bytecode não depende de arquitetura, então o resultado é
# idêntico ao do Dockerfile multi-estágio da API — sem emular a JVM do Maven em
# amd64, que num Mac ARM custa dezenas de minutos.
set -e
source "$(dirname "$0")/_comum.sh"

API="$ROOT/petbuddies-ai"

# O Oracle não é customizado: o schema nasce do Flyway, na subida da API. Então
# a imagem vem pronta do Docker Hub para o nosso registry por "az acr import" —
# cópia servidor-a-servidor, sem baixar 2 GB na máquina e sem um Dockerfile de
# uma linha só para reetiquetar.
# O laço existe porque um registry recém-criado leva alguns segundos para ficar
# visível ao import, que responde ResourceNotFound nesse intervalo.
echo "[1/3] imagem do Oracle (import para o registry)..."
for i in $(seq 1 12); do
  if az acr import --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" \
       --source "$IMG_ORACLE_ORIGEM" --image "$IMG_ORACLE:$TAG" --force 2>/dev/null; then
    break
  fi
  [ "$i" = 12 ] && { echo "ERRO: o import falhou depois de 1 min."; exit 1; }
  sleep 5
done

echo "[2/3] imagem do Java (mvn package no host, depois empacota)..."
(cd "$API" && mvn -q package -DskipTests)
cp "$API"/target/*.jar "$API/app.jar"
docker build --platform linux/amd64 -f "$API/Dockerfile.runtime" -t "$ACR_NAME.azurecr.io/$IMG_JAVA:$TAG" "$API"

echo ""
echo "[3/3] push da imagem da API..."
az acr login --name "$ACR_NAME"
docker push "$ACR_NAME.azurecr.io/$IMG_JAVA:$TAG"

echo ""
az acr repository list -n "$ACR_NAME" -o table
