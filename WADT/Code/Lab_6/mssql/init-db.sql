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
        [FullName] NVARCHAR(50) NOT NULL,
        [Nationality] NVARCHAR(2) NOT NULL,
        [ReqPhotoPath] NVARCHAR(200) NOT NULL,
        CONSTRAINT [PK_Celebrities] PRIMARY KEY CLUSTERED ([Id] ASC)
    );
END
GO
