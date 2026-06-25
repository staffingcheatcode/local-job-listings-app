# GOLDEN CHECKLIST AUDIT — Local Job Listings USA

**Audit date:** June 24, 2026
**Source of truth:** `CHECKPOINT.md` (backend MVP/security proof passed; core loop passed; security verification 15/15; `get-resume-url` edge function not deployed → signed-URL test skipped).
**Scope:** Documentation/audit only. No application logic, SQL policies, features, dependencies, or secrets were changed.

### How to read this
- **Status:** `DONE` (repo clearly proves it) · `PARTIAL` (some of it exists/works) · `NOT STARTED` · `UNKNOWN` (cannot be verified from the repo).
- **Priority:** `MVP REQUIRED` · `APP STORE REQUIRED` · `PRODUCTION REQUIRED` · `LATER`.
- A thing is only `DONE` if a migration, service file, or the passing test harness proves it. "It exists in the prototype as mock UI" is **not** DONE.

### Scoreboard (high level)
| Area | Verdict |
|---|---|
| Backend auth / RLS / access control | **Strong — DONE & tested (15/15)** |
| Data integrity guards (enum, append-only, unique) | **DONE & tested** |
| UI ↔ backend binding | **NOT STARTED (biggest MVP gap)** |
| Staffing-agency depth (branches/recruiters) | **NOT STARTED (no tables)** |
| App Store / legal / payments / analytics | **NOT STARTED (placeholders only)** |
| DevOps / backups / monitoring | **NOT STARTED / UNKNOWN** |

---

## 1. Accessibility / ADA compliance
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Semantic HTML + ARIA roles | PARTIAL | APP STORE REQUIRED | Prototype has focus styles & real `<button>`s, but many controls are `<div>`s; not audited | Audit when UI is bound; replace div-controls with semantic elements |
| Color contrast (WCAG AA) | UNKNOWN | APP STORE REQUIRED | Not measured | Run contrast check on real screens |
| Keyboard navigation | UNKNOWN | APP STORE REQUIRED | Not tested | Tab-order + focus-trap pass on bound UI |
| Screen-reader support | NOT STARTED | PRODUCTION REQUIRED | No labels/landmarks audited | VoiceOver/TalkBack pass before launch |
| Formal WCAG 2.1 AA review | NOT STARTED | PRODUCTION REQUIRED | — | Third-party a11y audit pre-launch |

## 2. User data rights / privacy rights
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Consent logging (terms, resume_share, non-discrimination) | DONE | MVP REQUIRED | `consent_logs` + `consent.js` + `log_consent` RPC; append-only; tested | Keep; wire UI toggles when binding |
| Data deletion request flow | PARTIAL | APP STORE REQUIRED | Prototype placeholder only; no real deletion endpoint | Build account/data deletion (also Store requirement) |
| Do Not Sell / Share | PARTIAL | PRODUCTION REQUIRED | UI placeholder; no backend enforcement | Implement opt-out flag + enforcement |
| Data export (access request) | NOT STARTED | PRODUCTION REQUIRED | No export endpoint | Build "download my data" |
| Consent recorded with timestamp/version | PARTIAL | PRODUCTION REQUIRED | Time captured; IP is browser-side (should be server-side) | Capture IP server-side (edge/proxy) |

## 3. App Store readiness
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| In-app account deletion | NOT STARTED | APP STORE REQUIRED | Apple & Google hard requirement | Build deletion screen + backend |
| Real Privacy / Terms / Support links | NOT STARTED | APP STORE REQUIRED | Placeholders only | Add real pages + links |
| App privacy disclosures / Play Data Safety | NOT STARTED | APP STORE REQUIRED | — | Complete forms before submission |
| Report / block tools (UGC) | NOT STARTED | APP STORE REQUIRED | Required for apps with user content | Build report job/user + block |
| No placeholder/broken screens in prod build | PARTIAL | APP STORE REQUIRED | Prototype is intentionally mock | Replace mocks with bound screens |
| Native iOS/Android app | NOT STARTED | APP STORE REQUIRED | Web prototype only | React Native/Expo conversion (Milestone 4) |

