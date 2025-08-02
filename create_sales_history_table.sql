-- Create sales_history table for tracking all changes to sales
-- Run this in your Supabase SQL Editor

create table public.sales_history (
    id uuid not null default gen_random_uuid (),
    sale_id uuid not null,
    change_type text not null,
    field_changed text null,
    old_value jsonb null,
    new_value jsonb null,
    reason text null,
    changed_by text not null,
    changed_at timestamp with time zone null default now(),
    metadata jsonb null,
    constraint sales_history_pkey primary key (id),
    constraint sales_history_sale_id_fkey foreign KEY (sale_id) references sales (id),
    constraint sales_history_change_type_check check (
        (
            change_type = any (
                array[
                    'created'::text,
                    'updated'::text,
                    'cancelled'::text,
                    'refunded'::text
                ]
            )
        )
    )
) TABLESPACE pg_default;

-- Create indexes for better performance
create index IF not exists idx_sales_history_sale_id on public.sales_history using btree (sale_id, changed_at) TABLESPACE pg_default;

create index IF not exists idx_sales_history_change_type on public.sales_history using btree (change_type, changed_at) TABLESPACE pg_default;

create index IF not exists idx_sales_history_changed_by on public.sales_history using btree (changed_by, changed_at) TABLESPACE pg_default;

-- Row Level Security (RLS) for sales_history
ALTER TABLE public.sales_history ENABLE ROW LEVEL SECURITY;

-- Allow users to view sales history for sales they can access
CREATE POLICY "Users can view sales history for accessible sales" ON public.sales_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.sales s 
            WHERE s.id = sale_id 
            AND (s.created_by = auth.uid() OR auth.role() = 'admin')
        )
    );

-- Allow users to insert sales history when they create/modify sales
CREATE POLICY "Users can insert sales history for their sales" ON public.sales_history
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.sales s 
            WHERE s.id = sale_id 
            AND (s.created_by = auth.uid() OR auth.role() = 'admin')
        )
    );

-- Prevent updates and deletes on sales history (audit trail should be immutable)
CREATE POLICY "Sales history is immutable" ON public.sales_history
    FOR UPDATE USING (false);

CREATE POLICY "Sales history cannot be deleted" ON public.sales_history
    FOR DELETE USING (false);

-- Grant necessary permissions
GRANT ALL ON public.sales_history TO authenticated;
GRANT SELECT ON public.sales_history TO anon;
