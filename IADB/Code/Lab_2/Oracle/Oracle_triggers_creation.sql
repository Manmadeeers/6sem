CREATE OR REPLACE TRIGGER trg_UpdateStockCapacity
AFTER INSERT OR UPDATE OR DELETE ON Products
FOR EACH ROW
BEGIN
    -- 1. Handle the "OLD" stock (Subtract quantity on DELETE or UPDATE)
    IF DELETING OR UPDATING THEN
        IF :OLD.Stock_id IS NOT NULL THEN
            UPDATE Stocks
            SET Filled_part = Filled_part - :OLD.Quantity
            WHERE Stock_ID = :OLD.Stock_id;
        END IF;
    END IF;

    -- 2. Handle the "NEW" stock (Add quantity on INSERT or UPDATE)
    IF INSERTING OR UPDATING THEN
        IF :NEW.Stock_id IS NOT NULL THEN
            UPDATE Stocks
            SET Filled_part = Filled_part + :NEW.Quantity
            WHERE Stock_ID = :NEW.Stock_id;
        END IF;
    END IF;
END;
/