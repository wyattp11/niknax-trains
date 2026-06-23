update public.members
set role = 'NN Owner',
    updated_at = now()
where lower(username) = 'crazylamplady';

update public.members
set role = 'NN Admin',
    updated_at = now()
where lower(username) = 'moonskyvintage';
