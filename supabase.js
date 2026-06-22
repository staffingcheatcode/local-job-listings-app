// ============================================================================
// Supabase client (browser, ES module).
// Uses supabase-js v2 from a CDN so there is no build step required.
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cfg = (typeof window !== "undefined" && window.LJL_CONFIG) || {};

// In some sandboxed previews localStorage is unavailable. We fall back to an
// in-memory store so the client still works (session just won't survive reload).
function safeStorage() {
  try {
    const k = "__ljl_test__";
    window.localStorage.setItem(k, "1");
    window.localStorage.removeItem(k);
    return window.localStorage;
  } catch {
    const mem = new Map();
    return {
      getItem: (k) => (mem.has(k) ? mem.get(k) : null),
      setItem: (k, v) => mem.set(k, v),
      removeItem: (k) => mem.delete(k),
    };
  }
}

export const supabase = createClient(
  cfg.SUPABASE_URL || "http://localhost",
  cfg.SUPABASE_ANON_KEY || "anon",
  {
    auth: {
      storage: safeStorage(),
      persistSession: true,
      autoRefreshToken: true,
    },
  }
);

export const isLive = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY);
