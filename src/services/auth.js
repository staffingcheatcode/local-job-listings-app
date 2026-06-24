// ============================================================================
// auth.js — signup / login / profile, with role-based metadata.
// Roles: 'job_seeker' | 'employer' | 'staffing_agency' | 'admin'
// A profiles row is created automatically by the handle_new_user() trigger.
// ============================================================================
import { supabase } from "../lib/supabase.js";

export async function signUp({ email, password, role = "job_seeker", fullName = "", phone = "" }) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { role, full_name: fullName, phone } },
  });
  if (error) throw error;
  return data.user;
}

export async function signIn({ email, password }) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data.user;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentUser() {
  const { data } = await supabase.auth.getUser();
  return data.user ?? null;
}

export async function getMyProfile() {
  const user = await getCurrentUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();
  if (error) throw error;
  return data;
}

// Job seekers fill in their preferences (radius, pay, categories...).
export async function upsertJobSeeker(fields) {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("job_seekers")
    .upsert({ id: user.id, ...fields, updated_at: new Date().toISOString() })
    .select()
    .single();
  if (error) throw error;
  return data;
}
