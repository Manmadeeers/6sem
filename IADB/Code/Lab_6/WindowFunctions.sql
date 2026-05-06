--1: operator's results for a quarter, half-year,year

with bounds as(
select
	trunc(least(min_order_date,min_pack_date),'mm') as min_month,
	trunc(greatest(max_order_date,max_pack_date),'mm') as max_month
from(
	select
		(select min(order_date) from orders) as min_order_date,
		(select max(order_date) from orders) as max_order_date,
		(select min(pack_date) from pack) as min_pack_date,
		(select max(pack_date) from pack) as max_pack_date
	from dual
)
),
months as(
select
	add_months(b.min_month,level-1) as month_start
from bounds b
connect by add_months(b.min_month,level-1)<=b.max_month
),
orders_monthly as(
select
	trunc(order_date,'mm') as month_start,
	count(*) as orders_count,
	sum(total_amount) as orders_amount
from orders
group by trunc(order_date,'mm')
),
pack_monthly as(
select
	trunc(p.pack_date,'mm') as month_start,
	sum(case when p.pack_status in('Packed','Shipped') then pi.quantity else 0 end) as packed_qty,
	sum(case when p.pack_status='Shipped' then pi.quantity else 0 end) as shipped_qty
from pack p
join pack_items pi on pi.pack_id=p.pack_id
group by trunc(p.pack_date,'mm')
),
base as(
select
	m.month_start,
	extract(year from m.month_start) as year_no,
	extract(month from m.month_start) as month_no,
	to_number(to_char(m.month_start,'q')) as quarter_no,
	case when extract(month from m.month_start) between 1 and 6 then 1 else 2 end as halfyear_no,
	nvl(o.orders_count,0) as orders_count_month,
	nvl(o.orders_amount,0) as orders_amount_month,
	nvl(p.packed_qty,0) as packed_qty_month,
	nvl(p.shipped_qty,0) as shipped_qty_month
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


--2:Operator's results for a determined period...


var date_from varchar2(10);
var date_to varchar2(10);

exec :date_from:='2024-01-01';
exec :date_to:='2026-12-31';

with base as(
select
	u.user_id,
	u.email,
	count(distinct case when p.pack_status in('Packed','Shipped') then p.order_id end) as processed_orders,
	nvl(sum(case when p.pack_status='Shipped' then pi.quantity else 0 end),0) as shipped_positions,
	nvl(sum(case when p.pack_status='Shipped' then pi.quantity*pi.unit_price else 0 end),0) as shipped_amount
from users u
left join pack p
	on p.user_id=u.user_id
	and p.pack_date>=to_date(:date_from,'yyyy-mm-dd')
	and p.pack_date<to_date(:date_to,'yyyy-mm-dd')+1
left join pack_items pi on pi.pack_id=p.pack_id
where u.user_role='Operator'
group by
	u.user_id,
	u.email
),
rated as(
select
	user_id,
	email,
	processed_orders,
	shipped_positions,
	cast(shipped_amount as number(19,4)) as shipped_amount,
	sum(shipped_amount) over() as total_shipped_amount,
	max(shipped_amount) over() as best_shipped_amount
from base
)
select
	user_id,
	email,
	processed_orders,
	shipped_positions,
	shipped_amount,
	cast(
		case
			when total_shipped_amount=0 then 0
			else shipped_amount*100/total_shipped_amount
		end
		as number(10,2)
	) as shipped_amount_vs_total_pct,
	cast(
		case
			when best_shipped_amount=0 then 0
			else shipped_amount*100/best_shipped_amount
		end
		as number(10,2)
	) as shipped_amount_vs_best_pct
from rated
order by
	shipped_amount desc,
	processed_orders desc,
	user_id;
    
    
--3: amount of processed orders for each operator for 6 month by each month

with months as(
select
	add_months(trunc(current_date,'mm'),-(level-1)) as month_start
from dual
connect by level<=6
),
operators as(
select
	u.user_id,
	u.email
from users u
where u.user_role='Operator'
),
pack_monthly as(
select
	p.user_id,
	trunc(p.pack_date,'mm') as month_start,
	count(distinct p.order_id) as processed_orders
from pack p
where p.pack_status in('Packed','Shipped')
and p.pack_date>=add_months(trunc(current_date,'mm'),-5)
and p.pack_date<add_months(trunc(current_date,'mm'),1)
group by
	p.user_id,
	trunc(p.pack_date,'mm')
)
select
	o.user_id,
	o.email,
	m.month_start,
	nvl(pm.processed_orders,0) as processed_orders
from operators o
cross join months m
left join pack_monthly pm
	on pm.user_id=o.user_id
	and pm.month_start=m.month_start
order by
	o.user_id,
	m.month_start;
    
    

--4: which operator had processed the most orders

with stat as(
select
	o.order_status,
	u.user_id,
	u.email,
	count(distinct p.order_id) as orders_count
from orders o
join pack p on p.order_id=o.order_id
join users u on u.user_id=p.user_id
where u.user_role='Operator'
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


