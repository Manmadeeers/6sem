use Warehouse;
go

create nonclustered index IX_Users_Email on Users(Email);
create nonclustered index IX_Users_Role on Users(Role);

create nonclustered index IX_Products_StodkID on Products(Stock_ID);
create nonclustered index IX_Products_Name on Products(Name);


create nonclustered index IX_Tasks_Users_Completed on Tasks(User_ID,Is_completed) include (Due_date);

create nonclustered index IX_OrderItems_OrderID on Order_items(Order_ID);
create nonclustered index IX_OrderItems_ProductID on Order_items(Product_ID);

go