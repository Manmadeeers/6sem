use Warehouse;

go
--1: alter table Stocks to add hierarchyid column there
alter table Stocks add node_path hierarchyid;

create  index ix_Stocks_node_path on Stocks(node_path);

alter table Stocks add storage_level as node_path.GetLevel();

select * from Stocks;

insert into Stocks (Capacity,Filled_part,Description,node_path)
values (100000,0,'Main Warehouse Facility',hierarchyid::GetRoot());

update Stocks
set node_path=hierarchyid::GetRoot()
where Stock_ID = 11;

--2:procedure to print all descendants of a certain parent

go

create or alter procedure sp_GetStorageSubordinates
	@ParentStockID int
as
begin
	set nocount on;

	declare @ParentPah hierarchyid;
	select @ParentPah = node_path
	from Stocks
	where Stock_ID=@ParentStockID;

	if @ParentPah is null
	begin
		raiserror('Storage with this id not found',16,1);
		return;
	end;

	select
		Stock_ID,
		Description as [StorageName],
		node_path.ToString() as [HierarchyPath],
		storage_level as [Level],
		Capacity,
		Filled_part
	from Stocks
	where node_path.IsDescendantOf(@ParentPah)=1
		and Stock_ID <> @ParentStockID
	order by
		node_path;
end;

exec sp_GetStorageSubordinates 11;

select * from Stocks;


--3: procedures to add descendants to stocks

go

create or alter procedure sp_AddStorageLocation
	@ParentStockID int,
	@Capacity int,
	@Description nvarchar(100)
as
begin
	set nocount on;

	declare @ParentPath hierarchyid;
	declare @LastChildPath hierarchyid;
	declare @NewPath hierarchyid;

	select @ParentPath  = node_path
	from Stocks
	where Stock_ID = @ParentStockID;

	if @ParentPath is null
	begin
		raiserror('Unable to add a descendant to this parent',16,1);
		return;
	end;

	select @LastChildPath = MAX(node_path)
	from Stocks
	where node_path.GetAncestor(1)=@ParentPath;

	set @NewPath = @ParentPath.GetDescendant(@LastChildPath,NULL);

	insert into Stocks (Capacity,Filled_part,Description,node_path)
	values (@Capacity, 0,@Description,@NewPath);

	select SCOPE_IDENTITY() as NewStockID;
end;

select * from Stocks;
exec sp_AddStorageLocation 1036, 25, 'Reserve compartment';
exec sp_AddStorageLocation 1035, 25, 'Reserve cealed compartment';
go

create or alter procedure sp_AlterDescendantsParent
	@ParentID int,
	@ChildID int
as
begin
	set nocount on;
	set transaction isolation level serializable;

	begin transaction
	begin try
		declare @ParentPath hierarchyid;
		declare @OldChildPth hierarchyid;
		declare @LastChildPath hierarchyid;
		declare @NewChildPath hierarchyid;

		select @ParentPath = node_path
		from Stocks
		where Stock_ID =@ParentID;

		if @ParentPath is null
		begin
			THROW 50001, 'Parent path not found or does not have a node_path', 1;
		end

		select @OldChildPth = node_path
		from Stocks
		where Stock_ID=@ChildID;

		select @LastChildPath = MAX(node_path)
		from Stocks
		where node_path.GetAncestor(1)=@ParentPath;

		set @NewChildPath = @ParentPath.GetDescendant(@LastChildPath,NULL);

		if @OldChildPth is not null
		begin
			update Stocks
			set node_path = node_path.GetReparentedValue(@OldChildPth,@NewChildPath)
			where node_path.IsDescendantOf(@OldChildPth)=1;
		end
		else
		begin
			update Stocks
			set node_path = @NewChildPath
			where Stock_ID=@ChildID;
		end;

		commit transaction;

	end try
	begin catch
		if @@TRANCOUNT>0 rollback transaction;
		declare @ErrMsg nvarchar(4000) = ERROR_MESSAGE();
		raiserror(@ErrMsg,16,1);
	end catch
