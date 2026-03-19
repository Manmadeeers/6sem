-- 1) Stocks

insert into Stocks (Capacity, Filled_part, Description) values (5000, 0, N'Main Refrigerated Zone - Sector A');

insert into Stocks (Capacity, Filled_part, Description) values (10000, 0, N'Dry Goods Storage - Sector B');

insert into Stocks (Capacity, Filled_part, Description) values (2000, 0, N'Hazardous Materials - Locked Room');

insert into Stocks (Capacity, Filled_part, Description) values (7500, 0, N'Bulk Pallet Racking - Sector D');

insert into Stocks (Capacity, Filled_part, Description) values (1500, 0, N'High-Value Electronics Vault');

commit;
select * from stocks;
-- 2) Users

insert into Users (Email, User_Role, Password_hash) values (

  'admin@warehouse.com',

  'Admin',

  hextoraw('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')

);


insert into Users (Email, User_Role, Password_hash) values (

  'manager.john@warehouse.com',

  'Manager',

  hextoraw('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')

);

insert into Users (Email, User_Role, Password_hash) values (

  'op.sarah@warehouse.com',

  'Operator',

  hextoraw('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')

);

insert into Users (Email, User_Role, Password_hash) values (

  'op.mike@warehouse.com',

  'Operator',

  hextoraw('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')

);

insert into Users (Email, User_Role, Password_hash) values (

  'accountant.lisa@warehouse.com',

  'Accountant',

  hextoraw('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')

);

commit;

select * from users;

-- 3) Products

insert into Products (Stock_ID, Name, Price, Quantity) values (10, N'Frozen Salmon Fillets 10kg', 120.5000, 50);

insert into Products (Stock_ID, Name, Price, Quantity) values (11, N'Organic Milk 1L (Case of 12)', 24.0000, 200);

insert into Products (Stock_ID, Name, Price, Quantity) values (12, N'Premium Basmati Rice 5kg', 15.9900, 500);

insert into Products (Stock_ID, Name, Price, Quantity) values (12, N'Whole Wheat Flour 2kg', 4.5000, 1000);

insert into Products (Stock_ID, Name, Price, Quantity) values (14, N'Smartphone Model X-200', 899.0000, 30);

insert into Products (Stock_ID, Name, Price, Quantity) values (12, N'Laptop Pro 15-inch', 1450.0000, 15);

insert into Products (Stock_ID, Name, Price, Quantity) values (13, N'Industrial Cleaning Acid', 55.0000, 10);

insert into Products (Stock_ID, Name, Price, Quantity) values (14, N'Standard Shipping Pallet (Wooden)', 12.0000, 300);

commit;
select * from products;



-- 4) Tasks

select * from users;

insert into Tasks (User_ID, Due_date, Priority, Description, Is_Completed) 

values (8, SYSTIMESTAMP + INTERVAL '1' DAY, 'High', N'Unload incoming shipment from Organic Farms Ltd.', 0);

insert into Tasks (User_ID, Due_date, Priority, Description, Is_Completed) 

values (8, SYSTIMESTAMP - INTERVAL '1' DAY, 'Moderate', N'Daily inventory count of Sector A', 1);

insert into Tasks (User_ID, Due_date, Priority, Description, Is_Completed) 

values (10, SYSTIMESTAMP + INTERVAL '4' HOUR, 'Highest', N'Urgent repackaging of damaged Laptop Pro boxes', 0);

insert into Tasks (User_ID, Due_date, Priority, Description, Is_Completed) 

values (13, SYSTIMESTAMP + INTERVAL '3' DAY, 'Low', N'Monthly safety inspection of Sector C', 0);

commit;


select * from tasks


-- 5) Orders

insert into Orders (Order_date, Order_status, Total_amount) values (SYSTIMESTAMP, 'Shipped', 1545.0000);

insert into Orders (Order_date, Order_status, Total_amount) values (SYSTIMESTAMP, 'In work', 2400.0000);

insert into Orders (Order_date, Order_status, Total_amount) values (SYSTIMESTAMP, 'Created', 500.0000);

insert into Orders (Order_date, Order_status, Total_amount) values (SYSTIMESTAMP, 'Canceled', 0.0000);

commit;

select * from Orders;


-- 6) Order_items

select * from Orders, Products;

insert into Order_items (Order_ID, Product_ID, Quantity) values (9, 35, 2);

insert into Order_items (Order_ID, Product_ID, Quantity) values (9, 36, 10);

insert into Order_items (Order_ID, Product_ID, Quantity) values (10, 36, 2);

insert into Order_items (Order_ID, Product_ID, Quantity) values (7, 37, 5);

insert into Order_items (Order_ID, Product_ID, Quantity) values (9, 37, 20);

commit;

select * from Order_items;


-- 7) Pack

insert into Pack (User_ID, Order_ID, Pack_date, Pack_status) values (8, 7, SYSTIMESTAMP - INTERVAL '4' DAY, 'Shipped');

insert into Pack (User_ID, Order_ID, Pack_date, Pack_status) values (10, 8, SYSTIMESTAMP - INTERVAL '1' DAY, 'Packed');

insert into Pack (User_ID, Order_ID, Pack_date, Pack_status) values (12, 9, SYSTIMESTAMP, 'Not packed');

commit;

select * from pack;


-- 8) Pack_items

insert into Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) values (6, 28, 11, 120.5000);

insert into Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) values (6, 30, 10, 15.9900);

insert into Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) values (7, 35, 2, 899.0000);

insert into Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) values (8, 31, 5, 24.0000);

commit;

select * from pack_items;
