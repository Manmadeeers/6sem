USE warehouse;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  ВАЖНО:
  - Скрипт удаляет данные необратимо.
  - Делайте бэкап перед запуском.
  - Логика: удаляем "старую половину" по ID, с учетом FK-зависимостей.
*/

------------------------------------------------------------
-- 0) Посмотреть исходные количества
------------------------------------------------------------
SELECT 'stocks'      AS table_name, COUNT(*) AS cnt FROM dbo.stocks
UNION ALL SELECT 'users',      COUNT(*) FROM dbo.users
UNION ALL SELECT 'products',   COUNT(*) FROM dbo.products
UNION ALL SELECT 'tasks',      COUNT(*) FROM dbo.tasks
UNION ALL SELECT 'orders',     COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items',COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'pack',       COUNT(*) FROM dbo.pack
UNION ALL SELECT 'pack_items', COUNT(*) FROM dbo.pack_items;
GO

------------------------------------------------------------
-- 1) Удаляем половину orders (и все зависимые строки)
------------------------------------------------------------
IF OBJECT_ID('tempdb..#del_orders') IS NOT NULL DROP TABLE #del_orders;
SELECT TOP (
    SELECT COUNT(*) / 2 FROM dbo.orders
) order_id
INTO #del_orders
FROM dbo.orders
ORDER BY order_id ASC; -- удаляем "старую" половину

DELETE pi
FROM dbo.pack_items pi
JOIN dbo.pack p ON p.pack_id = pi.pack_id
JOIN #del_orders d ON d.order_id = p.order_id;

DELETE p
FROM dbo.pack p
JOIN #del_orders d ON d.order_id = p.order_id;

DELETE oi
FROM dbo.order_items oi
JOIN #del_orders d ON d.order_id = oi.order_id;

DELETE o
FROM dbo.orders o
JOIN #del_orders d ON d.order_id = o.order_id;

CHECKPOINT;
GO

------------------------------------------------------------
-- 2) Удаляем половину users (и зависимые tasks/pack/pack_items)
------------------------------------------------------------
IF OBJECT_ID('tempdb..#del_users') IS NOT NULL DROP TABLE #del_users;
SELECT TOP (
    SELECT COUNT(*) / 2 FROM dbo.users
) user_id
INTO #del_users
FROM dbo.users
ORDER BY user_id ASC;

DELETE pi
FROM dbo.pack_items pi
JOIN dbo.pack p ON p.pack_id = pi.pack_id
JOIN #del_users d ON d.user_id = p.user_id;

DELETE p
FROM dbo.pack p
JOIN #del_users d ON d.user_id = p.user_id;

DELETE t
FROM dbo.tasks t
JOIN #del_users d ON d.user_id = t.user_id;

DELETE u
FROM dbo.users u
JOIN #del_users d ON d.user_id = u.user_id;

CHECKPOINT;
GO

------------------------------------------------------------
-- 3) Удаляем половину stocks (через products и их зависимости)
------------------------------------------------------------
IF OBJECT_ID('tempdb..#del_stocks') IS NOT NULL DROP TABLE #del_stocks;
SELECT TOP (
    SELECT COUNT(*) / 2 FROM dbo.stocks
) stock_id
INTO #del_stocks
FROM dbo.stocks
ORDER BY stock_id ASC;

IF OBJECT_ID('tempdb..#del_products_by_stocks') IS NOT NULL DROP TABLE #del_products_by_stocks;
SELECT p.product_id
INTO #del_products_by_stocks
FROM dbo.products p
JOIN #del_stocks s ON s.stock_id = p.stock_id;

DELETE pi
FROM dbo.pack_items pi
JOIN #del_products_by_stocks d ON d.product_id = pi.product_id;

DELETE oi
FROM dbo.order_items oi
JOIN #del_products_by_stocks d ON d.product_id = oi.product_id;

DELETE p
FROM dbo.products p
JOIN #del_products_by_stocks d ON d.product_id = p.product_id;

DELETE s
FROM dbo.stocks s
JOIN #del_stocks d ON d.stock_id = s.stock_id;

CHECKPOINT;
GO

------------------------------------------------------------
-- 4) Дочистка: если в products осталось больше половины, урезаем до половины
--    (после шага 3 обычно уже <= 50%, но на случай перекосов данных)
------------------------------------------------------------
DECLARE @products_to_delete INT =
(
    SELECT CASE WHEN COUNT(*) > 1 THEN COUNT(*) / 2 ELSE 0 END
    FROM dbo.products
);

IF @products_to_delete > 0
BEGIN
    IF OBJECT_ID('tempdb..#del_products_direct') IS NOT NULL DROP TABLE #del_products_direct;
    SELECT TOP (@products_to_delete) product_id
    INTO #del_products_direct
    FROM dbo.products
    ORDER BY product_id ASC;

    DELETE pi
    FROM dbo.pack_items pi
    JOIN #del_products_direct d ON d.product_id = pi.product_id;

    DELETE oi
    FROM dbo.order_items oi
    JOIN #del_products_direct d ON d.product_id = oi.product_id;

    DELETE p
    FROM dbo.products p
    JOIN #del_products_direct d ON d.product_id = p.product_id;
END

CHECKPOINT;
GO

------------------------------------------------------------
-- 5) Финальные количества
------------------------------------------------------------
SELECT 'stocks'      AS table_name, COUNT(*) AS cnt FROM dbo.stocks
UNION ALL SELECT 'users',      COUNT(*) FROM dbo.users
UNION ALL SELECT 'products',   COUNT(*) FROM dbo.products
UNION ALL SELECT 'tasks',      COUNT(*) FROM dbo.tasks
UNION ALL SELECT 'orders',     COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items',COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'pack',       COUNT(*) FROM dbo.pack
UNION ALL SELECT 'pack_items', COUNT(*) FROM dbo.pack_items;
GO