use warehouse;
go

create or alter procedure dbo.generate_warehouse_report_xml
	@date_from date,
	@date_to date,
	@report_xml xml output
as
begin
	set nocount on;

	;with base as(
		select
			o.order_id,
			o.order_date,
			oi.product_id,
			oi.quantity,
			p.stock_id,
			s.description as stock_description,
			cast(oi.quantity*p.price as decimal(19,4)) as line_amount
		from orders o
		join order_items oi on oi.order_id=o.order_id
		join products p on p.product_id=oi.product_id
		join stocks s on s.stock_id=p.stock_id
		where o.order_date>=@date_from
		and o.order_date<dateadd(day,1,@date_to)
	),
	stock_totals as(
		select
			b.stock_id,
			max(b.stock_description) as stock_description,
			count(distinct b.order_id) as orders_count,
			sum(b.quantity) as total_quantity,
			cast(sum(b.line_amount) as decimal(19,4)) as total_amount
		from base b
		group by b.stock_id
	)
	select
		@report_xml=(
			select
				convert(datetime2(0),sysdatetime()) as [@generated_at],
				@date_from as [@date_from],
				@date_to as [@date_to],
				(
					select
						count(distinct b.order_id) as [@total_orders],
						isnull(sum(b.quantity),0) as [@total_quantity],
						cast(isnull(sum(b.line_amount),0) as decimal(19,4)) as [@total_amount]
					from base b
					for xml path('summary'),type
				),
				(
					select
						st.stock_id as [@stock_id],
						st.orders_count as [@orders_count],
						st.total_quantity as [@total_quantity],
						st.total_amount as [@total_amount],
						st.stock_description as [text()]
					from stock_totals st
					order by st.stock_id
					for xml path('stock'),root('stocks'),type
				)
			for xml path('report'),type
		);
end;
go

create or alter procedure dbo.insert_warehouse_report
	@date_from date,
	@date_to date
as
begin
	set nocount on;

	declare @report_xml xml;

	exec dbo.generate_warehouse_report_xml
		@date_from=@date_from,
		@date_to=@date_to,
		@report_xml=@report_xml output;

	insert into dbo.report(report_xml)
	values(@report_xml);

	select scope_identity() as report_id;
end;
go

create or alter procedure dbo.get_report_stock_by_description
	@stock_description nvarchar(100)
as
begin
	set nocount on;

	select
		r.report_id,
		rep.r.value('@generated_at','datetime2(0)') as generated_at,
		rep.r.value('@date_from','date') as date_from,
		rep.r.value('@date_to','date') as date_to,
		stock.s.value('@stock_id','int') as stock_id,
		stock.s.value('@orders_count','int') as orders_count,
		stock.s.value('@total_quantity','int') as total_quantity,
		stock.s.value('@total_amount','decimal(19,4)') as total_amount,
		stock.s.value('text()[1]','nvarchar(100)') as stock_description
	from dbo.report r
	cross apply r.report_xml.nodes('/report') rep(r)
	cross apply rep.r.nodes('stocks/stock[text()[1]=sql:variable("@stock_description")]') stock(s)
	order by
		r.report_id,
		stock_id;
end;
go

exec dbo.insert_warehouse_report '2026-01-01','2026-01-31';
go

select report_id,report_xml
from dbo.report;
go

select * from Stocks;
exec dbo.get_report_stock_by_description N'Stock zone 1';
go