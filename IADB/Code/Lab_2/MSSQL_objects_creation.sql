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




