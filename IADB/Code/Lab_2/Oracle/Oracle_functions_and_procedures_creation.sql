create or replace function fn_getstockstatus(p_stockid in number) return nvarchar2 is
    v_status nvarchar2(20);
    v_percent number;
begin
    select (filled_part / capacity) * 100 into v_percent
    from stocks where stock_id = p_stockid;
    v_status := case
        when v_percent <= 20 then 'LOW'
        when v_percent >= 95 then 'FULL'
        else 'OK'
    end;
    return v_status;
end;

create or replace function fn_canfulfillorder(p_orderid in number) return number is
    v_count number;
begin
    select count(*) into v_count
    from order_items oi
    join products p on p.product_id = oi.product_id
    where oi.order_id = p_orderid and oi.quantity > p.quantity;
    if v_count > 0 then return 0; else return 1; end if;
end;


create or replace procedure sp_dispatchproduct(p_productid in number, p_quantitytodispatch in number) as
    v_currqty number;
begin
    select quantity into v_currqty
    from products where product_id = p_productid for update;
    if v_currqty < p_quantitytodispatch then
        raise_application_error(-20001, 'insufficient stock to fulfill dispatch.');
    end if;
    update products set quantity = quantity - p_quantitytodispatch
    where product_id = p_productid;
    update stocks set filled_part = filled_part - p_quantitytodispatch
    where stock_id = (select stock_id from products where product_id = p_productid);
    commit;
exception
    when others then rollback; raise;
end;



create or replace function fn_getmonthlyproductfinancials(p_month in number, p_year in number) return sys_refcursor is
    v_rc sys_refcursor;
begin
    open v_rc for
        select p.product_id,
               p.name as product_name,
               sum(pi.quantity) as total_units_sold,
               sum(pi.quantity * pi.unit_price) as total_revenue,
               avg(pi.unit_price) as avg_selling_price,
               count(distinct pk.order_id) as total_orders_fulfilled
        from products p
        join pack_items pi on p.product_id = pi.product_id
        join pack pk on pi.pack_id = pk.pack_id
        where extract(month from pk.pack_date) = p_month
          and extract(year from pk.pack_date) = p_year
          and pk.pack_status = 'Shipped'
        group by p.product_id, p.name;
    return v_rc;
end;


create or replace procedure usp_genwarehousefinreport as
    v_realized number(19,4);
    v_pending number(19,4);
    v_inventory number(19,4);
begin
    dbms_output.put_line('--- warehouse financial summary report ---');
    dbms_output.put_line('generated on: ' || to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss'));

    select nvl(sum(quantity * unit_price), 0) into v_realized
    from pack_items pi join pack p on pi.pack_id = p.pack_id
    where p.pack_status = 'Shipped';

    select nvl(sum(total_amount), 0) into v_pending
    from orders where order_status in ('Created', 'In work');

    select nvl(sum(quantity * price), 0) into v_inventory
    from products;

    dbms_output.put_line('realized revenue: ' || v_realized);
    dbms_output.put_line('pending pipeline: ' || v_pending);
    dbms_output.put_line('inventory value: ' || v_inventory);
    dbms_output.put_line('total projected: ' || (v_realized + v_pending));
end;


create or replace function fn_getorderpackprogress(p_orderid in number) return number is
    v_total number;
    v_packed number;
begin
    select nvl(sum(oi.quantity), 0) into v_total
    from order_items oi
    where oi.order_id = p_orderid;
    if v_total = 0 then return 0; end if;
    select nvl(sum(pi.quantity), 0) into v_packed
    from pack_items pi
    join pack p on pi.pack_id = p.pack_id
    where p.order_id = p_orderid
      and p.pack_status in ('Packed', 'Shipped');
    return round((v_packed * 100.0) / v_total, 2);
end;


create or replace function fn_getstockturnoverrate(p_stockid in number, p_days in number) return number is
    v_shipped number;
    v_currentstock number;
begin
    select nvl(sum(pi.quantity), 0) into v_shipped
    from pack_items pi
    join pack p on pi.pack_id = p.pack_id
    join products pr on pi.product_id = pr.product_id
    where pr.stock_id = p_stockid
      and p.pack_status = 'Shipped'
      and p.pack_date >= sysdate - p_days;
    select nvl(sum(quantity), 0) into v_currentstock
    from products
    where stock_id = p_stockid;
    if v_currentstock = 0 then return 0; end if;
    return round(v_shipped / v_currentstock, 4);
end;


create or replace procedure sp_escalateoverduetasks as
    v_count number;
begin
    update tasks
    set priority = case
        when priority = 'Low' then 'Moderate'
        when priority = 'Moderate' then 'High'
        when priority = 'High' then 'Highest'
        else priority
    end
    where is_completed = 0
      and due_date < sysdate
      and priority <> 'Highest';
    v_count := sql%rowcount;
    dbms_output.put_line('escalated ' || v_count || ' overdue tasks');
    commit;
end;


create or replace procedure sp_cancelstaleorders(p_staledays in number) as
    v_count number;
begin
    update orders
    set order_status = 'Canceled'
    where order_status = 'Created'
      and order_date < sysdate - p_staledays;
    v_count := sql%rowcount;
    dbms_output.put_line('canceled ' || v_count || ' stale orders older than ' || p_staledays || ' days');
    commit;
end;


create or replace procedure sp_transferproduct(p_productid in number, p_targetstockid in number, p_qty in number) as
    v_sourcestockid number;
    v_currentqty number;
    v_targetcapacity number;
    v_targetfilled number;
begin
    select stock_id, quantity into v_sourcestockid, v_currentqty
    from products
    where product_id = p_productid;

    if v_sourcestockid = p_targetstockid then
        raise_application_error(-20002, 'source and target stock are the same');
    end if;

    if v_currentqty < p_qty then
        raise_application_error(-20003, 'insufficient product quantity for transfer');
    end if;

    select capacity, filled_part into v_targetcapacity, v_targetfilled
    from stocks
    where stock_id = p_targetstockid;

    if (v_targetfilled + p_qty) > v_targetcapacity then
        raise_application_error(-20004, 'target stock does not have enough free capacity');
    end if;

    update stocks set filled_part = filled_part - p_qty
    where stock_id = v_sourcestockid;

    update stocks set filled_part = filled_part + p_qty
    where stock_id = p_targetstockid;

    update products set stock_id = p_targetstockid
    where product_id = p_productid;

    commit;
exception
    when others then rollback; raise;
end;

