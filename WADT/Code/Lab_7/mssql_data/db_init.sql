IF DB_ID(N'Celebrities') IS NULL
BEGIN
    CREATE DATABASE [Celebrities];
END
GO

USE [Celebrities];
GO

IF OBJECT_ID(N'dbo.Celebrities', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Celebrities] (
        [Id] INT IDENTITY(1,1) NOT NULL,
        [FullName] NVARCHAR(100) NOT NULL,
        [Nationality] NVARCHAR(100) NOT NULL,
        [ReqPhotoPath] NVARCHAR(500) NOT NULL,
        CONSTRAINT [PK_Celebrities] PRIMARY KEY CLUSTERED ([Id] ASC)
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM [dbo].[Celebrities]
    WHERE [FullName] = N'Smelov V.V.'
      AND [Nationality] = N'BY'
      AND [ReqPhotoPath] = N'NO'
)
BEGIN
    INSERT INTO [dbo].[Celebrities] ([FullName], [Nationality], [ReqPhotoPath])
    VALUES (N'Smelov V.V.', N'BY', N'NO');
END
GO
