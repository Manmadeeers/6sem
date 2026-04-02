alter pluggable database WarehousePDB open;

select * from users;

alter table users
add manager_id number;

alter table users
add constraint fk_users_hierarchy foreign key (manager_id) references users(user_id);

create or replace procedure sp_get_user_subordinates(p_user_id number)
is
begin
    for rec in(
        select 
            level as hierarchy_level,
            email,
            user_role,
            lpad(' ',2 * (level-1)) || email as visual_tree
        from users
        start with user_id = p_user_id
        connect by prior user_id = manager_id
    ) loop
        dbms_output.put_line('level ' || rec.hierarchy_level || ': '|| rec.visual_tree);
      end loop;
end;

begin
    sp_get_user_subordinates(p_user_id=>8);
end;

create or replace procedure sp_add_user_subordinate(
    p_manager_id number,
    p_user_id number
)
is
begin
    update users
    set manager_id=p_manager_id
    where user_id=p_user_id;
    
    commit;
    
    dbms_output.put_line('Users manager successsfullu changed. New manager id: ' || p_manager_id);
end;

select * from users;

begin
    --sp_addusersubordinate(p_manager_id=>8,p_user_id=>13);
    --sp_addusersubordinate(p_manager_id=>8,p_user_id=>10);
     sp_addusersubordinate(p_manager_id=>10,p_user_id=>11);
    sp_addusersubordinate(p_manager_id=>10,p_user_id=>12);
end;



create or replace procedure sp_add_user_subordinate_full(
    p_manager_id number,
    p_email varchar2,
    p_user_role varchar2,
    p_password_raw raw
)
is
begin
    insert into users (email, user_role, password_hash, manager_id)
    values (p_email, p_user_role,p_password_raw,p_manager_id);
    
    commit;
    
    dbms_output.put_line('User successfully added under manager with id: ' || p_manager_id);
end;

exec sp_add_user_subordinate_full(8,'reserve_admin@warehouse.com','Manager',HEXTORAW('D4E5F6'));


create or replace procedure sp_move_user_subordinates(
    p_old_manager_id number,
    p_new_manager_id number
)
is
begin
    update users
    set manager_id = p_new_manager_id
    where manager_id = p_old_manager_id;
    
    if SQL%ROWCOUNT = 0 then
        dbms_output.put_line('There are no subordinates to move');
    else
        dbms_output.put_line('Moved ' || SQL%ROWCOUNT || 'subordinates');
    end if;
    
    commit;
exception
    when others then
        rollback;
        raise;
end;
/

select * from users;
exec sp_move_user_subordinates(8,14);

begin
    sp_get_user_subordinates(p_user_id=>14);
end;