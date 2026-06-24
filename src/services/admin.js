// ============================================================================
// admin.js — moderation queue + approve/reject (admin-only, enforced by RLS/RPC).
// ============================================================================
import { supabase } from "../lib/supabase.js";

export async function listModerationQueue(status = "pending") {
  const { data, error } = await supabase
    .from("admin_moderation_queue")
    .select("*")
    .eq("status", status)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

// Pending jobs joined with their job details, for the admin review screen.
export async function listPendingJobs() {
  const { data, error } = await supabase
    .from("jobs")
    .select("*")
    .eq("moderation_status", "pending")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

export async function approveJob(jobId) {
  const { error } = await supabase.rpc("approve_job", { p_job_id: jobId });
  if (error) throw error;
}

export async function rejectJob(jobId, reason = "") {
  const { error } = await supabase.rpc("reject_job", { p_job_id: jobId, p_reason: reason });
  if (error) throw error;
}
