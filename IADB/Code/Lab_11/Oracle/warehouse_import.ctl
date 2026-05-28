options (skip=1)
load data
infile '/tmp/warehouse_import.txt'
into table warehouse_import_data
append
fields terminated by ';' optionally enclosed by '"'
trailing nullcols
(
	product_name        char(200) "upper(trim(:product_name))",
	stock_description   char(100) "upper(trim(:stock_description))",
	unit_price          "round(to_number(trim(:unit_price),'9999999990D9999','NLS_NUMERIC_CHARACTERS=.,'),1)",
	product_quantity    "round(to_number(trim(:product_quantity),'9999999990D9999','NLS_NUMERIC_CHARACTERS=.,'),1)",
	load_date           date 'YYYY-MM-DD'
)