-- Create wallet_balances table for tracking daily wallet balance management
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.wallet_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    opening_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    closing_balance DECIMAL(10,2),
    status VARCHAR(20) NOT NULL DEFAULT 'opened' CHECK (status IN ('opened', 'closed')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_wallet_balances_user_date ON public.wallet_balances(user_id, date);
CREATE INDEX IF NOT EXISTS idx_wallet_balances_date ON public.wallet_balances(date);
CREATE INDEX IF NOT EXISTS idx_wallet_balances_user ON public.wallet_balances(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_balances_status ON public.wallet_balances(status);

-- Enable Row Level Security
ALTER TABLE public.wallet_balances ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own wallet balances" ON public.wallet_balances;
DROP POLICY IF EXISTS "Users can create their own wallet balances" ON public.wallet_balances;
DROP POLICY IF EXISTS "Users can update their own wallet balances" ON public.wallet_balances;
DROP POLICY IF EXISTS "Admins can view all wallet balances" ON public.wallet_balances;

-- Create policies for wallet_balances table
CREATE POLICY "Users can view their own wallet balances" ON public.wallet_balances
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own wallet balances" ON public.wallet_balances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own wallet balances" ON public.wallet_balances
    FOR UPDATE USING (auth.uid() = user_id);

-- Admins can view all wallet balances
CREATE POLICY "Admins can view all wallet balances" ON public.wallet_balances
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Grant permissions
GRANT ALL ON public.wallet_balances TO authenticated;
GRANT SELECT ON public.wallet_balances TO anon;

-- Add constraint to ensure one wallet balance per user per day (drop if exists first)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name = 'unique_user_wallet_balance_per_day' 
               AND table_name = 'wallet_balances') THEN
        ALTER TABLE public.wallet_balances DROP CONSTRAINT unique_user_wallet_balance_per_day;
    END IF;
END $$;

ALTER TABLE public.wallet_balances 
ADD CONSTRAINT unique_user_wallet_balance_per_day 
UNIQUE (user_id, date);

-- Create or replace function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_wallet_balances_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS update_wallet_balances_updated_at_trigger ON public.wallet_balances;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_wallet_balances_updated_at_trigger
    BEFORE UPDATE ON public.wallet_balances
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_balances_updated_at();

-- Insert some sample data for testing (optional)
-- Note: Replace the user_id with actual UUID from your auth.users table
/*
INSERT INTO public.wallet_balances (
    user_id, 
    date, 
    opening_balance, 
    closing_balance, 
    status, 
    notes
) VALUES (
    '00000000-0000-0000-0000-000000000000', -- Replace with actual user ID
    CURRENT_DATE - INTERVAL '1 day',
    500.00,
    750.00,
    'closed',
    'Previous day balance'
) ON CONFLICT (user_id, date) DO NOTHING;
*/
