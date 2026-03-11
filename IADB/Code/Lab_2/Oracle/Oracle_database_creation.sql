create tablespace Warehouse_Data
Datafile '/opt/oracle/oradata/FREE/warehouse_dat.dbf'
size 10m
autoextend on next 5m maxsize 50m;

drop tablespace Warehouse_Temp including contents and datafiles;

create temporary tablespace Warehouse_Temp
tempfile '/opt/oracle/oradata/FREE/warehouse_temp.dbf'
size 5m
autoextend on next 5m maxsize 25m;

create user Warehouse_Admin identified by 1
default tablespace Warehouse_Data
temporary tablespace Warehouse_Temp;

grant connect, resource, create view to Warehouse_Admin;
alter user Warehouse_Admin quota unlimited on Warehouse_Data;