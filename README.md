# PetBuddies — DevOps Tools & Cloud Computing | FIAP Challenge 2026, Sprint 3

> Solução containerizada completa na Azure: **ACR + ACI**, aplicação e banco em containers,
> todos os recursos criados via Azure CLI.

**Escopo desta entrega:** a Sprint 3 cobre **uma** disciplina, e a escolhida é **Java Advanced** — a
API de cuidado e o banco MySQL, ambos em container, provisionados por Azure CLI.

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

O tutor entra pelo aplicativo; a veterinária usa as mesmas rotas com perfil próprio. A autenticação
é JWT, emitida pela própria API, e o histórico fica num MySQL na nuvem.

## Benefícios para o negócio

- **Cuidado preventivo deixa de depender de memória.** O plano de cuidado nasce do protocolo da clínica
  e calcula as datas de cada evento por animal — vacina, vermífugo e retorno param de ser lembrados
  por acaso.
- **O histórico clínico fica em um lugar só.** Consulta, procedimento, prescrição e atendimento
  ficam no mesmo registro, acessível ao tutor e à clínica.
- **A clínica configura o que oferece sem depender de desenvolvimento.** Protocolos, regras e ofertas
  são dados, não código.
- **Infraestrutura reproduzível.** `scripts/comandos.txt` recria o ambiente inteiro do zero, seção por
  seção, e a última seção o apaga por completo.

---

## Arquitetura

| Recurso Azure | Nome | Conteúdo |
|---|---|---|
| Container Registry | `petbuddiesrm565339` | imagens do MySQL e da API |
| Storage Account | `stpetbuddiesrm565339` | file share `mysql-cuidado-volume`, volume persistente do banco |
| Key Vault | `kv-petbuddies-rm565339` | senhas do banco, segredo JWT, credenciais do registry e chave da storage account |
| Container Instance | `rm565339-mysql` | MySQL 8.0 · 2 vCPU / 4 GB · porta 3306 |
| Container Instance | `rm565339-api-java` | Java 21 · Spring Boot 3.4 · 1 vCPU / 2 GB · porta 8080 |

Grupo de recursos `rg-petbuddies-devops`, região `chilecentral`. A autenticação é JWT, emitido pela
própria API.

![Arquitetura da solução na Azure](docs/arquitetura.png)

O **Key Vault** guarda os oito segredos (usuário e senha do banco, segredo JWT, chave da IA, chave da
storage account e as credenciais do registry). Nenhum deles aparece em script, log ou variável
visível: os scripts os leem do cofre no momento do `az container create` e os injetam como
`--secure-environment-variables`.

**Um schema, criado pela própria aplicação.** O usuário do banco nasce com o container, pelas
variáveis que a imagem do MySQL consome; as tabelas e a carga vêm depois, pelo Flyway, na subida
da API. Não há passo manual de schema entre um e outro.

---

## How To — execução completa

### Pré-requisitos

- Azure CLI (`az`), Docker, Git, JDK 21 + Maven
- `az login` já executado

### 1. Clonar e configurar

```bash
git clone https://github.com/3BugBuddies/petbuddies-devops-sprint3.git
cd petbuddies-devops-sprint3
cp .env.example .env
nano .env          # preencher as senhas (só alfanuméricas, começando por letra)
```

### 2. Carregar as variáveis

Cola o conteúdo de `scripts/variaveis-ambiente.txt` no terminal (preenche os valores em branco antes,
se ainda não tiver escolhido nomes de recurso). Fica valendo enquanto essa aba do terminal continuar
aberta.

### 3. Teste local (opcional)

Antes de subir à nuvem, o mesmo desenho roda na máquina com Docker Compose — o banco e a API, na
mesma rede:

```bash
docker compose up -d --build
docker compose ps                 # aguardar o MySQL ficar healthy
curl http://localhost:8080/swagger-ui.html
docker compose down -v            # derruba e APAGA o volume
```

### 4. Conferir o ambiente

Cola a seção `00 — PREFLIGHT` de `scripts/comandos.txt`.

Confere sessão, papel na subscription e providers registrados. **Nenhum recurso é criado aqui.**

### 5. Criar o registry

Cola a seção `01 — RESOURCE GROUP + CONTAINER REGISTRY + STORAGE ACCOUNT`.

Cria o grupo de recursos `rg-petbuddies-devops`, o ACR `petbuddiesrm565339` (SKU Basic, admin
habilitado — é com a credencial de admin que os ACIs se autenticam no registry) e a storage account
`stpetbuddiesrm565339` com o file share `mysql-cuidado-volume` — o volume persistente do MySQL.

### 6. Construir e publicar as imagens

Cola a seção `02 — IMAGENS`.

Importa o MySQL do Docker Hub pro ACR (`acr import`), constrói a imagem da API em `linux/amd64` e
publica as duas no registry.

### 7. Cofre de segredos

Cola a seção `03 — KEY VAULT E SEGREDOS`. Cria o Key Vault, dá a você a role `Key Vault Administrator`
nele e grava os 8 segredos (lidos do `.env`).

### 8. Subir os containers

Cola as seções `04 — ACI DO MYSQL` e `05 — ACI DA API JAVA`, nessa ordem — a `04` espera o banco abrir
antes de seguir.

O schema é criado na subida da aplicação, pelo **Flyway**: as tabelas mais o seed de demonstração
(`V2__seed_demonstracao.sql`), que já cobre a carga inicial das duas tabelas do CRUD.

### 9. Encerrar

Cola a seção `99 — DESTRUIR TUDO`.

---

## Endereços

