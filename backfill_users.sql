-- Insert any existing users from auth.users into public.users if they don't already exist.
-- This fixes the issue for accounts that were created BEFORE the trigger was active.

INSERT INTO public.users (id, email, full_name)
SELECT 
  id, 
  email, 
  raw_user_meta_data->>'full_name'
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.users);
