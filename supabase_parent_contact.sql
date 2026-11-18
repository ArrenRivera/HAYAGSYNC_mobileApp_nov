-- Add required parent/guardian phone storage for new registrations.
alter table public.users
  add column if not exists contact_number text;

create or replace function public.sync_parent_contact_number()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
declare
  clean_contact text := nullif(
    btrim(new.raw_user_meta_data ->> 'contact_number'),
    ''
  );
begin
  update public.users
  set contact_number = clean_contact
  where auth_user_id = new.id and role = 'parent';
  return new;
end;
$$;

revoke all on function public.sync_parent_contact_number()
  from public, anon, authenticated;

drop trigger if exists on_auth_user_created_zz_contact_sync on auth.users;
create trigger on_auth_user_created_zz_contact_sync
after insert on auth.users
for each row execute procedure public.sync_parent_contact_number();
