FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
WORKDIR /app
COPY publish/ .
EXPOSE 3000
ENV ASPNETCORE_URLS=http://0.0.0.0:3000
ENTRYPOINT ["./TDWA07-01"]
