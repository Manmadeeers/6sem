create pluggable database WarehousePDB
admin user wh_admin identified by 1
roles = (DBA)
file_name_convert = ('/opt/oracle/oradata/FREE/pdbseed/', '/opt/oracle/oradata/FREE/warehousepdb/');



alter pluggable database WarehousePDB open;


alter pluggable database WarehousePDB save state;

alter session set container = WarehousePDB;

create tablespace Warehouse_Data
datafile '/opt/oracle/oradata/FREE/warehousepdb/warehous_dat01.dbf'
size 10m autoextend on next 5m maxsize 50m;


create temporary tablespace Warehouse_Temp
tempfile '/opt/oracle/oradata/FREE/warehousepdb/warehouse_temp01.dbf'
size 5m autoextend on next 5m maxsize 25m;


create user Warehouse_Manager identified by 1
default tablespace Warehouse_Data
temporary tablespace Warehouse_Temp;


grant create session, create table, create procedure, create view, create sequence to Warehouse_Manager;

alter user Warehouse_Manager quota unlimited on Warehouse_Data;