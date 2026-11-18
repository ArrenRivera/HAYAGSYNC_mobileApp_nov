-- Run once in Supabase SQL Editor to allow up to two parent email addresses per child:
-- the primary parent's email plus one additional, already registered parent email.

create table if not exists public.student_guardians (
  student_id bigint not null references public.students(id) on delete cascade,
  guardian_profile_id bigint not null references public.users(id) on delete cascade,
  added_by bigint not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_profile_id)
);
create unique index if not exists student_guardians_one_guardian_per_student
  on public.student_guardians(student_id);
alter table public.student_guardians enable row level security;
revoke all on table public.student_guardians from public, anon, authenticated;

create or replace function public.parent_has_student_access(p_student_id bigint)
returns boolean language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.students s
    where s.id = p_student_id
      and (
        s.parent_id = public.current_profile_id()
        or exists (
          select 1 from public.student_guardians g
          where g.student_id = s.id
            and g.guardian_profile_id = public.current_profile_id()
        )
      )
  )
$$;

create or replace function public.get_parent_children()
returns setof public.students language sql stable security definer
set search_path = public, auth
as $$
  select s.* from public.students s
  where public.parent_has_student_access(s.id)
  order by s.name
$$;

create or replace function public.link_child_guardian(
  p_student_id bigint,
  p_guardian_email text
) returns text language plpgsql security definer
set search_path = public, auth
as $$
declare
  profile_id bigint := public.current_profile_id();
  guardian_id bigint;
  clean_email text := lower(btrim(p_guardian_email));
  existing_count integer;
begin
  if auth.uid() is null or public.current_app_role() <> 'parent' then
    raise exception 'Only a signed-in parent can share child access.';
  end if;
  if not exists (
    select 1 from public.students s
    where s.id = p_student_id and s.parent_id = profile_id
  ) then
    raise exception 'Only the primary linked parent can add another email.';
  end if;
  if clean_email = '' or clean_email = (
    select lower(email) from public.users where id = profile_id
  ) then
    raise exception 'Enter a different parent email address.';
  end if;

  select u.id into guardian_id from public.users u
  where lower(u.email) = clean_email and u.role = 'parent'
    and u.auth_user_id is not null limit 1;
  if guardian_id is null then
    raise exception 'No parent account uses this email yet. Ask the other guardian to register first.';
  end if;
  if exists (
    select 1 from public.student_guardians g
    where g.student_id = p_student_id and g.guardian_profile_id = guardian_id
  ) then
    return 'This parent account already has access.';
  end if;

  select count(*) into existing_count from public.student_guardians
  where student_id = p_student_id;
  if existing_count >= 1 then
    raise exception 'A child can have up to 2 parent email addresses in total.';
  end if;

  insert into public.student_guardians (student_id, guardian_profile_id, added_by)
  values (p_student_id, guardian_id, profile_id);
  return 'Additional parent email added successfully.';
end;
$$;

create or replace function public.get_child_guardians(p_student_id bigint)
returns table (email text, guardian_name text, linked_at timestamptz)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not exists (
    select 1 from public.students s
    where s.id = p_student_id and s.parent_id = public.current_profile_id()
  ) then
    raise exception 'Only the primary linked parent can manage guardian access.';
  end if;
  return query
    select u.email, u.name, g.created_at
    from public.student_guardians g
    join public.users u on u.id = g.guardian_profile_id
    where g.student_id = p_student_id
    order by g.created_at;
end;
$$;

create or replace function public.unlink_child_guardian(
  p_student_id bigint,
  p_guardian_email text
) returns void language plpgsql security definer
set search_path = public, auth
as $$
begin
  if not exists (
    select 1 from public.students s
    where s.id = p_student_id and s.parent_id = public.current_profile_id()
  ) then
    raise exception 'Only the primary linked parent can remove guardian access.';
  end if;
  delete from public.student_guardians g
  using public.users u
  where g.student_id = p_student_id and u.id = g.guardian_profile_id
    and lower(u.email) = lower(btrim(p_guardian_email));
end;
$$;

drop policy if exists student_guardians_select_owner_or_guardian on public.student_guardians;
create policy student_guardians_select_owner_or_guardian on public.student_guardians
for select to authenticated using (
  guardian_profile_id = public.current_profile_id()
  or exists (
    select 1 from public.students s
    where s.id = student_id and s.parent_id = public.current_profile_id()
  )
);

drop policy if exists students_select_owner_or_staff on public.students;
create policy students_select_owner_or_staff on public.students for select to authenticated
using (
  parent_id = public.current_profile_id()
  or public.is_staff()
  or public.parent_has_student_access(id)
);

create or replace function public.can_access_report(p_report_id bigint)
returns boolean language sql stable security definer
set search_path = public, auth
as $$
  select public.is_staff() or exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and (r.parent_id = public.current_profile_id()
        or public.parent_has_student_access(r.student_id))
  )
$$;

drop policy if exists reports_insert_owner_or_staff on public.reports;
create policy reports_insert_owner_or_staff on public.reports for insert to authenticated
with check (
  public.is_staff()
  or (
    public.current_app_role() = 'parent'
    and parent_id = public.current_profile_id()
    and (student_id is null or public.parent_has_student_access(student_id))
  )
);

create or replace function public.guard_report_inserts()
returns trigger language plpgsql security definer set search_path = public, auth
as $$
declare
  profile_name text;
