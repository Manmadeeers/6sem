create database Celebrities;

use Celebrities;


create table Celebrities(
	Id int identity(1,1) not null,
	FullName nvarchar(50) not null,
	Nationality nvarchar(2) not null,
	ReqPhotoPath nvarchar(200) not null,
	constraint PK_Celebrities primary key clustered (Id asc)
);

select * from Celebrities;

insert into Celebrities values
('Linus Torvalds','FN','NO'),
('Steve Jobs','US','NO'),
('Smelov','BY','NO');

update Celebrities
set FullName='Smelov V.V.'
where id =3;

insert into Celebrities values ('Test','NO','NO');

delete from Celebrities where id=4;
