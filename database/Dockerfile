# Oracle XE 21c — a imagem do banco desta entrega.
#
# O Dockerfile fixa a versão e dá ao projeto uma cópia própria no Container
# Registry, que é de onde o Container Instance puxa. O schema não nasce aqui:
# quem o cria é o Flyway, na subida da API.
#
# A tag :21-slim publica somente amd64, que é a arquitetura do ACI.
FROM gvenzl/oracle-xe:21-slim
