# CHECKPOINT — Local Job Listings USA

**Checkpoint date:** June 24, 2026
**Type:** Backend / security checkpoint — frozen for documentation.

---

## Status

- **Project name:** Local Job Listings USA
- **Current status:** ✅ Backend MVP / security proof **PASSED**
- **Core loop test:** ✅ Passed (employer posts → admin approves → seeker applies → employer updates status → seeker tracker updates)
- **Security verification:** ✅ Passed **15 / 15**
- **Known skipped item:** `get-resume-url` edge function **not deployed yet** → the resume **signed-URL test is SKIPPED** until it is deployed. This is expected and is **not** a failure.

---

## What is frozen at this checkpoint

This is a stable, verified backend foundation. Treat it as a known-good baseline.

### Database migrations applied (in order)
1. `supabase/migrations/0001_schema.sql` — tables, enums, constraints, triggers, RPCs
2. `supabase/migrations/0002_policies.sql` — row-level security + storage buckets/policies
3. `supabase/migrations/0003_hardening.sql` — role-escalation guard + RPC-only stage changes
4. `supabase/migrations/0004_rls_updates.sql` — **final RLS patch** (owner/created_by triggers + cleaned employer/job INSERT & SELECT policies)

> Note: an identical copy of `0004` was also provided as `final_sql_patches_2026_06_24.sql`. The canonical, applied version is `supabase/migrations/0004_rls_updates.sql`. Do **not** run the duplicate as a separate migration.

### Verified by
- `connect-test.html` → **Run end-to-end** (core loop) — passed
- `connect-test.html` → **Run security verification** (15 checks) — passed 15/15
- Results recorded in `TESTING_GUIDE.md` (note dated June 24, 2026)

---

## Stability rules (do not break the baseline)

- **Do not modify working RLS policies** unless a future test proves a real, reproducible issue. The current policies passed 15/15 — leave them alone.
- **Do not change application logic** (the `src/services/*` files) as part of documentation or audit work.
- **Do not change SQL policies** without a failing test that justifies it; if a change is ever required, add a **new** migration (e.g. `0005_*.sql`) rather than editing `0001`–`0004`.
- **Do not introduce new dependencies.**
- **Do not add secrets.** The browser uses the **anon/public** key only; the `service_role` / secret key is never placed in client code. (For real resume-file access, that key lives only inside the `get-resume-url` edge function's server environment.)

---

## Known / deferred items (not blockers for this checkpoint)

- `get-resume-url` edge function not deployed → signed-URL resume test skipped.
- Email confirmation is **off for testing** and must be re-enabled before production.
- Stripe billing, SMS notifications, mobile/App-Store screens, and legal pages are intentionally **not** built yet.

---

## Next phase

➡️ **Golden Checklist audit** before building full app screens.
After the audit, the first build step is binding the prototype UI to this backend for one vertical slice (employer post → admin approve → seeker apply → tracker update).

*This checkpoint is documentation only. No application logic, SQL policies, dependencies, or secrets were changed while creating it.*
