--1 fn_GetStockStatus

select * from Stocks;
select fn_GetStockStatus(11) as Status;
select fn_GetStockStatus(111) as Status;

--2 fn_CanFulfillOrder

select * from orders;

SELECT fn_CanFulfillOrder(8) as Can;
SELECT fn_CanFulfillOrder(88) as Can;

--3 fn_CalculateOrderTotal

SELECT  fn_CalculateOrderTotal(8) as Order_total;
SELECT  fn_CalculateOrderTotal(88) as Order_total;


--4 sp_DispatchProduct

select * from Products where product_id=35;

BEGIN

    sp_DispatchProduct(p_ProductID => 35, p_QuantityToDispatch => 10);

END;

/

--5 sp_AdjustStockCapacity
SET SERVEROUTPUT ON;


BEGIN

    sp_AdjustStockCapacity(p_StockID => 10, p_NewCapacity => 10000);

END;

/


--6 usp_GenWarehouseFinReport;


SET SERVEROUTPUT ON;


EXEC usp_GenWarehouseFinReport;



--7 fn_GetUserTaskSummary

VARIABLE rc REFCURSOR;

EXEC :rc := fn_GetUserTaskSummary(1);

PRINT rc;


--8: 




