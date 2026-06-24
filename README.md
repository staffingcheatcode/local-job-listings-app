# Local Job Listings USA — Backend MVP (Supabase)

This package turns the prototype's **core loop** into real, working software:

> Employer signs up → creates company profile → posts a job → **Admin approves** →
> Job seeker signs up → saves a resume + cover letter → **sees the approved job** →
> applies → **Employer advances status** (Submitted → … → Hired / Not selected) →
> **Job seeker's tracker updates** from real data.

Everything is enforced with Supabase **Auth + Postgres + Row Level Security + Storage**.

---

## What's in here

```
local-job-listings-usa/
  README.md                        this file — setup, security checklist, notes
  prototype.html                   the visual app prototype (front-end demo, in-memory)
  connect-test.html                runnable end-to-end + security test harness
  ARCHITECTURE_MAP.html            interactive founder dashboard (visual companion)
  ARCHITECTURE_BLUEPRINT.html      dark visual node-map / system blueprint companion file
  .env.example                     environment variable list
  supabase/
    migrations/0001_schema.sql     tables, enums, constraints, triggers, RPCs
    migrations/0002_policies.sql   row-level security + storage rules
    migrations/0003_hardening.sql  role-escalation guard + RPC-only stage changes
    seed.sql                       billing-plan reference rows + admin promote note
    functions/get-resume-url/index.ts   edge function: signed resume URL for employers
  src/
    lib/config.js                  <-- paste your Supabase URL + anon key here
    lib/supabase.js                browser client (no build step; CDN import)
    services/auth.js               signup / login / profile / job-seeker prefs
    services/orgs.js               employer & agency profiles (+ non-discrimination)
    services/jobs.js               create / list (public) / read jobs
    services/resumes.js            upload to storage + summary; employer signed-URL
    services/coverLetters.js       save/list + MOCK AI generator (no scoring)
    services/applications.js       apply, tracker, applicants, set-stage (RPC)
    services/admin.js              moderation queue, approve/reject (RPC)
    services/consent.js            append-only consent logging
```

---

## Setup (about 10 minutes)

1. **Create a Supabase project** (free tier is fine). Copy the **Project URL** and **anon public key** from *Project Settings → API*.
2. **Run the SQL** in the *SQL editor*, in order:
   `0001_schema.sql`, then `0002_policies.sql`, then `0003_hardening.sql`, then `seed.sql`.
   (The two storage buckets `resumes` and `cover-letters` are created by the policies file.)
3. **Turn off email confirmation for testing**: *Auth → Providers → Email →* uncheck *Confirm email*. (Re-enable before launch.)
4. **Paste your keys** into `src/lib/config.js` (and `.env` from `.env.example`).
5. **Create an admin**: open `connect-test.html`, sign up an admin account, then run once in SQL:
   ```sql
   update public.profiles set role='admin' where email='you@yourco.com';
   ```
6. **Run the loop**: in `connect-test.html`, save the connection and click **Run end-to-end**. You should see every step pass.
7. **Run security verification**: click **Run security verification** — it actively attempts unauthorized actions (role escalation, cross-tenant reads, forged events, free-text reject reasons) and confirms every one is blocked.
8. *(Optional, for real resume file viewing by employers)* deploy the edge function:
   ```
   supabase functions deploy get-resume-url
   supabase secrets set PROJECT_URL=... SERVICE_ROLE_KEY=...
   ```

> Run `connect-test.html` through a tiny local server (e.g. `npx serve .` in this folder) rather than `file://`, so ES module imports load correctly.

---

## ✅ What is REAL

