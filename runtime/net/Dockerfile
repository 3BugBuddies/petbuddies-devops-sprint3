# Runtime do back-office (.NET). Mesmo princípio do Java: o dotnet publish roda
# no host e gera IL portável; esta imagem só a empacota sobre a base amd64.
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app
RUN addgroup -S petbuddies && adduser -S petbuddies -G petbuddies
COPY publish/ .
USER petbuddies
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080 TZ=America/Sao_Paulo
ENTRYPOINT ["dotnet", "PetBuddies-API.dll"]
