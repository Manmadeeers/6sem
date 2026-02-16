use UNIVER;

create table FACULTY(
	FACULTY nvarchar(20) primary key,
	FACULTY_NAME nvarchar(100) not null
);


create table PULPIT(
	PULPIT nvarchar(20) primary key,
	PULPIT_NAME nvarchar(100) not null,
	FACULTY nvarchar(20) references FACULTY(FACULTY)
);


create table TEACHER(
	TEACHER nvarchar(20) primary key,
	TEACHER_NAME nvarchar(100) not null,
	PULPIT nvarchar(20)  references PULPIT(PULPIT)
);



create table SUBJECT(
	SUBJECT nvarchar(20) primary key,
	SUBJECT_NAME nvarchar(150) not null,
	PULPIT nvarchar(20) references PULPIT(PULPIT)
);



create table AUDITORIUM_TYPE(
	AUDITORIUM_TYPE nvarchar(20) primary key,
	AUDITORIUM_TYPE_NAME nvarchar(50) not null
);



create table AUDITORIUM(
	AUDITORIUM nvarchar(20) primary key,
	AUDITORIUM_NAME nvarchar(100) not null,
	AUDITORIUM_CAPACITY int not null,
	AUDITORIUM_TYPE nvarchar(20) references AUDITORIUM_TYPE(AUDITORIUM_TYPE)
);
