# PetBuddies — DevOps Tools & Cloud Computing | FIAP Challenge 2026, Sprint 3

> Solução containerizada completa na Azure: **ACR + ACI**, aplicação e banco em containers,
> todos os recursos criados via Azure CLI.

## Equipe

| Nome | RM |
|------|----|
| Felipe Yuiti Ishii | 565339 |
| Gabriel Nogueira Peixoto | 563925 |
| Giovanna Neri dos Santos | 566154 |
| Mariana Inoue | 565834 |

---

## Descrição da solução

**PetBuddies** é uma plataforma de cuidado veterinário contínuo. O tutor mantém o histórico do animal,
acompanha o plano de cuidado preventivo e recebe prescrições; a clínica registra consultas,
procedimentos e atendimentos, e configura o catálogo de protocolos que ela oferece.

A solução roda em dois serviços e um banco:

| Componente | Papel | Stack |
|---|---|---|
| **API de cuidado** | API única do produto: tutores, animais, consultas, planos de cuidado, autenticação | Java 21 · Spring Boot 3.4 |
| **Back-office** | Administração da clínica: protocolos, regras, ofertas e pontuação | .NET 8 · ASP.NET Core · EF Core |
| **Banco** | Dois schemas isolados, um por serviço | Oracle XE 21c |

A autenticação é JWT: a API de cuidado emite o token, o back-office o valida com o mesmo segredo.

## Benefícios para o negócio

- **Cuidado preventivo deixa de depender de memória.** O plano de cuidado nasce do protocolo da clínica
  e calcula as datas de cada evento por animal — vacina, vermífugo e retorno param de ser lembrados
  por acaso.
- **O histórico clínico fica em um lugar só.** Consulta, procedimento, prescrição e atendimento
  ficam no mesmo registro, acessível ao tutor e à clínica.
- **A clínica configura o que oferece sem depender de desenvolvimento.** Protocolos, regras e ofertas
  são dados, não código.
- **Infraestrutura reproduzível.** Sete scripts recriam o ambiente inteiro do zero, e um script o
  apaga por completo.

---

## Arquitetura

```
                  ┌──────────────────────────── Azure ────────────────────────────┐
  Tutor / Vet     │                                                               │
       │          │   ┌─────────────┐        ┌──────────────────────────────┐     │
       │  HTTPS   │   │     ACR     │ imagem │  ACI · API de cuidado (Java) │     │
       └──────────┼──▶│  petbuddies │───────▶│        porta 8080            │     │
                  │   │   rm565339  │        └──────────────┬───────────────┘     │
                  │   └─────────────┘                       │ JDBC                │
  Desenvolvedor   │          │ imagem                       ▼                     │
       │  az cli  │          │              ┌──────────────────────────────┐      │
       └──────────┼──────────┤              │   ACI · Oracle XE  :1521     │      │
                  │          │              │  PETBUDDIES_CUIDADO (16 tb)  │      │
                  │          │              │  PETBUDDIES_BACKOFFICE (4tb) │      │
                  │          │              └──────────────▲───────────────┘      │
                  │          │ imagem                      │ Oracle.EF            │
                  │          ▼              ┌──────────────┴───────────────┐      │
                  │   ┌─────────────┐  HTTP │ ACI · Back-office (.NET)     │      │
                  │   │  Key Vault  │◀──────┤        porta 8080            │      │
                  │   │  9 segredos │ creds └──────────────────────────────┘      │
                  │   └─────────────┘                                             │
                  └───────────────────────────────────────────────────────────────┘
```

O **Key Vault** guarda os nove segredos (senhas do Oracle, segredo JWT, chave da IA e credenciais do
registry). Nenhum deles aparece em script, log ou variável visível: os scripts os leem do cofre no
momento do `az container create` e os injetam como `--secure-environment-variables`.

