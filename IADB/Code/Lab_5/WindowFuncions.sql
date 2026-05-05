use warehouse;
go

--1: Orders and packs results(quantity, sum, quantity of packed/shipped positions from stocks, storage load percentage) for a qurter, half-year, year
;with date_limits as(
select
	(select min(order_date) from orders) as min_order_date,
	(select max(order_date) from orders) as max_order_date,
	(select min(pack_date) from pack) as min_pack_date,
	(select max(pack_date) from pack) as max_pack_date
),
bounds as(
select
	datefromparts(
		year(
			case
				when min_order_date is null then min_pack_date
				when min_pack_date is null then min_order_date
				when min_order_date<min_pack_date then min_order_date
				else min_pack_date
			end
		),
		month(
			case
				when min_order_date is null then min_pack_date
				when min_pack_date is null then min_order_date
				when min_order_date<min_pack_date then min_order_date
				else min_pack_date
			end
		),
		1
	) as min_month,
	datefromparts(
		year(
			case
				when max_order_date is null then max_pack_date
				when max_pack_date is null then max_order_date
				when max_order_date>max_pack_date then max_order_date
				else max_pack_date
			end
		),
		month(
			case
				when max_order_date is null then max_pack_date
				when max_pack_date is null then max_order_date
				when max_order_date>max_pack_date then max_order_date
				else max_pack_date
			end
		),
		1
	) as max_month
from date_limits
),
nums as(
select top(
	select datediff(month,min_month,max_month)+1
	from bounds
)
	row_number() over(order by (select null))-1 as n
from sys.all_objects a
cross join sys.all_objects b
),
months as(
select
	dateadd(month,n,b.min_month) as month_start
from nums
cross join bounds b
),
orders_monthly as(
select
	datefromparts(year(order_date),month(order_date),1) as month_start,
	count(*) as orders_count,
	sum(total_amount) as orders_amount
from orders
group by datefromparts(year(order_date),month(order_date),1)
),
pack_monthly as(
select
	datefromparts(year(p.pack_date),month(p.pack_date),1) as month_start,
	sum(case when p.pack_status in('Packed','Shipped') then pi.quantity else 0 end) as packed_qty,
	sum(case when p.pack_status='Shipped' then pi.quantity else 0 end) as shipped_qty
from pack p
join pack_items pi on pi.pack_id=p.pack_id
group by datefromparts(year(p.pack_date),month(p.pack_date),1)
),
base as(
select
	m.month_start,
	year(m.month_start) as year_no,
	month(m.month_start) as month_no,
	datepart(quarter,m.month_start) as quarter_no,
	case when month(m.month_start) between 1 and 6 then 1 else 2 end as halfyear_no,
	isnull(o.orders_count,0) as orders_count_month,
	isnull(o.orders_amount,0.0000) as orders_amount_month,
	isnull(p.packed_qty,0) as packed_qty_month,
	isnull(p.shipped_qty,0) as shipped_qty_month
from months m
left join orders_monthly o on o.month_start=m.month_start
left join pack_monthly p on p.month_start=m.month_start
)
select
	month_start,
	orders_count_month,
	orders_amount_month,
	packed_qty_month,
	shipped_qty_month,
	sum(orders_count_month) over(partition by year_no,month_no) as orders_count_month_total,
	sum(orders_amount_month) over(partition by year_no,month_no) as orders_amount_month_total,
	sum(packed_qty_month) over(partition by year_no,month_no) as packed_qty_month_total,
	sum(shipped_qty_month) over(partition by year_no,month_no) as shipped_qty_month_total,
	sum(orders_count_month) over(partition by year_no,quarter_no) as orders_count_quarter,
	sum(orders_amount_month) over(partition by year_no,quarter_no) as orders_amount_quarter,
	sum(packed_qty_month) over(partition by year_no,quarter_no) as packed_qty_quarter,
	sum(shipped_qty_month) over(partition by year_no,quarter_no) as shipped_qty_quarter,
	sum(orders_count_month) over(partition by year_no,halfyear_no) as orders_count_halfyear,
	sum(orders_amount_month) over(partition by year_no,halfyear_no) as orders_amount_halfyear,
	sum(packed_qty_month) over(partition by year_no,halfyear_no) as packed_qty_halfyear,
	sum(shipped_qty_month) over(partition by year_no,halfyear_no) as shipped_qty_halfyear,
	sum(orders_count_month) over(partition by year_no) as orders_count_year,
	sum(orders_amount_month) over(partition by year_no) as orders_amount_year,
	sum(packed_qty_month) over(partition by year_no) as packed_qty_year,
	sum(shipped_qty_month) over(partition by year_no) as shipped_qty_year
from base
order by month_start;

--2: Operator'r results(packed and shipped orders). Quantity of processed orders, quantity of shipped orders, sum of shipped orders, operator's sipment sum compared to storage's shipment sum
go

