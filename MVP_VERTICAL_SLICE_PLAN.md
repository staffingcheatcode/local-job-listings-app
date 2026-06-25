# MVP VERTICAL SLICE — Binding Plan (Planning Only)

**Date:** June 24, 2026
**Goal:** Bind ONE end-to-end slice of the existing `prototype.html` UI to the existing Supabase backend, reusing the existing `src/services/*` functions unchanged.
**This document is a plan. No code is written yet. Implementation waits for your approval.**

The slice (the same path the test harness already proves, but driven from the real UI):

> Employer signs up/in → creates company profile → posts a job → **Admin approves** →
> Job seeker signs up/in → sees the approved job → applies → **Employer sees the applicant** →
> Employer updates status → **Job seeker's tracker updates**.

---

## 0. Guardrails honored
- ❌ No SQL / RLS / migration changes (reuse `0001`–`0004` exactly as applied).
- ❌ No new dependencies. `supabase-js` is **already** present via `src/lib/supabase.js` (loaded from CDN); binding adds nothing new.
- ❌ No secrets committed. Keys live only in `src/lib/config.js`, which the user fills locally (it ships with empty strings).
- ❌ No Stripe / SMS / analytics / App-Store / AI / saved-jobs work. No edge-function deploy.
- ✅ **Demo mode stays intact.** Every binding is gated behind `window.LJL_LIVE`. With no keys, `prototype.html` behaves exactly as today (mock data). Live data only kicks in when keys are present.

---

## 1. Which prototype sections are mock-only today
All of these currently mutate in-memory arrays/state and never touch a backend:

| Screen (id) | Mock handler / data | What it does now |
|---|---|---|
| Employer signup (`#emp-signup`) | `go('emp-profile')` | Just navigates; no account created |
| Company profile (`#emp-profile`) | `go('emp-dash')` | Just navigates; no employer row |
| Employer dashboard (`#emp-dash`) | `renderEmpHome()` + `EMP_JOBS[]` | Lists hard-coded jobs |
| Post a job (`#emp-post`) | `toast(...);go('emp-dash')` | Shows a toast; nothing saved |
| Admin queue (`#admin-dash`) | `modAct(i,'Approved')` + `ADMIN_QUEUE[]` | Removes a row from a mock array |
| Seeker signup (`#signup`) | `go('search')` | Just navigates; no account |
| Job feed (`#feed`) | `renderFeed()` + `JOBS[]` | Lists hard-coded jobs |
| Job detail / apply (`#detail`,`#apply`) | `openJob()`, `submitApply()` + `state.applied[]` | Pushes to a mock array, `state.stage=1` |
| Tracker (`#tracker`) | `renderTracker()` + `advanceStage()` | Demo button moves a fake status |
| Applicant pipeline (`#emp-applicants`) | `renderEmpPipe()` + `APPLICANTS[]` | Lists hard-coded applicants |
| Applicant detail (`#emp-applicant`) | `setApplicantStage(id,i)` | Mutates a mock applicant |

---

## 2. Files that need changes

**Only two files are touched. No service, SQL, or migration files change.**

1. **`prototype.html`** (the app UI) — three kinds of minimal edits:
   - **Add field `id`s** to the inputs we must read: employer signup (email, password, company name), company profile (industry/size/city/about), post-a-job (title, city/state, pay min/max, type, category, description, requirements, benefits, openings, urgency, contact), seeker signup (email, password), and the apply note. Most already lack `id`s. (Markup-only; no logic change.)
   - **Add a config + client bootstrap**: a `<script src="src/lib/config.js"></script>` tag, then set `window.LJL_LIVE` (same pattern `connect-test.html` uses).
   - **Append ONE `<script type="module">` binding block** at the end that imports the services and, **only when `window.LJL_LIVE` is true**, overrides the slice's entry-point handlers (listed in §4). When not live, the existing mock handlers run untouched.