**Um Oracle, dois schemas.** A assinatura tem limite de 6 Standard Cores na região; duas instâncias
não deixariam folga para recriar um app. Os schemas são isolados: nenhum objeto de um serviço existe
no schema do outro.

---

## How To — execução completa

### Pré-requisitos

- Azure CLI (`az`), Docker, Git, JDK 21 + Maven, SDK do .NET 8
- `az login` já executado

### 1. Clonar e configurar

```bash
git clone https://github.com/GNogueirovski/petbuddies-devops.git
cd petbuddies-devops
cp .env.example .env
nano .env          # preencher as senhas (só alfanuméricas, começando por letra)
```

### 2. Conferir o ambiente

```bash
./scripts/00_preflight.sh
```

Confere sessão, identidade no Graph, papel na subscription, providers, quota de ACI e colisão de nome
de Key Vault. **Nenhum recurso é criado aqui.**

### 3. Criar o registry

```bash
./scripts/01_acr.sh
```

Cria o grupo de recursos `rg-petbuddies-devops` e o ACR `petbuddiesrm565339` (SKU Basic, admin
habilitado — é com a credencial de admin que os ACIs se autenticam no registry).

### 4. Construir e publicar as três imagens

```bash
./scripts/02_build-push.sh
```

Clona as duas APIs, constrói as três imagens em `linux/amd64` e as envia ao ACR:

```bash
docker build --platform linux/amd64 -t petbuddiesrm565339.azurecr.io/rm565339-oracle-petbuddies:v1 oracle/
docker build --platform linux/amd64 -t petbuddiesrm565339.azurecr.io/rm565339-api-java:v1 runtime/java/
docker build --platform linux/amd64 -t petbuddiesrm565339.azurecr.io/rm565339-api-net:v1 runtime/net/
az acr login --name petbuddiesrm565339
docker push petbuddiesrm565339.azurecr.io/rm565339-oracle-petbuddies:v1
docker push petbuddiesrm565339.azurecr.io/rm565339-api-java:v1
docker push petbuddiesrm565339.azurecr.io/rm565339-api-net:v1
```

### 5. Cofre de segredos

```bash
./scripts/03_key-vault.sh
```

### 6. Subir os containers

```bash
./scripts/04_aci-oracle.sh     # espera o banco abrir antes de retornar
./scripts/05_aci-dotnet.sh
./scripts/06_aci-java.sh
```

O schema de cada serviço é criado na subida da própria aplicação: **Flyway** no Java (16 tabelas mais
o seed de demonstração), **migrations do EF Core** no .NET (4 tabelas).

### 7. Encerrar

```bash
./scripts/99_destroy.sh
```

---

## Endereços

| Serviço | URL |
|---|---|
| API de cuidado (Swagger) | http://petbuddies-java-rm565339.mexicocentral.azurecontainer.io:8080/swagger-ui.html |
| Back-office (API) | http://petbuddies-net-rm565339.mexicocentral.azurecontainer.io:8080/api/protocolo |
| Health do back-office | http://petbuddies-net-rm565339.mexicocentral.azurecontainer.io:8080/health/live |
| Oracle | `petbuddies-oracle-rm565339.mexicocentral.azurecontainer.io:1521/XEPDB1` |

Usuários de demonstração: `maria@email.com` (tutor) e `ana@clinica.com` (veterinária), senha
`petbuddies123`.

O Swagger do back-office só é publicado em ambiente de desenvolvimento (`Program.cs:261`), e o
container sobe como `Production` — as rotas dele são consultadas direto:
`/api/protocolo`, `/api/regra-protocolo`, `/api/oferta` e `/api/regra-pontuacao`.

---

## CRUD sobre duas tabelas relacionadas

O CRUD demonstrado é **`T_PB_RESPONSAVEL` → `T_PB_ANIMAL`**: o tutor e seus animais, ligados por
`ID_RESPONSAVEL`. São tabelas do núcleo do produto — sem elas não existe cuidado de pet.

