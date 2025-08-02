-- Create inventory_movements table
CREATE TABLE IF NOT EXISTS public.inventory_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out', 'adjustment', 'refill', 'sale', 'return')),
    quantity NUMERIC NOT NULL,
    reference_id UUID,
    reference_type TEXT CHECK (reference_type IN ('sale', 'purchase', 'adjustment', 'refill', 'return')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON public.inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_movement_type ON public.inventory_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_reference ON public.inventory_movements(reference_id, reference_type);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_created_at ON public.inventory_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_created_by ON public.inventory_movements(created_by);

-- Enable Row Level Security
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can view all inventory movements
CREATE POLICY "Users can view all inventory movements" ON public.inventory_movements
    FOR SELECT USING (true);

-- Users can insert inventory movements
CREATE POLICY "Users can insert inventory movements" ON public.inventory_movements
    FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Users can update their own inventory movements (admin only)
CREATE POLICY "Admins can update inventory movements" ON public.inventory_movements
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT id FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Users can delete their own inventory movements (admin only)
CREATE POLICY "Admins can delete inventory movements" ON public.inventory_movements
    FOR DELETE USING (
        auth.uid() IN (
            SELECT id FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Add helpful comments
COMMENT ON TABLE public.inventory_movements IS 'Tracks all inventory movements including sales, refills, adjustments, and returns';
COMMENT ON COLUMN public.inventory_movements.movement_type IS 'Type of movement: in (stock increase), out (stock decrease), adjustment, refill, sale, return';
COMMENT ON COLUMN public.inventory_movements.quantity IS 'Quantity moved (positive for in/refill, negative for out/sale)';
COMMENT ON COLUMN public.inventory_movements.reference_type IS 'Type of reference document (sale, purchase, adjustment, etc.)';
COMMENT ON COLUMN public.inventory_movements.reference_id IS 'ID of the related transaction (sale_id, purchase_id, etc.)';
