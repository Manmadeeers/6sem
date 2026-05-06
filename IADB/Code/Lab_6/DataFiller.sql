insert into stocks(capacity,filled_part,description)
select
	500+mod(level,1500),
	mod(level*37,500+mod(level,1500)+1),
	'stock '||level
from dual
connect by level<=200;

insert into users(email,user_role,password_hash,created_at)
select
	'user'||level||'@warehouse.com',
	case mod(level,4)
		when 0 then 'Operator'
		when 1 then 'Manager'
		when 2 then 'Accountant'
		else 'Admin'
	end,
	standard_hash('user_'||level||'_'||rawtohex(sys_guid()),'SHA256'),
	current_timestamp-numtodsinterval(mod(level,900),'day')
from dual
connect by level<=400;

insert into products(stock_id,name,price,quantity)
with nums as(
	select level as n
	from dual
	connect by level<=1200
),
src as(
	select
		stock_id,
		row_number() over(order by stock_id) as rn,
		count(*) over() as cnt
	from stocks
)
select
	s.stock_id,
	'product '||n.n,
	round(dbms_random.value(5,5005),4),
	trunc(dbms_random.value(0,300))
from nums n
join src s on s.rn=mod(n.n-1,s.cnt)+1;

insert into tasks(user_id,due_date,priority,description,is_completed)
with nums as(
	select level as n
	from dual
	connect by level<=2500
),
src as(
	select
		user_id,
		row_number() over(order by user_id) as rn,
		count(*) over() as cnt
	from users
)
select
	s.user_id,
	current_timestamp+numtodsinterval(mod(n.n,365)-180,'day'),
	case mod(n.n,4)
		when 0 then 'Low'
		when 1 then 'Moderate'
		when 2 then 'High'
		else 'Highest'
	end,
	'task #'||n.n,
	case when mod(n.n,3)=0 then 1 else 0 end
from nums n
join src s on s.rn=mod(n.n-1,s.cnt)+1;

insert into orders(order_date,order_status,total_amount)
select
	current_timestamp-numtodsinterval(mod(level,730),'day'),
	case mod(level,4)
		when 0 then 'Created'
		when 1 then 'In work'
		when 2 then 'Shipped'
		else 'Canceled'
	end,
	round(dbms_random.value(50,20000),4)
from dual
connect by level<=3000;

insert into order_items(order_id,product_id,quantity)
with nums as(
	select level as n
	from dual
	connect by level<=3000
),
o as(
	select
		order_id,
		row_number() over(order by order_id) as rn,
		count(*) over() as cnt
	from orders
),
p as(
	select
		product_id,
		row_number() over(order by product_id) as rn,
		count(*) over() as cnt
	from products
)
select
	o.order_id,
	p.product_id,
	1+mod(n.n,20)
from nums n
join o on o.rn=mod(n.n-1,o.cnt)+1
join p on p.rn=mod(n.n*7-1,p.cnt)+1;

insert into pack(user_id,order_id,pack_date,pack_status)
with nums as(
	select level as n
	from dual
	connect by level<=3000
),
u as(
	select
		user_id,
		row_number() over(order by user_id) as rn,
		count(*) over() as cnt
	from users
	where user_role='Operator'
),
o as(
	select
		order_id,
		order_date,
		row_number() over(order by order_id) as rn,
		count(*) over() as cnt
	from orders
)
select
	u.user_id,
	o.order_id,
	o.order_date+numtodsinterval(mod(n.n,15),'day'),
	case mod(n.n,3)
		when 0 then 'Not packed'
		when 1 then 'Packed'
		else 'Shipped'
	end
from nums n
join u on u.rn=mod(n.n-1,u.cnt)+1
join o on o.rn=mod(n.n-1,o.cnt)+1;

insert into pack_items(pack_id,product_id,quantity,unit_price)
with nums as(
	select level as n
	from dual
	connect by level<=3000
),
pk as(
	select
		pack_id,
		row_number() over(order by pack_id) as rn,
		count(*) over() as cnt
	from pack
),
p as(
	select
		product_id,
		price,
		row_number() over(order by product_id) as rn,
		count(*) over() as cnt
	from products
)
select
	pk.pack_id,
	p.product_id,
	1+mod(n.n,25),
	p.price
from nums n
join pk on pk.rn=mod(n.n-1,pk.cnt)+1
join p on p.rn=mod(n.n*11-1,p.cnt)+1;

commit;