end;

select * from Stocks;
exec sp_AlterDescendantsParent 11, 1;
exec sp_AlterDescendantsParent 11, 2;
exec sp_AlterDescendantsParent 11, 3;
exec sp_AlterDescendantsParent 11, 4;
exec sp_AlterDescendantsParent 11, 5;
exec sp_AlterDescendantsParent 11, 6;
exec sp_AlterDescendantsParent 11, 7;
exec sp_AlterDescendantsParent 11, 8;
exec sp_AlterDescendantsParent 11, 9;
exec sp_AlterDescendantsParent 11, 10;
exec sp_AlterDescendantsParent 11, 12;

--4: procedure to move branches of descendats between parents

go

create or alter procedure sp_SwapStorageDescendants
	@SrcNodeId int,
	@DestNodeId int
as
begin
	set nocount on;
	set transaction isolation level serializable;
	begin transaction;
	begin try
		declare @SrcPath hierarchyid;
		declare @DestPath hierarchyid;
		select @SrcPath = node_path
		from stocks
		where stock_id = @SrcNodeId;
		select @DestPath = node_path
		from stocks
		where stock_id = @DestNodeId;
		if @SrcPath is null or @DestPath is null
		begin
			throw 50000, 'Parent nodes not found.', 1;
		end;
		if object_id('tempdb..#NodeMap') is not null drop table #NodeMap;
		create table #NodeMap (
			Rel_Path nvarchar(4000),
			Src_Stock_ID int,
			Dest_Stock_ID int,
			Src_Capacity int,
			Src_Filled_Part int,
			Src_Description nvarchar(100),
			Dest_Capacity int,
			Dest_Filled_Part int,
			Dest_Description nvarchar(100)
		);
		insert into #NodeMap (Rel_Path, Src_Stock_ID, Src_Capacity, Src_Filled_Part, Src_Description)
		select 
			substring(node_path.ToString(), len(@SrcPath.ToString()), 4000),
			stock_id, capacity, filled_part, description
		from stocks
		where node_path.IsDescendantOf(@SrcPath) = 1 
			and node_path <> @SrcPath;
		update m
		set 
			m.Dest_Stock_ID = s.stock_id,
			m.Dest_Capacity = s.capacity,
			m.Dest_Filled_Part = s.filled_part,
			m.Dest_Description = s.description
		from #NodeMap m
		join stocks s on substring(s.node_path.ToString(), len(@DestPath.ToString()), 4000) = m.Rel_Path
		where s.node_path.IsDescendantOf(@DestPath) = 1 
			and s.node_path <> @DestPath;
		update s
		set 
			s.capacity = m.Dest_Capacity,
			s.filled_part = m.Dest_Filled_Part,
			s.description = m.Dest_Description
		from stocks s
		join #NodeMap m on s.stock_id = m.Src_Stock_ID
		where m.Dest_Stock_ID is not null;
		update s
		set 
			s.capacity = m.Src_Capacity,
			s.filled_part = m.Src_Filled_Part,
			s.description = m.Src_Description
		from stocks s
		join #NodeMap m on s.stock_id = m.Dest_Stock_ID
		where m.Src_Stock_ID is not null;
		update stocks
		set node_path = node_path.GetReparentedValue(@SrcPath, @DestPath)
		where stock_id in (
			select Src_Stock_ID 
			from #NodeMap 
			where Dest_Stock_ID is null
		);
		update stocks
		set node_path = node_path.GetReparentedValue(@DestPath, @SrcPath)
		where node_path.IsDescendantOf(@DestPath) = 1 
			and node_path <> @DestPath
			and stock_id not in (
				select Dest_Stock_ID 
				from #NodeMap 
				where Dest_Stock_ID is not null
			);
		drop table #NodeMap;
		commit transaction;
	end try
	begin catch
		if @@trancount > 0 rollback transaction;
		throw;
	end catch;
end;

exec sp_GetStorageSubordinates 11;

exec sp_SwapStorageDescendants 1,2;
select * from Stocks;


