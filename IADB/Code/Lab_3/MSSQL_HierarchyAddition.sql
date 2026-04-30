USE Warehouse;
GO

-- 1. Add hierarchyid column and helper objects
IF COL_LENGTH('dbo.Stocks', 'node_path') IS NULL
    ALTER TABLE dbo.Stocks ADD node_path hierarchyid NULL;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'ix_Stocks_node_path'
      AND object_id = OBJECT_ID('dbo.Stocks')
)
    CREATE INDEX ix_Stocks_node_path ON dbo.Stocks(node_path);
GO

IF COL_LENGTH('dbo.Stocks', 'storage_level') IS NULL
    ALTER TABLE dbo.Stocks ADD storage_level AS node_path.GetLevel();
GO


select * from Stocks;

go
-- 2. Get full subtree by hierarchyid
CREATE OR ALTER PROCEDURE dbo.GetStorageHierarchy
    @ParentNode hierarchyid
AS
BEGIN
    SET NOCOUNT ON;

    IF @ParentNode IS NULL
        THROW 50001, 'Parent node cannot be NULL.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Stocks
        WHERE node_path = @ParentNode
    )
        THROW 50002, 'Parent node not found in Stocks.', 1;

    SELECT
        Stock_ID,
        Description AS StorageName,
        node_path.ToString() AS Node_Path,
        node_path.GetLevel() AS Hierarchy_Level,
        Capacity,
        Filled_part
    FROM dbo.Stocks
    WHERE node_path.IsDescendantOf(@ParentNode) = 1
    ORDER BY node_path;
END
GO

-- 3. Add child under a hierarchyid parent
CREATE OR ALTER PROCEDURE dbo.AddStorageChild
    @ParentNode hierarchyid,
    @Capacity int,
    @Description nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ParentNode IS NULL
        THROW 50003, 'Parent node cannot be NULL.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Stocks
        WHERE node_path = @ParentNode
    )
        THROW 50004, 'Parent node not found in Stocks.', 1;

    DECLARE @LastChild hierarchyid;
    DECLARE @NewNode hierarchyid;

    SELECT @LastChild = MAX(node_path)
    FROM dbo.Stocks
    WHERE node_path.GetAncestor(1) = @ParentNode;

    SET @NewNode = @ParentNode.GetDescendant(@LastChild, NULL);

    INSERT INTO dbo.Stocks (Capacity, Filled_part, Description, node_path)
    VALUES (@Capacity, 0, @Description, @NewNode);

    SELECT
        CAST(SCOPE_IDENTITY() AS int) AS NewStockID,
        @NewNode.ToString() AS NewNodePath;
END
GO

-- 4. Move whole subtree to another hierarchyid parent
CREATE OR ALTER PROCEDURE dbo.MoveStorageSubtree
    @OldParent hierarchyid,
    @NewParent hierarchyid
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;
    BEGIN TRY
        IF @OldParent IS NULL OR @NewParent IS NULL
            THROW 50005, 'Both node parameters are required.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Stocks
            WHERE node_path = @OldParent
        )
            THROW 50006, 'Old parent node not found.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Stocks
            WHERE node_path = @NewParent
        )
            THROW 50007, 'New parent node not found.', 1;

        IF @OldParent = hierarchyid::GetRoot()
            THROW 50008, 'The root node cannot be moved.', 1;

        IF @NewParent.IsDescendantOf(@OldParent) = 1
            THROW 50009, 'Cannot move a node under its own descendant.', 1;

        DECLARE @LastChild hierarchyid;
        DECLARE @NewRoot hierarchyid;

        SELECT @LastChild = MAX(node_path)
        FROM dbo.Stocks
        WHERE node_path.GetAncestor(1) = @NewParent
          AND node_path.IsDescendantOf(@OldParent) = 0;

        SET @NewRoot = @NewParent.GetDescendant(@LastChild, NULL);

        UPDATE dbo.Stocks
        SET node_path = node_path.GetReparentedValue(@OldParent, @NewRoot)
        WHERE node_path.IsDescendantOf(@OldParent) = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Demo data
