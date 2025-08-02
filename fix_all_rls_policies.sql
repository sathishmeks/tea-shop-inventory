-- Comprehensive fix for all RLS policies in Tea Shop database
-- Run this in your Supabase SQL Editor to fix all table access issues

-- First, temporarily disable RLS on all tables for debugging
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies on all tables
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
DROP POLICY IF EXISTS "Users can access user data" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Allow user profile creation" ON public.users;
DROP POLICY IF EXISTS "Temporary debug policy" ON public.users;

-- Clear any existing policies on other tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "allow_all" ON ' || r.schemaname || '.' || r.tablename;
        EXECUTE 'DROP POLICY IF EXISTS "Users can access own data" ON ' || r.schemaname || '.' || r.tablename;
        EXECUTE 'DROP POLICY IF EXISTS "Admins can access all" ON ' || r.schemaname || '.' || r.tablename;
    END LOOP;
END$$;

-- Grant all permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant permissions to anon users as well (for initial access)
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Insert your user into users table if not exists
INSERT INTO public.users (id, email, name, role)
SELECT 
  id, 
  email, 
  COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)) as name,
  'admin' as role
FROM auth.users 
WHERE email = 'sathishmeks@gmail.com'
ON CONFLICT (id) DO UPDATE SET 
  role = 'admin',
  name = COALESCE(EXCLUDED.name, users.name);

-- Create or replace the function to handle new user creation
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
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, users.name);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Re-enable RLS with permissive policies for now
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- Create simple, permissive policies for all tables
CREATE POLICY "allow_all_users" ON public.users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_products" ON public.products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_sales" ON public.sales FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_sale_items" ON public.sale_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_shifts" ON public.shifts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_inventory_movements" ON public.inventory_movements FOR ALL USING (true) WITH CHECK (true);

-- Ensure all tables have proper default values
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'staff';

-- Only set defaults for columns that exist
DO $$
BEGIN
    -- Check and set defaults for created_at columns where they exist
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'created_at') THEN
        ALTER TABLE public.users ALTER COLUMN created_at SET DEFAULT NOW();
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'created_at') THEN
        ALTER TABLE public.products ALTER COLUMN created_at SET DEFAULT NOW();
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'shifts' AND column_name = 'created_at') THEN
        ALTER TABLE public.shifts ALTER COLUMN created_at SET DEFAULT NOW();
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_movements' AND column_name = 'created_at') THEN
        ALTER TABLE public.inventory_movements ALTER COLUMN created_at SET DEFAULT NOW();
    END IF;
    
    -- Set defaults for timestamp columns in sales table (if they exist)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'sales' AND column_name = 'timestamp') THEN
        ALTER TABLE public.sales ALTER COLUMN timestamp SET DEFAULT NOW();
    END IF;
END$$;
