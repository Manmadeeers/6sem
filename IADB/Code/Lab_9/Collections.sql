--create collections

create or replace type k2_storage_places_ntt as table of storage_place_t;
/

create or replace type k1_product_item_t as object(
	product_data product_t,
	places k2_storage_places_ntt,
	map member function map_product_id return number deterministic,
	member function places_count return number deterministic
);
/


create or replace type body k1_product_item_t as
	map member function map_product_id return number deterministic
	is
	begin
		return self.product_data.product_id;
	end;

	member function places_count return number deterministic
	is
	begin
		if self.places is null then
			return 0;
		else
			return self.places.count;
		end if;
	end;

end;
/

create or replace type k1_products_ntt as table of k1_product_item_t;
/

-- build K1 collection from object tables [for each product we put into K2 all storage placesthat match the same stock_id and have enough free capacity]

declare
	v_k1 k1_products_ntt;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	dbms_output.put_line('K1 size = '||v_k1.count);
end;
/


-- check whether an arbitrary element is a member of K1

declare
	v_k1 k1_products_ntt;
	v_elem k1_product_item_t;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	if v_k1.count>0 then
		v_elem:=v_k1(1);

		if v_elem member of v_k1 then
			dbms_output.put_line(
				'Element with product_id='||v_elem.product_data.product_id||' is a member of K1'
			);
		else
			dbms_output.put_line('Element is not a member of K1');
		end if;
	end if;
end;
/


--find empty collections K1 here "empty" means K1 elements whose nested K2 is empty
declare
	v_k1 k1_products_ntt;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	for r in(
		select
			k.product_data.product_id as product_id,
			k.product_data.name as product_name
		from table(v_k1) k
		where cardinality(k.places)=0
		order by k.product_data.product_id
	) loop
		dbms_output.put_line(
			'Empty K2 for product_id='||r.product_id||', name='||r.product_name
		);
	end loop;
end;
/

--convert collection K1 to another collection type;
-- conversion to vararray

create or replace type product_name_varray_t as varray(5000) of varchar2(4000);
/

-- convert collection K1 to varray
declare
	v_k1 k1_products_ntt;
	v_names product_name_varray_t;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	select cast(
		multiset(
			select to_char(k.product_data.name)
			from table(v_k1) k
			order by k.product_data.product_id
		) as product_name_varray_t
	)
	into v_names
	from dual;

	dbms_output.put_line('Converted varray size = '||v_names.count);

	for i in 1..least(v_names.count,10) loop
		dbms_output.put_line('product_name['||i||'] = '||v_names(i));
	end loop;
end;
/

-- convert collection K1 to relational data
declare
	v_k1 k1_products_ntt;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	for r in(
		select
			k.product_data.product_id as product_id,
			k.product_data.name as product_name,
			sp.stock_id as storage_id,
			sp.description as storage_description
		from table(v_k1) k,
			 table(k.places) sp
		order by k.product_data.product_id,sp.stock_id
	) loop
		dbms_output.put_line(
			'product_id='||r.product_id||
			', name='||r.product_name||
			', storage_id='||r.storage_id||
			', storage='||r.storage_description
		);
	end loop;
end;
/

--demonstrate BULK operations:  BULK COLLECT from K1 and FORALL update object table; example: increase quantity by 1 for first 10 products from K1

declare
	v_k1 k1_products_ntt;
	type product_id_tab_t is table of number;
	v_product_ids product_id_tab_t;
begin
	select k1_product_item_t(
		value(p),
		cast(
			multiset(
				select value(sp)
				from storage_places_obj sp
				where sp.stock_id=p.stock_id
				and sp.free_capacity()>=p.quantity
			) as k2_storage_places_ntt
		)
	)
	bulk collect into v_k1
	from products_obj p;

	select k.product_data.product_id
	bulk collect into v_product_ids
	from table(v_k1) k
	where rownum<=10
	order by k.product_data.product_id;

	forall i in 1..v_product_ids.count
		update products_obj p
		set p.quantity=p.quantity+1
		where p.product_id=v_product_ids(i);

	dbms_output.put_line('Rows updated by FORALL = '||sql%rowcount);

	commit;
end;
/


-- check bulk update result

select
	p.product_id,
	p.name,
	p.quantity
from products_obj p
where p.product_id in(
	select product_id
	from(
		select product_id
		from products_obj
		order by product_id
	)
	where rownum<=10
)
order by p.product_id;
/
