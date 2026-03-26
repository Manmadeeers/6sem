use warehouse;

go

select dbo.fn_getstockstatus(1) as stock_status;
select dbo.fn_getstockstatus(2) as stock_status;
select dbo.fn_getstockstatus(999) as stock_status;

go

select dbo.fn_canfulfillorder(1) as can_fulfill;
select dbo.fn_canfulfillorder(2) as can_fulfill;
select dbo.fn_canfulfillorder(999) as can_fulfill;

go

select * from products where product_id = 1;
select stock_id, capacity, filled_part from stocks where stock_id = 1;

exec dbo.sp_dispatchproduct @productid = 1, @quantitytodispatch = 2;

select * from products where product_id = 1;
select stock_id, capacity, filled_part from stocks where stock_id = 1;
select * from stocks where Stock_ID=2;

go

select * from dbo.fn_getmonthlyproductfinancials(3, 2026);
select * from dbo.fn_getmonthlyproductfinancials(1, 2026);
select * from dbo.fn_getmonthlyproductfinancials(13, 2026);

go

exec dbo.usp_generatewarehousefinancialreport;

go

select dbo.fn_getorderpackprogress(1) as pack_progress;
select dbo.fn_getorderpackprogress(2) as pack_progress;
select dbo.fn_getorderpackprogress(999) as pack_progress;

go

select dbo.fn_getstockturnoverrate(1, 30) as turnover_30d;
select dbo.fn_getstockturnoverrate(1, 90) as turnover_90d;
select dbo.fn_getstockturnoverrate(999, 30) as turnover_30d;

go

select task_id, priority, due_date, is_completed from tasks where is_completed = 0;

exec dbo.sp_escalateoverduetasks;

select task_id, priority, due_date, is_completed from tasks where is_completed = 0;

go

select order_id, order_status, order_date from orders where order_status = 'Created';

exec dbo.sp_cancelstaleorders @staledays = 30;

select order_id, order_status, order_date from orders where order_status in ('Created', 'Canceled');

go

select product_id, stock_id, quantity from products where product_id = 1;
select stock_id, capacity, filled_part from stocks where stock_id in (1, 2);

exec dbo.sp_transferproduct @productid = 1, @targetstockid = 2, @qty = 5;

select product_id, stock_id, quantity from products where product_id = 1;
select stock_id, capacity, filled_part from stocks where stock_id in (1, 2);
