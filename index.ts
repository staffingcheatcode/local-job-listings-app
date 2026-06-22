// ============================================================================
// get-resume-url — Supabase Edge Function (Deno).
// Returns a short-lived signed URL for an applicant's resume file, but ONLY if
// the caller is the employer/agency that owns the job, or an admin.
//
// Deploy:  supabase functions deploy get-resume-url
// Secrets: supabase secrets set SERVICE_ROLE_KEY=... PROJECT_URL=...
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_URL = Deno.env.get("PROJECT_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) return json({ error: "Missing auth" }, 401);

    const { application_id } = await req.json();
    if (!application_id) return json({ error: "application_id required" }, 400);

    // Client bound to the CALLER's JWT — respects RLS for the ownership check.
    const asUser = createClient(PROJECT_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    // Because of RLS, this row only returns if the caller may see this application
    // (seeker, owning employer/agency, or admin). We additionally require a resume.
    const { data: app, error } = await asUser
      .from("applications")
      .select("id, resume_id, resumes(file_path)")
      .eq("id", application_id)
      .single();
    if (error || !app?.resumes?.file_path) return json({ error: "Not found or not allowed" }, 403);

    // Service-role client to actually mint the signed URL on the private bucket.
    const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY);
    const { data: signed, error: sErr } = await admin
      .storage.from("resumes")
      .createSignedUrl(app.resumes.file_path, 60 * 5); // 5 minutes
    if (sErr) return json({ error: sErr.message }, 500);

    return json({ signedUrl: signed.signedUrl });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
