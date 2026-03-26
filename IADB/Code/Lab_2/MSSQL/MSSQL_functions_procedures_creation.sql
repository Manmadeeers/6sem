use warehouse;

go

create or alter function dbo.fn_getstockstatus(@stockid int)
returns nvarchar(20)
as
begin
    if not exists (select 1 from dbo.stocks where stock_id = @stockid)
        return N'NOT_FOUND';
    declare @percent float;
    select @percent = (cast(filled_part as float) / cast(capacity as float)) * 100.0
    from dbo.stocks
    where stock_id = @stockid;
    declare @status nvarchar(20);
    set @status = case
        when @percent <= 20.0 then N'LOW'
        when @percent >= 95.0 then N'FULL'
        else N'OK'
    end;
    return @status;
end;

go

create or alter function dbo.fn_canfulfillorder(@orderid int)
returns bit
as
begin
    if not exists (select 1 from dbo.orders where order_id = @orderid)
        return 0;
    declare @can bit = 1;
    if exists (
        select 1
        from dbo.order_items oi
        join dbo.products p on p.product_id = oi.product_id
        where oi.order_id = @orderid
          and oi.quantity > p.quantity
    )
        set @can = 0;
    return @can;
end;

go

create or alter procedure dbo.sp_dispatchproduct
    @productid int,
    @quantitytodispatch int
as
begin
    set nocount on;
    set xact_abort on;

    begin try
        declare @currentproductqty int;
        select @currentproductqty = quantity
        from dbo.products
        where product_id = @productid;

        if @currentproductqty is null
        begin
            raiserror('product not found for product_id = %d', 16, 1, @productid);
            return;
        end

        declare @currentstockfilled int;
        select @currentstockfilled = s.filled_part
        from dbo.stocks s
        join dbo.products p on s.stock_id = p.stock_id
        where p.product_id = @productid;

        if @currentstockfilled is null
        begin
            raiserror('stock not found for product_id = %d', 16, 1, @productid);
            return;
        end

        if @currentproductqty < @quantitytodispatch
            raiserror('insufficient product quantity', 16, 1);

        if @currentstockfilled < @quantitytodispatch
            raiserror('insufficient stock filled in warehouse', 16, 1);

        begin transaction;

            update dbo.products
            set quantity = quantity - @quantitytodispatch
            where product_id = @productid;

            update dbo.stocks
            set filled_part = filled_part - @quantitytodispatch
            from dbo.stocks s
            join dbo.products p on s.stock_id = p.stock_id
            where p.product_id = @productid;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0
            rollback transaction;
        throw;
    end catch
end;

go

create or alter function dbo.fn_getmonthlyproductfinancials(
    @reportmonth int,
    @reportyear int
)
returns table
as
return (
    select
        p.product_id,
        p.name as product_name,
        sum(pi.quantity) as total_units_sold,
        sum(pi.quantity * pi.unit_price) as total_revenue,
        cast(avg(pi.unit_price) as decimal(19,4)) as avg_selling_price,
        count(distinct pk.order_id) as total_orders_fulfilled
    from products p
    join pack_items pi on p.product_id = pi.product_id
    join pack pk on pi.pack_id = pk.pack_id
    where month(pk.pack_date) = @reportmonth
      and year(pk.pack_date) = @reportyear
      and pk.pack_status = 'Shipped'
    group by p.product_id, p.name
);

go

create or alter procedure dbo.usp_generatewarehousefinancialreport	
as
begin
    set nocount on;
    print '--- warehouse financial summary report ---';
    print 'generated on: ' + cast(getdate() as varchar(25));
    print '------------------------------------------';

    declare @realizedrevenue decimal(19,4);
    select @realizedrevenue = isnull(sum(quantity * unit_price), 0)
    from pack_items pi
    join pack p on pi.pack_id = p.pack_id
    where p.pack_status = 'Shipped';

    declare @pendingrevenue decimal(19,4);
    select @pendingrevenue = isnull(sum(total_amount), 0)
    from orders
    where order_status in ('Created', 'In work');

    declare @inventoryvalue decimal(19,4);
    select @inventoryvalue = isnull(sum(quantity * price), 0)
    from products;

    select
        @realizedrevenue as realized_revenue_usd,
        @pendingrevenue as pending_pipeline_usd,
        @inventoryvalue as current_inventory_value_usd,
        (@realizedrevenue + @pendingrevenue) as total_projected_revenue_usd;

    select
        order_status,
        count(order_id) as order_count,
        sum(total_amount) as status_total_usd
    from orders
    group by order_status;
