CREATE INDEX IX_Users_Email ON Users(Email);

CREATE INDEX IX_Users_Role ON Users(User_Role);

CREATE INDEX IX_Products_StockID ON Products(Stock_id);

CREATE INDEX IX_Products_Name ON Products(Name);

CREATE INDEX IX_Tasks_User_Comp_Due ON Tasks(User_ID, Is_completed, Due_date);

CREATE INDEX IX_OrderItems_OrderID ON Order_items(Order_ID);

CREATE INDEX IX_OrderItems_ProductID ON Order_items(Product_ID);