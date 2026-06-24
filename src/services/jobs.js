// ============================================================================
// jobs.js — create / list / read jobs.
// Public listing returns ONLY approved + active jobs (enforced again by RLS).
// ============================================================================
import { supabase } from "../lib/supabase.js";
import { getCurrentUser } from "./auth.js";

// Employer posts a job. It starts as draft+pending and is auto-queued for
// moderation by a DB trigger. pay_min/pay_max are required (pay transparency).
export async function createEmployerJob(employerId, job) {
  const user = await getCurrentUser();
  const payload = {
    poster_type: "employer",
    employer_id: employerId,
    created_by: user.id,
    title: job.title,
    company_name: job.companyName,
    city_state: job.cityState,
    zip: job.zip ?? null,
    address: job.address ?? null,
    pay_min: job.payMin,
    pay_max: job.payMax,
    employment_type: job.employmentType,   // enum: full_time | part_time | temp_to_hire | contract | direct_hire
    shifts: job.shifts ?? [],
    category: job.category ?? null,
    description: job.description ?? null,
    requirements: job.requirements ?? [],
    benefits: job.benefits ?? [],
    openings: job.openings ?? 1,
    urgency: job.urgency ?? "normal",
    screening_questions: job.screeningQuestions ?? [],
    contact_person: job.contactPerson ?? null,
    status: "draft",
    moderation_status: "pending",
  };
  const { data, error } = await supabase.from("jobs").insert(payload).select().single();
  if (error) throw error;
  return data;
}

// Public job feed (job seekers). Optional simple filters.
export async function listPublicJobs({ category, employmentType, payMin } = {}) {
  let q = supabase
    .from("jobs")
    .select("*")
    .eq("moderation_status", "approved")
    .eq("status", "active")
    .order("created_at", { ascending: false });
  if (category) q = q.eq("category", category);
  if (employmentType) q = q.eq("employment_type", employmentType);
  if (payMin) q = q.gte("pay_max", payMin);
  const { data, error } = await q;
  if (error) throw error;
  return data;
}

export async function getJob(jobId) {
  const { data, error } = await supabase.from("jobs").select("*").eq("id", jobId).single();
  if (error) throw error;
  return data;
}

// Employer's own posts (any status).
export async function listMyEmployerJobs(employerId) {
  const { data, error } = await supabase
    .from("jobs")
    .select("*")
    .eq("employer_id", employerId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}
