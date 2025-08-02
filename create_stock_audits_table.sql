-- Create stock_audits table for inventory tracking
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.stock_audits (
  id TEXT PRIMARY KEY,
  product_id UUID REFERENCES public.products(id) NOT NULL,
  product_name TEXT NOT NULL,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('restock', 'sale', 'adjustment', 'waste', 'return_')),
  quantity_before INTEGER NOT NULL,
  quantity_change INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  cost_per_unit DECIMAL(10,2),
  total_cost DECIMAL(10,2),
  supplier TEXT,
  invoice_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_by TEXT NOT NULL,
  approved_by TEXT,
  approved_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stock_audits_product ON public.stock_audits(product_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_audits_movement_type ON public.stock_audits(movement_type, created_at);

-- Enable Row Level Security
ALTER TABLE public.stock_audits ENABLE ROW LEVEL SECURITY;

-- Create policies for stock_audits table
CREATE POLICY "Anyone can view stock audits" ON public.stock_audits
FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create stock audits" ON public.stock_audits
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update stock audits" ON public.stock_audits
FOR UPDATE USING (auth.role() = 'authenticated');

-- Grant permissions
GRANT ALL ON public.stock_audits TO authenticated;
GRANT SELECT ON public.stock_audits TO anon;