end;

go

create or alter function dbo.fn_getorderpackprogress(@orderid int)
returns decimal(5,2)
as
begin
    declare @total int, @packed int;
    select @total = sum(oi.quantity)
    from order_items oi
    where oi.order_id = @orderid;
    if @total is null or @total = 0
        return 0.00;
    select @packed = isnull(sum(pi.quantity), 0)
    from pack_items pi
    join pack p on pi.pack_id = p.pack_id
    where p.order_id = @orderid
      and p.pack_status in ('Packed', 'Shipped');
    return cast((@packed * 100.0) / @total as decimal(5,2));
end;

go

create or alter function dbo.fn_getstockturnoverrate(@stockid int, @days int)
returns decimal(10,4)
as
begin
    declare @shipped int;
    select @shipped = isnull(sum(pi.quantity), 0)
    from pack_items pi
    join pack p on pi.pack_id = p.pack_id
    join products pr on pi.product_id = pr.product_id
    where pr.stock_id = @stockid
      and p.pack_status = 'Shipped'
      and p.pack_date >= dateadd(day, -@days, getdate());
    declare @currentstock int;
    select @currentstock = isnull(sum(quantity), 0)
    from products
    where stock_id = @stockid;
    if @currentstock = 0
        return 0.0000;
    return cast(@shipped as decimal(10,4)) / cast(@currentstock as decimal(10,4));
end;

go

create or alter procedure dbo.sp_escalateoverduetasks
as
begin
    set nocount on;
    update tasks
    set priority = case
        when priority = 'Low' then 'Moderate'
        when priority = 'Moderate' then 'High'
        when priority = 'High' then 'Highest'
        else priority
    end
    where is_completed = 0
      and due_date < getdate()
      and priority <> 'Highest';
    print 'escalated ' + cast(@@rowcount as varchar(10)) + ' overdue tasks';
end;

go

create or alter procedure dbo.sp_cancelstaleorders
    @staledays int
as
begin
    set nocount on;
    update orders
    set order_status = 'Canceled'
    where order_status = 'Created'
      and order_date < dateadd(day, -@staledays, getdate());
    print 'canceled ' + cast(@@rowcount as varchar(10)) + ' stale orders older than ' + cast(@staledays as varchar(10)) + ' days';
end;

go

create or alter procedure dbo.sp_transferproduct
    @productid int,
    @targetstockid int,
    @qty int
as
begin
    set nocount on;
    set xact_abort on;

    begin try
        declare @sourcestockid int, @currentqty int;
        select @sourcestockid = stock_id, @currentqty = quantity
        from products
        where product_id = @productid;

        if @sourcestockid is null
            raiserror('product not found', 16, 1);

        if @sourcestockid = @targetstockid
            raiserror('source and target stock are the same', 16, 1);

        if @currentqty < @qty
            raiserror('insufficient product quantity for transfer', 16, 1);

        declare @targetcapacity int, @targetfilled int;
        select @targetcapacity = capacity, @targetfilled = filled_part
        from stocks
        where stock_id = @targetstockid;

        if @targetcapacity is null
            raiserror('target stock not found', 16, 1);

        if (@targetfilled + @qty) > @targetcapacity
            raiserror('target stock does not have enough free capacity', 16, 1);

        begin transaction;
            update stocks
            set filled_part = filled_part - @qty
            where stock_id = @sourcestockid;

            update stocks
            set filled_part = filled_part + @qty
            where stock_id = @targetstockid;

            update products
            set stock_id = @targetstockid,
                quantity = quantity
            where product_id = @productid;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0
            rollback transaction;
        throw;
    end catch
end;
