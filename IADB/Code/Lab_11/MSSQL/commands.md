# MSSQL Data Import
docker cp "C:\Users\Manmade\Desktop\6sem\IADB\Code\Lab_11\MSSQL\MSSQL_import.txt" mssql-dev:/tmp/MSSQL_import.txt                                                                                                                               

docker exec mssql-dev /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "123StrongPass!" -C -d Warehouse -Q "BULK INSERT dbo.storage_import_stage FROM '/tmp/MSSQL_import.txt' WITH (FIRSTROW=2, FIELDTERMINATOR=';', ROWTERMINATOR='0x0d0a', TABLOCK);"
    