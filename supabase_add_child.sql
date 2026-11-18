-- Run once in Supabase SQL Editor to enable Add Another Child.
-- Existing roster entries can only be linked when all reviewed OCR details match.
alter table public.students add column if not exists first_name text;
alter table public.students add column if not exists last_name text;
alter table public.students add column if not exists middle_initial text;
alter table public.students add column if not exists gender text;
alter table public.students add column if not exists parent_fullname text;

create or replace function public.add_child_to_parent(
  p_student_number text,
  p_student_name text,
  p_grade text,
  p_section text,
  p_academic_year text,
  p_first_name text,
  p_last_name text,
  p_middle_initial text,
  p_gender text
) returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  profile_id bigint;
  profile_name text;
  existing_student public.students%rowtype;
  normalized_middle text;
begin
  if auth.uid() is null or public.current_app_role() <> 'parent' then
    raise exception 'Only a signed-in parent can add a linked child.';
  end if;
  if nullif(btrim(p_student_number), '') is null then
    raise exception 'Student number is required.';
  end if;
  if nullif(btrim(p_first_name), '') is null
    or nullif(btrim(p_last_name), '') is null
    or nullif(btrim(p_middle_initial), '') is null
    or nullif(btrim(p_grade), '') is null
    or nullif(btrim(p_section), '') is null
    or nullif(btrim(p_gender), '') is null then
    raise exception 'Complete all student details before linking the child.';
  end if;

  profile_id := public.current_profile_id();
  select u.name into profile_name from public.users u where u.id = profile_id;
  normalized_middle := lower(regexp_replace(btrim(p_middle_initial), '\.$', ''));

  select * into existing_student
  from public.students
  where lrn = btrim(p_student_number)
  for update;

  if found then
    if lower(btrim(coalesce(existing_student.first_name, ''))) <> lower(btrim(p_first_name))
      or lower(btrim(coalesce(existing_student.last_name, ''))) <> lower(btrim(p_last_name))
      or lower(regexp_replace(btrim(coalesce(existing_student.middle_initial, '')), '\.$', '')) <> normalized_middle
      or lower(btrim(coalesce(existing_student.grade, ''))) <> lower(btrim(p_grade))
      or lower(btrim(coalesce(existing_student.section, ''))) <> lower(btrim(p_section))
      or lower(btrim(coalesce(existing_student.gender, ''))) <> lower(btrim(p_gender)) then
      raise exception 'The student number exists with different details. Please check the certificate or contact the school.';
    end if;

    if existing_student.parent_id is not null and existing_student.parent_id <> profile_id then
      raise exception 'This student is already linked to another parent account. Please contact the school office.';
    end if;

    update public.students
    set parent_id = profile_id,
        parent_fullname = profile_name
    where id = existing_student.id;
    return existing_student.id;
  end if;

  insert into public.students (
    parent_id, name, grade, section, academic_year, lrn,
    first_name, last_name, middle_initial, gender, parent_fullname
  ) values (
    profile_id, btrim(p_student_name), btrim(p_grade), btrim(p_section),
    coalesce(nullif(btrim(p_academic_year), ''), ''), btrim(p_student_number),
    btrim(p_first_name), btrim(p_last_name),
    regexp_replace(btrim(p_middle_initial), '\.$', ''), btrim(p_gender), profile_name
  ) returning id into existing_student.id;

  return existing_student.id;
end;
$$;

revoke all on function public.add_child_to_parent(text,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.add_child_to_parent(text,text,text,text,text,text,text,text,text) to authenticated;