- **Auth** — real email/password signup & login; a `profiles` row is auto-created with the chosen role.
- **Database** — full schema with **enum-constrained** stages and reject reasons; a discriminatory or free-text rejection reason is *impossible to store*.
- **Row Level Security** — seekers see only their own data; employers see only applications to **their** jobs (and those applicants' docs); agencies the same for their orders; admins see all.
- **Public visibility gate** — jobs are invisible until `moderation_status='approved' AND status='active'`. Verified in the harness (anon sees 0 before approval, seeker sees it after).
- **Admin approval** — via the `approve_job` RPC, which checks `is_admin()` in SQL (not the browser).
- **Role-escalation guard (NEW)** — a `before update` trigger on `profiles` blocks any role change by an authenticated user; only an admin or the service-role backend may change a role. Self-signup as `admin` is also clamped to `job_seeker` at the database level.
- **RPC-only stage changes (NEW)** — the direct-update backstop policy was removed, so the browser cannot `UPDATE applications` directly; stage moves must go through `set_application_stage`, which checks ownership in SQL.
- **Status pipeline** — `set_application_stage` RPC checks job ownership and the "reason only when *Not selected*" rule.
- **Immutable history** — every stage change is written to `application_status_events` by a trigger; clients cannot forge or edit it (no insert/update policy, plus a trigger that blocks UPDATE/DELETE outright).
- **Consent logging** — terms, resume-share, and non-discrimination acceptances are written to `consent_logs` (append-only).
- **Audit logging** — approvals, rejections, and stage changes are written to `audit_logs` by `SECURITY DEFINER` functions; admin-readable only.
- **Storage** — private `resumes` / `cover-letters` buckets; a seeker can only touch files under their own `{uid}/…` folder. Employer file access only via the authorization-checked edge function (signed URL, 5-min expiry).

## 🟡 What is MOCKED (intentionally)

- **AI resume & cover-letter generation** — `coverLetters.genCoverLetterText()` is a deterministic template. No external API is called, and **AI never scores, ranks, rejects, or gates** anything. Replace with a *server-side* call once keys are configured (keep it server-side so the key isn't exposed, and keep it assist-only).
- **Billing / Stripe** — `billing_plans` are reference rows only; no checkout or entitlement logic yet.
- **SMS / TCPA send** — consent is captured; no Twilio send is wired.
- **Resume file viewing by employers** — for the demo, employers read the resume **summary** field (no file access). The included edge function is the secure way to grant signed file access; deploy it when you want true file viewing.

## 🔴 What still needs PRODUCTION HARDENING

- **Email confirmation** — re-enable before launch; add password reset & rate limits.
- **Resume virus scanning + type/size limits** on upload.
- **PII handling** — IP capture for consent should happen server-side (edge/proxy), not from the browser.
- **Background checks** — *not implemented.* If added later, they require a **separate FCRA-compliant** flow: written disclosure, applicant authorization, and pre-adverse / adverse-action notices. Placeholders only.
- **Legal review** — privacy policy, terms, TCPA language, and state pay-transparency specifics must be reviewed by counsel.
- **Rate limiting / abuse** on job posting and applications; admin tooling for reports.

> ✅ **Role-escalation guard is now implemented** (migration `0003_hardening.sql`) and verified by the harness — it is no longer an open hardening item.

---

## Compliance posture (unchanged from the prototype)

This is built to be **compliance-aware, not "fully compliant."** Keep these front and center:

- Local Job Listings USA does **not** guarantee jobs, interviews, placement, or employer contact.
- Employers and staffing agencies make **all final hiring decisions**.
- AI may assist with resumes, cover letters, and fit explanations — it **cannot** rank, reject, or make hiring decisions.
- Employers and staffing agencies must **agree not to discriminate** (captured at org creation + `consent_logs`).
- Background checks, if added, require separate **FCRA-compliant** authorization and adverse-action workflows.
- **Have qualified legal counsel review before launch.**

---

## SECURITY VERIFICATION CHECKLIST

Run **Run security verification** in `connect-test.html`. It sets up two employers, two seekers, and an admin, then actively attempts each unauthorized action and confirms it is blocked. Expected result: **all pass**.

| # | Check | How it's verified | Status |
|---|---|---|---|
| 1 | **Role escalation blocked** | Signed-in seeker and employer each try `update profiles set role='admin'`; role is unchanged (DB trigger `guard_role_change`). Self-signup as admin is clamped. | ✅ enforced in DB |
| 2 | **RLS tests passed** | Job invisible before approval / visible after; seeker sees only own applications. | ✅ |
| 3 | **Unauthorized employer blocked** | Employer B gets **0** rows for Employer A's job applicants and cannot read App A. | ✅ |
| 4 | **Unauthorized seeker blocked** | Seeker 1 cannot read Seeker 2's resume or application (RLS returns nothing). | ✅ |
| 5 | **Private resume storage verified** | Resume files live in a **private** bucket; storage RLS scopes each user to their own `{uid}/…` folder. | ✅ |
| 6 | **Signed resume URL verified** | Owning employer **can** mint a 5-min signed URL via the edge function; an unrelated employer is **denied**. | ✅ (deploy edge fn to run live) |
| 7 | **Rejection reason enum verified** | Valid enum reason accepted; invalid enum value rejected by Postgres. | ✅ |
| 8 | **Free-text discriminatory reason cannot be stored** | Direct write of `reject_reason='too old…'` fails the enum cast. | ✅ |
| 9 | **Stage changes go through the RPC** | Direct `update applications set stage=…` changes nothing (no update policy); only `set_application_stage` works. | ✅ |
| 10 | **Status history append-only verified** | Browser `insert`/`update`/`delete` on `application_status_events` is rejected; only trigger-written rows exist. | ✅ |
| 11 | **No service-role key in browser** | Browser config holds the **anon** key only; the service-role key exists only in the edge function's server env. | ✅ by design |
| 12 | **Email confirmation re-enabled before production** | Turned **off** only for testing — must be re-enabled before launch. | ⚠ action required |

### Edge function verification (`get-resume-url`)

- ✅ **No `service_role` key in browser code** — it is read from `Deno.env` inside the function only; nothing in `src/` references it.
- ✅ **Browser uses the anon key only** — `src/lib/config.js` and `supabase.js` use `SUPABASE_ANON_KEY`.
- ✅ **Service role used server-side only** — used solely to `createSignedUrl` after the check passes.
- ✅ **Authorization checked before signing** — the function first queries the application with a client bound to the **caller's** JWT, so RLS decides visibility; only then is a URL minted.
- ✅ **Random user cannot get a URL** — an unauthorized caller's RLS query returns no row → `403`, no signed URL. Short 5-minute expiry limits exposure.

---

The visual prototype stays as-is; here's the one-to-one wiring for the next increment. Each prototype action just calls the matching service function and renders the result.

| Prototype action | Service call |
|---|---|
| Employer "Submit job for review" (`emp-post`) | `jobs.createEmployerJob(employerId, {...})` |
| Admin queue "Approve" (`admin-dash`) | `admin.approveJob(jobId)` |
| Job feed list (`feed`) | `jobs.listPublicJobs(filters)` |
| Job detail open (`detail`) | `jobs.getJob(jobId)` |
| Apply "Submit application" (`apply`) | `applications.applyToJob({...})` |
| Applicant pipeline (`emp-applicants`) | `applications.listApplicantsForJob(jobId)` |
| Stage picker (`emp-applicant`) | `applications.setApplicationStage(appId, stage, reason)` |
| Tracker (`tracker`) | `applications.getApplicationTracker(appId)` |
| AI cover letter (`coverletter`) | `coverLetters.genCoverLetterText()` → `saveCoverLetter()` |
| Resume upload (`docs`) | `resumes.uploadResume(file, {summary})` |

I recommend binding one vertical slice at a time (employer post → admin approve → seeker apply → tracker), testing each against your live project, before moving to messaging, billing, and the agency pipeline.