| Serviço | URL |
|---|---|
| API de cuidado (Swagger) | http://petbuddies-java-rm565339.chilecentral.azurecontainer.io:8080/swagger-ui.html |
| MySQL | `petbuddies-mysql-rm565339.chilecentral.azurecontainer.io:3306/petbuddies_cuidado` |

Usuários de demonstração: `maria@email.com` (tutor) e `ana@clinica.com` (veterinária), senha
`petbuddies123`.



---

## CRUD sobre duas tabelas relacionadas

O CRUD demonstrado é **`T_PB_RESPONSAVEL` → `T_PB_ANIMAL`**, um relacionamento **1:N**:

| Tabela | Lado | Chave |
|---|---|---|
| `T_PB_RESPONSAVEL` | **1** — o tutor | PK `ID_RESPONSAVEL` |
| `T_PB_ANIMAL` | **N** — os animais dele | FK `ID_RESPONSAVEL` → `T_PB_RESPONSAVEL` |

São tabelas do núcleo do produto: sem tutor e sem animal não existe cuidado de pet.

Inclusão, alteração e exclusão em animal e responsável são restritas ao perfil **veterinária**; o
tutor só consulta. Por isso o CRUD abaixo autentica com `ana@clinica.com`. No Swagger, o token vai
em **Authorize** e fica guardado ao recarregar a página.

```bash
BASE=http://petbuddies-java-rm565339.chilecentral.azurecontainer.io:8080

TOKEN=$(curl -s -X POST $BASE/api/auth/login -H 'Content-Type: application/json' \
  -d '{"login":"ana@clinica.com","senha":"petbuddies123"}' | jq -r .token)

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

### Acompanhar e inspecionar os containers

```bash
# saída da aplicação
az container logs --resource-group rg-petbuddies-devops --name rm565339-api-java
az container logs --resource-group rg-petbuddies-devops --name rm565339-api-java --follow

# abrir um shell dentro do container
az container exec --resource-group rg-petbuddies-devops --name rm565339-api-java --exec-command "/bin/sh"

# estado de todos os containers do grupo
az container list --resource-group rg-petbuddies-devops --output table
```

### Evidência de persistência — SELECT direto no banco

Há dois caminhos, e os dois valem como evidência.

**a) Pelo próprio container**, sem instalar nada na máquina — o `mysql` client já vive na imagem:

```bash
az container exec --resource-group rg-petbuddies-devops --name rm565339-mysql \
  --exec-command "/bin/bash"

# já dentro do container:
mysql -u PETBUDDIES_CUIDADO -p petbuddies_cuidado
```

**b) De um cliente externo** (MySQL Workbench, DataGrip), conectando em
`petbuddies-mysql-rm565339.chilecentral.azurecontainer.io:3306`, database `petbuddies_cuidado`, com
o usuário `PETBUDDIES_CUIDADO` e execute, após cada operação:

```sql
SELECT a.ID_ANIMAL, a.NM_NOME_ANIMAL, a.ES_ESPECIE, a.NR_PESO,
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
- **Containers sem privilégio administrativo.** As imagens criam um usuário próprio e declaram
  `USER` antes do entrypoint — nenhuma roda como root.
- `*.log` e `.env` estão no `.gitignore`.

---

## Notas de implementação

**`az acr build` não é usado.** ACR Tasks é bloqueado nesta assinatura (`TasksOperationsNotAllowed`,
restrição do Azure for Students). O build é local com `docker build` + `docker push`.

**`--platform linux/amd64` é obrigatório.** O ACI executa apenas amd64. Em um Mac ARM, sem a flag, a
imagem sobe no ACI e morre em laço.

**A aplicação é compilada no host, não dentro da imagem.** O jar é bytecode e não depende de
arquitetura, então compilar nativo em ARM e empacotar sobre uma base amd64 dá a mesma imagem sem
emular a JVM do Maven, que é o estágio caro. As imagens saem em menos de dois minutos.

**Os FQDNs são previsíveis.** O ACI monta sempre `<dns-label>.<região>.azurecontainer.io`, então os
endereços são conhecidos antes de criar qualquer container — o que dispensa capturar o FQDN de um
serviço para configurar o outro.

## Estrutura do repositório

```
.
├── README.md                       este documento — o roteiro de deploy
├── script_bd.sql                   DDL das tabelas
├── .env.example                    modelo das variáveis; o .env não vai para o Git
├── docker-compose.yml              execução local
├── docs/arquitetura.png            desenho da solução na Azure
├── petbuddies-ai/                  código-fonte da API
│   ├── Dockerfile                  multi-estágio, compila com Maven na imagem
│   ├── Dockerfile.runtime          empacota o jar já construído (usado pelo 02)
│   ├── pom.xml
│   └── src/
└── scripts/
    ├── comandos.txt                todos os comandos do deploy, por seção (00 a 99)
    └── variaveis-ambiente.txt      modelo das variáveis de nome de recurso
```

**Volume no banco: Storage Account, montada direto no MySQL.** Um Oracle rodando sobre Azure Files
como volume do ACI não funciona — testado em 2026-09-12, o container entra em `CrashLoopBackOff`,
porque o Azure Files entrega um compartilhamento SMB e o Oracle precisa de semântica POSIX para os
datafiles. Por isso o banco migrou para **MySQL**: a mesma storage account (`stpetbuddiesrm565339`,
file share `mysql-cuidado-volume`) é montada em `/var/lib/mysql`. Testado em 2026-09-13: o container
abre de primeira, sem crash loop, e a persistência foi confirmada apagando e recriando o container —
os dados do seed voltaram com o mesmo `createdAt` de antes, ou seja, sobreviveram fora do ciclo de
vida do container.
