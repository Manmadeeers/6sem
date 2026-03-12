CREATE OR REPLACE FUNCTION fn_GetStockStatus(p_StockID IN NUMBER) RETURN NVARCHAR2 IS
v_Status NVARCHAR2(20); v_Percent NUMBER;
BEGIN
SELECT (Filled_part/Capacity)*100 INTO v_Percent FROM Stocks WHERE Stock_ID = p_StockID;
v_Status := CASE WHEN v_Percent <= 20 THEN 'LOW' WHEN v_Percent >= 95 THEN 'FULL' ELSE 'OK' END;
RETURN v_Status;
END;
/
CREATE OR REPLACE FUNCTION fn_CanFulfillOrder(p_OrderID IN NUMBER) RETURN NUMBER IS
v_count NUMBER;
BEGIN
SELECT COUNT(*) INTO v_count FROM Order_items oi JOIN Products p ON p.Product_ID = oi.Product_ID WHERE oi.Order_ID = p_OrderID AND oi.Quantity > p.Quantity;
IF v_count > 0 THEN RETURN 0; ELSE RETURN 1; END IF;
END;
/
CREATE OR REPLACE FUNCTION fn_CalculateOrderTotal(p_OrderID IN NUMBER) RETURN NUMBER IS
v_Total NUMBER(19,4);
BEGIN
SELECT SUM(pi.Quantity*pi.Unit_price) INTO v_Total FROM Pack_items pi JOIN Pack p ON pi.Pack_ID = p.Pack_ID WHERE p.Order_ID = p_OrderID;
RETURN NVL(v_Total, 0.0000);
END;
/
CREATE OR REPLACE PROCEDURE sp_DispatchProduct(p_ProductID IN NUMBER, p_QuantityToDispatch IN NUMBER) AS
v_CurrQty NUMBER;
BEGIN
SELECT Quantity INTO v_CurrQty FROM Products WHERE Product_ID = p_ProductID FOR UPDATE;
IF v_CurrQty < p_QuantityToDispatch THEN raise_application_error(-20001, 'Insufficient stock to fulfill dispatch.'); END IF;
UPDATE Products SET Quantity = Quantity - p_QuantityToDispatch WHERE Product_ID = p_ProductID;
UPDATE Stocks SET Filled_part = Filled_part - p_QuantityToDispatch WHERE Stock_ID = (SELECT Stock_id FROM Products WHERE Product_ID = p_ProductID);
COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/
CREATE OR REPLACE FUNCTION fn_GetUserTaskSummary(p_UserID IN NUMBER) RETURN SYS_REFCURSOR IS
v_rc SYS_REFCURSOR;
BEGIN
OPEN v_rc FOR SELECT U.Email, U.User_Role, (SELECT COUNT(*) FROM Tasks WHERE User_ID = p_UserID AND Is_completed = 1) AS Completed_tasks, (SELECT COUNT(*) FROM Tasks WHERE User_ID = p_UserID AND Is_completed = 0 AND Priority = 'Highest') AS Urgent_Pending FROM Users U WHERE U.User_ID = p_UserID;
RETURN v_rc;
END;
/
CREATE OR REPLACE PROCEDURE sp_AdjustStockCapacity(p_StockID IN NUMBER, p_NewCapacity IN NUMBER) AS
v_Filled NUMBER;
BEGIN
SELECT Filled_part INTO v_Filled FROM Stocks WHERE Stock_ID = p_StockID;
IF p_NewCapacity < v_Filled THEN DBMS_OUTPUT.PUT_LINE('Error: New capacity cannot be less than the currently filled volume'); ELSE UPDATE Stocks SET Capacity = p_NewCapacity WHERE Stock_ID = p_StockID; DBMS_OUTPUT.PUT_LINE('Stock capacity updated successfully'); END IF;
END;
/
CREATE OR REPLACE FUNCTION fn_GetMonthlyProductFinancials(p_Month IN NUMBER, p_Year IN NUMBER) RETURN SYS_REFCURSOR IS
v_rc SYS_REFCURSOR;
BEGIN
OPEN v_rc FOR SELECT P.Product_ID, P.Name AS Product_Name, SUM(PI.Quantity) AS Total_Units_Sold, SUM(PI.Quantity * PI.Unit_price) AS Total_Revenue, AVG(PI.Unit_price) AS Avg_Selling_Price, COUNT(DISTINCT PK.Order_ID) AS Total_Orders_Fulfilled FROM Products P JOIN Pack_items PI ON P.Product_ID = PI.Product_ID JOIN Pack PK ON PI.Pack_ID = PK.Pack_ID WHERE EXTRACT(MONTH FROM PK.Pack_date) = p_Month AND EXTRACT(YEAR FROM PK.Pack_date) = p_Year AND PK.Pack_status = 'Shipped' GROUP BY P.Product_ID, P.Name;
RETURN v_rc;
END;
/
CREATE OR REPLACE PROCEDURE usp_GenWarehouseFinReport AS
v_Realized NUMBER(19,4); v_Pending NUMBER(19,4); v_Inventory NUMBER(19,4);
BEGIN
DBMS_OUTPUT.PUT_LINE('--- WAREHOUSE FINANCIAL SUMMARY REPORT ---'); DBMS_OUTPUT.PUT_LINE('Generated on: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
SELECT NVL(SUM(Quantity * Unit_price), 0) INTO v_Realized FROM Pack_items pi JOIN Pack p ON pi.Pack_ID = p.Pack_ID WHERE p.Pack_status = 'Shipped';
SELECT NVL(SUM(Total_amount), 0) INTO v_Pending FROM Orders WHERE Order_status IN ('Created', 'In work');
SELECT NVL(SUM(Quantity * Price), 0) INTO v_Inventory FROM Products;
DBMS_OUTPUT.PUT_LINE('Realized Revenue: ' || v_Realized); DBMS_OUTPUT.PUT_LINE('Pending Pipeline: ' || v_Pending); DBMS_OUTPUT.PUT_LINE('Inventory Value: ' || v_Inventory); DBMS_OUTPUT.PUT_LINE('Total Projected: ' || (v_Realized + v_Pending));
END;
/