## 4. Auth / API / secrets / database security
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Supabase email/password auth | DONE | MVP REQUIRED | Tested in harness | — |
| RLS enabled on all core tables | DONE | MVP REQUIRED | `0002` + `0004`; passed 15/15 | Do not modify unless a test proves an issue |
| Role-escalation guard | DONE | MVP REQUIRED | `0003`; tested | — |
| RPC-only stage changes | DONE | MVP REQUIRED | `0003`; tested | — |
| Enum-constrained reject reasons | DONE | MVP REQUIRED | `0001`; tested | — |
| service_role key never in browser | DONE | MVP REQUIRED | Anon key only client-side; verified | Keep edge fn server-only |
| Email confirmation enabled | PARTIAL | PRODUCTION REQUIRED | OFF for testing per CHECKPOINT | Re-enable before real users |
| Rate limiting / abuse protection | NOT STARTED | PRODUCTION REQUIRED | None on signup/post/apply | Add limits |
| Secrets hygiene (no secrets in repo) | DONE | MVP REQUIRED | Only `.env.example`; no keys committed | — |

## 5. Access control matrix
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Seeker sees only own data | DONE | MVP REQUIRED | Tested | — |
| Employer sees only own applicants | DONE | MVP REQUIRED | Tested | — |
| Unrelated employer blocked | DONE | MVP REQUIRED | Tested | — |
| Admin full access | DONE | MVP REQUIRED | Tested | — |
| Staffing-agency isolation | PARTIAL | MVP REQUIRED | `owns_agency_for_rls` exists (`0004`) but agency flow not exercised by harness | Add agency cases to security test |
| Written access-control matrix doc | PARTIAL | LATER | Described in README/blueprint; no single matrix table | Optional: formal matrix doc |

## 6. DevOps / environments / backups
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Staging vs production separation | NOT STARTED | PRODUCTION REQUIRED | Single project | Create separate envs |
| CI / automated migrations | NOT STARTED | PRODUCTION REQUIRED | Migrations run manually in SQL editor | Add migration pipeline |
| Database backups / PITR | UNKNOWN | PRODUCTION REQUIRED | Supabase defaults exist but not configured/verified | Enable + verify backups |
| Monitoring / alerts / error logging | NOT STARTED | PRODUCTION REQUIRED | None | Add logging + alerts |
| Edge function deploy pipeline | NOT STARTED | PRODUCTION REQUIRED | `get-resume-url` not deployed | Deploy + automate |

## 7. Race conditions / data integrity
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| One application per job | DONE | MVP REQUIRED | `unique (job_id, seeker_id)` | — |
| Append-only status history | DONE | MVP REQUIRED | Trigger writes events; UPDATE/DELETE blocked; tested | — |
| Pay-range / poster_type constraints | DONE | MVP REQUIRED | Check constraints in `0001` | — |
| Concurrent stage updates / idempotency | UNKNOWN | PRODUCTION REQUIRED | RPC checks ownership; no concurrency test | Add concurrency test |
| Atomic apply (insert + consent) | PARTIAL | PRODUCTION REQUIRED | Consent logged in a second call (not one transaction) | Wrap in a transaction/RPC later |

## 8. Payments / Stripe
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Billing plans data | PARTIAL | LATER | `billing_plans` are reference rows in `seed.sql` only | — |
| Stripe checkout | NOT STARTED | LATER | Not integrated | Build after MVP |
| Plan entitlement enforcement | NOT STARTED | LATER | No limits enforced | Build with billing |

## 9. Stripe webhooks
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Webhook endpoint | NOT STARTED | LATER | — | With Stripe |
| Signature verification | NOT STARTED | LATER | — | With Stripe |
| Subscription state sync | NOT STARTED | LATER | — | With Stripe |

## 10. Frontend hardening
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| UI bound to backend | NOT STARTED | MVP REQUIRED | Prototype uses in-memory mock data | Bind first vertical slice |
| Input validation / sanitization | NOT STARTED | PRODUCTION REQUIRED | Not present | Validate on bound forms + server |
| XSS / output escaping | UNKNOWN | PRODUCTION REQUIRED | Prototype uses `innerHTML` with template data; risky once real user data flows | Escape user content when binding |
| No sensitive data in localStorage | PARTIAL | PRODUCTION REQUIRED | Prototype avoids it; Supabase session uses storage by design | Review on bound app |
| CSP / security headers | NOT STARTED | PRODUCTION REQUIRED | — | Add at hosting layer |

