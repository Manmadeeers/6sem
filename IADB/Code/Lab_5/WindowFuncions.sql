USE warehouse;
GO


--orders quantity, sum, packed and delivered positions, stocks load for a quarter, half-year and year

;WITH bounds AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(MIN(d.dt)),
            MONTH(MIN(d.dt)),
            1
        ) AS min_month,
        DATEFROMPARTS(
            YEAR(MAX(d.dt)),
            MONTH(MAX(d.dt)),
            1
        ) AS max_month
    FROM
    (
        SELECT order_date AS dt FROM orders
        UNION ALL
        SELECT pack_date  AS dt FROM pack
    ) d
),
months AS
(
    SELECT min_month AS month_start
    FROM bounds

    UNION ALL

    SELECT DATEADD(MONTH, 1, m.month_start)
    FROM months m
    CROSS JOIN bounds b
    WHERE m.month_start < b.max_month
),
orders_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month_start,
        COUNT(*) AS orders_count,
        SUM(total_amount) AS orders_amount
    FROM orders
    -- если не нужны отмененные заказы, раскомментируйте:
    -- WHERE order_status <> 'Canceled'
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
),
pack_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(p.pack_date), MONTH(p.pack_date), 1) AS month_start,
        SUM(CASE
                WHEN p.pack_status IN ('Packed', 'Shipped') THEN pi.quantity
                ELSE 0
            END) AS packed_qty,
        SUM(CASE
                WHEN p.pack_status = 'Shipped' THEN pi.quantity
                ELSE 0
            END) AS shipped_qty
    FROM pack p
    JOIN pack_items pi
        ON pi.pack_id = p.pack_id
    GROUP BY DATEFROMPARTS(YEAR(p.pack_date), MONTH(p.pack_date), 1)
),
base AS
(
    SELECT
        m.month_start,
        YEAR(m.month_start) AS [year_no],
        DATEPART(QUARTER, m.month_start) AS quarter_no,
        CASE
            WHEN MONTH(m.month_start) BETWEEN 1 AND 6 THEN 1
            ELSE 2
        END AS halfyear_no,
        ISNULL(o.orders_count, 0) AS orders_count_month,
        ISNULL(o.orders_amount, 0.0000) AS orders_amount_month,
        ISNULL(p.packed_qty, 0) AS packed_qty_month,
        ISNULL(p.shipped_qty, 0) AS shipped_qty_month
    FROM months m
    LEFT JOIN orders_monthly o
        ON o.month_start = m.month_start
    LEFT JOIN pack_monthly p
        ON p.month_start = m.month_start
)
SELECT
    month_start,

    orders_count_month,
    orders_amount_month,
    packed_qty_month,
    shipped_qty_month,

    SUM(orders_count_month) OVER (
        PARTITION BY year_no, quarter_no
    ) AS orders_count_quarter,

    SUM(orders_amount_month) OVER (
        PARTITION BY year_no, quarter_no
    ) AS orders_amount_quarter,

    SUM(packed_qty_month) OVER (
        PARTITION BY year_no, quarter_no
    ) AS packed_qty_quarter,

    SUM(shipped_qty_month) OVER (
        PARTITION BY year_no, quarter_no
    ) AS shipped_qty_quarter,

    SUM(orders_count_month) OVER (
        PARTITION BY year_no, halfyear_no
    ) AS orders_count_halfyear,

    SUM(orders_amount_month) OVER (
        PARTITION BY year_no, halfyear_no
    ) AS orders_amount_halfyear,

    SUM(packed_qty_month) OVER (
        PARTITION BY year_no, halfyear_no
    ) AS packed_qty_halfyear,

    SUM(shipped_qty_month) OVER (
        PARTITION BY year_no, halfyear_no
    ) AS shipped_qty_halfyear,

    SUM(orders_count_month) OVER (
        PARTITION BY year_no
    ) AS orders_count_year,

    SUM(orders_amount_month) OVER (
        PARTITION BY year_no
    ) AS orders_amount_year,

    SUM(packed_qty_month) OVER (
        PARTITION BY year_no
    ) AS packed_qty_year,

    SUM(shipped_qty_month) OVER (
        PARTITION BY year_no
    ) AS shipped_qty_year

FROM base
ORDER BY month_start
OPTION (MAXRECURSION 32767);
GO


--


