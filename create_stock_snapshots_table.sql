-- Create stock_snapshots table for tracking inventory at session start/end
-- This table records complete inventory state when sessions begin and end

CREATE TABLE IF NOT EXISTS public.stock_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.wallet_balances(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    snapshot_type VARCHAR(20) NOT NULL CHECK (snapshot_type IN ('session_start', 'session_end')),
    snapshot_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total_products_count INTEGER NOT NULL DEFAULT 0,
    total_stock_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create stock_snapshot_items table for individual product quantities
CREATE TABLE IF NOT EXISTS public.stock_snapshot_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id UUID NOT NULL REFERENCES public.stock_snapshots(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    unit VARCHAR(50),
    quantity_recorded DECIMAL(10,3) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stock_snapshots_session ON public.stock_snapshots(session_id);
CREATE INDEX IF NOT EXISTS idx_stock_snapshots_user ON public.stock_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_stock_snapshots_type ON public.stock_snapshots(snapshot_type);
CREATE INDEX IF NOT EXISTS idx_stock_snapshots_date ON public.stock_snapshots(snapshot_date);

CREATE INDEX IF NOT EXISTS idx_stock_snapshot_items_snapshot ON public.stock_snapshot_items(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_stock_snapshot_items_product ON public.stock_snapshot_items(product_id);

-- Enable Row Level Security
ALTER TABLE public.stock_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_snapshot_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own stock snapshots" ON public.stock_snapshots;
DROP POLICY IF EXISTS "Users can create their own stock snapshots" ON public.stock_snapshots;
DROP POLICY IF EXISTS "Admins can view all stock snapshots" ON public.stock_snapshots;

DROP POLICY IF EXISTS "Users can view their own snapshot items" ON public.stock_snapshot_items;
DROP POLICY IF EXISTS "Users can create their own snapshot items" ON public.stock_snapshot_items;
DROP POLICY IF EXISTS "Admins can view all snapshot items" ON public.stock_snapshot_items;

-- Create policies for stock_snapshots table
CREATE POLICY "Users can view their own stock snapshots" ON public.stock_snapshots
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own stock snapshots" ON public.stock_snapshots
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can view all stock snapshots
CREATE POLICY "Admins can view all stock snapshots" ON public.stock_snapshots
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Create policies for stock_snapshot_items table
CREATE POLICY "Users can view their own snapshot items" ON public.stock_snapshot_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.stock_snapshots
            WHERE id = snapshot_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create their own snapshot items" ON public.stock_snapshot_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.stock_snapshots
            WHERE id = snapshot_id AND user_id = auth.uid()
        )
    );

-- Admins can view all snapshot items
CREATE POLICY "Admins can view all snapshot items" ON public.stock_snapshot_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Grant permissions
GRANT ALL ON public.stock_snapshots TO authenticated;
GRANT SELECT ON public.stock_snapshots TO anon;

GRANT ALL ON public.stock_snapshot_items TO authenticated;
GRANT SELECT ON public.stock_snapshot_items TO anon;

-- Add comments for documentation
COMMENT ON TABLE public.stock_snapshots IS 'Records complete inventory state at session start and end for verification';
COMMENT ON COLUMN public.stock_snapshots.snapshot_type IS 'Type of snapshot: session_start or session_end';
COMMENT ON COLUMN public.stock_snapshots.total_stock_value IS 'Total value of all inventory at snapshot time';

COMMENT ON TABLE public.stock_snapshot_items IS 'Individual product quantities and values at snapshot time';
COMMENT ON COLUMN public.stock_snapshot_items.quantity_recorded IS 'Actual quantity recorded at snapshot time';
COMMENT ON COLUMN public.stock_snapshot_items.total_value IS 'Calculated as quantity_recorded * unit_price';
