# Oracle XE 21c com os dois schemas do PetBuddies.
#
# O gvenzl cria o primeiro usuário pelas variáveis APP_USER/APP_USER_PASSWORD.
# O segundo nasce do script em container-entrypoint-initdb.d/, porque um .sql
# ali roda como SYS no CDB — e o usuário precisa existir no PDB XEPDB1.
FROM gvenzl/oracle-xe:21-slim

COPY container-entrypoint-initdb.d/ /container-entrypoint-initdb.d/
