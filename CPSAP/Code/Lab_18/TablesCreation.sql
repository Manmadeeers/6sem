use UNIVER;

create table FACULTY(
	FACULTY varchar(20) primary key,
	FACULTY_NAME varchar(50) not null
);

create table PULPIT(
	PULPIT varchar(20) primary key,
	PULPIT_NAME varchar(20) not null,
	FACULTY varchar(20) references FACULTY(FACULTY)
);

create table TEACHER(
	TEACHER varchar(20) primary key,
	TEACHER_NAME varchar(50) not null,
	PULPIT varchar(20)  references PULPIT(PULPIT)
);


create table SUBJECT(
	SUBJECT varchar(20) primary key,
	SUBJECT_NAME varchar(50) not null,
	PULPIT varchar(20) references PULPIT(PULPIT)
);


create table AUDITORIUM_TYPE(
	AUDITORIUM_TYPE varchar(20) primary key,
	AUDITORIUM_TYPE_NAME varchar(50) not null
);

create table AUDITORIUM(
	AUDITORIUM varchar(20) primary key,
	AUDITORIUM_NAME varchar(50) not null,
	AUDITORIUM_CAPACITY int not null,
	AUDITORIUM_TYPE varchar(20) references AUDITORIUM_TYPE(AUDITORIUM_TYPE)
);