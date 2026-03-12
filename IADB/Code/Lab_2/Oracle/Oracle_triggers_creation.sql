CREATE OR REPLACE TRIGGER trg_UpdateStockCapacity
AFTER INSERT OR UPDATE OR DELETE ON Products
FOR EACH ROW
BEGIN
    IF DELETING OR (UPDATING AND :OLD.Stock_id IS NOT NULL) THEN
        UPDATE Stocks
        SET Filled_part = (SELECT NVL(SUM(Quantity), 0) 
                           FROM Products 
                           WHERE Stock_id = :OLD.Stock_id)
        WHERE Stock_ID = :OLD.Stock_id;
    END IF;

    IF INSERTING OR (UPDATING AND :NEW.Stock_id IS NOT NULL) THEN
        UPDATE Stocks
        SET Filled_part = (SELECT NVL(SUM(Quantity), 0) 
                           FROM Products 
                           WHERE Stock_id = :NEW.Stock_id)
        WHERE Stock_ID = :NEW.Stock_id;
    END IF;
END;

/
