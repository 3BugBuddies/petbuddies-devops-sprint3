# Runtime da API de cuidado (Java).
#
# Só empacota: o jar é construído antes, pelo 02_build-push.sh, com o Maven do
# host. O jar é bytecode e não depende de arquitetura, então construí-lo nativo
# em ARM e empacotá-lo numa base amd64 dá a mesma imagem que um build amd64
# inteiro — sem emular a JVM do Maven, que é o estágio caro.
FROM --platform=linux/amd64 eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S petbuddies && adduser -S petbuddies -G petbuddies
COPY app.jar app.jar
USER petbuddies
EXPOSE 8080
ENTRYPOINT ["java", "-Duser.timezone=America/Sao_Paulo", "-jar", "app.jar"]
