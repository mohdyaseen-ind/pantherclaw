import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://unxnpjzemjnexltzemni.supabase.co',
  process.env.SUPABASE_ANON_KEY || 'dummy'
);

async function check() {
  const { data, error } = await supabase.from('users').select('*');
  console.log("Users in public.users:", data);
  console.log("Error:", error);
}

check();