begin
  if public.current_app_role() = 'parent' then
    select u.name into profile_name from public.users u where u.id = public.current_profile_id();
    if new.student_id is not null then
      select s.name, s.grade, s.section
      into new.student_name, new.student_grade, new.student_section
      from public.students s
      where s.id = new.student_id and public.parent_has_student_access(s.id);
    end if;
    new.parent_id := public.current_profile_id();
    new.parent_name := coalesce(profile_name, 'Parent');
    new.reporter_id := auth.uid()::text;
    new.reporter_name := coalesce(profile_name, 'Parent');
    new.report_source := 'Parent-Reported';
    new.status := 'Pending';
    new.appeal_count := 0;
    new.discipline_action := null;
    new.discipline_notes := null;
    new.escalation_reason := null;
    new.escalation_notes := null;
    new.escalated_to := null;
    new.board_findings := null;
    new.board_decision := null;
    new.punishment_imposed := null;
    new.president_notes := null;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_report_inserts_trigger on public.reports;
create trigger guard_report_inserts_trigger
before insert on public.reports
for each row execute procedure public.guard_report_inserts();

-- Create parent reports through a validated server-side transaction. This
-- avoids client INSERT policy mismatches while preserving parent/child checks.
create or replace function public.submit_parent_report(p_report jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  profile_id bigint;
  profile_name text;
  selected_student_id bigint;
  saved_report public.reports%rowtype;
  witnesses_value jsonb;
begin
  if auth.uid() is null or public.current_app_role() <> 'parent' then
    raise exception 'Only a signed-in parent can submit a report.';
  end if;

  profile_id := public.current_profile_id();
  if profile_id is null then
    raise exception 'Parent profile could not be found.';
  end if;

  selected_student_id := nullif(p_report ->> 'student_id', '')::bigint;
  if selected_student_id is not null
    and not public.parent_has_student_access(selected_student_id) then
    raise exception 'You do not have access to the selected student.';
  end if;

  if nullif(btrim(p_report ->> 'title'), '') is null
    or nullif(btrim(p_report ->> 'description'), '') is null
    or nullif(btrim(p_report ->> 'category'), '') is null
    or nullif(p_report ->> 'incident_date', '') is null then
    raise exception 'Complete the required report details before submitting.';
  end if;

  select u.name into profile_name
  from public.users u
  where u.id = profile_id;

  if jsonb_typeof(p_report -> 'witnesses') = 'string' then
    witnesses_value := (p_report ->> 'witnesses')::jsonb;
  else
    witnesses_value := p_report -> 'witnesses';
  end if;

  insert into public.reports (
    parent_id, parent_name, student_id, student_name, student_grade,
    student_section, title, description, category, incident_date,
    incident_location, evidence_url, evidence_verification_state,
    evidence_verification_details, ai_summary, status, bully_name,
    bully_grade_section, witnesses
  ) values (
    profile_id, coalesce(profile_name, 'Parent'), selected_student_id,
    coalesce(p_report ->> 'student_name', 'Student'),
    coalesce(p_report ->> 'student_grade', ''),
    coalesce(p_report ->> 'student_section', ''),
    btrim(p_report ->> 'title'), btrim(p_report ->> 'description'),
    btrim(p_report ->> 'category'),
    (p_report ->> 'incident_date')::timestamptz,
    coalesce(p_report ->> 'incident_location', ''),
    nullif(p_report ->> 'evidence_url', ''),
    coalesce(p_report ->> 'evidence_verification_state', 'Unverified'),
    nullif(p_report ->> 'evidence_verification_details', ''),
    nullif(p_report ->> 'ai_summary', ''), 'Pending',
    nullif(p_report ->> 'bully_name', ''),
    nullif(p_report ->> 'bully_grade_section', ''), witnesses_value
  ) returning * into saved_report;

  insert into public.timeline_events (
    report_id, title, description, actor_name, actor_role
  ) values (
    saved_report.id, 'Report Submitted',
    'Incident report filed by ' || coalesce(profile_name, 'parent') || '.',
    coalesce(profile_name, 'Parent'), 'Parent'
  );

  return to_jsonb(saved_report);
end;
$$;
revoke all on function public.submit_parent_report(jsonb) from public, anon;
grant execute on function public.submit_parent_report(jsonb) to authenticated;

drop policy if exists hayagsync_evidence_select_owner_or_staff on storage.objects;
create policy hayagsync_evidence_select_owner_or_staff on storage.objects
for select to authenticated using (
  bucket_id = 'hayagsync-evidence'
  and (
    (storage.foldername(name))[1] = public.current_profile_id()::text
    or public.is_staff()
    or exists (
      select 1 from public.reports r
      where (',' || coalesce(r.evidence_url, '') || ',') like '%,' || name || ',%'
        and public.can_access_report(r.id)
    )
  )
);

drop policy if exists ai_summaries_select_parent_scope on public.ai_summaries;
create policy ai_summaries_select_parent_scope on public.ai_summaries for select to authenticated
using (
  public.current_app_role() = 'parent' and exists (
    select 1 from public.students s
    where s.id::text = scope_id and public.parent_has_student_access(s.id)
  )
);
drop policy if exists ai_summaries_insert_parent_scope on public.ai_summaries;
create policy ai_summaries_insert_parent_scope on public.ai_summaries for insert to authenticated
with check (
  public.current_app_role() = 'parent' and exists (
    select 1 from public.students s
    where s.id::text = scope_id and public.parent_has_student_access(s.id)
  )
);

revoke all on function public.parent_has_student_access(bigint) from public, anon;
revoke all on function public.get_parent_children() from public, anon;
revoke all on function public.link_child_guardian(bigint,text) from public, anon;
revoke all on function public.get_child_guardians(bigint) from public, anon;
revoke all on function public.unlink_child_guardian(bigint,text) from public, anon;
grant execute on function public.parent_has_student_access(bigint) to authenticated;
grant execute on function public.get_parent_children() to authenticated;
grant execute on function public.link_child_guardian(bigint,text) to authenticated;
grant execute on function public.get_child_guardians(bigint) to authenticated;
grant execute on function public.unlink_child_guardian(bigint,text) to authenticated;
