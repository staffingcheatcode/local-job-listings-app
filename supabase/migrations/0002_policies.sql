-- ============================================================================
-- Local Job Listings USA — Row Level Security (migration 0002)
-- Run AFTER 0001_schema.sql.
--
-- Access rules enforced here:
--   * Job seekers: only their own profile, resumes, cover letters, applications.
--   * Employers:   only applications for THEIR jobs (+ those applicants' docs).
--   * Agencies:    only applications for THEIR job orders.
--   * Admins:      everything.
--   * Jobs are public ONLY when moderation_status='approved' AND status='active'.
-- ============================================================================

alter table public.profiles                  enable row level security;
alter table public.job_seekers               enable row level security;
alter table public.employers                 enable row level security;
alter table public.staffing_agencies         enable row level security;
alter table public.jobs                       enable row level security;
alter table public.resumes                    enable row level security;
alter table public.cover_letters              enable row level security;
alter table public.applications               enable row level security;
alter table public.application_status_events  enable row level security;
alter table public.consent_logs               enable row level security;
alter table public.audit_logs                 enable row level security;
alter table public.admin_moderation_queue     enable row level security;

-- ---------------------------------------------------------------- PROFILES
create policy profiles_select_self_or_admin on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy profiles_insert_self on public.profiles
  for insert with check (id = auth.uid());
create policy profiles_update_self_or_admin on public.profiles
  for update using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- Note: role escalation is prevented at the app layer + (recommended) a trigger.

-- ------------------------------------------------------------- JOB SEEKERS
create policy js_all_own on public.job_seekers
  for all using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- --------------------------------------------------------------- EMPLOYERS
create policy emp_select_own_or_admin on public.employers
  for select using (owner_id = auth.uid() or public.is_admin());
create policy emp_insert_own on public.employers
  for insert with check (owner_id = auth.uid());
create policy emp_update_own_or_admin on public.employers
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

-- -------------------------------------------------------- STAFFING AGENCIES
create policy ag_select_own_or_admin on public.staffing_agencies
  for select using (owner_id = auth.uid() or public.is_admin());
create policy ag_insert_own on public.staffing_agencies
  for insert with check (owner_id = auth.uid());
create policy ag_update_own_or_admin on public.staffing_agencies
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

-- -------------------------------------------------------------------- JOBS
-- Public can read only approved + active jobs. Owners read their own (any status).
create policy jobs_select_public on public.jobs
  for select using (
    (moderation_status = 'approved' and status = 'active')
    or public.owns_job(id)
    or public.is_admin()
  );
create policy jobs_insert_owner on public.jobs
  for insert with check (
    created_by = auth.uid() and (
      (poster_type = 'employer'        and exists (select 1 from public.employers e        where e.id = employer_id and e.owner_id = auth.uid())) or
      (poster_type = 'staffing_agency' and exists (select 1 from public.staffing_agencies a where a.id = agency_id    and a.owner_id = auth.uid()))
    )
  );
-- Owner may edit content; moderation_status change is blocked by guard_moderation() trigger.
create policy jobs_update_owner_or_admin on public.jobs
  for update using (public.owns_job(id) or public.is_admin())
  with check (public.owns_job(id) or public.is_admin());

-- ----------------------------------------------------------------- RESUMES
-- Seeker manages own. Employer/agency may READ a resume that is attached to an
-- application on a job they own. Admin reads all.
create policy resumes_owner_all on public.resumes
  for all using (seeker_id = auth.uid() or public.is_admin())
  with check (seeker_id = auth.uid() or public.is_admin());
create policy resumes_select_for_owning_employer on public.resumes
  for select using (
    exists (
      select 1 from public.applications ap
      where ap.resume_id = resumes.id and public.owns_job(ap.job_id)
    )
  );

-- ------------------------------------------------------------ COVER LETTERS
create policy cl_owner_all on public.cover_letters
  for all using (seeker_id = auth.uid() or public.is_admin())
  with check (seeker_id = auth.uid() or public.is_admin());
create policy cl_select_for_owning_employer on public.cover_letters
  for select using (
    exists (
      select 1 from public.applications ap
      where ap.cover_letter_id = cover_letters.id and public.owns_job(ap.job_id)
    )
  );

-- ------------------------------------------------------------- APPLICATIONS
-- Seeker sees own. Employer/agency sees applications to jobs they own. Admin all.
create policy app_select_seeker_or_owner on public.applications
  for select using (
    seeker_id = auth.uid() or public.owns_job(job_id) or public.is_admin()
  );
-- Seeker applies for themselves; the job must be publicly visible at apply time.
create policy app_insert_seeker on public.applications
  for insert with check (
    seeker_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id and j.moderation_status = 'approved' and j.status = 'active'
    )
  );
-- Job owner (or admin) may update stage/reason. Seeker may NOT change stage.
-- (In practice the app calls the set_application_stage() RPC; this policy backstops it.)
create policy app_update_owner_or_admin on public.applications
  for update using (public.owns_job(job_id) or public.is_admin())
  with check (public.owns_job(job_id) or public.is_admin());

-- ------------------------------------------------ APPLICATION STATUS EVENTS
-- Read by the seeker (their app), the owning employer/agency, or admin.
-- No client INSERT/UPDATE/DELETE policy => only SECURITY DEFINER triggers write history.
create policy ase_select_related on public.application_status_events
  for select using (
    exists (
      select 1 from public.applications ap
      where ap.id = application_id
        and (ap.seeker_id = auth.uid() or public.owns_job(ap.job_id) or public.is_admin())
    )
  );

-- ------------------------------------------------------------- CONSENT LOGS
-- Append-only: insert your own, read your own (or admin). No update/delete policy.
create policy consent_insert_self on public.consent_logs
  for insert with check (user_id = auth.uid());
create policy consent_select_self_or_admin on public.consent_logs
  for select using (user_id = auth.uid() or public.is_admin());

-- --------------------------------------------------------------- AUDIT LOGS
-- Admin-readable only. Writes happen via SECURITY DEFINER write_audit() (no insert policy).
create policy audit_select_admin on public.audit_logs
  for select using (public.is_admin());

-- ------------------------------------------------------ ADMIN MODERATION Q
create policy modq_admin_all on public.admin_moderation_queue
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================================
-- STORAGE  (private buckets + per-user folder access)
--   Path convention: '{auth.uid()}/resume/<file>'  and  '{auth.uid()}/cover/<file>'
--   Employers do NOT get file access via storage RLS — they read resume.summary,
--   or fetch a signed URL from the get-resume-url edge function (service role).
-- ============================================================================
insert into storage.buckets (id, name, public) values ('resumes','resumes', false)
  on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('cover-letters','cover-letters', false)
  on conflict (id) do nothing;

create policy "resume owner read"   on storage.objects for select
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "resume owner write"  on storage.objects for insert
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "resume owner update" on storage.objects for update
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "resume owner delete" on storage.objects for delete
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cover owner read"   on storage.objects for select
  using (bucket_id = 'cover-letters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "cover owner write"  on storage.objects for insert
  with check (bucket_id = 'cover-letters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "cover owner update" on storage.objects for update
  using (bucket_id = 'cover-letters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "cover owner delete" on storage.objects for delete
  using (bucket_id = 'cover-letters' and (storage.foldername(name))[1] = auth.uid()::text);
