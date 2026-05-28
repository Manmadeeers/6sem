use warehouse;
go

--FOR DATA EXPORT
create or alter function dbo.fn_products_stocks_by_period
(
	@date_from date,
	@date_to date
)
returns table
as
return
(
	select distinct
		p.product_id,
		p.name as product_name,
		p.price,
		p.quantity as product_quantity,
		s.stock_id,
		s.capacity,
		s.filled_part,
		s.description as stock_description,
		o.order_id,
		o.order_date,
		o.order_status
	from orders o
	join order_items oi on oi.order_id=o.order_id
	join products p on p.product_id=oi.product_id
	join stocks s on s.stock_id=p.stock_id
	where o.order_date>=@date_from
	and o.order_date<dateadd(day,1,@date_to)
);
go



select *
from dbo.fn_products_stocks_by_period('2026-01-01','2026-12-31')
order by order_date,product_id;
go



--FOR DATA IMPORT


if object_id('dbo.storage_import_stage','u') is not null
	drop table dbo.storage_import_stage;
go

create table dbo.storage_import_stage(
	product_name nvarchar(200) not null,
	stock_description nvarchar(100) not null,
	unit_price decimal(19,4) not null,
	product_quantity int not null,
	load_date date not null
);
go




select * from storage_import_stage;


