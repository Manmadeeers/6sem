USE warehouse;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Optional reset block (uncomment if you want a fresh refill)
BEGIN TRAN;
DELETE FROM pack_items;
DELETE FROM pack;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM tasks;
DELETE FROM products;
DELETE FROM users;
DELETE FROM stocks;

DBCC CHECKIDENT ('pack_items', RESEED, 0);
DBCC CHECKIDENT ('pack', RESEED, 0);
DBCC CHECKIDENT ('order_items', RESEED, 0);
DBCC CHECKIDENT ('orders', RESEED, 0);
DBCC CHECKIDENT ('tasks', RESEED, 0);
DBCC CHECKIDENT ('products', RESEED, 0);
DBCC CHECKIDENT ('users', RESEED, 0);
DBCC CHECKIDENT ('stocks', RESEED, 0);
COMMIT;
GO
*/

BEGIN TRAN;

------------------------------------------------------------
-- 1) Stocks (12 warehouses/zones)
------------------------------------------------------------
INSERT INTO stocks (capacity, filled_part, description)
VALUES
(1800, 0, N'North Hub A1'),
(2200, 0, N'North Hub A2'),
(1500, 0, N'East Distribution B1'),
(2600, 0, N'East Distribution B2'),
(1400, 0, N'South Cold Storage C1'),
(2000, 0, N'South Dry Storage C2'),
(3000, 0, N'Central Bulk D1'),
(3200, 0, N'Central Bulk D2'),
(1700, 0, N'West Transit E1'),
(1900, 0, N'West Transit E2'),
(2100, 0, N'Returns & QC F1'),
(1600, 0, N'Fast-Pick Zone G1');

------------------------------------------------------------
-- 2) Users (40 users, realistic roles/emails)
------------------------------------------------------------
;WITH N AS (
    SELECT TOP (40) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO users (email, role, password_hash, created_at)
SELECT
    CONCAT('user', FORMAT(n, '000'), '@warehouse.local') AS email,
    CASE 
        WHEN n BETWEEN 1 AND 18 THEN 'Operator'
        WHEN n BETWEEN 19 AND 28 THEN 'Manager'
        WHEN n BETWEEN 29 AND 35 THEN 'Accountant'
        ELSE 'Admin'
    END AS role,
    HASHBYTES('SHA2_512', CONCAT('Pwd#', n, ':', NEWID(), ':warehouse_seed')) AS password_hash,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 540, SYSDATETIME())
FROM N;

------------------------------------------------------------
-- 3) Products (180 products distributed across stocks)
------------------------------------------------------------
;WITH N AS (
    SELECT TOP (180) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO products (stock_id, name, price, quantity)
SELECT
    ((n - 1) % 12) + 1 AS stock_id,
    CONCAT(
        CASE ((n - 1) % 10) + 1
            WHEN 1 THEN N'Industrial Gloves'
            WHEN 2 THEN N'Packing Tape'
            WHEN 3 THEN N'Cardboard Box'
            WHEN 4 THEN N'Barcode Label'
            WHEN 5 THEN N'Pallet Wrap'
            WHEN 6 THEN N'Safety Helmet'
            WHEN 7 THEN N'Cleaning Kit'
            WHEN 8 THEN N'Battery Pack'
            WHEN 9 THEN N'RF Scanner'
            ELSE N'Plastic Container'
        END,
        N' ',
        RIGHT('000' + CAST(n AS varchar(10)), 3)
    ) AS name,
    CAST((8 + (ABS(CHECKSUM(NEWID())) % 4500) / 10.0) AS decimal(19,4)) AS price,
    5 + (ABS(CHECKSUM(NEWID())) % 55) AS quantity
FROM N;

------------------------------------------------------------
-- 4) Tasks (220 tasks assigned to users)
------------------------------------------------------------
;WITH N AS (
    SELECT TOP (220) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO tasks (user_id, due_date, priority, description, is_completed)
SELECT
    1 + (ABS(CHECKSUM(NEWID())) % 40) AS user_id,
    DATEADD(DAY, (ABS(CHECKSUM(NEWID())) % 45) - 10, SYSDATETIME()) AS due_date,
    CASE ABS(CHECKSUM(NEWID())) % 10
        WHEN 0 THEN 'Highest'
        WHEN 1 THEN 'High'
        WHEN 2 THEN 'High'
        WHEN 3 THEN 'Moderate'
        WHEN 4 THEN 'Moderate'
        WHEN 5 THEN 'Moderate'
        WHEN 6 THEN 'Moderate'
        ELSE 'Low'
    END AS priority,
    CONCAT(
        N'Task #', n, N': ',
        CASE (n % 8)
            WHEN 0 THEN N'Cycle count for zone'
            WHEN 1 THEN N'Restock fast-pick shelves'
            WHEN 2 THEN N'Quality check incoming batch'
            WHEN 3 THEN N'Prepare outbound shipment docs'
            WHEN 4 THEN N'Investigate inventory mismatch'
            WHEN 5 THEN N'Update damaged goods report'
            WHEN 6 THEN N'Verify order consolidation'
            ELSE N'Check replenishment request'
        END
    ) AS description,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 27 THEN 1 ELSE 0 END AS is_completed
FROM N;

------------------------------------------------------------
-- 5) Orders (120 orders)
------------------------------------------------------------
;WITH N AS (
    SELECT TOP (120) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO orders (order_date, order_status, total_amount)
SELECT
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 120), DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 24, SYSDATETIME())) AS order_date,
    CASE ABS(CHECKSUM(NEWID())) % 100
        WHEN 0 THEN 'Canceled'
        WHEN 1 THEN 'Canceled'
        WHEN 2 THEN 'Canceled'
        WHEN 3 THEN 'Shipped'
        WHEN 4 THEN 'Shipped'
        WHEN 5 THEN 'Shipped'
        WHEN 6 THEN 'In work'
        WHEN 7 THEN 'In work'
        ELSE 'Created'
    END AS order_status,
    0.0000
