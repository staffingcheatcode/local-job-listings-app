-- Final SQL patch for Staffing Cheat Code RLS modifications (2026-06-24)
-- Enforce row level security for employers and jobs; set owner id and created_by; helper functions; triggers and policies.

-- Enable RLS on employers and jobs
alter table public.employers enable row level security;
alter table public.jobs enable row level security;

-- Helper functions to check ownership
create or replace function public.owns_employer_for_rls(p_employer_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.employers e
    where e.id = p_employer_id
      and e.owner_id = p_user_id
  );
$$;

create or replace function public.owns_agency_for_rls(p_agency_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staffing_agencies sa
    where sa.id = p_agency_id
      and sa.owner_id = p_user_id
  );
$$;

-- Trigger to set employer owner_id to auth.uid()
create or replace function public.set_employers_owner_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.owner_id := auth.uid();
  return new;
end;
$$;
drop trigger if exists trg_set_employers_owner_id on public.employers;
create trigger trg_set_employers_owner_id
before insert on public.employers
for each row
execute function public.set_employers_owner_id();

-- Trigger to set job created_by to auth.uid()
create or replace function public.set_jobs_created_by()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.created_by := auth.uid();
  return new;
end;
$$;
drop trigger if exists trg_set_jobs_created_by on public.jobs;
create trigger trg_set_jobs_created_by
before insert on public.jobs
for each row
execute function public.set_jobs_created_by();

-- Remove existing INSERT policies on jobs and employers if present
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'jobs'
      and cmd = 'INSERT'
  loop
    execute format('drop policy if exists %I on public.jobs', pol.policyname);
  end loop;
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'employers'
      and cmd = 'INSERT'
  loop
    execute format('drop policy if exists %I on public.employers', pol.policyname);
  end loop;
end $$;

-- Insert policy: allow employers and agencies to insert jobs they own
create policy jobs_insert_owner_clean
on public.jobs
for insert
to authenticated
with check (
  auth.uid() is not null
  and created_by = auth.uid()
  and (
    (
      poster_type = 'employer'
      and employer_id is not null
      and public.owns_employer_for_rls(employer_id, auth.uid())
    )
    or
    (
      poster_type = 'staffing_agency'
      and agency_id is not null
      and public.owns_agency_for_rls(agency_id, auth.uid())
    )
    or
    (
      poster_type is null
      and employer_id is not null
      and public.owns_employer_for_rls(employer_id, auth.uid())
    )
  )
);

-- Insert policy for employers: require owner_id = auth.uid()
create policy employers_insert_authenticated_owner
on public.employers
for insert
to authenticated
with check (
  auth.uid() is not null
  and owner_id = auth.uid()
);

-- Select policy for employers and agencies: owners/admin can see their own
drop policy if exists employers_select_owner_or_admin on public.employers;
create policy employers_select_owner_or_admin
on public.employers
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
);

drop policy if exists staffing_agencies_select_owner_or_admin on public.staffing_agencies;
create policy staffing_agencies_select_owner_or_admin
on public.staffing_agencies
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
);

-- Select policy for jobs: allow owners/admins to see their own jobs; public only sees approved active jobs
drop policy if exists jobs_select_owner_or_admin on public.jobs;
create policy jobs_select_owner_or_admin
on public.jobs
for select
to authenticated
using (
  created_by = auth.uid()
  or public.is_admin()
  or (
    poster_type = 'employer'
    and employer_id is not null
    and public.owns_employer_for_rls(employer_id, auth.uid())
  )
  or (
    poster_type = 'staffing_agency'
    and agency_id is not null
    and public.owns_agency_for_rls(agency_id, auth.uid())
  )
);