```bash
BASE=http://petbuddies-java-rm565339.mexicocentral.azurecontainer.io:8080

TOKEN=$(curl -s -X POST $BASE/api/auth/login -H 'Content-Type: application/json' \
  -d '{"login":"maria@email.com","senha":"petbuddies123"}' | jq -r .token)

# CREATE
curl -X POST $BASE/api/animal -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"nome":"Filó","especie":"CACHORRO","porte":"MEDIO","sexo":"FEMEA",
       "dataNascimento":"2022-03-15","responsavelId":1}'

# READ
curl $BASE/api/animal/1      -H "Authorization: Bearer $TOKEN"
curl $BASE/api/responsavel/1 -H "Authorization: Bearer $TOKEN"

# UPDATE
curl -X PUT $BASE/api/animal/1 -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"nome":"Filó","especie":"CACHORRO","porte":"MEDIO","sexo":"FEMEA",
       "dataNascimento":"2022-03-15","peso":12.4,"responsavelId":1}'

# DELETE
curl -X DELETE $BASE/api/animal/1 -H "Authorization: Bearer $TOKEN"
```

### Evidência de persistência — SELECT direto no banco

Conecte em `petbuddies-oracle-rm565339.mexicocentral.azurecontainer.io:1521/XEPDB1` com o usuário
`PETBUDDIES_CUIDADO` e execute, após cada operação:

```sql
SELECT a.ID_ANIMAL, a.NM_NOME_ANIMAL, a.TP_ESPECIE, a.PS_PESO,
       r.NM_NOME_RESPONSAVEL, r.EM_EMAIL
  FROM T_PB_ANIMAL a
  JOIN T_PB_RESPONSAVEL r ON r.ID_RESPONSAVEL = a.ID_RESPONSAVEL
 ORDER BY a.ID_ANIMAL;
```

O DDL completo das tabelas está em [`script_bd.sql`](script_bd.sql).

---

## Segurança

- **Nenhum dado sensível no código-fonte.** Senhas, segredo JWT e chave de IA vivem no `.env`
  (ignorado pelo Git) e no **Key Vault**. Os scripts os leem do cofre e os passam ao ACI por
  `--secure-environment-variables`, que não são devolvidas por `az container show`.
- **Containers sem privilégio administrativo.** As três imagens criam um usuário próprio e declaram
  `USER` antes do entrypoint — nenhuma roda como root.
- `*.log` e `.env` estão no `.gitignore`.

---

## Notas de implementação

**`az acr build` não é usado.** ACR Tasks é bloqueado nesta assinatura (`TasksOperationsNotAllowed`,
restrição do Azure for Students). O build é local com `docker build` + `docker push`.

**`--platform linux/amd64` é obrigatório.** O ACI executa apenas amd64 e a imagem `gvenzl/oracle-xe`
só publica amd64. Em um Mac ARM, sem a flag, a imagem sobe no ACI e morre em laço.

**Java e .NET são compilados no host, não dentro da imagem.** O artefato dos dois é portável — jar é
bytecode, o publish do .NET é IL — então compilar nativo e empacotar sobre uma base amd64 dá a mesma
imagem sem emular o compilador. As três imagens saem em menos de dois minutos.

**Os FQDNs são previsíveis.** O ACI monta sempre `<dns-label>.<região>.azurecontainer.io`, então os
três endereços são conhecidos antes de criar qualquer container. É o que resolve a dependência
circular entre os dois serviços, que apontam um para o outro.

**Sem volume no banco.** O Oracle não suporta seus datafiles sobre SMB, que é o que o Azure Files
oferece ao ACI, e o primeiro boot sobre ele fica 2 a 3× mais lento. Como o schema de cada serviço
nasce na subida da própria aplicação — Flyway no Java, migrations do EF no .NET — um restart do
container reconstrói o banco em vez de perdê-lo. A entrega desta Sprint não exige volume nomeado.