FROM N;

------------------------------------------------------------
-- 6) Order items (2..5 items per order, unique product per order)
------------------------------------------------------------
;WITH O AS (
    SELECT order_id
    FROM orders
),
Picks AS (
    SELECT
        o.order_id,
        p.product_id,
        ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY NEWID()) AS rn,
        2 + (ABS(CHECKSUM(NEWID())) % 4) AS items_needed
    FROM O o
    CROSS JOIN products p
),
Chosen AS (
    SELECT order_id, product_id
    FROM Picks
    WHERE rn <= items_needed
)
INSERT INTO order_items (order_id, product_id, quantity)
SELECT
    c.order_id,
    c.product_id,
    1 + (ABS(CHECKSUM(NEWID())) % 12) AS quantity
FROM Chosen c;

------------------------------------------------------------
-- 7) Recalculate order totals from order_items + product price
------------------------------------------------------------
;WITH Totals AS (
    SELECT
        oi.order_id,
        SUM(CAST(oi.quantity * p.price AS decimal(19,4))) AS total_amount
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY oi.order_id
)
UPDATE o
SET o.total_amount = t.total_amount
FROM orders o
JOIN Totals t ON t.order_id = o.order_id;

------------------------------------------------------------
-- 8) Pack records for most orders (not all created/canceled are packed)
------------------------------------------------------------
INSERT INTO pack (user_id, order_id, pack_date, pack_status)
SELECT
    1 + (ABS(CHECKSUM(NEWID())) % 18) AS user_id, -- mostly operators
    o.order_id,
    DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 72, o.order_date) AS pack_date,
    CASE o.order_status
        WHEN 'Shipped' THEN 'Shipped'
        WHEN 'In work' THEN 'Packed'
        ELSE CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 45 THEN 'Packed' ELSE 'Not packed' END
    END AS pack_status
FROM orders o
WHERE o.order_status <> 'Canceled'
  AND ABS(CHECKSUM(NEWID())) % 100 < 88; -- ~88% of non-canceled orders have pack rows

------------------------------------------------------------
-- 9) Pack items copied from order items with current product prices
------------------------------------------------------------
INSERT INTO pack_items (pack_id, product_id, quantity, unit_price)
SELECT
    pk.pack_id,
    oi.product_id,
    CASE 
        WHEN pk.pack_status = 'Not packed' THEN 0 + oi.quantity
        ELSE oi.quantity
    END AS quantity,
    p.price AS unit_price
FROM pack pk
JOIN order_items oi ON oi.order_id = pk.order_id
JOIN products p ON p.product_id = oi.product_id;

------------------------------------------------------------
-- 10) Update stock filled_part from product quantities
------------------------------------------------------------
;WITH StockLoad AS (
    SELECT stock_id, SUM(quantity) AS used_capacity
    FROM products
    GROUP BY stock_id
)
UPDATE s
SET s.filled_part = sl.used_capacity
FROM stocks s
JOIN StockLoad sl ON sl.stock_id = s.stock_id;

COMMIT;
GO

-- Quick sanity checks:
SELECT COUNT(*) AS stocks_count FROM stocks;
SELECT COUNT(*) AS users_count FROM users;
SELECT COUNT(*) AS products_count FROM products;
SELECT COUNT(*) AS tasks_count FROM tasks;
SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS order_items_count FROM order_items;
SELECT COUNT(*) AS pack_count FROM pack;
SELECT COUNT(*) AS pack_items_count FROM pack_items;

SELECT TOP (20) * FROM orders ORDER BY order_id DESC;
SELECT TOP (20) * FROM pack ORDER BY pack_id DESC;


select * from Stocks;