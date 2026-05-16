
begin execute immediate 'drop index idx_storage_places_obj_description'; exception when others then null; end;
/
begin execute immediate 'drop index idx_products_obj_name'; exception when others then null; end;
/
begin execute immediate 'drop index idx_storage_places_obj_free_capacity'; exception when others then null; end;
/
begin execute immediate 'drop index idx_products_obj_total_value'; exception when others then null; end;
/

begin execute immediate 'drop view storage_places_ov'; exception when others then null; end;
/
begin execute immediate 'drop view products_ov'; exception when others then null; end;
/

begin execute immediate 'drop table storage_places_obj purge'; exception when others then null; end;
/
begin execute immediate 'drop table products_obj purge'; exception when others then null; end;
/

begin execute immediate 'drop type storage_place_t force'; exception when others then null; end;
/
begin execute immediate 'drop type product_t force'; exception when others then null; end;
/

alter session set container = WarehousePDB;

grant create type to Warehouse_Manager;

select * 
from dba_sys_privs
where grantee='WAREHOUSE_MANAGER';

--1: Object types creation

--------STOCKS---------------
--declaration


create or replace type storage_place_t as object(
	stock_id number,
	capacity number,
	filled_part number,
	description nvarchar2(100),

	constructor function storage_place_t(
		p_capacity number,
		p_description nvarchar2
	) return self as result,

	map member function sort_key return number deterministic,
	member function free_capacity return number deterministic,
	member procedure load_goods(p_amount number)
);
/


--implementaion

create or replace type body storage_place_t as

	constructor function storage_place_t(
		p_capacity number,
		p_description nvarchar2
	) return self as result
	is
	begin
		self.stock_id:=null;
		self.capacity:=p_capacity;
		self.filled_part:=0;
		self.description:=p_description;
		return;
	end;

	map member function sort_key return number deterministic
	is
	begin
		return self.capacity-self.filled_part;
	end;

	member function free_capacity return number deterministic
	is
	begin
		return self.capacity-self.filled_part;
	end;

	member procedure load_goods(p_amount number)
	is
	begin
		if p_amount<0 then
			raise_application_error(-20001,'amount must be positive');
		end if;

		if self.filled_part+p_amount>self.capacity then
			raise_application_error(-20002,'capacity exceeded');
		end if;

		self.filled_part:=self.filled_part+p_amount;
	end;

end;
/


----------------PRODUCTS---------------

--declaration
create or replace type product_t as object(
	product_id number,
	stock_id number,
	name nvarchar2(200),
	price number(19,4),
	quantity number,

	constructor function product_t(
		p_name nvarchar2,
		p_price number,
		p_quantity number
	) return self as result,

	map member function sort_key return number deterministic,
	member function total_value return number deterministic,
	member procedure add_quantity(p_amount number)
);
/

--implementation
create or replace type body product_t as

	constructor function product_t(
		p_name nvarchar2,
		p_price number,
		p_quantity number
	) return self as result
	is
	begin
		self.product_id:=null;
		self.stock_id:=null;
		self.name:=p_name;
		self.price:=p_price;
		self.quantity:=p_quantity;
		return;
	end;

	map member function sort_key return number deterministic
	is
	begin
		return self.price*self.quantity;
	end;

	member function total_value return number deterministic
	is
	begin
		return self.price*self.quantity;
	end;

	member procedure add_quantity(p_amount number)
	is
	begin
		if p_amount<0 then
			raise_application_error(-20003,'amount must be positive');
		end if;

		self.quantity:=self.quantity+p_amount;
	end;

end;
/



--2: Copy data from relational to object tables

--object table for stocks
create table storage_places_obj of storage_place_t(
	primary key(stock_id)
);
/

--object table for products
create table products_obj of product_t(
	primary key(product_id)
);
/

--copy data from STOCKS
insert into storage_places_obj
select storage_place_t(
	stock_id,
	capacity,
	filled_part,
	description
)
from stocks;
/

--copy data from PRODUCTS
insert into products_obj
select product_t(
	product_id,
	stock_id,
	name,
	price,
	quantity
)
from products;
/

commit;
/

--quick check
select * from storage_places_obj;
select * from products_obj;
/

--4: Object views usage demo

--view for storage_t
create or replace view storage_places_ov of storage_place_t
with object identifier(stock_id)
as
select
	stock_id,
	capacity,
	filled_part,
	description
from stocks;
/

--view for products_t

create or replace view products_ov of product_t
with object identifier(product_id)
as
select
	product_id,
	stock_id,
	name,
	price,
	quantity
from products;
/


--basic view usage

select
	s.stock_id,
	s.description,
	s.capacity,
	s.filled_part
from storage_places_ov s;
/

select
	p.product_id,
	p.name,
	p.price,
	p.quantity
from products_ov p;
/

--call function and procedure methods via object view

select
	s.stock_id,
	s.description,
	s.free_capacity() as free_capacity,
	s.sort_key() as compare_key
from storage_places_ov s;
/

select
	p.product_id,
	p.name,
	p.price,
	p.quantity,
	p.total_value() as total_value,
	p.sort_key() as compare_key
from products_ov p;
/


--object view usage for relational tables demo

update storage_places_ov
set filled_part=filled_part+50
where stock_id=28;
/

select * from Products;
update products_ov
set quantity=quantity+10
where product_id=28;
/

commit;
/

--check relational tables to see wheather the changes have applied
select * from Stocks where Stock_id=28;

select * from Products where Product_id=28;


--5: demonstrate indxes usage (indexing by attribute, indexing my method in object table)
begin execute immediate 'drop index idx_storage_places_obj_description'; exception when others then null; end;
/
begin execute immediate 'drop index idx_products_obj_name'; exception when others then null; end;
/
begin execute immediate 'drop index idx_storage_places_obj_free_capacity'; exception when others then null; end;
/
begin execute immediate 'drop index idx_products_obj_total_value'; exception when others then null; end;
/

-- index by attribute
create index idx_storage_places_obj_description
on storage_places_obj(description);
/

create index idx_products_obj_name
on products_obj(name);
/

-- index by method
create index idx_storage_places_obj_free_capacity
on storage_places_obj s (s.free_capacity());
/   

create index idx_products_obj_total_value
on products_obj p (p.total_value());
/

-- sample queries using attribute indexes
explain plan for
select *
from storage_places_obj
where description='stock 134';

select * from table(dbms_xplan.display);
/


explain plan for
select *
from products_obj
where name='Industrial Cleaning Acid';
/

select * from table(dbms_xplan.display);
/

-- sample queries using method indexes
explain plan for
select
	s.stock_id,
	s.description,
	s.free_capacity() as free_capacity
from storage_places_obj s
where s.free_capacity()>100;
/

select * from table(dbms_xplan.display);
/



explain plan for
select
	p.product_id,
	p.name,
	p.total_value() as total_value
from products_obj p
where p.total_value()>10000;
/

select * from table(dbms_xplan.display);
/

