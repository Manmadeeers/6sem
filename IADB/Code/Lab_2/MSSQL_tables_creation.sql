use Warehouse;

create table Stocks(
	Stock_ID int primary key,
	Capacity int not null check(Capacity>0),
	Filled_part int not null default 0,
	Description nvarchar(100) not null,
	constraint CK_Stock_Capacity check(Filled_part<=Capacity)
);

create table Users(
	User_ID int primary key,
	Email varchar(255) not null unique,
	Role varchar(30) not null,
	Password_hash varbinary(64) not null unique, --SHA-512 algorithm
	Created_at datetime2 default GETDATE(),
	constraint CK_User_Role check(Role in ('Operator', 'Manager', 'Accountant', 'Admin')),
);

create table Products(
	Product_ID int primary key,
	Stock_id int not null,
	Name nvarchar(200) not null,
	Price decimal(19,4) not null default 0.0000,
	Quantity int not null default 0 check(Quantity>=0),
	constraint FK_Products_Stocks foreign key(Stock_ID) references Stocks(Stock_ID)
);



create table Tasks(
	Task_ID int primary key,
	User_ID int not null,
	Due_date datetime2 not null,
	Priority varchar(30) not null check(Priority in ('Low','Moderate','High','Highest')),
	Description nvarchar(max) not null,
	Is_completed bit default 0,
	constraint FK_Tasks_Users foreign key (User_ID) references Users(User_ID)
);

create table Orders(
	Order_ID int primary key,
	Order_date datetime2 not null default GETDATE(),
	Order_status varchar(50) not null  default 'Created',
	Total_amount decimal(19,4) default 0.0000,
	constraint CK_Order_Status check(Order_status in ('Created','In work','Shipped','Canceled'))
);

create table Order_items(
	Item_ID int primary key,
	Order_ID int not null,
	Product_ID int not null,
	Quantity int not null default 1 check(Quantity>0),
	constraint FK_OrderItems_Orders foreign key (Order_ID) references Orders(Order_ID),
	constraint FK_OrderItems_Products foreign key (Product_ID) references Products(Product_ID)
);

create table Pack(
	Pack_ID int primary key,
	User_ID int not null,
	Order_ID int not null,
	Pack_date datetime2 not null default GETDATE(),
	Pack_status varchar(50) check(Pack_status in ('Not packed','Packed','Shipped')) default 'Not packed',
	constraint FK_Pack_Users foreign key(User_ID) references Users(User_ID),
	constraint FK_Pack_Orders foreign key(Order_ID) references Orders(Order_ID)
);


create table Pack_items(
	Item_ID int primary key,
	Pack_ID int not null ,
	Product_ID int not null,
	Quantity int not null default 1 check(Quantity>0) ,
	Unit_price decimal(19,4) not null check(Unit_price>=0),
	constraint FK_PackItems_Pack foreign key(Pack_ID) references Pack(Pack_ID),
	constraint FK_PackItems_Products foreign key(Product_ID) references Products(Product_ID)
);

