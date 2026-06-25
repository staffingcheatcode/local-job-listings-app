# Testing Guide — Local Job Listings USA (backend checkpoint)
**NOTE (June 24, 2026):** Core loop test passed; security verification passed (15/15). The resume signed URL test is skipped until the `get-resume-url` edge function is deployed.


This guide walks you through testing the **current package** so you can confirm the backend works.
It assumes you have never used Supabase, GitHub, or a terminal. Go slowly, one step at a time.

You are **not** building anything new here. You are just checking that the engine runs.

There are two tests at the end:
1. **Core loop test** — proves a real job application can move through the whole app.
2. **Security verification** — proves the locks hold (people can't see each other's data).

---

## 1) Unzip and open the package

1. Find the file **`local-job-listings-usa.zip`**.
2. Double-click it.
   - **Windows:** a window opens. Click **Extract all** → **Extract**.
   - **Mac:** a folder appears automatically next to the zip.
3. You now have a folder called **`local-job-listings-usa`**.
4. **Keep everything inside this folder together.** Do not move or rename files inside it — the test pages load other files by their location, and moving them breaks the connections.

Inside you should see: `prototype.html`, `connect-test.html`, `ARCHITECTURE_MAP.html`, `ARCHITECTURE_BLUEPRINT.html`, `README.md`, `.env.example`, a `supabase` folder, and a `src` folder.

---

## 2) Run it locally (so the test page works)

The test page (`connect-test.html`) loads small helper files. Most browsers block that when you open the file by double-clicking it. So you need to run a tiny “local server.” Pick **one** method.

### Method A — Easiest, click-based (recommended): VS Code + Live Server

1. Download and install **Visual Studio Code** (free) from `https://code.visualstudio.com`.
2. Open VS Code. On the left, click the **Extensions** icon (four little squares).
3. In the search box type **Live Server**. Click **Install** on the one by *Ritwick Dey*.
4. In VS Code, go to **File → Open Folder…** and choose your **`local-job-listings-usa`** folder.
5. In the file list on the left, **right-click `connect-test.html`** → click **Open with Live Server**.
6. Your browser opens to an address like `http://127.0.0.1:5500/connect-test.html`. ✅ That's correct.

### Method B — One command: Python

1. **Mac:** open the **Terminal** app. **Windows:** open **PowerShell**.
2. Type `cd ` (the letters c, d, then a space). **Do not press Enter yet.**
3. **Drag the `local-job-listings-usa` folder** from your file window into the Terminal window, then press **Enter**.
4. Type this and press **Enter**:
   - Mac: `python3 -m http.server 8000`
   - Windows: `python -m http.server 8000`
5. Open your browser and go to: `http://localhost:8000/connect-test.html`

> If you opened the page and the web address starts with `file://`, that's the wrong way — go back and use Method A or B. You need an address starting with `http://`.

Leave this running. You'll come back to the page after the Supabase setup below.

---

## 3) Create the Supabase project

