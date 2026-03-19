use Warehouse;
go

INSERT INTO Stocks (Capacity, Filled_part, Description) VALUES 

(5000, 0, N'Main Refrigerated Zone - Sector A'),

(10000, 0, N'Dry Goods Storage - Sector B'),

(2000, 0, N'Hazardous Materials - Locked Room'),

(7500, 0, N'Bulk Pallet Racking - Sector D'),

(1500, 0, N'High-Value Electronics Vault');

GO

INSERT INTO Users (Email, Role, Password_hash) VALUES 

('admin@warehouse.com', 'Admin', 0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF),

('manager.john@warehouse.com', 'Manager', 0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890),

('op.sarah@warehouse.com', 'Operator', 0x55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555),

('op.mike@warehouse.com', 'Operator', 0x66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666),

('accountant.lisa@warehouse.com', 'Accountant', 0x77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777);

GO


INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES 

(1, N'Frozen Salmon Fillets 10kg', 120.5000, 50),

(1, N'Organic Milk 1L (Case of 12)', 24.0000, 200),

(2, N'Premium Basmati Rice 5kg', 15.9900, 500),

(2, N'Whole Wheat Flour 2kg', 4.5000, 1000),

(5, N'Smartphone Model X-200', 899.0000, 30),

(5, N'Laptop Pro 15-inch', 1450.0000, 15),

(3, N'Industrial Cleaning Acid', 55.0000, 10),

(4, N'Standard Shipping Pallet (Wooden)', 12.0000, 300);

GO


INSERT INTO Tasks (User_ID, Due_date, Priority, Description, Is_completed) VALUES 

(3, DATEADD(day, 1, GETDATE()), 'High', N'Unload incoming shipment from Organic Farms Ltd.', 0),

(3, DATEADD(day, -1, GETDATE()), 'Moderate', N'Daily inventory count of Sector A', 1),

(4, DATEADD(hour, 4, GETDATE()), 'Highest', N'Urgent repackaging of damaged Laptop Pro boxes', 0),

(2, DATEADD(day, 3, GETDATE()), 'Low', N'Monthly safety inspection of Sector C', 0);

GO


INSERT INTO Orders (Order_date, Order_status, Total_amount) VALUES 

(DATEADD(day, -5, GETDATE()), 'Shipped', 1545.0000),

(DATEADD(day, -2, GETDATE()), 'In work', 2400.0000),

(DATEADD(hour, -2, GETDATE()), 'Created', 500.0000),

(DATEADD(day, -10, GETDATE()), 'Canceled', 0.0000);

GO


INSERT INTO Order_items (Order_ID, Product_ID, Quantity) VALUES 

(1, 1, 2), -- 2 Salmon

(1, 3, 10), -- 10 Rice

(2, 5, 2), -- 2 Smartphones

(2, 2, 5), -- 5 Milk cases

(3, 8, 20); -- 20 Pallets

GO

INSERT INTO Pack (User_ID, Order_ID, Pack_date, Pack_status) VALUES 

(3, 1, DATEADD(day, -4, GETDATE()), 'Shipped'),

(4, 2, DATEADD(day, -1, GETDATE()), 'Packed'),

(3, 3, GETDATE(), 'Not packed');

GO





