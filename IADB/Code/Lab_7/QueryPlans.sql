--1: forecast for processed orders and sum of shipped orders for each operator for the next year(month-by-month) incrementing by 0.5%

with monthly_stats as(
select
	u.user_id,
	u.email,
	trunc(p.pack_date,'mm') as month_start,
	count(distinct case when p.pack_status in('Packed','Shipped') then p.order_id end) as processed_orders,
	nvl(sum(case when p.pack_status='Shipped' then pi.quantity*pi.unit_price else 0 end),0) as shipped_amount
from users u
join pack p on p.user_id=u.user_id
left join pack_items pi on pi.pack_id=p.pack_id
where u.user_role='Operator'
group by
	u.user_id,
	u.email,
	trunc(p.pack_date,'mm')
),
last_history as(
select
	user_id,
	email,
	last_month,
	processed_orders,
	shipped_amount
from monthly_stats
match_recognize(
	partition by user_id,email
	order by month_start
	measures
		final last(month_start) as last_month,
		final last(processed_orders) as processed_orders,
		final last(shipped_amount) as shipped_amount
	one row per match
	pattern(a+)
	define a as 1=1
)
),
seed as(
select
	l.user_id,
	l.email,
	l.last_month,
	n.month_no,
	case when n.month_no=0 then l.processed_orders end as processed_orders,
	case when n.month_no=0 then l.shipped_amount end as shipped_amount
from last_history l
cross join(
	select level-1 as month_no
	from dual
	connect by level<=13
)n
),
forecast as(
select
	user_id,
	email,
	last_month,
	month_no,
	processed_orders,
	shipped_amount
from seed
model
	partition by(user_id,email,last_month)
	dimension by(month_no)
	measures(processed_orders,shipped_amount)
	rules sequential order(
		processed_orders[for month_no from 1 to 12 increment 1]=round(nvl(processed_orders[cv(month_no)-1],0)*1.005),
		shipped_amount[for month_no from 1 to 12 increment 1]=round(nvl(shipped_amount[cv(month_no)-1],0)*1.005,4)
	)
)
select
	user_id,
	email,
	add_months(last_month,month_no) as forecast_month,
	processed_orders as forecast_processed_orders,
	shipped_amount as forecast_shipped_amount
from forecast
where month_no between 1 and 12
order by
	user_id,
	forecast_month;

--2: growth, decline, volume growth for each operator

with monthly_shipments as(
select
	u.user_id,
	u.email,
	trunc(p.pack_date,'mm') as month_start,
	nvl(sum(case when p.pack_status='Shipped' then pi.quantity*pi.unit_price else 0 end),0) as shipped_amount
from users u
join pack p on p.user_id=u.user_id
left join pack_items pi on pi.pack_id=p.pack_id
where u.user_role='Operator'
group by
	u.user_id,
	u.email,
	trunc(p.pack_date,'mm')
)
select
	user_id,
	email,
	start_month,
	growth_month,
	decline_month,
	regrowth_month,
	start_amount,
	growth_amount,
	decline_amount,
	regrowth_amount
from monthly_shipments
match_recognize(
	partition by user_id,email
	order by month_start
	measures
		first(a.month_start) as start_month,
		first(b.month_start) as growth_month,
		first(c.month_start) as decline_month,
		first(d.month_start) as regrowth_month,
		first(a.shipped_amount) as start_amount,
		first(b.shipped_amount) as growth_amount,
		first(c.shipped_amount) as decline_amount,
		first(d.shipped_amount) as regrowth_amount
	one row per match
	pattern(a b c d)
	define
		b as b.shipped_amount>a.shipped_amount,
		c as c.shipped_amount<b.shipped_amount,
		d as d.shipped_amount>c.shipped_amount
)
order by
	user_id,
	start_month;

    

