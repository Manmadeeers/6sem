USE warehouse;
GO

use warehouse;
go

if object_id('tempdb..#nums') is not null
	drop table #nums;
go

select top(200)
	row_number() over(order by (select null)) as n
into #nums
from sys.all_objects a
cross join sys.all_objects b;
go

;with src as(
select
	row_number() over(order by stock_id) as rn,
	capacity,
	filled_part,
	description
from stocks
),
cnt as(
select count(*) as c
from src
)
insert into stocks(capacity,filled_part,description)
select
	s.capacity,
	s.filled_part,
	s.description
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by product_id) as rn,
	stock_id,
	name,
	price,
	quantity
from products
),
cnt as(
select count(*) as c
from src
)
insert into products(stock_id,name,price,quantity)
select
	s.stock_id,
	s.name,
	s.price,
	s.quantity
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by task_id) as rn,
	user_id,
	due_date,
	priority,
	description,
	is_completed
from tasks
),
cnt as(
select count(*) as c
from src
)
insert into tasks(user_id,due_date,priority,description,is_completed)
select
	s.user_id,
	s.due_date,
	s.priority,
	s.description,
	s.is_completed
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by order_id) as rn,
	order_date,
	order_status,
	total_amount
from orders
),
cnt as(
select count(*) as c
from src
)
insert into orders(order_date,order_status,total_amount)
select
	s.order_date,
	s.order_status,
	s.total_amount
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by item_id) as rn,
	order_id,
	product_id,
	quantity
from order_items
),
cnt as(
select count(*) as c
from src
)
insert into order_items(order_id,product_id,quantity)
select
	s.order_id,
	s.product_id,
	s.quantity
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by pack_id) as rn,
	user_id,
	order_id,
	pack_date,
	pack_status
from pack
),
cnt as(
select count(*) as c
from src
)
insert into pack(user_id,order_id,pack_date,pack_status)
select
	s.user_id,
	s.order_id,
	s.pack_date,
	s.pack_status
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

;with src as(
select
	row_number() over(order by item_id) as rn,
	pack_id,
	product_id,
	quantity,
	unit_price
from pack_items
),
cnt as(
select count(*) as c
from src
)
insert into pack_items(pack_id,product_id,quantity,unit_price)
select
	s.pack_id,
	s.product_id,
	s.quantity,
	s.unit_price
from #nums n
cross join cnt c
join src s on c.c>0 and s.rn=((n.n-1)%c.c)+1;
go

drop table #nums;
go


SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @StockCount      int = 300;
DECLARE @UserCount       int = 8000;
DECLARE @ProductCount    int = 40000;
DECLARE @TaskCount       int = 25000;
DECLARE @OrderCount      int = 18000;
DECLARE @OrderItemCount  int = 90000;
DECLARE @PackCount       int = 14000;
DECLARE @PackItemCount   int = 70000;
DECLARE @BatchSize       int = 5000;

DECLARE @MaxCount int =
(
    SELECT MAX(v)
    FROM (VALUES
        (@StockCount),
        (@UserCount),
        (@ProductCount),
        (@TaskCount),
        (@OrderCount),
        (@OrderItemCount),
        (@PackCount),
        (@PackItemCount)
    ) x(v)
);

IF OBJECT_ID('tempdb..#N') IS NOT NULL
    DROP TABLE #N;

CREATE TABLE #N
(
    n int NOT NULL PRIMARY KEY
);

INSERT INTO #N(n)
SELECT TOP (@MaxCount)
       ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_objects a
CROSS JOIN sys.all_objects b;

DELETE FROM pack_items;
DELETE FROM pack;
DELETE FROM order_items;
DELETE FROM tasks;
DELETE FROM products;
DELETE FROM orders;
DELETE FROM users;
DELETE FROM stocks;

DBCC CHECKIDENT ('pack_items', RESEED, 0);
DBCC CHECKIDENT ('pack', RESEED, 0);
DBCC CHECKIDENT ('order_items', RESEED, 0);
DBCC CHECKIDENT ('tasks', RESEED, 0);
DBCC CHECKIDENT ('products', RESEED, 0);
DBCC CHECKIDENT ('orders', RESEED, 0);
DBCC CHECKIDENT ('users', RESEED, 0);
DBCC CHECKIDENT ('stocks', RESEED, 0);

CHECKPOINT;

INSERT INTO stocks (capacity, filled_part, description)
SELECT
    100000 + (n * 137) % 50000,
    0,
    CONCAT(N'Stock zone ', n)
FROM #N
WHERE n <= @StockCount;

CHECKPOINT;

DECLARE @From int, @To int;

