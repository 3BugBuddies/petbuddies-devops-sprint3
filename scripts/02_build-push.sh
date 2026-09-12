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
# Java e .NET são construídos com as ferramentas do host (Maven e dotnet) porque
# o artefato das duas é portável: jar é bytecode, publish do .NET é IL. Emular o
# estágio de compilação em amd64 custaria dezenas de minutos e nada em troca.
set -e
source "$(dirname "$0")/_comum.sh"

BUILD_DIR="$ROOT/.build"
mkdir -p "$BUILD_DIR"

clona() {  # clona() <url> <destino>
  if [ -d "$BUILD_DIR/$2/.git" ]; then
    echo "  $2: já clonado, atualizando..."; git -C "$BUILD_DIR/$2" pull --ff-only -q
  else
    echo "  $2: clonando..."; git clone -q --depth 1 "$1" "$BUILD_DIR/$2"
  fi
}

# A entrega cobre Java Advanced: as imagens avaliadas são o Oracle e a API de
# cuidado. A do back-office sai só com COM_BACKOFFICE=1, para a banca.
echo "[1/3] código-fonte..."
clona https://github.com/3BugBuddies/PetBuddies-AI.git petbuddies-ai
if [ -n "$COM_BACKOFFICE" ]; then
  clona https://github.com/3BugBuddies/PetBuddies-API.git PetBuddies-API
fi

echo "[2/3] imagem do Oracle..."
docker build --platform linux/amd64 -t "$ACR_NAME.azurecr.io/$IMG_ORACLE:$TAG" "$ROOT/oracle"

echo "[3/3] imagem do Java (mvn package no host, depois empacota)..."
(cd "$BUILD_DIR/petbuddies-ai" && mvn -q package -DskipTests)
cp "$BUILD_DIR"/petbuddies-ai/target/*.jar "$ROOT/runtime/java/app.jar"
docker build --platform linux/amd64 -t "$ACR_NAME.azurecr.io/$IMG_JAVA:$TAG" "$ROOT/runtime/java"

if [ -n "$COM_BACKOFFICE" ]; then
  echo "[extra] imagem do .NET (fora da entrega de DevOps)..."
  rm -rf "$ROOT/runtime/net/publish"
  dotnet publish "$BUILD_DIR/PetBuddies-API/PetBuddies-API/PetBuddies-API.csproj" \
    -c Release -o "$ROOT/runtime/net/publish" -p:UseAppHost=false -v q --nologo
  docker build --platform linux/amd64 -t "$ACR_NAME.azurecr.io/$IMG_NET:$TAG" "$ROOT/runtime/net"
fi

echo ""
echo "push..."
az acr login --name "$ACR_NAME"
for img in "$IMG_ORACLE" "$IMG_JAVA" ${COM_BACKOFFICE:+"$IMG_NET"}; do
  docker push "$ACR_NAME.azurecr.io/$img:$TAG"
done

echo ""
az acr repository list -n "$ACR_NAME" -o table
