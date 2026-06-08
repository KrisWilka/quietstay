import { createClient } from '@supabase/supabase-js';

/**
 * Public (anon) Supabase client. Safe for the browser and server components:
 * Row-Level Security protects the data. Only published guidebooks and their
 * guest-visible items are readable by the anon role.
 */
export function createSupabaseClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  return createClient(url, key);
}
