alter session set container = WarehousePDB;

create tablespace lob_data
datafile '/opt/oracle/oradata/FREE/warehousepdb/lob_data01.dbf'
size 100m
autoextend on next 20m maxsize 1g;


create or replace directory lob_doc_dir as '/opt/oracle/extdocs';
create or replace directory lob_photo_dir as '/opt/oracle/extphotos';



create user lob_user identified by 1
default tablespace lob_data
temporary tablespace temp;

grant create session to lob_user;
grant create table to lob_user;
grant create procedure to lob_user;
grant create sequence to lob_user;
grant create view to lob_user;

grant read on directory lob_doc_dir to lob_user;
grant read on directory lob_photo_dir to lob_user;




alter user lob_user quota unlimited on lob_data;


