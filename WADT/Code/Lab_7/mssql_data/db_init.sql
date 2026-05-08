create database Celebrities;
go

use Celebrities;
go

create table Celebrities(
    Id int identity(1,1) primary key,
    FullName varchar(100) not null,
    Nationality varchar(100) not null,
    ReqPhotoPath varchar(500) not null
);

go

insert into Celebrities (FullName,Nationality,ReqPhotoPath) values ('Smelov V.V.','BY','NO');
go