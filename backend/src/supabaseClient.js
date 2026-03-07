import { createClient } from "@supabase/supabase-js";
import { config } from "./config.js";

if (!config.supabaseUrl || !config.supabaseServiceRoleKey) {
  // The server can still start, but any DB access will fail fast with a clear message.
  // This avoids silent misconfiguration during early development.
  // eslint-disable-next-line no-console
  console.warn(
    "[Supabase] SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set. Database operations will fail."
  );
}

export const supabaseAdmin = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