1. Go to `https://supabase.com` and click **Start your project** / **Sign in**. Sign up (GitHub or email both fine).
2. Click **New project**.
3. Choose an **Organization** (it may create a default one for you).
4. Fill in:
   - **Name:** `local-job-listings` (anything is fine)
   - **Database Password:** click **Generate a password**, then **copy it and save it somewhere safe**. (You won't need it for this test, but keep it.)
   - **Region:** pick the one closest to you.
5. Click **Create new project**.
6. Wait 1–2 minutes while it says “Setting up project.” When it's ready, you'll see the project dashboard.

---

## 4) Find your Project URL

1. In the project, look at the bottom-left and click the **gear icon** (**Project Settings**).
2. Click **API** (in newer dashboards it may say **API** or **API Keys / Data API**).
3. Find **Project URL**. It looks like `https://abcdefgh.supabase.co`.
4. Copy it and paste it into a notes file for a moment.

---

## 5) Find your anon public key

1. On that same **API** settings page, find **Project API keys**.
2. Copy the key labeled **`anon`** **`public`**.
   - Newer dashboards may call it the **Publishable key** — that's the same browser-safe key. Use that one.
3. **Do NOT copy** the **`service_role`** key (sometimes called the **secret** key). That one is dangerous in a browser. Leave it alone.

> 🔒 The anon/public key is meant for browsers, so it's okay to use. The service_role/secret key must never be pasted into the app or shared. We never use it in the browser.

---

## 6) Paste the URL and anon key

For testing, you paste them **into the test page**, not into any file:

1. Go back to the **`connect-test.html`** page in your browser.
2. In **“1 · Connection”**, paste your **Project URL** into the **SUPABASE_URL** box.
3. Paste your **anon public key** into the **SUPABASE_ANON_KEY** box.
4. Click **Save connection**. You should see **“saved ✓”** turn green.

(There's also a file at `src/lib/config.js` for keys — that's only needed later when we build the real app screens. You do **not** need it for this test.)

---

## 7) Run the SQL files in the correct order

The SQL files build your database. You'll copy each file's text and run it.

**How to open a file's text:** in your folder, go into `supabase/migrations/`. Open a `.sql` file with a plain text editor — right-click → **Open with** → **Notepad** (Windows) or **TextEdit** (Mac), or open it in VS Code. Then **select all the text** (Ctrl+A / Cmd+A) and **copy** (Ctrl+C / Cmd+C).

**Where to run it:**
1. In Supabase, on the left sidebar click **SQL Editor**.
2. Click **+ New query**.
3. **Paste** the copied SQL into the big box.
4. Click **Run** (or press Ctrl+Enter / Cmd+Enter).
5. You should see **“Success. No rows returned”** at the bottom.

**Do this four times, in this exact order:**
1. `supabase/migrations/0001_schema.sql`
2. `supabase/migrations/0002_policies.sql`
3. `supabase/migrations/0003_hardening.sql`
4. `supabase/seed.sql`

> Run them one at a time. Wait for “Success” before the next one. Order matters — `0001` must be first.

---

## 8) Do you need to create storage buckets manually?

**No — the SQL does it for you.** Running `0002_policies.sql` creates two private buckets: **`resumes`** and **`cover-letters`**.

To double-check: on the left sidebar click **Storage**. You should see both buckets listed. If for some reason they're missing, create them by hand:
1. **Storage → New bucket**
2. Name it exactly `resumes`, make sure **Public** is **OFF**, click **Create**.
3. Repeat for `cover-letters`.

---

## 9) Turn off email confirmation (for testing only)

The test creates several pretend accounts. Email confirmation would block them, so turn it off for now.

1. On the left sidebar click **Authentication**.
2. Click **Sign In / Providers** (older dashboards: **Providers**, or **Settings**).
3. Click **Email**.
4. Find **Confirm email** and turn the toggle **OFF**.
5. Click **Save**.

> ⚠️ This is for testing only. You'll turn it back ON before real users sign up.

---

## 10) Open connect-test.html

If you used **Method A (Live Server)** or **Method B (Python)** in step 2, your `connect-test.html` is already open at an `http://...` address. If you closed it, reopen it the same way. Make sure your connection from step 6 still shows **“saved ✓”** (if not, paste the URL/key again and click **Save connection**).

---

## 11) Create the admin account

1. On the `connect-test.html` page, go to **“2 · Admin account.”**
2. Type an **Admin email** (for example `admin@yourcompany.com`) and an **Admin password** you'll remember.
3. Click **Sign up admin account**.
4. You'll see a message confirming it was created, and a reminder to promote it (next step).

---

## 12) Promote the admin account (exact SQL line)

New accounts start as regular users. Make this one an admin:

1. In Supabase, go to **SQL Editor → + New query**.
2. Paste this line, **replacing the email with the exact admin email you just used**:

```sql
update public.profiles set role = 'admin' where email = 'admin@yourcompany.com';
```

3. Click **Run**. You should see **“Success”** and that **1 row** was updated.

> The email must match exactly (same spelling, all lowercase). If it says 0 rows updated, the email didn't match — check it and run again.

---

## 13) Run the core loop test

1. Back on the `connect-test.html` page, go to **“3 · Run the full core loop.”**
2. Click **▶ Run end-to-end**.
3. Watch the black log box fill in, step by step.

---

## 14) What a passing core loop test looks like

You'll see steps **①** through **⑪** appear, most with a green **✓**, for example:

```
① Employer signs up…           ✓
② Employer creates company…    ✓
③ Employer posts a job…        ✓
④ Confirm job is NOT public…   visible to anon: 0 (expected 0)
⑤ Admin approves the job…      ✓
⑥ Job seeker signs up…         ✓
⑦ Seeker saves resume + cover  ✓
⑧ Seeker sees the job + applies ✓
⑨ Employer sees the applicant  ✓
⑩ Employer advances status…    → … → reached Hired
⑪ Seeker reloads tracker…      history: Submitted → … → Hired
```

And at the very bottom, in green:

```
✅ CORE LOOP PASSED — real auth, RLS, storage-less resume read, RPC status, and immutable event history all working.
```

If you see that green **CORE LOOP PASSED** line, the backend works. 🎉

---

## 15) Run the security verification test

1. On the same page, go to **“4 · Security verification.”**
2. Click **▶ Run security verification**.
3. Watch the second log box. It sets up pretend accounts, then actively *tries to break in* and confirms each attempt fails.

---

## 16) What a passing security verification looks like

You'll see a list of **PASS** lines, for example:

```
PASS  Role guard — job_seeker cannot self-promote to admin
PASS  Role guard — employer cannot self-promote to admin
PASS  1 · Job is INVISIBLE before admin approval
PASS  2 · Job is VISIBLE after admin approval
PASS  3 · Seeker sees ONLY their own applications
PASS  4 · Employer SEES applicants for their own job
PASS  4 · Employer sees NONE for a job they don't own
PASS  5 · Unrelated employer cannot view another employer's applicants
PASS  6 · Seeker cannot read another seeker's resume / application
PASS  7 · Valid enum reason accepted, invalid enum rejected
PASS  8 · Free-text discriminatory rejection reason CANNOT be stored
PASS  9 · Direct stage UPDATE blocked; RPC works
PASS  10 · Status history is append-only
PASS  10 · Trigger-written history is present & readable
```

And at the bottom, in green:

```
✅ ALL SECURITY TESTS PASSED (N/N).
```

**About test #11 (resume signed URL):** it's normal to see **`SKIP 11 · signed URL — edge function not reachable`**. That just means the optional resume-link function isn't deployed yet. It is **not** a failure — you can ignore it for this checkpoint.

---

## 17) Errors you might see, and how to fix them

| What you see | What it means | Fix |
|---|---|---|
| `Failed to fetch dynamically imported module` or a blank page | You opened the file directly (file://) instead of through a local server | Use **Method A or B** in step 2; the address must start with `http://` |
| `Save the connection first` | URL/key not saved | Paste both in **“1 · Connection”** and click **Save connection** |
| `Invalid API key` / `401` / `Failed to fetch` | Wrong URL or anon key, or extra spaces | Re-copy the **Project URL** and **anon public** key (step 4–5); make sure no spaces before/after |
| `Email not confirmed` during signup | Email confirmation is still on | Do **step 9** (turn off Confirm email), then run again |
| `Admin account is not promoted yet` | The promote SQL didn't match the email | Re-run **step 12** with the exact admin email; check it says “1 row” |
| `relation "..." does not exist` or `function ... does not exist` | SQL not run, or run out of order | Re-run **0001 → 0002 → 0003 → seed** in order (step 7) |
| `policy ... already exists` when re-running SQL | You ran a file twice | Usually harmless — the first run already worked. If unsure, ask for help before changing anything |
| Storage buckets missing | The bucket insert didn't take | Create `resumes` and `cover-letters` by hand (step 8), both **Private** |
| `SKIP 11 · signed URL` | Edge function not deployed (optional) | Ignore for this checkpoint — it's expected |

---

## 18) Files you should NOT touch during testing

During testing you only **type into the browser test page** and **click around the Supabase website**. Do **not** edit, rename, move, or delete any of these:

- `prototype.html`
- `connect-test.html`
- `ARCHITECTURE_MAP.html`
- `ARCHITECTURE_BLUEPRINT.html`
- Anything in the **`src/`** folder (`config.js`, `supabase.js`, all `services/*.js`)
- Anything in the **`supabase/`** folder (the `.sql` files, the edge function)
- `README.md`

(The only file you ever *type keys into* is `src/lib/config.js`, and that's for **later**, when we build the real screens — **not** needed for this test.)

---

## 🛑 STOP AND ASK FOR HELP

Don't keep clicking if one of these happens. Stop and send me what's described in the last section.

- **SQL error:** a red error box appears in the Supabase SQL Editor when you click Run. → Stop. Don't run the other SQL files yet.
- **Supabase key error:** the test says `Invalid API key`, `401`, or the connection won't save. → Stop. Re-check the URL and anon key once; if it still fails, ask.
- **Admin not promoted:** the test says `Admin account is not promoted yet`, or the promote SQL says **0 rows updated**. → Stop. Don't rerun the tests repeatedly.
- **Core loop fails:** any step ①–⑪ shows `✗ FAILED` instead of green. → Stop at the first failure.
- **Security verification fails:** you see any `FAIL` line, or the bottom says `⚠ N test(s) FAILED`. → Stop.
- **Storage bucket issue:** you don't see `resumes` and `cover-letters` under Storage, and creating them by hand didn't help. → Stop.
- **Edge function issue:** *Ignore this for now.* Test #11 showing **SKIP** is expected and fine. Only ask if you intentionally tried to deploy the edge function and got an error.

---

## 📸 If something fails, send me exactly this

To help you fast, send back:

1. **The full text of the black log box.** Click inside it, select all the text, copy it, and paste it to me. (This is the most useful thing.)
2. **A screenshot of the test page** showing which section failed.
3. **If it was a SQL error:** a screenshot of the red error message in the Supabase SQL Editor, and tell me **which file** you were running (0001 / 0002 / 0003 / seed).
4. **Browser console errors:** press **F12** (or right-click → **Inspect**) → click the **Console** tab → screenshot anything in **red**.
5. **Tell me which step number** in this guide you were on when it failed.

> 🔒 **Safety:** When sending logs or screenshots, you can leave the **anon/public key** in — it's browser-safe. **Never** send the **service_role / secret** key, and never send your **database password**. If a screenshot would show the service_role key, blur or crop it out first.

---

When both tests show their green “PASSED” lines, the backend checkpoint is complete, and the next step (later) is binding the first real screen flow to this backend.