DELETE FROM dbo.Stocks;
DBCC CHECKIDENT ('dbo.Stocks', RESEED, 0);
GO

INSERT INTO dbo.Stocks (Capacity, Filled_part, Description)
VALUES
(100000, 0, N'Main Warehouse Facility'), -- /
(60000, 0, N'Zone A'),                   -- /1/
(40000, 0, N'Zone B'),                   -- /2/
(20000, 0, N'Rack A1'),                  -- /1/1/
(15000, 0, N'Rack A2'),                  -- /1/2/
(25000, 0, N'Rack B1'),                  -- /2/1/
(10000, 0, N'Rack B2');                  -- /2/2/
GO

UPDATE dbo.Stocks SET node_path = hierarchyid::GetRoot()       WHERE Stock_ID = 1;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/1/')    WHERE Stock_ID = 2;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/2/')    WHERE Stock_ID = 3;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/1/1/')  WHERE Stock_ID = 4;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/1/2/')  WHERE Stock_ID = 5;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/2/1/')  WHERE Stock_ID = 6;
UPDATE dbo.Stocks SET node_path = hierarchyid::Parse('/2/2/')  WHERE Stock_ID = 7;
GO

SELECT
    Stock_ID,
    Description,
    node_path.ToString() AS Node_Path,
    Capacity,
    Filled_part
FROM dbo.Stocks
ORDER BY node_path;
GO

-- 2. Read hierarchy
DECLARE @node hierarchyid;
SET @node = hierarchyid::Parse('/');
EXEC dbo.GetStorageHierarchy @ParentNode = @node;
GO

DECLARE @node2 hierarchyid;
SET @node2 = hierarchyid::Parse('/2/');
EXEC dbo.GetStorageHierarchy @ParentNode = @node2;
GO

-- 3. Add child
select * from stocks;

DECLARE @ParentNode hierarchyid;
SELECT @ParentNode = node_path
FROM dbo.Stocks
WHERE Stock_ID = 6;

EXEC dbo.AddStorageChild
    @ParentNode = @ParentNode,
    @Capacity = 5000,
    @Description = N'Overflow Shelf B1';
GO

-- 4. Move subtree
DECLARE @old hierarchyid;
DECLARE @new hierarchyid;

SET @old = hierarchyid::Parse('/2/1/');
SET @new = hierarchyid::Parse('/1/');

EXEC dbo.MoveStorageSubtree
    @OldParent = @old,
    @NewParent = @new;
GO

SELECT
    Stock_ID,
    Description,
    node_path.ToString() AS Node_Path,
    Capacity,
    Filled_part
FROM dbo.Stocks
ORDER BY node_path;
GO


CREATE OR ALTER PROCEDURE dbo.SwapStorageBranchChildren
    @FirstNode hierarchyid,
    @SecondNode hierarchyid
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @TempNode hierarchyid;
        DECLARE @LastRootChild hierarchyid;

        IF @FirstNode IS NULL OR @SecondNode IS NULL
            THROW 50001, 'Both nodes are required.', 1;

        IF @FirstNode = @SecondNode
            THROW 50002, 'You cannot swap a branch with itself.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Stocks WHERE node_path = @FirstNode)
            THROW 50003, 'First node not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Stocks WHERE node_path = @SecondNode)
            THROW 50004, 'Second node not found.', 1;

        IF @FirstNode.IsDescendantOf(@SecondNode) = 1
            THROW 50005, 'Nested branches cannot be swapped this way.', 1;

        IF @SecondNode.IsDescendantOf(@FirstNode) = 1
            THROW 50006, 'Nested branches cannot be swapped this way.', 1;

        SELECT @LastRootChild = MAX(node_path)
        FROM dbo.Stocks
        WHERE node_path.GetAncestor(1) = hierarchyid::GetRoot();

        SET @TempNode = hierarchyid::GetRoot().GetDescendant(@LastRootChild, NULL);

        -- Move children of the first branch to a temporary place
        UPDATE dbo.Stocks
        SET node_path = node_path.GetReparentedValue(@FirstNode, @TempNode)
        WHERE node_path.IsDescendantOf(@FirstNode) = 1
          AND node_path <> @FirstNode;

        -- Move children of the second branch into the first branch
        UPDATE dbo.Stocks
        SET node_path = node_path.GetReparentedValue(@SecondNode, @FirstNode)
        WHERE node_path.IsDescendantOf(@SecondNode) = 1
          AND node_path <> @SecondNode;

        -- Move saved children of the first branch into the second branch
        UPDATE dbo.Stocks
        SET node_path = node_path.GetReparentedValue(@TempNode, @SecondNode)
        WHERE node_path.IsDescendantOf(@TempNode) = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



