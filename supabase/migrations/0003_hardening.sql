-- ============================================================================
-- Local Job Listings USA — Hardening (migration 0003)
-- Run AFTER 0001_schema.sql and 0002_policies.sql.
-- This file is additive/idempotent. It does NOT redesign anything; it closes
-- three foundation gaps:
--   (1) No one can escalate their own account role (DB-enforced).
--   (2) Nobody can self-sign-up as 'admin' (admins are created deliberately).
--   (3) Application stage changes can ONLY happen via set_application_stage RPC.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- (2) Signup clamp: a user-supplied role of 'admin' is downgraded to job_seeker.
--     Employers/agencies may still self-select at signup; admin cannot.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role user_role;
begin
  v_role := coalesce((new.raw_user_meta_data->>'role')::user_role, 'job_seeker');
  if v_role = 'admin' then
    v_role := 'job_seeker';                    -- admins are never self-served
  end if;

  insert into public.profiles (id, role, email, phone, full_name)
  values (new.id, v_role, new.email,
          new.raw_user_meta_data->>'phone',
          new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end $$;

-- ----------------------------------------------------------------------------
-- (1) Role-escalation guard on UPDATE of profiles.role.
--     A role change is permitted ONLY when the caller is:
--       * an existing admin (is_admin()), OR
--       * the service_role backend (JWT role = 'service_role'), OR
--       * a trusted server/SQL context with no JWT (e.g. the SQL editor running
--         as the postgres role, used for the one-time admin promotion).
--     Authenticated job_seekers / employers / agencies are blocked.
-- ----------------------------------------------------------------------------
create or replace function public.guard_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    if public.is_admin() then
      return new;                                   -- admin acting in the app
    elsif coalesce(auth.jwt() ->> 'role', '') = 'service_role' then
      return new;                                   -- backend with service key
    elsif auth.jwt() is null then
      return new;                                   -- trusted SQL/server context
    else
      raise exception 'Changing your account role is not allowed.'
        using errcode = '42501';                    -- insufficient_privilege
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_role_change on public.profiles;
create trigger trg_guard_role_change
  before update on public.profiles
  for each row execute function public.guard_role_change();

-- ----------------------------------------------------------------------------
-- (3) Make application stage changes RPC-only.
--     Remove the direct-update backstop policy so the browser client cannot
--     UPDATE applications directly. set_application_stage() is SECURITY DEFINER,
--     so legitimate stage moves still work (and remain auth-checked in SQL).
-- ----------------------------------------------------------------------------
drop policy if exists app_update_owner_or_admin on public.applications;

-- (Optional but recommended) make the immutable history truly immutable even to
-- privileged roles by rejecting UPDATE/DELETE on the events table.
create or replace function public.block_event_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'application_status_events is append-only';
end $$;

drop trigger if exists trg_block_event_update on public.application_status_events;
create trigger trg_block_event_update
  before update or delete on public.application_status_events
  for each row execute function public.block_event_mutation();
