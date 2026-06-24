// ============================================================================
// orgs.js — employer & staffing-agency profiles.
// ============================================================================
import { supabase } from "../lib/supabase.js";
import { getCurrentUser } from "./auth.js";
import { logConsent } from "./consent.js";

// Create the employer company profile. Requires the non-discrimination agreement.
export async function createEmployer({ companyName, industry, size, hqCity, about, agreedNonDiscrimination }) {
  if (!agreedNonDiscrimination) {
    throw new Error("Employers must agree to the non-discrimination policy.");
  }
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("employers")
    .insert({
      owner_id: user.id,
      company_name: companyName,
      industry, size, hq_city: hqCity, about,
      agreed_non_discrimination: true,
    })
    .select()
    .single();
  if (error) throw error;
  await logConsent("non_discrimination", true);
  return data;
}

export async function getMyEmployer() {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("employers")
    .select("*")
    .eq("owner_id", user.id)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function createAgency({ name, about, specialties = [], agreedNonDiscrimination }) {
  if (!agreedNonDiscrimination) {
    throw new Error("Staffing agencies must agree to the non-discrimination policy.");
  }
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("staffing_agencies")
    .insert({ owner_id: user.id, name, about, specialties, agreed_non_discrimination: true })
    .select()
    .single();
  if (error) throw error;
  await logConsent("non_discrimination", true);
  return data;
}

export async function getMyAgency() {
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("staffing_agencies")
    .select("*")
    .eq("owner_id", user.id)
    .maybeSingle();
  if (error) throw error;
  return data;
}
