# Variáveis compartilhadas por todos os scripts. Carregado com: source scripts/_comum.sh
RM="rm565339"
RESOURCE_GROUP="rg-petbuddies-devops"
LOCATION="mexicocentral"          # ACI habilitado e com quota nesta assinatura (ver 00_preflight)
ACR_NAME="petbuddies$RM"
ACR_LOCATION="mexicocentral"      # trocado para brazilsouth se ACR Tasks não existir aqui
KEY_VAULT="kv-petbuddies-$RM"
# Sobrescrevível para publicar uma versão ao lado da que está no ar, em vez de
# substituí-la: PETBUDDIES_TAG=v2 ./scripts/05_aci-dotnet.sh
TAG="${PETBUDDIES_TAG:-v1}"

IMG_ORACLE="$RM-oracle-petbuddies"
IMG_JAVA="$RM-api-java"
IMG_NET="$RM-api-net"

ACI_ORACLE="$RM-oracle"
ACI_JAVA="$RM-api-java"
ACI_NET="$RM-api-net"

DNS_ORACLE="petbuddies-oracle-$RM"
DNS_JAVA="petbuddies-java-$RM"
DNS_NET="petbuddies-net-$RM"

# FQDNs previsíveis: o ACI monta sempre <dns-label>.<região>.azurecontainer.io.
# Saber os três antes de criar qualquer container resolve a dependência circular
# — o Java precisa da URL do .NET e o health check do .NET precisa da do Java.
FQDN_ORACLE="$DNS_ORACLE.$LOCATION.azurecontainer.io"
FQDN_JAVA="$DNS_JAVA.$LOCATION.azurecontainer.io"
FQDN_NET="$DNS_NET.$LOCATION.azurecontainer.io"

REPO_JAVA="https://github.com/3BugBuddies/PetBuddies-AI.git#main:."
REPO_NET="https://github.com/3BugBuddies/PetBuddies-API.git#main:PetBuddies-API"

# Raiz do repositório. BASH_SOURCE não existe em zsh, então há fallback e uma
# conferência: sem ela, um source fora do bash resolve a pasta errada em silêncio.
ROOT="${PETBUDDIES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)}"
if [ ! -d "$ROOT/oracle" ]; then
  echo "ERRO: ROOT resolvido como '$ROOT', que não é a raiz do repo." >&2
  echo "Rode com bash, ou exporte PETBUDDIES_ROOT=/caminho/para/petbuddies-devops" >&2
  return 1 2>/dev/null || exit 1
fi
carrega_env() {
  [ -f "$ROOT/.env" ] || { echo "ERRO: .env não encontrado. cp .env.example .env e preencha."; exit 1; }
  set -a; source "$ROOT/.env"; set +a
}
