-- Verify sales_history table structure and data
-- Run this in your Supabase SQL Editor to check the table

-- Check if the table exists and show its structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'sales_history'
ORDER BY ordinal_position;

-- Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'sales_history';

-- Check sample data (if any)
SELECT 
    id,
    sale_id,
    change_type,
    field_changed,
    reason,
    changed_by,
    changed_at
FROM public.sales_history 
ORDER BY changed_at DESC 
LIMIT 5;

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'sales_history';