insert into pack_items(pack_id,product_id,quantity,unit_price)
select top(5)
	pack_id,
	product_id,
	quantity,
	unit_price
from pack_items
order by item_id;
go



--duplicated deletion
;with duplicates as(
select
	item_id,
	row_number() over(
		partition by pack_id,product_id,quantity,unit_price
		order by item_id
	) as row_num
from pack_items
)
delete from duplicates
where row_num>1;
go

--pagination

declare @date_from date='2026-01-01';
declare @date_to date='2026-12-31';
declare @page_no int=1;
declare @page_count int;

if object_id('tempdb..#rated') is not null
	drop table #rated;

;with base as(
select
	u.user_id,
	u.email,
	count(distinct case when p.pack_status in('Packed','Shipped') then p.order_id end) as processed_orders,
	sum(case when p.pack_status='Shipped' then pi.quantity else 0 end) as shipped_positions,
	sum(case when p.pack_status='Shipped' then pi.quantity*pi.unit_price else 0 end) as shipped_amount
from users u
left join pack p
	on p.user_id=u.user_id
	and p.pack_date>=@date_from
	and p.pack_date<dateadd(day,1,@date_to)
left join pack_items pi on pi.pack_id=p.pack_id
where u.role='Operator'
group by
	u.user_id,
	u.email
)
select
	row_number() over(order by isnull(shipped_amount,0) desc,processed_orders desc,user_id) as real_row_num,
	user_id,
	email,
	processed_orders,
	shipped_positions,
	cast(isnull(shipped_amount,0) as decimal(19,4)) as shipped_amount,
	sum(isnull(shipped_amount,0)) over() as total_shipped_amount,
	max(isnull(shipped_amount,0)) over() as best_shipped_amount
into #rated
from base;

select
	@page_count=case
		when count(*)=0 then 1
		else ceiling(count(*)/20.0)
	end
from #rated;

while @page_no<=@page_count
begin
	print 'page '+cast(@page_no as varchar(10));

	select
		row_number() over(order by real_row_num) as row_num,
		@page_no as page_no,
		user_id,
		email,
		processed_orders,
		shipped_positions,
		shipped_amount,
		cast(case
			when total_shipped_amount=0 then 0
			when total_shipped_amount is null then null
			else shipped_amount*100.0/total_shipped_amount
		end as decimal(10,2)) as shipped_amount_vs_total_pct,
		cast(case
			when best_shipped_amount=0 then 0
			when best_shipped_amount is null then null
			else shipped_amount*100.0/best_shipped_amount
		end as decimal(10,2)) as shipped_amount_vs_best_pct
	from #rated
	where real_row_num between (@page_no-1)*20+1 and @page_no*20
	order by real_row_num;

	set @page_no=@page_no+1;
end

drop table #rated;
go



--3: amount of processed orders for each operator for 6 months
go

;with months as(
select
	datefromparts(year(dateadd(month,-5,getdate())),month(dateadd(month,-5,getdate())),1) as month_start
union all
select
	dateadd(month,1,month_start)
from months
where month_start<datefromparts(year(getdate()),month(getdate()),1)
),
operators as(
select
	u.user_id,
	u.email
from users u
where u.role='Operator'
),
pack_monthly as(
select
	p.user_id,
	datefromparts(year(p.pack_date),month(p.pack_date),1) as month_start,
	count(distinct p.order_id) as processed_orders
from pack p
where p.pack_status in('Packed','Shipped')
and p.pack_date>=datefromparts(year(dateadd(month,-5,getdate())),month(dateadd(month,-5,getdate())),1)
and p.pack_date<dateadd(month,1,datefromparts(year(getdate()),month(getdate()),1))
group by
	p.user_id,
	datefromparts(year(p.pack_date),month(p.pack_date),1)
)
select
	o.user_id,
	o.email,
	m.month_start,
	isnull(pm.processed_orders,0) as processed_orders
from operators o
cross join months m
left join pack_monthly pm
	on pm.user_id=o.user_id
	and pm.month_start=m.month_start
order by
	o.user_id,
	m.month_start
option(maxrecursion 6);

--4: which operator has processed the biggest amoutn of orders by status
go

;with stat as(
select
	o.order_status,
	u.user_id,
	u.email,
	count(distinct p.order_id) as orders_count
from orders o
join pack p on p.order_id=o.order_id
join users u on u.user_id=p.user_id
where u.role='Operator'
group by
	o.order_status,
	u.user_id,
	u.email
),
rated as(
select
	order_status,
	user_id,
	email,
	orders_count,
	rank() over(partition by order_status order by orders_count desc) as rnk
from stat
)
select
	order_status,
	user_id,
	email,
	orders_count
from rated
where rnk=1
order by
	order_status,
	user_id;
go




