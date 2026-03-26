use warehouse;

create table stocks(
	stock_id int identity(1,1) primary key,
	capacity int not null check(capacity>0),
	filled_part int not null default 0,
	description nvarchar(100) not null,
	constraint ck_stock_capacity check(filled_part<=capacity)
);

create table users(
	user_id int identity(1,1) primary key,
	email varchar(255) not null unique,
	role varchar(30) not null,
	password_hash varbinary(64) not null unique,
	created_at datetime2 default getdate(),
	constraint ck_user_role check(role in ('Operator', 'Manager', 'Accountant', 'Admin'))
);

create table products(
	product_id int identity(1,1) primary key,
	stock_id int not null,
	name nvarchar(200) not null,
	price decimal(19,4) not null default 0.0000,
	quantity int not null default 0 check(quantity>=0),
	constraint fk_products_stocks foreign key(stock_id) references stocks(stock_id)
);

create table tasks(
	task_id int identity(1,1) primary key,
	user_id int not null,
	due_date datetime2 not null,
	priority varchar(30) not null check(priority in ('Low','Moderate','High','Highest')),
	description nvarchar(max) not null,
	is_completed bit default 0,
	constraint fk_tasks_users foreign key (user_id) references users(user_id)
);

create table orders(
	order_id int identity(1,1) primary key,
	order_date datetime2 not null default getdate(),
	order_status varchar(50) not null default 'Created',
	total_amount decimal(19,4) default 0.0000,
	constraint ck_order_status check(order_status in ('Created','In work','Shipped','Canceled'))
);

create table order_items(
	item_id int identity(1,1) primary key,
	order_id int not null,
	product_id int not null,
	quantity int not null default 1 check(quantity>0),
	constraint fk_orderitems_orders foreign key (order_id) references orders(order_id),
	constraint fk_orderitems_products foreign key (product_id) references products(product_id)
);

create table pack(
	pack_id int identity(1,1) primary key,
	user_id int not null,
	order_id int not null,
	pack_date datetime2 not null default getdate(),
	pack_status varchar(50) check(pack_status in ('Not packed','Packed','Shipped')) default 'Not packed',
	constraint fk_pack_users foreign key(user_id) references users(user_id),
	constraint fk_pack_orders foreign key(order_id) references orders(order_id)
);

create table pack_items(
	item_id int identity(1,1) primary key,
	pack_id int not null,
	product_id int not null,
	quantity int not null default 1 check(quantity>0),
	unit_price decimal(19,4) not null check(unit_price>=0),
	constraint fk_packitems_pack foreign key(pack_id) references pack(pack_id),
	constraint fk_packitems_products foreign key(product_id) references products(product_id)
);
