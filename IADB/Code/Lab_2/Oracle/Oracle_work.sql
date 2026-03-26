select fn_getstockstatus(10) as stock_status from dual;
select fn_getstockstatus(12) as stock_status from dual;
select fn_getstockstatus(999) as stock_status from dual;


select fn_canfulfillorder(7) as can_fulfill from dual;
select fn_canfulfillorder(8) as can_fulfill from dual;
select fn_canfulfillorder(999) as can_fulfill from dual;



select * from products where product_id = 28;
select stock_id, capacity, filled_part from stocks where stock_id = 10;

begin
    sp_dispatchproduct(p_productid => 28, p_quantitytodispatch => 2);
end;


select * from products where product_id = 28;
select stock_id, capacity, filled_part from stocks where stock_id = 10;

declare
    v_rc sys_refcursor;
    v_id number;
    v_name nvarchar2(200);
    v_units number;
    v_revenue number;
    v_avg number;
    v_orders number;
begin
    v_rc := fn_getmonthlyproductfinancials(3, 2026);
    loop
        fetch v_rc into v_id, v_name, v_units, v_revenue, v_avg, v_orders;
        exit when v_rc%notfound;
        dbms_output.put_line(v_id || ' | ' || v_name || ' | units: ' || v_units || ' | revenue: ' || v_revenue);
    end loop;
    close v_rc;
end;


set serveroutput on;

begin
    usp_genwarehousefinreport;
end;



select fn_getorderpackprogress(7) as pack_progress from dual;
select fn_getorderpackprogress(8) as pack_progress from dual;
select fn_getorderpackprogress(999) as pack_progress from dual;

select fn_getstockturnoverrate(10, 30) as turnover_30d from dual;
select fn_getstockturnoverrate(10, 90) as turnover_90d from dual;
select fn_getstockturnoverrate(999, 30) as turnover_30d from dual;

select task_id, priority, due_date, is_completed from tasks where is_completed = 0;

begin
    sp_escalateoverduetasks;
end;



select task_id, priority, due_date, is_completed from tasks where is_completed = 0;

select order_id, order_status, order_date from orders where order_status = 'Created';

begin
    sp_cancelstaleorders(p_staledays =>1);
end;


select order_id, order_status, order_date from orders where order_status in ('Created', 'Canceled');

select product_id, stock_id, quantity from products where product_id = 28;
select stock_id, capacity, filled_part from stocks where stock_id in (10, 11);

begin
    sp_transferproduct(p_productid => 28, p_targetstockid => 11, p_qty => 5);
end;


select product_id, stock_id, quantity from products where product_id = 28;
select stock_id, capacity, filled_part from stocks where stock_id in (10, 11);
