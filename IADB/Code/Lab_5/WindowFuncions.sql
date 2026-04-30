use Warehouse;

--1

DECLARE @ReportYear INT = NULL; -- например 2026; NULL = все годы

WITH months AS (
    SELECT DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month_start
    FROM orders
    UNION
    SELECT DATEFROMPARTS(YEAR(pack_date), MONTH(pack_date), 1) AS month_start
    FROM pack
),
orders_m AS (
    SELECT
        DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start,
        COUNT(*) AS orders_count,
        SUM(o.total_amount) AS orders_amount,
        SUM(CASE WHEN o.order_status = 'Shipped' THEN 1 ELSE 0 END) AS shipped_orders
    FROM orders o
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
),
pack_m AS (
    SELECT
        DATEFROMPARTS(YEAR(p.pack_date), MONTH(p.pack_date), 1) AS month_start,
        COUNT(DISTINCT p.pack_id) AS packs_count,
        SUM(CASE WHEN p.pack_status IN ('Packed', 'Shipped') THEN 1 ELSE 0 END) AS processed_packs,
        SUM(CASE WHEN p.pack_status = 'Shipped' THEN 1 ELSE 0 END) AS shipped_packs,
        SUM(pi.quantity) AS packed_items_qty,
        SUM(CASE WHEN p.pack_status = 'Shipped' THEN pi.quantity ELSE 0 END) AS shipped_items_qty
    FROM pack p
    LEFT JOIN pack_items pi ON pi.pack_id = p.pack_id
    GROUP BY DATEFROMPARTS(YEAR(p.pack_date), MONTH(p.pack_date), 1)
),
base AS (
    SELECT
        m.month_start,
        YEAR(m.month_start) AS [year_no],
        DATEPART(QUARTER, m.month_start) AS quarter_no,
        CASE WHEN MONTH(m.month_start) <= 6 THEN 1 ELSE 2 END AS halfyear_no,

        ISNULL(o.orders_count, 0) AS orders_count,
        ISNULL(o.orders_amount, 0.0000) AS orders_amount,
        ISNULL(o.shipped_orders, 0) AS shipped_orders,

        ISNULL(p.packs_count, 0) AS packs_count,
        ISNULL(p.processed_packs, 0) AS processed_packs,
        ISNULL(p.shipped_packs, 0) AS shipped_packs,
        ISNULL(p.packed_items_qty, 0) AS packed_items_qty,
        ISNULL(p.shipped_items_qty, 0) AS shipped_items_qty
    FROM months m
    LEFT JOIN orders_m o ON o.month_start = m.month_start
    LEFT JOIN pack_m p ON p.month_start = m.month_start
    WHERE @ReportYear IS NULL OR YEAR(m.month_start) = @ReportYear
)
SELECT
    month_start,
    year_no,
    quarter_no,
    halfyear_no,

    -- Помесячные итоги
    orders_count,
    orders_amount,
    shipped_orders,
    packs_count,
    processed_packs,
    shipped_packs,
    packed_items_qty,
    shipped_items_qty,

    -- Позиция месяца в периоде (ROW_NUMBER)
    ROW_NUMBER() OVER (PARTITION BY year_no, quarter_no ORDER BY month_start) AS rn_in_quarter,
    ROW_NUMBER() OVER (PARTITION BY year_no, halfyear_no ORDER BY month_start) AS rn_in_halfyear,
    ROW_NUMBER() OVER (PARTITION BY year_no ORDER BY month_start) AS rn_in_year,

    -- Квартальные итоги (window)
    SUM(orders_count)      OVER (PARTITION BY year_no, quarter_no) AS quarter_orders_count,
    SUM(orders_amount)     OVER (PARTITION BY year_no, quarter_no) AS quarter_orders_amount,
    SUM(shipped_items_qty) OVER (PARTITION BY year_no, quarter_no) AS quarter_shipped_items_qty,

    -- Полугодовые итоги (window)
    SUM(orders_count)      OVER (PARTITION BY year_no, halfyear_no) AS halfyear_orders_count,
    SUM(orders_amount)     OVER (PARTITION BY year_no, halfyear_no) AS halfyear_orders_amount,
    SUM(shipped_items_qty) OVER (PARTITION BY year_no, halfyear_no) AS halfyear_shipped_items_qty,

    -- Годовые итоги (window)
    SUM(orders_count)      OVER (PARTITION BY year_no) AS year_orders_count,
    SUM(orders_amount)     OVER (PARTITION BY year_no) AS year_orders_amount,
    SUM(shipped_items_qty) OVER (PARTITION BY year_no) AS year_shipped_items_qty

FROM base
ORDER BY month_start;
GO