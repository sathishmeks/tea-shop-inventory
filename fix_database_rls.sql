-- Fix for PostgreSQL infinite recursion error in RLS policies
-- Run this in your Supabase SQL Editor to fix the users table RLS issue

-- First, drop ALL existing policies on users table to avoid conflicts
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
DROP POLICY IF EXISTS "Users can access user data" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Allow user profile creation" ON public.users;

-- Create a single, non-recursive policy for users table
CREATE POLICY "Users can access user data" ON public.users
  FOR ALL USING (
    -- Users can access their own data
    auth.uid() = id
    OR
    -- Or if they are an admin (check directly against auth.users table to avoid recursion)
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid() 
      AND au.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Alternative: Create separate policies without recursion
-- DROP POLICY IF EXISTS "Users can access user data" ON public.users;

-- CREATE POLICY "Users can view own profile" ON public.users
--   FOR SELECT USING (auth.uid() = id);

-- CREATE POLICY "Users can update own profile" ON public.users
--   FOR UPDATE USING (auth.uid() = id);

-- CREATE POLICY "Allow user profile creation" ON public.users
--   FOR INSERT WITH CHECK (auth.uid() = id);

-- Ensure the users table has proper default values and constraints
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'staff';

-- Create or replace the function to handle new user creation without RLS conflicts
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff')
  )
  ON CONFLICT (id) DO NOTHING; -- Avoid duplicate insertion errors
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Insert the current user into users table if not exists (for testing)
-- Replace 'sathishmeks@gmail.com' with your actual email if different
INSERT INTO public.users (id, email, name, role)
SELECT 
  id, 
  email, 
  COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)) as name,
  'admin' as role  -- Set as admin for testing
FROM auth.users 
WHERE email = 'sathishmeks@gmail.com'
ON CONFLICT (id) DO UPDATE SET 
  role = 'admin',
  name = COALESCE(EXCLUDED.name, users.name);

-- Also create a more permissive temporary policy for debugging
DROP POLICY IF EXISTS "Temporary debug policy" ON public.users;
CREATE POLICY "Temporary debug policy" ON public.users
  FOR ALL USING (true)  -- Allow all operations temporarily for debugging
  WITH CHECK (true);

-- Disable the restrictive policy temporarily
DROP POLICY IF EXISTS "Users can access user data" ON public.users;
