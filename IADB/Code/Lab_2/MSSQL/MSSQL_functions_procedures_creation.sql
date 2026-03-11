use Warehouse;

go

--to check the percentage of filled part of a specific stock
create function fn_GetStockStatus(@StockID int)
returns nvarchar(20)
as 
begin
	declare @Status nvarchar(20);
	declare @Percent float;

	select @Percent  = (CAST(Filled_part as float)/CAST(Capacity as float))*100
	from Stocks
	where Stock_ID = @StockID;

	set @Status = CASE
		WHEN @Percent<=20 THEN 'LOW'
		WHEN @Percent>=95 THEN 'FULL'
		ELSE 'OK'
	end;

	return @Status
end;
go


create function fn_CanFulfillOrder(@OrderID int)
returns bit
as
begin
 declare @can bit = 1;

 if exists(
	select 1
	from Order_items oi
	join Products p on p.Product_ID = oi.Product_ID
	where oi.Order_ID = @OrderID
	and oi.Quantity>P.Quantity
 )
 set @can = 0;

 return @can;
end;

go

create function fn_CalculateOrderTotal (@OrderID int)
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

create procedure sp_DispatchProduct
	@ProductID int,
	@QuantityToDispatch int
as
begin
	set nocount on;
	begin transaction;

	begin try
		if(select Quantity from Products where Product_ID=@ProductID) < @QuantityToDispatch
		begin
			raiserror('Insufficient stock to fulfill dispatch.', 16,1);
			rollback transaction;
			return;
		end;

		update Products
		set Quantity = Quantity-@QuantityToDispatch
		where Product_ID=@ProductID;

		update S
		set Filled_part = Filled_part - @QuantityToDispatch
		from Stocks S
		join Products P on S.Stock_ID = P.Stock_id
		where P.Product_ID=@ProductID;

		commit transaction;
	end try
	begin catch
		rollback transaction;
		throw;
	end catch
end;
go 

go

create function dbo.fn_GetUserTaskSummary (@UserID int)
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