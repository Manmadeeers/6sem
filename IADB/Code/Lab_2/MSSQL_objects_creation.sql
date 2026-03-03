use Warehouse;

go

create view  CompletedOperatorTasks as --Operators effectiveness view
select
	u.User_ID,
	u.Email,
	COUNT(t.Task_ID) as Completed_Tasks_Count
from
	Users u
inner join 
	Tasks t on u.User_ID=t.User_ID
where 
	u.Role = 'Operator'
and
	t.Is_completed = 1
group by
	u.User_ID,
	u.Email;

go

go

create view MonthlyFinantialSummary as --Monthly finantial overview
with DateRange as(
	select
		DATEADD(MONTH, DATEDIFF(MONTH,0,GETDATE()-1),0) as StartOfMonth,
		DATEADD(MILLISECOND, -3, DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0)) as EndOfMonth
),
InboundValue as(
	select SUM(Price*Quantity) as Total_Stock_Value
	from dbo.Products
),
OrderValue as(
	select isnull(sum(Total_amount),0) as Total_Ordered_Value
	from Orders, DateRange
	where Order_date BETWEEN DateRange.StartOfMonth AND DateRange.EndOfMonth
),
PackedValue as(
	select isnull(sum(pi.Quantity*pi.Unit_price),0) as Total_Packed_Value
	from Pack_items pi
	inner join Pack p on pi.Pack_ID = p.Pack_ID
	cross join DateRange
	where p.Pack_date between DateRange.StartOfMonth and EndOfMonth
)
select
	(select StartOfMonth from DateRange) as ReportMonthStart,
	iv.Total_Stock_Value as Current_Inventory_Value, 
	ov.Total_Ordered_Value as Monthly_Orders_Total,
	pv.Total_Packed_Value as Monthly_Packed_Total,
	(ov.Total_Ordered_Value - pv.Total_Packed_Value) as Unpacked_Order_Gap,
	case 
		when ov.Total_Ordered_Value = 0 then 0
		else (pv.Total_Packed_Value / ov.Total_Ordered_Value)*100
	end as Fulfillment_Rate_Percentage
from InboundValue iv, OrderValue ov, PackedValue pv;

go



