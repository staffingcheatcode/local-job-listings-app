// ============================================================================
// FILL THIS IN with your Supabase project values, then everything else works.
// Find these in Supabase dashboard -> Project Settings -> API.
//
// IMPORTANT: only the ANON (public) key goes in the browser. NEVER put the
// service_role key in front-end code — it bypasses Row Level Security.
// ============================================================================

window.LJL_CONFIG = {
  SUPABASE_URL:      "",   // e.g. "https://abcd1234.supabase.co"
  SUPABASE_ANON_KEY: "",   // the public anon key (safe for the browser)

  // Optional: where the get-resume-url edge function lives (defaults to
  // `${SUPABASE_URL}/functions/v1/get-resume-url` if left blank).
  RESUME_URL_FUNCTION: "",
};

// Convenience flag the app uses to decide between REAL data and DEMO mode.
window.LJL_LIVE = !!(window.LJL_CONFIG.SUPABASE_URL && window.LJL_CONFIG.SUPABASE_ANON_KEY);
