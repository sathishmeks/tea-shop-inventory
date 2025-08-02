-- Create sales_sessions table for tracking daily sale session endings
-- This table records when users end their sales session for the day

CREATE TABLE IF NOT EXISTS public.sales_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    session_end_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total_sales_count INTEGER NOT NULL DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'ended',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sales_sessions_user_date ON public.sales_sessions(user_id, session_date);
CREATE INDEX IF NOT EXISTS idx_sales_sessions_date ON public.sales_sessions(session_date);
CREATE INDEX IF NOT EXISTS idx_sales_sessions_user ON public.sales_sessions(user_id);

-- Enable Row Level Security
ALTER TABLE public.sales_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own sales sessions" ON public.sales_sessions;
DROP POLICY IF EXISTS "Users can create their own sales sessions" ON public.sales_sessions;
DROP POLICY IF EXISTS "Users can update their own sales sessions" ON public.sales_sessions;

-- Create policies for sales_sessions table
CREATE POLICY "Users can view their own sales sessions" ON public.sales_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own sales sessions" ON public.sales_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sales sessions" ON public.sales_sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.sales_sessions TO authenticated;
GRANT SELECT ON public.sales_sessions TO anon;

-- Add constraint to ensure one session per user per day (drop if exists first)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name = 'unique_user_session_per_day' 
               AND table_name = 'sales_sessions') THEN
        ALTER TABLE public.sales_sessions 
        DROP CONSTRAINT unique_user_session_per_day;
    END IF;
END $$;

ALTER TABLE public.sales_sessions 
ADD CONSTRAINT unique_user_session_per_day 
UNIQUE(user_id, session_date);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_sales_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and create new one
DROP TRIGGER IF EXISTS update_sales_sessions_updated_at ON public.sales_sessions;
CREATE TRIGGER update_sales_sessions_updated_at
    BEFORE UPDATE ON public.sales_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_sales_sessions_updated_at();
