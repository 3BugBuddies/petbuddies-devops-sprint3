# Variáveis compartilhadas por todos os scripts. Carregado com: source scripts/_comum.sh
RM="rm565339"
# Grupo e região sobrescrevíveis para validar mudança de script sem encostar no
# ambiente que está no ar:
#   PETBUDDIES_RG=rg-teste PETBUDDIES_LOCATION=brazilsouth ./scripts/01_acr.sh
RESOURCE_GROUP="${PETBUDDIES_RG:-rg-petbuddies-devops}"
LOCATION="${PETBUDDIES_LOCATION:-chilecentral}"   # ACI com quota nesta assinatura (ver 00_preflight)
ACR_NAME="${PETBUDDIES_ACR:-petbuddies$RM}"
ACR_LOCATION="$LOCATION"
KEY_VAULT="${PETBUDDIES_KV:-kv-petbuddies-$RM}"
# Sobrescrevível para publicar uma versão ao lado da que está no ar, em vez de
# substituí-la: PETBUDDIES_TAG=v2 ./scripts/05_aci-java.sh
TAG="${PETBUDDIES_TAG:-v1}"

IMG_ORACLE="$RM-oracle-petbuddies"
IMG_ORACLE_ORIGEM="docker.io/gvenzl/oracle-xe:21-slim"
IMG_JAVA="$RM-api-java"

ACI_ORACLE="$RM-oracle${PETBUDDIES_SUFIXO:-}"
ACI_JAVA="$RM-api-java${PETBUDDIES_SUFIXO:-}"

# O rótulo de DNS é único por região, então uma execução de teste paralela à
# que está no ar precisa de sufixo próprio: PETBUDDIES_SUFIXO=-teste
SUFIXO="${PETBUDDIES_SUFIXO:-}"
DNS_ORACLE="petbuddies-oracle-$RM$SUFIXO"
DNS_JAVA="petbuddies-java-$RM$SUFIXO"

# FQDNs previsíveis: o ACI monta sempre <dns-label>.<região>.azurecontainer.io,
# então o endereço de cada container é conhecido antes de ele existir.
FQDN_ORACLE="$DNS_ORACLE.$LOCATION.azurecontainer.io"
FQDN_JAVA="$DNS_JAVA.$LOCATION.azurecontainer.io"

REPO_JAVA="https://github.com/3BugBuddies/PetBuddies-AI.git#main:."
REPO_NET="https://github.com/3BugBuddies/PetBuddies-API.git#main:PetBuddies-API"

# Raiz do repositório. BASH_SOURCE não existe em zsh, então há fallback e uma
# conferência: sem ela, um source fora do bash resolve a pasta errada em silêncio.
ROOT="${PETBUDDIES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)}"
if [ ! -d "$ROOT/scripts" ]; then
  echo "ERRO: ROOT resolvido como '$ROOT', que não é a raiz do repo." >&2
  echo "Rode com bash, ou exporte PETBUDDIES_ROOT=/caminho/para/petbuddies-devops" >&2
  return 1 2>/dev/null || exit 1
fi
# Diz em voz alta para onde a execução está apontando. Sem isto, um
# PETBUDDIES_* esquecido no shell redireciona tudo em silêncio — e o erro só
# aparece quando o recurso errado já foi criado ou apagado.
mostra_alvo() {
  local sobrescritas=""
  for v in PETBUDDIES_RG PETBUDDIES_LOCATION PETBUDDIES_ACR PETBUDDIES_KV PETBUDDIES_SUFIXO PETBUDDIES_TAG; do
    [ -n "${!v}" ] && sobrescritas="$sobrescritas $v"
  done
  echo "alvo: grupo $RESOURCE_GROUP · região $LOCATION · registry $ACR_NAME · cofre $KEY_VAULT · tag $TAG"
  if [ -n "$sobrescritas" ]; then
    echo "ATENÇÃO: execução redirecionada por variável de ambiente —$sobrescritas" >&2
    echo "         se isto não era intencional, abra um terminal novo." >&2
  fi
}

carrega_env() {
  [ -f "$ROOT/.env" ] || { echo "ERRO: .env não encontrado. cp .env.example .env e preencha."; exit 1; }
  set -a; source "$ROOT/.env"; set +a
}