SET @From = 1;
WHILE @From <= @UserCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @UserCount THEN @From + @BatchSize - 1 ELSE @UserCount END;

    INSERT INTO users (email, role, password_hash, created_at)
    SELECT
        CONCAT('user', n, '@warehouse.local'),
        CASE n % 4
            WHEN 0 THEN 'Operator'
            WHEN 1 THEN 'Manager'
            WHEN 2 THEN 'Accountant'
            ELSE 'Admin'
        END,
        HASHBYTES('SHA2_256', CONCAT('user-password-', n)),
        DATEADD(MINUTE, -n, SYSDATETIME())
    FROM #N
    WHERE n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

SET @From = 1;
WHILE @From <= @ProductCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @ProductCount THEN @From + @BatchSize - 1 ELSE @ProductCount END;

    INSERT INTO products (stock_id, name, price, quantity)
    SELECT
        ((n - 1) % @StockCount) + 1,
        CONCAT(N'Product ', n),
        CAST(5 + ((n * 113) % 250000) / 100.0 AS decimal(19,4)),
        1 + ((n * 17) % 250)
    FROM #N
    WHERE n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

UPDATE s
SET s.filled_part = x.total_qty
FROM stocks s
JOIN
(
    SELECT stock_id, SUM(quantity) AS total_qty
    FROM products
    GROUP BY stock_id
) x ON x.stock_id = s.stock_id;

CHECKPOINT;

SET @From = 1;
WHILE @From <= @TaskCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @TaskCount THEN @From + @BatchSize - 1 ELSE @TaskCount END;

    INSERT INTO tasks (user_id, due_date, priority, description, is_completed)
    SELECT
        ((n - 1) % @UserCount) + 1,
        DATEADD(DAY, (n % 90) + 1, SYSDATETIME()),
        CASE n % 4
            WHEN 0 THEN 'Low'
            WHEN 1 THEN 'Moderate'
            WHEN 2 THEN 'High'
            ELSE 'Highest'
        END,
        CONCAT(N'Task #', n, N' for warehouse workflow and stock operations.'),
        CASE WHEN n % 5 = 0 THEN 1 ELSE 0 END
    FROM #N
    WHERE n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

SET @From = 1;
WHILE @From <= @OrderCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @OrderCount THEN @From + @BatchSize - 1 ELSE @OrderCount END;

    INSERT INTO orders (order_date, order_status, total_amount)
    SELECT
        DATEADD(DAY, -(n % 180), SYSDATETIME()),
        CASE
            WHEN n % 10 = 0 THEN 'Canceled'
            WHEN n % 3 = 0 THEN 'Shipped'
            WHEN n % 2 = 0 THEN 'In work'
            ELSE 'Created'
        END,
        0.0000
    FROM #N
    WHERE n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

SET @From = 1;
WHILE @From <= @OrderItemCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @OrderItemCount THEN @From + @BatchSize - 1 ELSE @OrderItemCount END;

    INSERT INTO order_items (order_id, product_id, quantity)
    SELECT
        ((n - 1) % @OrderCount) + 1,
        ((n * 7 - 1) % @ProductCount) + 1,
        1 + ((n * 11) % 12)
    FROM #N
    WHERE n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

UPDATE o
SET o.total_amount = x.total_amount
FROM orders o
JOIN
(
    SELECT
        oi.order_id,
        CAST(SUM(oi.quantity * p.price) AS decimal(19,4)) AS total_amount
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY oi.order_id
) x ON x.order_id = o.order_id;

CHECKPOINT;

SET @From = 1;
WHILE @From <= @PackCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @PackCount THEN @From + @BatchSize - 1 ELSE @PackCount END;

    INSERT INTO pack (user_id, order_id, pack_date, pack_status)
    SELECT
        ((n.n - 1) % @UserCount) + 1,
        o.order_id,
        DATEADD(HOUR, (n.n % 72) + 1, o.order_date),
        CASE
            WHEN o.order_status = 'Shipped' THEN 'Shipped'
            WHEN o.order_status = 'Created' THEN 'Not packed'
            ELSE 'Packed'
        END
    FROM #N n
    JOIN orders o
      ON o.order_id = ((n.n - 1) % @OrderCount) + 1
    WHERE n.n BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;

SET @From = 1;
WHILE @From <= @PackItemCount
BEGIN
    SET @To = CASE WHEN @From + @BatchSize - 1 < @PackItemCount THEN @From + @BatchSize - 1 ELSE @PackItemCount END;

    ;WITH pack_source AS
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY p.pack_id, oi.item_id) AS rn,
            p.pack_id,
            oi.product_id,
            oi.quantity
        FROM pack p
        JOIN order_items oi
          ON oi.order_id = p.order_id
    )
    INSERT INTO pack_items (pack_id, product_id, quantity, unit_price)
    SELECT
        ps.pack_id,
        ps.product_id,
        ps.quantity,
        pr.price
    FROM pack_source ps
    JOIN products pr
      ON pr.product_id = ps.product_id
    WHERE ps.rn BETWEEN @From AND @To;

    SET @From = @To + 1;
    CHECKPOINT;
END;
GO
