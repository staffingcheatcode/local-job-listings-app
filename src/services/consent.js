// ============================================================================
// consent.js — write a consent acceptance to consent_logs (append-only).
// Called on signup (terms/privacy), apply (resume_share), org create
// (non_discrimination), SMS opt-in (sms_tcpa), and Do-Not-Sell (dns_opt_out).
// ============================================================================
import { supabase } from "../lib/supabase.js";

export async function logConsent(consentType, granted = true, version = "v1") {
  // Best-effort UA; IP is captured server-side in production (edge/proxy).
  const ua = typeof navigator !== "undefined" ? navigator.userAgent : null;
  const { error } = await supabase.rpc("log_consent", {
    p_type: consentType,
    p_granted: granted,
    p_version: version,
    p_ip: null,
    p_ua: ua,
  });
  if (error) throw error;
}
