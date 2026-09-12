# Helpers compartilhados pelos scripts de ACI.
segredo() { az keyvault secret show --vault-name "$KEY_VAULT" --name "$1" --query value -o tsv; }
fqdn()    { az container show -g "$RESOURCE_GROUP" -n "$1" --query ipAddress.fqdn -o tsv; }

# Espera o Oracle abrir. Sem volume o primeiro boot cria o datafile do zero, e
# os apps não sobem antes disso: o Flyway e o Migrate() falham em banco fechado.
espera_oracle() {
  echo "aguardando o Oracle abrir (3 a 6 min no primeiro boot)..."
  for i in $(seq 1 60); do
    if az container logs -g "$RESOURCE_GROUP" -n "$ACI_ORACLE" 2>/dev/null | grep -q "DATABASE IS READY TO USE"; then
      echo "  banco aberto na tentativa $i"; return 0
    fi
    sleep 15
  done
  echo "ERRO: o Oracle não abriu em 15 min. Veja: az container logs -g $RESOURCE_GROUP -n $ACI_ORACLE"
  return 1
}
