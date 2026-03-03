use master;
GO

create database Warehouse on
(name = Warehouse_dat,
	Filename = '/var/opt/mssql/data/warehouse_dat.mdf',
	Size = 10MB,
	Maxsize = 50MB,
	Filegrowth = 5MB)
log on (
	name = warehouse_log,
	filename = '/var/opt/mssql/data/warehouse_log.ldf',
	size = 5MB,
	maxsize = 25MB,
	filegrowth = 5MB);

GO