2. **`src/bindings/slice1.js`** (NEW, optional but recommended) — the binding logic itself, imported by the module block above. Keeping it in its own file makes the `prototype.html` diff tiny and makes the whole binding removable by deleting one import. *(If you'd rather not add any new file, the same code can live inline in the module block — your call at approval time.)*

> Note: this is the only new file proposed, and it is plain local JS (not a dependency).

---

## 3. Existing service functions to reuse (unchanged)

| Slice step | Service call (exact) |
|---|---|
| Employer sign up | `auth.signUp({ email, password, role:'employer', fullName })` |
| Employer sign in (fallback if exists) | `auth.signIn({ email, password })` |
| Create company profile | `orgs.createEmployer({ companyName, industry, size, hqCity, about, agreedNonDiscrimination:true })` |
| Get my employer (id) | `orgs.getMyEmployer()` |
| Post job | `jobs.createEmployerJob(employerId, {...})` |
| Employer's jobs list | `jobs.listMyEmployerJobs(employerId)` |
| Admin: pending jobs | `admin.listPendingJobs()` (and/or `admin.listModerationQueue()`) |
| Admin: approve | `admin.approveJob(jobId)` |
| Seeker sign up | `auth.signUp({ email, password, role:'job_seeker', fullName })` + `auth.upsertJobSeeker({...})` |
| Public feed | `jobs.listPublicJobs()` |
| Job detail | `jobs.getJob(jobId)` |
| Resume (for the slice) | `resumes.saveTextResume({ summary })` → returns `resume_id` |
| Cover letter (optional) | `coverLetters.genCoverLetterText({...})` + `coverLetters.saveCoverLetter({...})` |
| Apply | `applications.applyToJob({ jobId, resumeId, coverLetterId, note, shareConsent:true })` |
| Consent records | `consent.logConsent('terms')`, `logConsent('non_discrimination')`, `logConsent('resume_share')` (the apply step also logs resume_share inside `applyToJob`) |
| Employer applicant list | `applications.listApplicantsForJob(jobId)` |
| Move status | `applications.setApplicationStage(applicationId, stage, reason)` using `applications.STAGES` / `REJECT_REASONS` |
| Seeker tracker | `applications.getApplicationTracker(applicationId)` |

---

## 4. UI sections to bind (handler → behavior)

A small `window.LIVE = {}` object will hold session-derived ids: `employerId`, `jobId`, `applicationId`, `resumeId`. Each override calls a service, then hands data to the **existing render functions** so the visuals don't change.

1. **Employer signup** — `#emp-signup` "Continue" → `signUp(role=employer)` (on "already registered", fall back to `signIn`) → `logConsent('terms')` + `logConsent('non_discrimination')` → `go('emp-profile')`.
2. **Company profile** — `#emp-profile` "Create company profile" → `createEmployer({…, agreedNonDiscrimination:true})` → store `LIVE.employerId` → `go('emp-dash')`.
3. **Employer dashboard** — override the data source of `renderEmpHome()` to `listMyEmployerJobs(LIVE.employerId)`, mapped into the existing `empCardHTML` shape.
4. **Post a job** — `#emp-post` "Submit job for review" → `createEmployerJob(LIVE.employerId, {...})` → refresh dashboard. Job is created `pending`/`draft` by the backend default.
5. **Admin queue** — override `renderAdminQueue()` to use `listPendingJobs()`; `modAct(i,'Approved')` for a job → `approveJob(jobId)` → refresh. (Admin signs in as the promoted admin account.)
6. **Seeker signup** — `#signup` "Create account" → `signUp(role=job_seeker)` + `upsertJobSeeker({location,…})` + `logConsent('terms')` → `go('feed')`.
7. **Job feed** — override `renderFeed()` data source to `listPublicJobs()`, mapped to the card shape; `openJob(id)` uses the live row (uuid) and stores it for apply.
8. **Apply** — `#apply` "Submit application": ensure a resume exists (`saveTextResume` if none) → optional cover letter → `applyToJob({ jobId, resumeId, coverLetterId, note })` → store `LIVE.applicationId` → `go('success')` → tracker.
9. **Tracker** — override `renderTracker()` to read `getApplicationTracker(LIVE.applicationId)` and map backend stages → the existing stepper. In live mode the **"Advance status (demo)" button is hidden** (status only moves from the employer side); a **"Refresh" action** re-pulls the tracker.
10. **Applicant pipeline** — override `renderEmpPipe()` to `listApplicantsForJob(LIVE.jobId)`, mapped to the existing applicant-card shape (name from `profiles.full_name`, resume `summary`, cover letter, stage).
11. **Applicant detail status** — `setApplicantStage(id,i)` → `setApplicationStage(applicationId, STAGES[i], reason)` (reason only for `not_selected`, from `REJECT_REASONS`).

---

## 5. Data flow (live)

```
Employer signup ─signUp(employer)─▶ Supabase Auth ─trigger─▶ profiles(role=employer)
Company profile ─createEmployer()─▶ employers (owner_id=auth.uid by 0004 trigger)
Post a job ──────createEmployerJob()─▶ jobs (moderation=pending, status=draft) ─trigger─▶ admin_moderation_queue
Admin approve ───approveJob() RPC──▶ jobs (moderation=approved, status=active) + audit_logs
Seeker signup ───signUp(job_seeker)─▶ profiles + job_seekers ; logConsent ▶ consent_logs
Job feed ────────listPublicJobs()──▶ jobs WHERE approved+active   (RLS-public)
Apply ───────────saveTextResume()──▶ resumes ; applyToJob() ─▶ applications + status event + consent_logs(resume_share)
Pipeline ────────listApplicantsForJob()─▶ applications (RLS: owner only) + resume summary
Status change ───setApplicationStage() RPC─▶ applications.stage + application_status_events (append-only)
Tracker ─────────getApplicationTracker()─▶ applications.stage + ordered events
```

Stage mapping (backend enum → the tracker's visible steps):
`submitted → resume_received → in_review → second_stage → interview_requested → (offer_extended | hired | not_selected)`.
The prototype tracker shows 6 steps with a final decision node — the binding maps the 8 enum values onto those steps.

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Module imports fail on `file://`** | Must open `prototype.html` via a local server (`http://…`), same as `connect-test.html`. Document in testing steps. |
| **Signups can't sign in immediately** | "Confirm email" must be **OFF** for testing (already the case from the test checkpoint). |
| **XSS** — live user text (company name, note) injected via `innerHTML` | Add a small `escapeHtml()` helper and escape all live strings before rendering. (Addresses the Frontend-hardening audit item for this slice.) |
| **Field-shape mismatch** (e.g. UI "Temp-to-hire" vs enum `temp_to_hire`; pay strings vs numbers) | Add explicit mapping in the binding; never send raw labels. |
| **Single auth session** — prototype lets you hop roles freely | In live mode each role requires a real sign-in; "Switch account type" calls `signOut()`. Use separate browser tabs/incognito for employer vs admin vs seeker. |
| **Apply needs a resume_id** | If the seeker has no resume yet, create a text resume via `saveTextResume()` (file-upload UI binding deferred). |
| **Admin must be promoted** | Reuse the admin account promoted during testing (`update profiles set role='admin' …`). |
| **Breaking demo mode** | All overrides gated on `window.LJL_LIVE`; with empty keys the prototype stays 100% mock. Removing the one import reverts fully. |
| **Resume file view** | Employer sees the resume **summary** only; file view needs the (undeployed) edge function — out of scope here. |

---

## 7. Exact testing steps (after binding is implemented)

1. Serve the repo over http (`npx serve .` or `python3 -m http.server 8000`) and open `prototype.html` via the `http://…` address.
2. Put the **same** Supabase URL + anon key (from the test project) into `src/lib/config.js`. Confirm a small "live mode" indicator shows on.
3. Confirm **Confirm email is OFF** and an **admin account is promoted** (from the test checkpoint).
4. **Employer (tab A):** Onboarding → "I'm an employer" → sign up with a **new real email/password** → company profile → create → dashboard.
5. **Post a job** → submit → it appears in the employer dashboard list (pending).
6. **Admin (tab B, incognito):** sign in as the promoted admin → moderation queue shows the pending job → **Approve**.
7. **Seeker (tab C, incognito):** "I'm looking for work" → sign up → **the approved job appears** in the feed.
8. Open the job → **Apply** (text resume + optional note) → success → tracker shows **Submitted**.
9. **Employer (tab A):** applicant pipeline → the seeker appears → open applicant → move status to **Interview requested**, then **Hired**.
10. **Seeker (tab C):** tracker → **Refresh** → shows the new stage + history (Submitted → … → Hired).
11. **Regression:** blank out the keys in `config.js`, reload → confirm the prototype still runs in full **demo/mock** mode with no errors.

**Pass = ** a real job posted from the UI becomes visible only after admin approval, a real application appears in the employer's pipeline, and the seeker's tracker reflects employer-driven status changes — all from the pretty screens.

---

## 8. What stays MOCK for now (intentionally out of scope)

- **Saved jobs** (no table; not building it).
- **Staffing-agency** flows: signup, branches, recruiters, job orders, candidate pipeline, assign recruiter.
- **Messages / chat.**
- **Resume FILE upload + employer file view** (signed-URL edge function not deployed) — slice uses a text resume; employer reads the summary.
- **Cover letter** may stay mock or bind only `saveCoverLetter` (optional); AI text remains the existing assist-only mock generator.
- **Search radius / pay / map filters** — feed shows all approved jobs; filters stay cosmetic for the slice.
- **Account settings & compliance toggles** (Do-Not-Sell, data deletion, SMS) — remain mock; only signup/apply consent logging is wired.
- **Billing / Stripe, SMS, analytics, App-Store screens, native app, AI features.**

---

## 9. Rollback

Because every change is gated behind `window.LJL_LIVE` and the logic lives in one imported file, reverting is: remove the `src/bindings/slice1.js` import (and the config `<script>` tag) from `prototype.html`. The field `id`s added to inputs are harmless and can stay.

---

*Planning only. No application logic, SQL, RLS, migrations, dependencies, or secrets were changed in producing this document.*
