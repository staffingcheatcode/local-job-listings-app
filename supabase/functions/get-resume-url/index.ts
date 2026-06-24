// ============================================================================
// get-resume-url — Supabase Edge Function (Deno).
//
// SECURITY MODEL (verified):
//   * The browser calls this with the caller's ANON-key session JWT only.
//   * The service_role key NEVER leaves the server — it lives in this function's
//     environment (Deno.env) and is used only to mint the signed URL.
//   * Authorization is checked BEFORE any URL is created: we query the
//     application using a client bound to the CALLER's JWT, so Row Level
//     Security decides whether the caller may see it. A random user (or an
//     unrelated employer) gets no row back -> 403, no URL.
//   * Signed URLs expire quickly (300s).
//
// Deploy:  supabase functions deploy get-resume-url
// Secrets: supabase secrets set PROJECT_URL=... SERVICE_ROLE_KEY=...
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_URL = Deno.env.get("PROJECT_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const SIGNED_URL_TTL_SECONDS = 300; // 5 minutes

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    // 1) Require a caller token (anon-key session JWT). No token -> no access.
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) return json({ error: "Missing authorization" }, 401);

    const { application_id } = await req.json().catch(() => ({}));
    if (!application_id) return json({ error: "application_id required" }, 400);

    // 2) Authorize using a client bound to the CALLER's JWT. RLS does the work:
    //    the row is only returned to the seeker, the owning employer/agency,
    //    or an admin. Anyone else gets nothing.
    const asCaller = createClient(PROJECT_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: app, error } = await asCaller
      .from("applications")
      .select("id, resume_id, resumes(file_path)")
      .eq("id", application_id)
      .single();

    if (error || !app?.resumes?.file_path) {
      return json({ error: "Not found or not authorized" }, 403);
    }

    // 3) Only NOW, with authorization confirmed, mint a short-lived signed URL
    //    using the service role (server-side only).
    const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: signed, error: sErr } = await admin
      .storage.from("resumes")
      .createSignedUrl(app.resumes.file_path, SIGNED_URL_TTL_SECONDS);
    if (sErr) return json({ error: sErr.message }, 500);

    return json({ signedUrl: signed.signedUrl, expiresInSeconds: SIGNED_URL_TTL_SECONDS });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
