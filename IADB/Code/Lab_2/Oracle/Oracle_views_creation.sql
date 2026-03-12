CREATE OR REPLACE VIEW CompletedOperatorTasks AS
SELECT
    u.User_ID,
    u.Email,
    COUNT(t.Task_ID) AS Completed_Tasks_Count
FROM
    Users u
INNER JOIN 
    Tasks t ON u.User_ID = t.User_ID
WHERE 
    u.User_Role = 'Operator'
AND
    t.Is_completed = 1
GROUP BY
    u.User_ID,
    u.Email;


CREATE OR REPLACE VIEW MonthlyFinancialSummary AS
WITH DateRange AS (
    SELECT
        TRUNC(SYSDATE, 'MM') AS StartOfMonth,
        LAST_DAY(TRUNC(SYSDATE, 'MM')) + (1 - 1/86400) AS EndOfMonth
    FROM DUAL 
),

InboundValue AS (
    SELECT NVL(SUM(Price * Quantity), 0) AS Total_Stock_Value
    FROM Products
),

OrderValue AS (
    SELECT NVL(SUM(Total_amount), 0) AS Total_Ordered_Value
    FROM Orders, DateRange
    WHERE Order_date BETWEEN DateRange.StartOfMonth AND DateRange.EndOfMonth
),

PackedValue AS (
    SELECT NVL(SUM(pi.Quantity * pi.Unit_price), 0) AS Total_Packed_Value
    FROM Pack_items pi
    INNER JOIN Pack p ON pi.Pack_ID = p.Pack_ID
    CROSS JOIN DateRange
    WHERE p.Pack_date BETWEEN DateRange.StartOfMonth AND DateRange.EndOfMonth
)

SELECT
    (SELECT StartOfMonth FROM DateRange) AS ReportMonthStart,
    iv.Total_Stock_Value AS Current_Inventory_Value, 
    ov.Total_Ordered_Value AS Monthly_Orders_Total,
    pv.Total_Packed_Value AS Monthly_Packed_Total,
    (ov.Total_Ordered_Value - pv.Total_Packed_Value) AS Unpacked_Order_Gap,
    CASE 
        WHEN ov.Total_Ordered_Value = 0 THEN 0
        ELSE (pv.Total_Packed_Value / ov.Total_Ordered_Value) * 100
    END AS Fulfillment_Rate_Percentage
FROM InboundValue iv, OrderValue ov, PackedValue pv;