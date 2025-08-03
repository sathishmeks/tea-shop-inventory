-- Tea Shop Inventory - Product Insert Script
-- This script inserts the product data into the products table

INSERT INTO products (
    id,
    name,
    description,
    category,
    price,
    cost_price,
    stock_quantity,
    minimum_stock,
    unit,
    supplier,
    barcode,
    image_url,
    is_active,
    created_at,
    updated_at,
    created_by
) VALUES 
-- Drinks - Juice
(gen_random_uuid(), '10rs Juice', 'Fresh fruit juice - small size', 'Drinks', 10.00, 6.00, 50, 10, 'bottle', 'Local Juice Supplier', NULL, NULL, true, NOW(), NOW(), NULL),
(gen_random_uuid(), '20rs Juice', 'Fresh fruit juice - large size', 'Drinks', 20.00, 12.00, 40, 10, 'bottle', 'Local Juice Supplier', NULL, NULL, true, NOW(), NOW(), NULL),

-- Drinks - Water
(gen_random_uuid(), '10rs Water', 'Mineral water - small bottle', 'Drinks', 10.00, 5.00, 100, 20, 'bottle', 'Water Supplier', NULL, NULL, true, NOW(), NOW(), NULL),
(gen_random_uuid(), '20rs Water', 'Mineral water - large bottle', 'Drinks', 20.00, 10.00, 80, 15, 'bottle', 'Water Supplier', NULL, NULL, true, NOW(), NOW(), NULL),

-- Drinks - Tea
(gen_random_uuid(), '10rs Tea', 'Hot tea - regular size', 'Drinks', 10.00, 4.00, 30, 10, 'cup', 'Tea Supplier', NULL, NULL, true, NOW(), NOW(), NULL),

-- Snacks - Chips & Popcorn
(gen_random_uuid(), '20rs Chips & Popcorn', 'Mixed chips and popcorn pack', 'Snacks', 20.00, 12.00, 60, 15, 'packet', 'Snacks Distributor', NULL, NULL, true, NOW(), NOW(), NULL),
(gen_random_uuid(), '10rs Chips', 'Small chips packet', 'Snacks', 10.00, 6.00, 80, 20, 'packet', 'Snacks Distributor', NULL, NULL, true, NOW(), NOW(), NULL),

-- Snacks - Biscuits
(gen_random_uuid(), '5rs Biscuit', 'Small biscuit pack', 'Snacks', 5.00, 3.00, 100, 25, 'packet', 'Biscuit Supplier', NULL, NULL, true, NOW(), NOW(), NULL),
(gen_random_uuid(), '10rs Biscuit', 'Medium biscuit pack', 'Snacks', 10.00, 6.00, 75, 20, 'packet', 'Biscuit Supplier', NULL, NULL, true, NOW(), NOW(), NULL),
(gen_random_uuid(), '25rs Biscuit', 'Large premium biscuit pack', 'Snacks', 25.00, 15.00, 40, 10, 'packet', 'Biscuit Supplier', NULL, NULL, true, NOW(), NOW(), NULL),

-- Snacks - Vadai
(gen_random_uuid(), '10rs Vadai', 'Traditional South Indian snack', 'Snacks', 10.00, 5.00, 25, 8, 'piece', 'Local Kitchen', NULL, NULL, true, NOW(), NOW(), NULL);

-- Update sequence if needed (for PostgreSQL)
-- This ensures the next auto-generated ID doesn't conflict
-- SELECT setval('products_id_seq', (SELECT MAX(id) FROM products) + 1);

-- Verification query to check inserted data
-- SELECT name, category, price, stock_quantity, minimum_stock, unit FROM products ORDER BY category, price;