## 11. Marketplace safety
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Job approval gating (hidden until approved+active) | DONE | MVP REQUIRED | Tested (invisible before approval) | — |
| Admin moderation queue | PARTIAL | MVP REQUIRED | `admin_moderation_queue` + `admin.js` + prototype UI; not bound | Bind admin approve/reject |
| Report job / user / message | NOT STARTED | APP STORE REQUIRED | — | Build report intake |
| Block user | NOT STARTED | APP STORE REQUIRED | — | Build block |
| Scam / fake-job detection | NOT STARTED | PRODUCTION REQUIRED | Manual moderation only | Add heuristics/automation later |
| Discriminatory-language prevention | PARTIAL | MVP REQUIRED | Safe-reason enum + no protected-class filters by design; no content scanning | Add content checks later |

## 12. Legal / trust pages
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Privacy Policy (counsel-reviewed) | NOT STARTED | APP STORE REQUIRED | Placeholder text only | Draft + legal review |
| Terms & Conditions | NOT STARTED | APP STORE REQUIRED | Placeholder only | Draft + legal review |
| TCPA / SMS consent language | PARTIAL | PRODUCTION REQUIRED | Consent captured; final legal text pending | Finalize with counsel |
| EEO / non-discrimination policy | PARTIAL | MVP REQUIRED | Agreement captured at signup; policy text placeholder | Finalize policy text |
| "No job guarantee" disclaimers | PARTIAL | MVP REQUIRED | Present throughout prototype; not legally reviewed | Keep + legal review |
| Legal counsel sign-off | NOT STARTED | PRODUCTION REQUIRED | — | Engage counsel before launch |

## 13. Analytics / tracking compliance
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Analytics integration | NOT STARTED | LATER | None present (low privacy risk now) | Add privacy-respecting analytics later |
| Cookie / tracking consent | PARTIAL | APP STORE REQUIRED | Prototype placeholder; no real trackers yet | Wire real consent if/when tracking added |
| Do Not Track / opt-out | NOT STARTED | PRODUCTION REQUIRED | — | Implement with analytics |

## 14. Admin requirements
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Approve / reject jobs | DONE | MVP REQUIRED | `approve_job`/`reject_job` RPC; admin-only; tested | Bind admin UI |
| Account approval (employers/agencies) | PARTIAL | MVP REQUIRED | Service + prototype; verification flow placeholder; not tested | Wire + test |
| Flagged posts / reports review | NOT STARTED | APP STORE REQUIRED | Reports intake not built | Build with report tools |
| Consent / audit log viewing | PARTIAL | PRODUCTION REQUIRED | Tables admin-readable via RLS; prototype views not bound | Bind read-only views |
| Admin created deliberately (not self-serve) | DONE | MVP REQUIRED | Signup clamps admin → job_seeker; SQL promote only | — |

## 15. Employer requirements
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Signup + company profile | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `orgs.createEmployer` tested; UI not bound | Bind signup/profile |
| Post a job (pay range required) | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `jobs.createEmployerJob` tested | Bind post-a-job |
| Applicant pipeline (own jobs only) | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `listApplicantsForJob` tested | Bind pipeline |
| Move applicant status (safe reasons) | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `setApplicationStage` tested | Bind status control |
| View applicant resume | PARTIAL | MVP REQUIRED | Summary readable; file via edge fn NOT deployed | Deploy `get-resume-url` |
| Messaging | NOT STARTED | LATER | Prototype mock only | Build later |

## 16. Staffing agency requirements
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Agency signup / profile | PARTIAL | MVP REQUIRED | `orgs.createAgency` exists; not in core-loop test; UI mock | Test + bind |
| Branches | NOT STARTED | LATER | **No `agency_branches` table** | Add table when building agency depth |
| Recruiters / seats | NOT STARTED | LATER | **No `recruiters` table** | Add table later |
| Job orders | PARTIAL | LATER | Would reuse jobs; agency posting not wired/tested | Wire after employer slice |
| Candidate pipeline / assign recruiter | NOT STARTED | LATER | No `assigned_recruiter_id` wiring/table | Build later |

