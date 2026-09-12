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

echo "[1/3] imagem do Oracle..."
docker build --platform linux/amd64 -t "$ACR_NAME.azurecr.io/$IMG_ORACLE:$TAG" "$ROOT/database"

echo "[2/3] imagem do Java (mvn package no host, depois empacota)..."
(cd "$API" && mvn -q package -DskipTests)
cp "$API"/target/*.jar "$API/app.jar"
docker build --platform linux/amd64 -f "$API/Dockerfile.runtime" -t "$ACR_NAME.azurecr.io/$IMG_JAVA:$TAG" "$API"

echo ""
echo "[3/3] push..."
az acr login --name "$ACR_NAME"
for img in "$IMG_ORACLE" "$IMG_JAVA"; do
  docker push "$ACR_NAME.azurecr.io/$img:$TAG"
done

echo ""
az acr repository list -n "$ACR_NAME" -o table
