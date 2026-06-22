-- ============================================================================
-- Local Job Listings USA — Seed / helper SQL (optional)
-- ============================================================================

-- Promote a user to admin AFTER they have signed up once through the app.
-- Replace the email, then run this single statement:
--
--   update public.profiles set role = 'admin' where email = 'you@yourcompany.com';
--
-- (Admin accounts should be created deliberately, never self-served.)

-- ---------------------------------------------------------------------------
-- Reference billing plans (not enforced yet — Stripe wiring is a later step).
-- Stored as plain rows so the app can list them; no payment logic here.
-- ---------------------------------------------------------------------------
create table if not exists public.billing_plans (
  id        text primary key,
  audience  text not null,            -- 'employer' | 'agency'
  name      text not null,
  price     text not null,
  interval  text,                     -- 'month' | 'per_lead' | 'per_post' | 'per_seat'
  features  text[] default '{}'
);

insert into public.billing_plans (id,audience,name,price,interval,features) values
  ('emp_free','employer','Free','$0','month', array['1 active job post','Up to 10 applicants/mo','Basic pipeline']),
  ('emp_pro','employer','Pro Monthly','$149','month', array['Unlimited posts','Full pipeline & messaging','Export applicants']),
  ('emp_ppl','employer','Pay-per-applicant','$12','per_lead', array['Pay only for unlocked applicants','No monthly commitment']),
  ('emp_feat','employer','Featured / Urgent','$39','per_post', array['Top of feed','Urgent badge']),
  ('ag_starter','agency','Starter','$0','month', array['1 branch','1 recruiter seat','3 job orders']),
  ('ag_agency','agency','Agency','$399','month', array['Unlimited orders','5 recruiter seats','Multi-branch']),
  ('ag_plus','agency','Agency Plus','$899','month', array['15 recruiter seats','Priority placement'])
on conflict (id) do nothing;

alter table public.billing_plans enable row level security;
create policy plans_read_all on public.billing_plans for select using (true);
