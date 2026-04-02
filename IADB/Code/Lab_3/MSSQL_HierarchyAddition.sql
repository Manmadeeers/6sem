use Warehouse;

go
--1: adding heirarchyid datatype clumn to users table
alter table Users add Org_path hierarchyid;
alter table Users add Org_level as Org_path.GetLevel();

select * from Users;

go

--2: creating a procedure to return all subordinates of a specified user
create or alter procedure sp_GetAllSubordiates
	@UserID int
as
begin
	set nocount on;

	declare @ManagePath hierarchyid;

	select @ManagePath = Org_path
	from Users
	where User_ID = @UserID;

	if @ManagePath is null
	begin
		raiserror('User not found or does not have an org_path',16,1);
		return;
	end;

	select
        User_ID,
        Email,
        Role,
        Org_path.ToString() AS [String_Path],
		Org_level as [Hierarchy_level],
		Created_at
    from Users
    where Org_path.IsDescendantOf(@ManagePath) = 1
    order by Org_path;

end;

go;

update Users
set Org_path=hierarchyid::GetRoot()
where User_ID=1;

select * from Users;

exec dbo.sp_GetAllSubordiates @UserID=1;


--3: creating a procedure to add a subordinate from an existing list of users and a new user as a subordinate
go

create or alter procedure sp_AddSubordinate
	@ParentID int,
	@ChildID int
as
begin
	set nocount on;
	set xact_abort on;

	declare @ParentPath hierarchyid;
	declare @LastChildPath hierarchyid;
	declare @NewNodePath hierarchyid;

	begin transaction;
		select @ParentPath = Org_path
		from Users
		where User_ID = @ParentID;

		if @ParentPath is null
			begin
				rollback transaction;
				raiserror('Specified user not found or does not have a hierarchycal path',16,1);
				return;
			end;

			select @LastChildPath = MAX(Org_path)
			from Users
			where Org_path.GetAncestor(1) = @ParentPath;

			set @NewNodePath = @ParentPath.GetDescendant(@LastChildPath,null);
			
			update Users
			set Org_path = @NewNodePath
			where User_ID=@ChildID;

			commit transaction;

end;

select * from Users;
exec dbo.sp_AddSubordinate @ParentID=1, @ChildID=5;

exec dbo.sp_AddSubordinate @ParentID=1, @ChildID=2;
exec dbo.sp_AddSubordinate @ParentID=2, @ChildID=3;
exec dbo.sp_AddSubordinate @ParentID=2, @ChildID=4;

go;

create or alter procedure sp_AddSubordinateFull
	@ParentID int,
	@Email varchar(255),
	@Role varchar(30),
	@PasswordHash varbinary(64)
as
begin
	set nocount on;
	set xact_abort on;

	declare @ParentPath hierarchyid;
	declare @LastChildPath hierarchyid;
	declare @NewNodePath hierarchyid;

	begin transaction;
		select @ParentPath= Org_path
		from Users
		where User_ID = @ParentID;

		if @ParentPath is null
			begin
				rollback transaction;
				raiserror('Specified user not found or does not have a hierarchycal path',16,1);
				return;
			end;

			select @LastChildPath = MAX(Org_path)
			from Users
			where Org_path.GetAncestor(1) = @ParentPath;

			set @NewNodePath = @ParentPath.GetDescendant(@LastChildPath,null);
			
			insert into Users (Email, Role,Password_hash,Org_path)
			values (@Email, @Role, @PasswordHash,@NewNodePath);

			select SCOPE_IDENTITY() as NewUserID;
			commit transaction;
end;

exec dbo.sp_AddSubordinateFull @ParentID=2, @Email='subordinate2@warehouse.com', @Role='Manager', @PasswordHash=0xBCD2356;

select * from users;

--4:creatign a procedure to move a whole branch of subordinates from one root to another
go;

create or alter procedure sp_Movesubordinates
	@OldParentID int,
	@NewParentID int
as
begin
	set nocount on;
	set xact_abort on;

	declare @OldParentPath hierarchyid;
	declare @NewParentPath hierarchyid;

	begin transaction;
		select @OldParentPath = Org_path
		from Users
		where User_ID=@OldParentID;

		select @NewParentPath = Org_path
		from Users
		where User_ID=@NewParentID;

		if @OldParentPath is null or @NewParentPath is null
		begin
			raiserror('One of specified parents not found',16,1);
			rollback transaction;
			return;
		end;

		update users
		set Org_path = Org_path.GetReparentedValue(@OldParentPath,@NewParentPath)
		where Org_path.IsDescendantOf(@OldParentPath)=1
		and Org_path <> @OldParentPath;

		select @@ROWCOUNT as MovedUsers;

	commit transaction;
end;


select * from Users;

exec dbo.sp_Movesubordinates @OldParentID=5, @NewParentID=2;


