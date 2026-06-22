// ============================================================================
// applications.js — apply, view tracker, list applicants, move stage.
// Stage changes go through the set_application_stage RPC so authorization and
// the "reason only when not_selected" rule are enforced in the database.
// ============================================================================
import { supabase } from "../lib/supabase.js";
import { getCurrentUser } from "./auth.js";
import { logConsent } from "./consent.js";

export const STAGES = [
  "submitted","resume_received","in_review","second_stage",
  "interview_requested","offer_extended","hired","not_selected",
];

export const STAGE_LABELS = {
  submitted: "Submitted",
  resume_received: "Resume received",
  in_review: "In review",
  second_stage: "Second-stage review",
  interview_requested: "Interview requested",
  offer_extended: "Offer extended",
  hired: "Hired",
  not_selected: "Not selected",
};

export const REJECT_REASONS = {
  position_filled: "Position filled",
  experience_mismatch: "Experience mismatch",
  certification_required: "Certification/license required",
  schedule_mismatch: "Schedule mismatch",
  location_mismatch: "Location/commute mismatch",
  employer_selected_other: "Employer selected another candidate",
  other_neutral: "Other neutral reason",
};

// Job seeker applies. Records the resume-share consent in consent_logs.
export async function applyToJob({ jobId, resumeId, coverLetterId = null, note = "", shareConsent = true }) {
  const user = await getCurrentUser();
  if (!shareConsent) throw new Error("Resume-share consent is required to apply.");

  const { data, error } = await supabase
    .from("applications")
    .insert({ job_id: jobId, seeker_id: user.id, resume_id: resumeId, cover_letter_id: coverLetterId, note })
    .select()
    .single();
  if (error) throw error; // unique violation => already applied
  await logConsent("resume_share", true);
  return data;
}

// Job seeker: their applications (for the tracker list).
export async function listMyApplications() {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("applications")
    .select("*, jobs(title, company_name, city_state)")
    .eq("seeker_id", user.id)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

// Tracker detail: the application + its ordered status history.
export async function getApplicationTracker(applicationId) {
  const { data: app, error: e1 } = await supabase
    .from("applications")
    .select("*, jobs(title, company_name, city_state)")
    .eq("id", applicationId)
    .single();
  if (e1) throw e1;
  const { data: events, error: e2 } = await supabase
    .from("application_status_events")
    .select("*")
    .eq("application_id", applicationId)
    .order("created_at", { ascending: true });
  if (e2) throw e2;
  return { app, events };
}

// Employer: applicants for one of their jobs (joins seeker docs they're allowed to read).
export async function listApplicantsForJob(jobId) {
  const { data, error } = await supabase
    .from("applications")
    .select("*, profiles:seeker_id(full_name), resumes(summary, file_name), cover_letters(title, body)")
    .eq("job_id", jobId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

// Employer/admin moves an applicant. reason only valid when stage='not_selected'.
export async function setApplicationStage(applicationId, stage, reason = null) {
  const { error } = await supabase.rpc("set_application_stage", {
    p_application_id: applicationId,
    p_stage: stage,
    p_reason: reason,
  });
  if (error) throw error;
}
