alter pluggable database WarehousePDB open;

--1: alter table Stocks to add hierarchycal column
select * from Stocks;

alter table Stocks add parent_id number;

alter table Stocks
add constraint fk_stocks_parent
foreign key (parent_id) references stocks(stock_id)
deferrable initially immediate;



create index ix_stocks_parent_id on stocks(parent_id);

update stocks 
set parent_id=NULL
where stock_id=27;

select * from Stocks;
--2:create a procedure to print all descendants of a specific node

create or replace procedure sp_print_tree(
    p_ParentID number
)
as
    
    v_indent_size constant number := 4;
begin
    
    DBMS_OUTPUT.PUT_LINE('--- Hierarchy for node ID: ' || p_ParentID || ' ---');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------');

    
    for r in (
        select
            level as tree_level,
            description,
            stock_id,
            case
                when level = 1 then description
                else LPAD(' ', (LEVEL - 1) * v_indent_size, ' ') || '└── ' || description
            end as visual_node
        from stocks
        start with stock_id = p_parentid
        connect by prior stock_id = parent_id
        order siblings by description
    ) 
    loop
       
        DBMS_OUTPUT.PUT_LINE(r.visual_node);
    end loop;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------');
exception
    when others then
        DBMS_OUTPUT.PUT_LINE('Failed to print dependancy tree: ' || SQLERRM);
end;
/

set serveroutput on;
begin
    sp_print_tree(27);
end;

select * from Stocks;


--3: procedures to add a new descendant or make descendants out of existing data

create or replace procedure sp_enslave_existant(
    p_parent_id number,
    p_child_id number
)
as
    v_exists number;
    e_same_node exception;
    e_no_parent exception;
    e_no_child exception;
begin
    if p_parent_id = p_child_id then
        raise e_same_node;
    end if;
    
    select count(*)
    into v_exists
    from stocks
    where stock_id = p_parent_id;
    
    if v_exists=0 then 
        raise e_no_parent;
    end if;
    
    select count(*)
    into v_exists
    from stocks
    where stock_id = p_child_id;
    
    if v_exists = 0 then
        raise e_no_child;
    end if;
    
    update stocks
    set parent_id = p_parent_id
    where stock_id = p_child_id;
    
    commit;
    
    dbms_output.put_line('Slave ' || p_child_id || 'successfully added for master '|| p_parent_id);

exception
    when e_same_node then 
        RAISE_APPLICATION_ERROR(-20001,'Child and parent ids are simillar');
    when e_no_parent then
        RAISE_APPLICATION_ERROR(-20002,'No parent found with this id');
    when e_no_child then
        RAISE_APPLICATION_ERROR(-20003,'No child found with this id');
    when others then
        rollback;
        raise;
    
end;
select * from Stocks;
exec sp_enslave_existant(27,14);

create or replace procedure sp_enslave_new(
    p_parent_id number,
    p_capacity number,
    p_description varchar2
)
as
    v_parent_exists number;
begin
    if p_parent_id is not null then
        select count(*)
        into v_parent_exists
        from stocks
        where stock_id = p_parent_id;
        
        if v_parent_exists = 0 then
            RAISE_APPLICATION_ERROR(-20003,'No parent found for thid id');
        end if;
    end if;
    
    insert into stocks(capacity, description, parent_id)
    values (p_capacity, p_description, p_parent_id);
    
    commit;
exception
    when others then
        rollback;
        raise;
        
end;

select * from Stocks;
exec sp_enslave_new(30,100,'Dry goods shelf A');



create or replace procedure sp_swap_slaves(
    p_first_node number,
    p_second_node number
)
as
    v_exists number;
    v_temp_id constant number := -999999;
begin
    execute immediate 'SET CONSTRAINTS ALL DEFERRED';

    if p_first_node = p_second_node then 
        RAISE_APPLICATION_ERROR(-20010, 'Could not swap children of identical nodes');
    end if;
    
    select COUNT(*)
    into v_exists
    from Stocks
    where stock_id in (p_first_node, p_second_node);
    
    if v_exists<2 then 
        RAISE_APPLICATION_ERROR(-20011,'One of the nodes does not exists. Unable to swap');
    end if;
    
    update stocks
    set parent_id = v_temp_id
    where parent_id = p_first_node;
    
    update stocks
    set parent_id = p_first_node
    where parent_id = p_second_node;
    
    update stocks
    set parent_id = p_second_node
    where parent_id = v_temp_id;
    
    commit;
    
exception
    when others then 
        rollback;
        raise;
    
end;


select * from Stocks;
exec sp_swap_slaves(10,11);