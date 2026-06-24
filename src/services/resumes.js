// ============================================================================
// resumes.js — upload a resume file (private storage) + metadata row.
// The `summary` (plain text) is what an authorized employer reads in the MVP;
// the actual file stays private to the job seeker.
// ============================================================================
import { supabase } from "../lib/supabase.js";
import { getCurrentUser } from "./auth.js";

// Upload a File/Blob to the private 'resumes' bucket under '{uid}/resume/...'.
export async function uploadResume(file, { summary = "", makeDefault = true } = {}) {
  const user = await getCurrentUser();
  const safeName = (file.name || "resume.pdf").replace(/[^\w.\-]/g, "_");
  const path = `${user.id}/resume/${Date.now()}_${safeName}`;

  const { error: upErr } = await supabase.storage.from("resumes").upload(path, file, {
    upsert: false,
    contentType: file.type || "application/octet-stream",
  });
  if (upErr) throw upErr;

  if (makeDefault) {
    await supabase.from("resumes").update({ is_default: false }).eq("seeker_id", user.id);
  }
  const { data, error } = await supabase
    .from("resumes")
    .insert({ seeker_id: user.id, file_path: path, file_name: safeName, summary, source: "upload", is_default: makeDefault })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// Create a resume row from AI/text only (no file) — used by the mock AI builder.
export async function saveTextResume({ summary, fileName = "AI Resume", makeDefault = true }) {
  const user = await getCurrentUser();
  if (makeDefault) {
    await supabase.from("resumes").update({ is_default: false }).eq("seeker_id", user.id);
  }
  const { data, error } = await supabase
    .from("resumes")
    .insert({ seeker_id: user.id, file_name: fileName, summary, source: "ai", is_default: makeDefault })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function listMyResumes() {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("resumes").select("*").eq("seeker_id", user.id)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

// Employer view of an applicant's actual file = signed URL from the edge function.
export async function getResumeFileUrl(applicationId) {
  const cfg = window.LJL_CONFIG || {};
  const url = cfg.RESUME_URL_FUNCTION || `${cfg.SUPABASE_URL}/functions/v1/get-resume-url`;
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${session?.access_token}` },
    body: JSON.stringify({ application_id: applicationId }),
  });
  if (!res.ok) throw new Error(`Could not get resume URL (${res.status})`);
  return (await res.json()).signedUrl;
}
