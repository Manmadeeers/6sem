-- 1. Populate Stocks
INSERT INTO Stocks (Capacity, Filled_part, Description) VALUES (1000, 0, 'Main Cold Storage - Section A');
INSERT INTO Stocks (Capacity, Filled_part, Description) VALUES (5000, 0, 'Dry Goods Warehouse - Zone 1');
INSERT INTO Stocks (Capacity, Filled_part, Description) VALUES (2000, 0, 'Hazardous Materials Bunker');

-- 2. Populate Users
-- Password hashes are dummy RAW values (64 bytes)
INSERT INTO Users (Email, User_Role, Password_hash) VALUES ('admin@warehouse.com', 'Admin', HEXTORAW('A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890'));
INSERT INTO Users (Email, User_Role, Password_hash) VALUES ('op1@warehouse.com', 'Operator', HEXTORAW('B1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890'));
INSERT INTO Users (Email, User_Role, Password_hash) VALUES ('mgr1@warehouse.com', 'Manager', HEXTORAW('C1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890A1B2C3D4E5F67890'));

-- 3. Populate Products
-- Stock_id values correspond to IDs generated above (1, 2, 3)
INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES (1, 'Organic Milk 1L', 2.50, 200);
INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES (1, 'Greek Yogurt 500g', 4.75, 150);
INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES (2, 'Basmati Rice 5kg', 12.00, 300);
INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES (2, 'Whole Wheat Flour 2kg', 3.50, 450);
INSERT INTO Products (Stock_id, Name, Price, Quantity) VALUES (3, 'Industrial Cleaner 5L', 25.00, 50);

-- 4. Populate Tasks
INSERT INTO Tasks (User_ID, Due_date, Priority, Description, Is_completed) 
VALUES (2, SYSTIMESTAMP + INTERVAL '1' DAY, 'High', 'Unload delivery from Truck #42', 0);
INSERT INTO Tasks (User_ID, Due_date, Priority, Description, Is_completed) 
VALUES (2, SYSTIMESTAMP - INTERVAL '2' HOUR, 'Moderate', 'Inventory count for Section A', 1);

-- 5. Populate Orders
INSERT INTO Orders (Order_date, Order_status, Total_amount) VALUES (SYSTIMESTAMP - INTERVAL '5' DAY, 'Shipped', 157.50);
INSERT INTO Orders (Order_date, Order_status, Total_amount) VALUES (SYSTIMESTAMP - INTERVAL '1' DAY, 'In work', 45.00);
INSERT INTO Orders (Order_date, Order_status, Total_amount) VALUES (SYSTIMESTAMP, 'Created', 12.00);

-- 6. Populate Order_items
INSERT INTO Order_items (Order_ID, Product_ID, Quantity) VALUES (1, 1, 10);
INSERT INTO Order_items (Order_ID, Product_ID, Quantity) VALUES (1, 2, 5);
INSERT INTO Order_items (Order_ID, Product_ID, Quantity) VALUES (2, 3, 3);

-- 7. Populate Pack (for the shipped order)
INSERT INTO Pack (User_ID, Order_ID, Pack_date, Pack_status) VALUES (2, 1, SYSTIMESTAMP - INTERVAL '4' DAY, 'Shipped');

-- 8. Populate Pack_items
INSERT INTO Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) VALUES (1, 1, 10, 2.50);
INSERT INTO Pack_items (Pack_ID, Product_ID, Quantity, Unit_price) VALUES (1, 2, 5, 4.75);

-- 9. Final Commit
COMMIT;

-- Note: The