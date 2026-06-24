// ============================================================================
// coverLetters.js — save / list cover letters (+ a MOCK AI generator).
// The AI here is a deterministic template. It NEVER scores or ranks anyone.
// Swap genCoverLetterText() for a real server-side call once keys are set.
// ============================================================================
import { supabase } from "../lib/supabase.js";
import { getCurrentUser } from "./auth.js";

// MOCK: produces a short, friendly, professional draft. No external call.
export function genCoverLetterText({ jobTitle = "the role", company = "", highlight = "", seekerName = "" }) {
  const greet = company ? `Dear ${company} Hiring Team,` : "Dear Hiring Team,";
  const extra = highlight ? `${highlight[0].toUpperCase()}${highlight.slice(1)}. ` : "";
  return `${greet}

I'm excited to apply for the ${jobTitle} position. I'm a reliable, safety-minded worker who takes pride in showing up ready to work every shift.

${extra}I work well on a team and learn fast. I'd welcome the chance to bring that same dependability to yours.

Thank you for your time and consideration.

Sincerely,
${seekerName || "[Your name]"}`;
}

export async function saveCoverLetter({ title, body, jobId = null, source = "ai" }) {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("cover_letters")
    .insert({ seeker_id: user.id, job_id: jobId, title, body, source })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function listMyCoverLetters() {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("cover_letters").select("*").eq("seeker_id", user.id)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}
