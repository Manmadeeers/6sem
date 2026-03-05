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