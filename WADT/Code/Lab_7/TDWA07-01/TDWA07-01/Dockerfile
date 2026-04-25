FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY TDWA07-01.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release -r linux-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=false \
    -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
WORKDIR /app

COPY --from=build /app/publish/ ./
EXPOSE 3000
ENTRYPOINT ["./TDWA07-01"]
