-- Tea Shop Inventory Database Schema for Supabase
-- Run this in your Supabase SQL Editor

-- Create users table (extends auth.users)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- Create products table
CREATE TABLE public.products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  cost_price DECIMAL(10,2),
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  minimum_stock INTEGER DEFAULT 10,
  unit TEXT NOT NULL DEFAULT 'kg',
  supplier TEXT,
  barcode TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id),
  is_active BOOLEAN DEFAULT TRUE
);

-- Create sales table
CREATE TABLE public.sales (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_number TEXT UNIQUE NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  total_amount DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'upi', 'other')),
  sale_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id) NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled', 'refunded'))
);

-- Create sale_items table
CREATE TABLE public.sale_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID REFERENCES public.sales(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) NOT NULL,
  quantity DECIMAL(10,3) NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0
);

-- Create inventory_movements table
CREATE TABLE public.inventory_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES public.products(id) NOT NULL,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('purchase', 'sale', 'adjustment', 'return', 'damage')),
  quantity DECIMAL(10,3) NOT NULL,
  reference_id UUID, -- can reference sale_id or other tables
  reference_type TEXT, -- 'sale', 'purchase', 'adjustment', etc.
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id) NOT NULL
);

-- Create indexes for better performance
CREATE INDEX idx_products_category ON public.products(category);
CREATE INDEX idx_products_active ON public.products(is_active);
CREATE INDEX idx_sales_date ON public.sales(sale_date);
CREATE INDEX idx_sales_created_by ON public.sales(created_by);
CREATE INDEX idx_inventory_movements_product ON public.inventory_movements(product_id, created_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER trigger_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create function to automatically insert user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    'staff' -- Default role is staff, admins can be promoted manually
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create user profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable Row Level Security on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can read their own data, admins can read all
CREATE POLICY "Users can view own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admins can view all users" ON public.users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Products policies - all authenticated users can read, only admins can modify
CREATE POLICY "Anyone can view products" ON public.products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Only admins can modify products" ON public.products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Sales policies - users can view their own sales, admins can view all
CREATE POLICY "Users can view own sales" ON public.sales
  FOR SELECT USING (created_by = auth.uid());

CREATE POLICY "Admins can view all sales" ON public.sales
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Users can create sales" ON public.sales
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- Sale items follow sales permissions
CREATE POLICY "Users can view sale items for their sales" ON public.sale_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.sales
      WHERE id = sale_id AND created_by = auth.uid()
    )
  );

CREATE POLICY "Admins can view all sale items" ON public.sale_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Inventory movements - all authenticated users can view, only authenticated can create
CREATE POLICY "Anyone can view inventory movements" ON public.inventory_movements
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create inventory movements" ON public.inventory_movements
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- Create wallet_balances table for tracking daily wallet balance management
CREATE TABLE public.wallet_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    opening_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    closing_balance DECIMAL(10,2),
    status VARCHAR(20) NOT NULL DEFAULT 'opened' CHECK (status IN ('opened', 'closed')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for wallet_balances
CREATE INDEX idx_wallet_balances_user_date ON public.wallet_balances(user_id, date);
CREATE INDEX idx_wallet_balances_date ON public.wallet_balances(date);
CREATE INDEX idx_wallet_balances_user ON public.wallet_balances(user_id);
CREATE INDEX idx_wallet_balances_status ON public.wallet_balances(status);

-- Enable Row Level Security for wallet_balances
ALTER TABLE public.wallet_balances ENABLE ROW LEVEL SECURITY;

-- Create policies for wallet_balances table
CREATE POLICY "Users can view their own wallet balances" ON public.wallet_balances
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can create their own wallet balances" ON public.wallet_balances
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own wallet balances" ON public.wallet_balances
    FOR UPDATE USING (user_id = auth.uid());

-- Admins can view all wallet balances
CREATE POLICY "Admins can view all wallet balances" ON public.wallet_balances
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Insert sample data
-- Note: To create admin users, first sign up normally, then update their role manually

-- Sample products
INSERT INTO public.products (name, description, category, price, cost_price, stock_quantity, minimum_stock, unit, supplier) VALUES
('Earl Grey Tea', 'Premium Earl Grey black tea with bergamot', 'Black Tea', 250.00, 180.00, 50, 10, 'kg', 'Premium Tea Suppliers'),
('Green Tea', 'Organic green tea leaves', 'Green Tea', 300.00, 220.00, 30, 10, 'kg', 'Organic Tea Co'),
('Chamomile Tea', 'Relaxing herbal chamomile tea', 'Herbal Tea', 400.00, 300.00, 25, 5, 'kg', 'Herbal Wellness'),
('Masala Chai', 'Traditional Indian spiced tea blend', 'Spiced Tea', 200.00, 150.00, 40, 15, 'kg', 'Spice Garden'),
('Oolong Tea', 'Semi-fermented oolong tea', 'Oolong Tea', 450.00, 350.00, 20, 5, 'kg', 'Mountain Tea Estate');