CREATE OR ALTER PROCEDURE dbo.SwapStorageBranchChildrenById
    @FirstStockID int,
    @SecondStockID int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FirstNode hierarchyid;
    DECLARE @SecondNode hierarchyid;

    SELECT @FirstNode = node_path
    FROM dbo.Stocks
    WHERE Stock_ID = @FirstStockID;

    SELECT @SecondNode = node_path
    FROM dbo.Stocks
    WHERE Stock_ID = @SecondStockID;

    EXEC dbo.SwapStorageBranchChildren
        @FirstNode = @FirstNode,
        @SecondNode = @SecondNode;
END;
GO




CREATE OR ALTER PROCEDURE dbo.MoveAllChildrenToAnotherParent
    @SourceParentID int,
    @DestinationParentID int
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @SourcePath hierarchyid;
        DECLARE @DestinationPath hierarchyid;

        SELECT @SourcePath = node_path
        FROM dbo.Stocks
        WHERE Stock_ID = @SourceParentID;

        SELECT @DestinationPath = node_path
        FROM dbo.Stocks
        WHERE Stock_ID = @DestinationParentID;

        IF @SourcePath IS NULL
            THROW 50001, 'Source parent not found.', 1;

        IF @DestinationPath IS NULL
            THROW 50002, 'Destination parent not found.', 1;

        IF @SourceParentID = @DestinationParentID
            THROW 50003, 'Source and destination cannot be the same.', 1;

        IF @DestinationPath.IsDescendantOf(@SourcePath) = 1
           AND @DestinationPath <> @SourcePath
            THROW 50004, 'Destination parent cannot be inside the source branch.', 1;

        DECLARE @Children TABLE
        (
            RowNum int identity(1,1) primary key,
            ChildPath hierarchyid
        );

        INSERT INTO @Children (ChildPath)
        SELECT node_path
        FROM dbo.Stocks
        WHERE node_path.GetAncestor(1) = @SourcePath
        ORDER BY node_path;

        DECLARE @i int = 1;
        DECLARE @cnt int;
        DECLARE @OldChildPath hierarchyid;
        DECLARE @LastChildPath hierarchyid;
        DECLARE @NewChildPath hierarchyid;

        SELECT @cnt = COUNT(*) FROM @Children;

        WHILE @i <= @cnt
        BEGIN
            SELECT @OldChildPath = ChildPath
            FROM @Children
            WHERE RowNum = @i;

            SELECT @LastChildPath = MAX(node_path)
            FROM dbo.Stocks
            WHERE node_path.GetAncestor(1) = @DestinationPath;

            SET @NewChildPath = @DestinationPath.GetDescendant(@LastChildPath, NULL);

            UPDATE dbo.Stocks
            SET node_path = node_path.GetReparentedValue(@OldChildPath, @NewChildPath)
            WHERE node_path.IsDescendantOf(@OldChildPath) = 1;

            SET @i += 1;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


SELECT Stock_ID, Description, node_path.ToString() AS Path
FROM dbo.Stocks
ORDER BY node_path;
GO

EXEC dbo.MoveAllChildrenToAnotherParent
    @SourceParentID = 2,
    @DestinationParentID = 6
GO

SELECT Stock_ID, Description, node_path.ToString() AS Path
FROM dbo.Stocks
ORDER BY node_path;
GO
