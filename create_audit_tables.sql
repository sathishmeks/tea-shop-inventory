-- Create Stock Audits table for tracking inventory changes
CREATE TABLE IF NOT EXISTS stock_audits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('added', 'removed', 'adjusted', 'restocked')),
    quantity_before DECIMAL(10,2) NOT NULL DEFAULT 0,
    quantity_after DECIMAL(10,2) NOT NULL DEFAULT 0,
    quantity_changed DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(10,2),
    total_cost DECIMAL(10,2),
    reason TEXT,
    performed_by UUID REFERENCES auth.users(id),
    reference_type VARCHAR(50), -- 'sale', 'restock', 'manual_adjustment', etc.
    reference_id UUID, -- ID of the related sale, restock, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB
);

-- Create Sales History table for tracking sale edits
CREATE TABLE IF NOT EXISTS sales_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('created', 'updated', 'cancelled', 'refunded')),
    field_changed VARCHAR(100),
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stock_audits_product_id ON stock_audits(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_audits_created_at ON stock_audits(created_at);
CREATE INDEX IF NOT EXISTS idx_stock_audits_change_type ON stock_audits(change_type);
CREATE INDEX IF NOT EXISTS idx_stock_audits_reference ON stock_audits(reference_type, reference_id);

CREATE INDEX IF NOT EXISTS idx_sales_history_sale_id ON sales_history(sale_id);
CREATE INDEX IF NOT EXISTS idx_sales_history_changed_at ON sales_history(changed_at);
CREATE INDEX IF NOT EXISTS idx_sales_history_change_type ON sales_history(change_type);
CREATE INDEX IF NOT EXISTS idx_sales_history_changed_by ON sales_history(changed_by);

-- Enable Row Level Security (RLS)
ALTER TABLE stock_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for stock_audits table
CREATE POLICY "Allow authenticated users to read stock_audits" ON stock_audits
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert stock_audits" ON stock_audits
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own stock_audits" ON stock_audits
    FOR UPDATE USING (performed_by = auth.uid());

CREATE POLICY "Allow authenticated users to delete stock_audits" ON stock_audits
    FOR DELETE USING (auth.role() = 'authenticated');

-- RLS Policies for sales_history table
CREATE POLICY "Allow authenticated users to read sales_history" ON sales_history
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert sales_history" ON sales_history
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own sales_history" ON sales_history
    FOR UPDATE USING (changed_by = auth.uid());

CREATE POLICY "Allow authenticated users to delete sales_history" ON sales_history
    FOR DELETE USING (auth.role() = 'authenticated');

-- Add triggers for automatically setting timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Note: These tables don't have updated_at columns, but this function is available for future use

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON stock_audits TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sales_history TO authenticated;

-- Grant usage on sequences (for UUID generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
