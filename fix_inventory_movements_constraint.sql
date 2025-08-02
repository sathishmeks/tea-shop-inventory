-- Check current constraint
SELECT conname, consrc 
FROM pg_constraint 
WHERE conrelid = 'public.inventory_movements'::regclass
AND contype = 'c';

-- Drop the existing constraint if it exists
ALTER TABLE public.inventory_movements 
DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

-- Add the correct constraint
ALTER TABLE public.inventory_movements 
ADD CONSTRAINT inventory_movements_movement_type_check 
CHECK (movement_type IN ('in', 'out', 'adjustment', 'refill', 'sale', 'return'));

-- Also check reference_type constraint
ALTER TABLE public.inventory_movements 
DROP CONSTRAINT IF EXISTS inventory_movements_reference_type_check;

ALTER TABLE public.inventory_movements 
ADD CONSTRAINT inventory_movements_reference_type_check 
CHECK (reference_type IN ('sale', 'purchase', 'adjustment', 'refill', 'return'));

-- Verify the new constraints
SELECT conname, consrc 
FROM pg_constraint 
WHERE conrelid = 'public.inventory_movements'::regclass
AND contype = 'c';