## 17. Job seeker requirements
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Account + profile/preferences | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `auth` + `job_seekers` tested | Bind onboarding |
| Resume upload (private storage) | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `resumes.uploadResume` + storage RLS | Bind upload |
| Cover letter (AI assist) | PARTIAL | MVP REQUIRED | Mock generator; save/list done; UI not bound | Keep AI assist-only |
| Apply (resume + cover + consent) | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `applyToJob` tested | Bind apply flow |
| Application tracker | DONE (backend) / PARTIAL (UI) | MVP REQUIRED | `getApplicationTracker` tested | Bind tracker |
| Saved jobs | NOT STARTED | MVP REQUIRED | **No `saved_jobs` table**; prototype UI only | Add table if MVP includes saving |
| My Documents | PARTIAL | LATER | Prototype UI; relies on resumes/cover tables | Bind lists |

## 18. AI safety / hiring compliance
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| AI is assist-only (no scoring/ranking/rejection) | DONE | MVP REQUIRED | Mock template; no scoring code; safe-reason enum; no auto-reject | Keep guarantee when real AI added |
| Human-in-the-loop hiring decisions | DONE | MVP REQUIRED | Employer decides via RPC; no auto-advance | — |
| AI disclosure in UI | PARTIAL | MVP REQUIRED | Present in prototype; not in bound UI yet | Carry into bound screens |
| Real-AI data/vendor policy | NOT STARTED | PRODUCTION REQUIRED | No real AI integrated yet | Define before integrating AI |
| Bias / adverse-impact monitoring | NOT STARTED | PRODUCTION REQUIRED | — | Plan before any AI ranking is ever considered |

## 19. Business strategy
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| Monetization model defined | PARTIAL | LATER | Plans conceptualized (seed + prototype billing); not implemented | Validate pricing |
| Go-to-market / positioning | UNKNOWN | LATER | Not a repo artifact | Owner decision |
| Pricing validation | UNKNOWN | LATER | — | Market test |

## 20. Final launch checklist
| Item | Status | Priority | Notes | Next Action |
|---|---|---|---|---|
| All MVP-required items complete | NOT STARTED | MVP REQUIRED | Backend proven; UI binding pending | Complete MVP gaps below |
| All App-Store-required items complete | NOT STARTED | APP STORE REQUIRED | Deletion, legal, report/block, native app | — |
| All Production-required items complete | NOT STARTED | PRODUCTION REQUIRED | Backups, monitoring, rate limits, email confirm | — |
| Legal review sign-off | NOT STARTED | PRODUCTION REQUIRED | — | Engage counsel |
| Launch gate (aggregate) | NOT STARTED | PRODUCTION REQUIRED | Depends on all above | — |

---

## Highest-priority blockers before MVP

These are the `MVP REQUIRED` items that are **not yet DONE**, in rough order:

1. **Bind the prototype UI to the backend** — the single biggest gap. Everything backend is proven but the app still runs on mock data. Start with one vertical slice: employer post → admin approve → seeker apply → status update → tracker. *(Frontend hardening #10, and the UI halves of #14–#17.)*
2. **Deploy the `get-resume-url` edge function** — so employers can view applicant resume files (today only the summary is readable; the signed-URL test is skipped). *(#15)*
3. **Add a `saved_jobs` table** — if "save a job" is in the MVP, it currently has no backend. *(#17)*
4. **Bind the admin moderation flow** — approve/reject works in the backend (tested) but isn't wired to a usable admin screen; needed for marketplace safety at MVP. *(#11, #14)*
5. **Finalize EEO + "no job guarantee" disclaimer text and carry it into the bound UI** — present as placeholders today. *(#12, #18)*
6. **Confirm staffing-agency isolation with a test** — ownership policy exists (`0004`) but isn't exercised by the harness. *(#5)*

> Not MVP blockers, but the first things after MVP: re-enable email confirmation, add rate limiting, deletion/legal/report-block (App Store), then payments/SMS/analytics.

*This audit changed no application logic, SQL policies, features, dependencies, or secrets. It is a documentation artifact only.*
