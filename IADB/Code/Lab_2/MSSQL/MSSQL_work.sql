use Warehouse;

go

-- 1) fn_GetStockStatus

select dbo.fn_GetStockStatus(1) as StockStatus       -- returns 'OK', 'LOW', or 'FULL'
select dbo.fn_GetStockStatus(999) as StockStatus	--non existent stock


-- 2) fn_CanFulfillOrder

SELECT dbo.fn_CanFulfillOrder(1) AS CanFulfill;          -- 1 = true, 0 = false

SELECT dbo.fn_CanFulfillOrder(999) AS CanFulfill;        -- non existent order


-- 3) fn_CalculateOrderTotal

SELECT dbo.fn_CalculateOrderTotal(1) AS OrderTotal;  -- total for Order_ID = 1

SELECT dbo.fn_CalculateOrderTotal(999) AS OrderTotal; --non existent order




-- 4) sp_DispatchProduct
EXEC dbo.sp_DispatchProduct @ProductID = 1, @QuantityToDispatch = 2;

select * from Products where Product_ID=1;
SELECT Stock_ID, Capacity, Filled_part FROM dbo.Stocks WHERE Stock_ID = 1;


-- 5) fn_GetUserTaskSummary (TVF)

SELECT * FROM dbo.fn_GetUserTaskSummary(2);
SELECT * FROM dbo.fn_GetUserTaskSummary(100);

select * from Products where Stock_id=1;


-- 6) sp_AdjustStockCapacity

EXEC dbo.sp_AdjustStockCapacity @StockID = 1, @NewCapacity = 6001;
select * from Stocks where Stock_ID=1;


-- 7) dbo.fn_GetMonthlyProductFinancials
SELECT * FROM dbo.fn_GetMonthlyProductFinancials(3,2026);
SELECT * FROM dbo.fn_GetMonthlyProductFinancials(13,2026);


-- 8) dbo.usp_GenerateWarehouseFinancialReport
EXEC dbo.usp_GenerateWarehouseFinancialReport; 