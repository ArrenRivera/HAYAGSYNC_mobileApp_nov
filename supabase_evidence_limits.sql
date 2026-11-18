-- Apply this in Supabase SQL Editor after deploying the app update.
-- Evidence limits enforced by the app: 5 files / 50 MB total, with image
-- and video limits checked before upload. Storage also caps each anonymous
-- evidence object at 20 MB.

update storage.buckets
set file_size_limit = 20971520
where id = 'hayagsync-anonymous-evidence';

create or replace function public.submit_anonymous_report(p_report jsonb)
returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  new_report_id bigint;
begin
  insert into public.reports (
    parent_id, parent_name, student_id, student_name, student_grade, student_section,
    title, description, category, incident_date, incident_location, evidence_url,
    evidence_verification_state, status, bully_name, bully_grade_section, witnesses,
    report_source, reporter_name, urgency_level
  ) values (
    null, 'Anonymous Reporter', null,
    coalesce(nullif(p_report ->> 'student_name', ''), 'Unidentified Student'),
    coalesce(nullif(p_report ->> 'student_grade', ''), 'Grade 7'),
    coalesce(nullif(p_report ->> 'student_section', ''), 'Section To Be Determined'),
    coalesce(nullif(p_report ->> 'title', ''), 'Anonymous Bullying Report'),
    coalesce(p_report ->> 'description', ''),
    coalesce(p_report ->> 'category', 'Other'),
    coalesce((p_report ->> 'incident_date')::timestamptz, now()),
    coalesce(p_report ->> 'incident_location', ''),
    nullif(p_report ->> 'evidence_url', ''),
    case when nullif(p_report ->> 'evidence_url', '') is null
      then 'No evidence uploaded' else 'Uploaded - Awaiting Review' end,
    'Pending', nullif(p_report ->> 'bully_name', ''),
    nullif(p_report ->> 'bully_grade_section', ''), p_report -> 'witnesses',
    'Anonymous', 'Anonymous Reporter', coalesce(p_report ->> 'urgency_level', 'Moderate')
  ) returning id into new_report_id;

  insert into public.timeline_events (report_id, title, description, actor_name, actor_role)
  values (new_report_id, 'Anonymous Report Submitted',
    'Incident report submitted anonymously. Case awaiting Stage 1: OSD Initial Assessment.',
    'Anonymous Reporter', 'Anonymous');

  insert into public.notifications (recipient_role, title, message, report_id)
  values ('osd', 'New Anonymous Report: Case #' || new_report_id,
    'A new anonymous report was submitted. Stage 1: OSD Initial Assessment required.', new_report_id);

  return new_report_id;
end;
$$;

-- Existing rows with attached evidence now wait for human review.
update public.reports
set evidence_verification_state = 'Uploaded - Awaiting Review'
where evidence_url is not null
  and btrim(evidence_url) <> ''
  and evidence_verification_state = 'Unverified';
