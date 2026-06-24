-- ============================================================================
-- Local Job Listings USA — Core schema (migration 0001)
-- Postgres / Supabase. Safe to run once in the SQL editor or via `supabase db push`.
-- RLS POLICIES live in 0002_policies.sql — run that AFTER this file.
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()

-- ----------------------------------------------------------------------------
-- ENUMS  (enum-constrained values can never be free-text — see reject_reason)
-- ----------------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('job_seeker','employer','staffing_agency','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type employment_type as enum ('full_time','part_time','temp_to_hire','contract','direct_hire');
exception when duplicate_object then null; end $$;

do $$ begin
  create type job_status as enum ('draft','active','paused','closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type moderation_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type verification_status as enum ('pending','verified','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type poster_type as enum ('employer','staffing_agency');
exception when duplicate_object then null; end $$;

-- The Domino's-style tracker stages, in order.
do $$ begin
  create type application_stage as enum (
    'submitted','resume_received','in_review','second_stage',
    'interview_requested','offer_extended','hired','not_selected'
  );
exception when duplicate_object then null; end $$;

-- SAFE reject reasons only. No discriminatory / free-text reasons are possible.
do $$ begin
  create type reject_reason as enum (
    'position_filled','experience_mismatch','certification_required',
    'schedule_mismatch','location_mismatch','employer_selected_other','other_neutral'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type consent_type as enum (
    'terms','privacy','sms_tcpa','resume_share','non_discrimination','dns_opt_out','cookie'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type moderation_item_type as enum ('job','employer','agency','report');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- PROFILES  (1:1 with auth.users)
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        user_role not null default 'job_seeker',
  email       text,
  phone       text,
  full_name   text,
  created_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- JOB SEEKERS  (id == profiles.id)
-- ----------------------------------------------------------------------------
create table if not exists public.job_seekers (
  id          uuid primary key references public.profiles(id) on delete cascade,
  headline    text,
  location    text,
  lat         double precision,
  lng         double precision,
  radius_mi   int  default 25,
  pay_min     numeric(8,2),
  pay_max     numeric(8,2),
  job_types   text[] default '{}',
  shifts      text[] default '{}',
  categories  text[] default '{}',
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- EMPLOYERS  (a profile can own one employer org in the MVP)
-- ----------------------------------------------------------------------------
create table if not exists public.employers (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.profiles(id) on delete cascade,
  company_name        text not null,
  industry            text,
  size                text,
  hq_city             text,
  about               text,
  logo_url            text,
  verification_status verification_status not null default 'pending',
  agreed_non_discrimination boolean not null default false,
  created_at          timestamptz not null default now()
);
create index if not exists employers_owner_idx on public.employers(owner_id);

-- ----------------------------------------------------------------------------
-- STAFFING AGENCIES  (kept minimal for this MVP turn; same shape as employers)
-- ----------------------------------------------------------------------------
create table if not exists public.staffing_agencies (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.profiles(id) on delete cascade,
  name                text not null,
  about               text,
  specialties         text[] default '{}',
  verification_status verification_status not null default 'pending',
  agreed_non_discrimination boolean not null default false,
  created_at          timestamptz not null default now()
);
create index if not exists agencies_owner_idx on public.staffing_agencies(owner_id);

-- ----------------------------------------------------------------------------
-- JOBS
--   * pay_min/pay_max REQUIRED (pay-transparency).
--   * Not public until moderation_status='approved' AND status='active'.
--   * Exactly one of employer_id / agency_id, matching poster_type.
-- ----------------------------------------------------------------------------
create table if not exists public.jobs (
  id                 uuid primary key default gen_random_uuid(),
  poster_type        poster_type not null,
  employer_id        uuid references public.employers(id) on delete cascade,
  agency_id          uuid references public.staffing_agencies(id) on delete cascade,
  created_by         uuid not null references public.profiles(id),
  title              text not null,
  company_name       text not null,            -- denormalized for public display
  city_state         text not null,
  zip                text,
  address            text,                      -- revealed to applicant after hire
  lat                double precision,
  lng                double precision,
  pay_min            numeric(8,2) not null,
  pay_max            numeric(8,2) not null,
  employment_type    employment_type not null,
  shifts             text[] default '{}',
  category           text,
  description        text,
  requirements       text[] default '{}',
  benefits           text[] default '{}',
  openings           int default 1,
  urgency            text default 'normal',     -- normal | urgent | featured
  screening_questions jsonb default '[]'::jsonb,
  contact_person     text,
  status             job_status not null default 'draft',
  moderation_status  moderation_status not null default 'pending',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint pay_range_valid check (pay_max >= pay_min and pay_min >= 0),
  constraint poster_matches check (
    (poster_type = 'employer'        and employer_id is not null and agency_id is null) or
    (poster_type = 'staffing_agency' and agency_id   is not null and employer_id is null)
  )
);
create index if not exists jobs_public_idx on public.jobs(moderation_status, status);
create index if not exists jobs_employer_idx on public.jobs(employer_id);
create index if not exists jobs_agency_idx on public.jobs(agency_id);

-- ----------------------------------------------------------------------------
-- RESUMES
--   file_path -> private storage object. `summary` lets an authorized employer
--   read content for the MVP without direct file access (file via edge function).
-- ----------------------------------------------------------------------------
create table if not exists public.resumes (
  id          uuid primary key default gen_random_uuid(),
  seeker_id   uuid not null references public.job_seekers(id) on delete cascade,
  file_path   text,                 -- e.g. '{uid}/resume/123.pdf' in bucket 'resumes'
  file_name   text,
  summary     text,                 -- plain-text summary shown to authorized employers
  source      text not null default 'upload',  -- 'upload' | 'ai'
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists resumes_seeker_idx on public.resumes(seeker_id);

-- ----------------------------------------------------------------------------
-- COVER LETTERS  (job-specific when job_id is set)
-- ----------------------------------------------------------------------------
create table if not exists public.cover_letters (
  id          uuid primary key default gen_random_uuid(),
  seeker_id   uuid not null references public.job_seekers(id) on delete cascade,
  job_id      uuid references public.jobs(id) on delete set null,
  title       text,
  body        text,
  file_path   text,
  source      text not null default 'ai',      -- 'ai' | 'upload'
  created_at  timestamptz not null default now()
);
create index if not exists cover_letters_seeker_idx on public.cover_letters(seeker_id);

-- ----------------------------------------------------------------------------
-- APPLICATIONS  (one per seeker per job)
--   * reject_reason only allowed when stage = 'not_selected'.
-- ----------------------------------------------------------------------------
create table if not exists public.applications (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references public.jobs(id) on delete cascade,
  seeker_id       uuid not null references public.job_seekers(id) on delete cascade,
  resume_id       uuid references public.resumes(id) on delete set null,
  cover_letter_id uuid references public.cover_letters(id) on delete set null,
  note            text,
  stage           application_stage not null default 'submitted',
  reject_reason   reject_reason,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint one_application_per_job unique (job_id, seeker_id),
  constraint reason_only_when_not_selected check (
    reject_reason is null or stage = 'not_selected'
  )
);
create index if not exists applications_job_idx on public.applications(job_id);
create index if not exists applications_seeker_idx on public.applications(seeker_id);

-- ----------------------------------------------------------------------------
-- APPLICATION STATUS EVENTS  (immutable history — written by triggers/RPC only)
-- ----------------------------------------------------------------------------
create table if not exists public.application_status_events (
  id              uuid primary key default gen_random_uuid(),
  application_id  uuid not null references public.applications(id) on delete cascade,
  from_stage      application_stage,
  to_stage        application_stage not null,
  reason          reject_reason,
  changed_by      uuid references public.profiles(id),
  note            text,
  created_at      timestamptz not null default now()
);
create index if not exists ase_app_idx on public.application_status_events(application_id);

-- ----------------------------------------------------------------------------
-- CONSENT LOGS  (append-only)
-- ----------------------------------------------------------------------------
create table if not exists public.consent_logs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  consent_type     consent_type not null,
  granted          boolean not null,
  document_version text,
  ip               text,
  user_agent       text,
  created_at       timestamptz not null default now()
);
create index if not exists consent_user_idx on public.consent_logs(user_id);

-- ----------------------------------------------------------------------------
-- AUDIT LOGS  (append-only; written by SECURITY DEFINER functions)
-- ----------------------------------------------------------------------------
create table if not exists public.audit_logs (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references public.profiles(id),
  action       text not null,
  target_table text,
  target_id    uuid,
  metadata     jsonb default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
create index if not exists audit_actor_idx on public.audit_logs(actor_id);

-- ----------------------------------------------------------------------------
-- ADMIN MODERATION QUEUE
-- ----------------------------------------------------------------------------
create table if not exists public.admin_moderation_queue (
  id          uuid primary key default gen_random_uuid(),
  item_type   moderation_item_type not null,
  item_id     uuid not null,
  flag_reason text,
  status      text not null default 'pending',  -- pending | approved | rejected | removed
  reviewed_by uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists modq_status_idx on public.admin_moderation_queue(status);

-- ============================================================================
-- HELPER FUNCTIONS  (SECURITY DEFINER so they can be used safely inside RLS)
-- ============================================================================

-- Create a profile row automatically when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, email, phone, full_name)
  values (
    new.id,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'job_seeker'),
    new.email,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'full_name'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Does the current user own the org behind this job? (employer or agency)
create or replace function public.owns_job(p_job_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1
    from public.jobs j
    left join public.employers e        on e.id = j.employer_id
    left join public.staffing_agencies a on a.id = j.agency_id
    where j.id = p_job_id
      and (e.owner_id = auth.uid() or a.owner_id = auth.uid())
  );
$$;

-- Append an audit row (used by RPCs).
create or replace function public.write_audit(p_action text, p_table text, p_target uuid, p_meta jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(actor_id, action, target_table, target_id, metadata)
  values (auth.uid(), p_action, p_table, p_target, coalesce(p_meta,'{}'::jsonb));
end $$;

-- ============================================================================
-- TRIGGERS: status-event history + moderation guard + queue auto-enqueue
-- ============================================================================

-- On INSERT of an application -> record the initial 'submitted' event.
create or replace function public.app_on_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.application_status_events(application_id, from_stage, to_stage, changed_by)
  values (new.id, null, new.stage, auth.uid());
  return new;
end $$;

drop trigger if exists trg_app_insert on public.applications;
create trigger trg_app_insert
  after insert on public.applications
  for each row execute function public.app_on_insert();

-- On stage change -> stamp updated_at and record an event.
create or replace function public.app_on_stage_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.stage is distinct from old.stage then
    new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists trg_app_stage_before on public.applications;
create trigger trg_app_stage_before
  before update on public.applications
  for each row execute function public.app_on_stage_change();

create or replace function public.app_after_stage_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.stage is distinct from old.stage then
    insert into public.application_status_events(application_id, from_stage, to_stage, reason, changed_by)
    values (new.id, old.stage, new.stage, new.reject_reason, auth.uid());
  end if;
  return new;
end $$;

drop trigger if exists trg_app_stage_after on public.applications;
create trigger trg_app_stage_after
  after update on public.applications
  for each row execute function public.app_after_stage_change();

-- Prevent anyone who is not an admin from changing moderation_status.
create or replace function public.guard_moderation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.moderation_status is distinct from old.moderation_status and not public.is_admin() then
    raise exception 'Only admins can change moderation_status';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_moderation on public.jobs;
create trigger trg_guard_moderation
  before update on public.jobs
  for each row execute function public.guard_moderation();

-- Auto-enqueue a new job for moderation.
create or replace function public.job_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.admin_moderation_queue(item_type, item_id, flag_reason)
  values ('job', new.id, 'New post awaiting review');
  return new;
end $$;

drop trigger if exists trg_job_after_insert on public.jobs;
create trigger trg_job_after_insert
  after insert on public.jobs
  for each row execute function public.job_after_insert();

-- ============================================================================
-- RPCs the client calls (auth enforced in SQL, not in the browser)
-- ============================================================================

-- Admin approves a job -> makes it publicly visible + resolves queue + audit.
create or replace function public.approve_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can approve jobs';
  end if;

  update public.jobs
     set moderation_status = 'approved',
         status = 'active',
         updated_at = now()
   where id = p_job_id;

  update public.admin_moderation_queue
     set status = 'approved', reviewed_by = auth.uid(), resolved_at = now()
   where item_type = 'job' and item_id = p_job_id and status = 'pending';

  perform public.write_audit('job_approved','jobs',p_job_id);
end $$;

create or replace function public.reject_job(p_job_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can reject jobs';
  end if;

  update public.jobs
     set moderation_status = 'rejected', status = 'closed', updated_at = now()
   where id = p_job_id;

  update public.admin_moderation_queue
     set status = 'rejected', reviewed_by = auth.uid(), resolved_at = now()
   where item_type = 'job' and item_id = p_job_id and status = 'pending';

  perform public.write_audit('job_rejected','jobs',p_job_id, jsonb_build_object('reason', p_reason));
end $$;

-- Move an applicant through the pipeline. Only the job's owner or an admin may.
-- reject_reason is enum-constrained and only stored when stage = 'not_selected'.
create or replace function public.set_application_stage(
  p_application_id uuid,
  p_stage application_stage,
  p_reason reject_reason default null
)
returns void language plpgsql security definer set search_path = public as $$
declare v_job uuid;
begin
  select job_id into v_job from public.applications where id = p_application_id;
  if v_job is null then raise exception 'Application not found'; end if;

  if not (public.owns_job(v_job) or public.is_admin()) then
    raise exception 'Not authorized to update this application';
  end if;

  if p_stage <> 'not_selected' and p_reason is not null then
    raise exception 'A reason can only be set when the stage is Not selected';
  end if;

  update public.applications
     set stage = p_stage,
         reject_reason = case when p_stage = 'not_selected' then p_reason else null end
   where id = p_application_id;

  perform public.write_audit('application_stage_changed','applications',p_application_id,
                             jsonb_build_object('stage', p_stage, 'reason', p_reason));
end $$;

-- Log a consent acceptance (browser passes ip/user_agent best-effort).
create or replace function public.log_consent(
  p_type consent_type, p_granted boolean,
  p_version text default null, p_ip text default null, p_ua text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.consent_logs(user_id, consent_type, granted, document_version, ip, user_agent)
  values (auth.uid(), p_type, p_granted, p_version, p_ip, p_ua);
end $$;
