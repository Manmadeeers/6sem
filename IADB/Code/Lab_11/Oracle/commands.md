# Oracle data export

docker exec -it oracle-free bash


sqlplus warehouse_manager/1@//localhost:1521/WarehousePDB



set pagesize 0
set linesize 32767
set feedback off
set verify off
set heading on
set trimspool on
set colsep ';'

spool /tmp/warehouse_period_export.txt

select
	order_id,
	to_char(order_date,'YYYY-MM-DD') as order_date,
	product_id,
	product_name,
	stock_id,
	stock_description,
	to_char(unit_price,'FM9999999990D0000','NLS_NUMERIC_CHARACTERS=.,') as unit_price,
	product_quantity,
	to_char(line_amount,'FM9999999990D0000','NLS_NUMERIC_CHARACTERS=.,') as line_amount
from table(fn_warehouse_period_data(date '2026-01-01',date '2026-01-31'));

spool off
exit
/

ls -l /tmp/warehouse_period_export.txt

exit

docker cp oracle-free:/tmp/warehouse_period_export.txt C:\Users\Manmade\Desktop\6sem\IADB\Code\Lab_11\Oracle\warehouse_period_export.txt


# Oracle data import



 docker cp "C:\Users\Manmade\Desktop\6sem\IADB\Code\Lab_11\Oracle\warehouse_import.txt" oracle-free:/tmp/warehouse_import.txt                                                                 
>> docker cp "C:\Users\Manmade\Desktop\6sem\IADB\Code\Lab_11\Oracle\warehouse_import.ctl" oracle-free:/tmp/warehouse_import.ctl


 docker exec -it oracle-free bash -lc "sqlldr warehouse_manager/1@//localhost:1521/WarehousePDB control=/tmp/warehouse_import.ctl log=/tmp/warehouse_import.log bad=/tmp/warehouse_import.bad"