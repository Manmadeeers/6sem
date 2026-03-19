use Warehouse;

go

--to check the percentage of filled part of a specific stock
CREATE OR ALTER FUNCTION dbo.fn_GetStockStatus(@StockID int)
RETURNS nvarchar(20)
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Stocks WHERE Stock_ID = @StockID)
        RETURN N'NOT_FOUND';
    DECLARE @Percent float;
    SELECT @Percent = (CAST(Filled_part AS float) / CAST(Capacity AS float)) * 100.0
    FROM dbo.Stocks
    WHERE Stock_ID = @StockID;
    DECLARE @Status nvarchar(20);
    SET @Status = CASE
        WHEN @Percent <= 20.0 THEN N'LOW'
        WHEN @Percent >= 95.0 THEN N'FULL'
        ELSE N'OK'
    END;
    RETURN @Status;
END;
GO


CREATE OR ALTER FUNCTION dbo.fn_CanFulfillOrder(@OrderID int)
RETURNS bit
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE Order_ID = @OrderID)
        RETURN 0;
    DECLARE @can bit = 1;
    IF EXISTS (
        SELECT 1
        FROM dbo.Order_items oi
        JOIN dbo.Products p ON p.Product_ID = oi.Product_ID
        WHERE oi.Order_ID = @OrderID
          AND oi.Quantity > p.Quantity
    )
        SET @can = 0;
    RETURN @can;
END;
go

create or alter function fn_CalculateOrderTotal (@OrderID int)
returns decimal (19,4)
as
begin
	declare @Total decimal(19,4);

	select @Total = SUM(pi.Quantity*pi.Unit_price)
	from Pack_items pi
	join Pack p on pi.Pack_ID = p.Pack_ID
	where p.Order_ID = @OrderID;

	return ISNULL(@Total,0.0000);
end;

go

CREATE OR ALTER PROCEDURE dbo.sp_DispatchProduct
    @ProductID int,
    @QuantityToDispatch int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Validate product exists and fetch current quantities
        DECLARE @CurrentProductQty int;
        SELECT @CurrentProductQty = Quantity
        FROM dbo.Products
        WHERE Product_ID = @ProductID;

        IF @CurrentProductQty IS NULL
        BEGIN
            RAISERROR('Product not found for Product_ID = %d', 16, 1, @ProductID);
            RETURN;
        END

        -- Validate stock status for this product
        DECLARE @CurrentStockFilled int;
        SELECT @CurrentStockFilled = S.Filled_part
        FROM dbo.Stocks S
        JOIN dbo.Products P ON S.Stock_ID = P.Stock_id
        WHERE P.Product_ID = @ProductID;

        IF @CurrentStockFilled IS NULL
        BEGIN
            RAISERROR('Stock not found for Product_ID = %d', 16, 1, @ProductID);
            RETURN;
        END

        -- Guard against underflow
        IF @CurrentProductQty < @QuantityToDispatch
            RAISERROR('Insufficient product quantity', 16, 1);

        IF @CurrentStockFilled < @QuantityToDispatch
            RAISERROR('Insufficient stock filled in warehouse', 16, 1);

        -- Perform dispatch atomically
        BEGIN TRANSACTION;

            UPDATE dbo.Products
            SET Quantity = Quantity - @QuantityToDispatch
            WHERE Product_ID = @ProductID;

            UPDATE dbo.Stocks
            SET Filled_part = Filled_part - @QuantityToDispatch
            FROM dbo.Stocks S
            JOIN dbo.Products P ON S.Stock_ID = P.Stock_id
            WHERE P.Product_ID = @ProductID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

go

create or alter function dbo.fn_GetUserTaskSummary (@UserID int)
returns table
as 
return(
	select 
		U.Email,
		U.Role,
		(select count(*) from Tasks where User_ID = @UserID and Is_completed = 1) as Completed_tasks,
		(select count(*) from Tasks where User_ID = @UserID and Is_completed = 0 and Priority = 'Highest') as Urgent_Pending
	from Users U
	where U.User_ID = @UserID
);

go

create procedure sp_AdjustStockCapacity
	@StockID int,
	@NewCapacity int
as
begin
	if @NewCapacity < (select Filled_part from Stocks where Stock_ID=@StockID)
	begin
		print 'Error: New capacity cannot be less that the currently filled volume';
	end
	else
	begin
		update Stocks
		set Capacity = @NewCapacity
		where Stock_ID=@StockID;
		print 'Stock capacity updated successfully';
	end
end;

go

CREATE FUNCTION dbo.fn_GetMonthlyProductFinancials (
    @ReportMonth INT,
    @ReportYear INT
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        P.Product_ID,
        P.Name AS Product_Name,
        SUM(PI.Quantity) AS Total_Units_Sold,
        SUM(PI.Quantity * PI.Unit_price) AS Total_Revenue,
        CAST(AVG(PI.Unit_price) AS DECIMAL(19,4)) AS Avg_Selling_Price,
        COUNT(DISTINCT PK.Order_ID) AS Total_Orders_Fulfilled
    FROM Products P
    JOIN Pack_items PI ON P.Product_ID = PI.Product_ID
    JOIN Pack PK ON PI.Pack_ID = PK.Pack_ID
    WHERE MONTH(PK.Pack_date) = @ReportMonth 
      AND YEAR(PK.Pack_date) = @ReportYear
      AND PK.Pack_status = 'Shipped'
    GROUP BY P.Product_ID, P.Name
);

go

CREATE PROCEDURE dbo.usp_GenerateWarehouseFinancialReport
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '--- WAREHOUSE FINANCIAL SUMMARY REPORT ---';
    PRINT 'Generated on: ' + CAST(GETDATE() AS VARCHAR(25));
    PRINT '------------------------------------------';
    -- 1. Shipped Items
    DECLARE @RealizedRevenue DECIMAL(19,4);
    SELECT @RealizedRevenue = ISNULL(SUM(Quantity * Unit_price), 0)
    FROM Pack_items pi
    JOIN Pack p ON pi.Pack_ID = p.Pack_ID
    WHERE p.Pack_status = 'Shipped';

    -- 2.Orders in 'Created' or 'In work'
    DECLARE @PendingRevenue DECIMAL(19,4);
    SELECT @PendingRevenue = ISNULL(SUM(Total_amount), 0)
    FROM Orders
    WHERE Order_status IN ('Created', 'In work');

    -- 3 Value of current stock

    DECLARE @InventoryValue DECIMAL(19,4);
    SELECT @InventoryValue = ISNULL(SUM(Quantity * Price), 0)
    FROM Products;

    -- Final Result
    SELECT 
        @RealizedRevenue AS Realized_Revenue_USD,
        @PendingRevenue AS Pending_Pipeline_USD,
        @InventoryValue AS Current_Inventory_Value_USD,
        (@RealizedRevenue + @PendingRevenue) AS Total_Projected_Revenue_USD;

    -- Detailed Status 

    SELECT 
        Order_status, 
        COUNT(Order_ID) AS Order_Count, 
        SUM(Total_amount) AS Status_Total_USD
    FROM Orders
    GROUP BY Order_status;
END;