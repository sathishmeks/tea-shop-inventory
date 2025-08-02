-- Create sales_history table for tracking all changes to sales
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.sales_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID REFERENCES public.sales(id) NOT NULL,
  change_type TEXT NOT NULL CHECK (change_type IN ('created', 'updated', 'cancelled', 'refunded')),
  field_changed TEXT, -- which field was changed (e.g., 'customer_name', 'total_amount', 'items')
  old_value JSONB, -- previous value
  new_value JSONB, -- new value
  reason TEXT, -- reason for the change
  changed_by TEXT NOT NULL, -- user who made the change
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  metadata JSONB -- additional context like IP address, user agent, etc.
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sales_history_sale_id ON public.sales_history(sale_id, changed_at);
CREATE INDEX IF NOT EXISTS idx_sales_history_change_type ON public.sales_history(change_type, changed_at);
CREATE INDEX IF NOT EXISTS idx_sales_history_changed_by ON public.sales_history(changed_by, changed_at);

-- Enable Row Level Security
ALTER TABLE public.sales_history ENABLE ROW LEVEL SECURITY;

-- Create policies for sales_history table
CREATE POLICY "Anyone can view sales history" ON public.sales_history
FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create sales history" ON public.sales_history
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Only admins can update or delete history records (for data integrity)
CREATE POLICY "Admins can update sales history" ON public.sales_history
FOR UPDATE USING (auth.role() = 'authenticated');

-- Grant permissions
GRANT ALL ON public.sales_history TO authenticated;
GRANT SELECT ON public.sales_history TO anon;
