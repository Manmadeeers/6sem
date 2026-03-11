use Warehouse;

go

create trigger trg_UpdateStockCapacity--to update stock's filled part after every data manipulation
on Products
after insert, update, delete
as
begin
	set nocount on;
	update s
	set s.Filled_part = (select isnull(sum(Quantity),0) from products where Stock_id=s.Stock_ID)
	from Stocks s
	where s.Stock_ID in (select Stock_ID from inserted union select Stock_ID from deleted)
end;

go

