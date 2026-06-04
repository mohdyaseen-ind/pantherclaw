-- Pantherclaw Seed Data V2 (Updated for new constraints and columns)
-- Run this AFTER running supabase_schema_v2.sql

-- 1. Insert Categories
INSERT INTO public.categories (id, slug, name, sort_order)
VALUES 
  ('ca111111-1111-1111-1111-111111111111', 'men', 'Men', 1),
  ('ca222222-2222-2222-2222-222222222222', 'women', 'Women', 2);

-- 2. Insert Products
INSERT INTO public.products (id, category_id, slug, name, subtitle, description, price, mrp, images, badge, is_active)
VALUES 
  (
    '11111111-1111-1111-1111-111111111111', 
    'ca111111-1111-1111-1111-111111111111',
    'signature-baggy-light-wash', 
    'Signature Baggy', 
    'Light Wash · Baggy Wide-Leg', 
    'Our classic signature baggy fit. Engineered for excess volume without losing structure at the waist.', 
    4999, 
    5999,
    ARRAY['https://pub-your-r2-url.dev/img3.jpeg', 'https://pub-your-r2-url.dev/img4.jpeg'], 
    'Bestseller', 
    true
  ),
  (
    '22222222-2222-2222-2222-222222222222', 
    'ca111111-1111-1111-1111-111111111111',
    'obsidian-wide-leg', 
    'Obsidian Wide-Leg', 
    'Faded Black · Baggy Wide-Leg', 
    'Washed and faded to perfection. Heavyweight denim with a perfect drape.', 
    5499, 
    6499,
    ARRAY['https://pub-your-r2-url.dev/img1.jpeg', 'https://pub-your-r2-url.dev/img2.jpeg'], 
    'New', 
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333', 
    'ca222222-2222-2222-2222-222222222222',
    'vintage-wash-skater', 
    'Vintage Skater', 
    'Dirty Wash · Loose Skater', 
    'Inspired by 90s skate culture. Loose, relaxed, and incredibly durable.', 
    4299, 
    5299,
    ARRAY['https://pub-your-r2-url.dev/img5.jpeg', 'https://pub-your-r2-url.dev/img6.jpeg'], 
    NULL, 
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444', 
    'ca222222-2222-2222-2222-222222222222',
    'midnight-baggy-mens', 
    'Midnight Baggy', 
    'Carbon Black · Oversized Baggy', 
    'True carbon black dye. Oversized for maximum comfort and silhouette.', 
    5999, 
    7999,
    ARRAY['https://pub-your-r2-url.dev/img2.jpeg', 'https://pub-your-r2-url.dev/img1.jpeg'], 
    'Bestseller', 
    true
  );

-- 3. Insert Variants (Inventory for each product)
INSERT INTO public.product_variants (product_id, sku, size, color, color_hex, inventory_count)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-28', '28', 'Light Wash', '#89b6f5', 15),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-30', '30', 'Light Wash', '#89b6f5', 40),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-32', '32', 'Light Wash', '#89b6f5', 20),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-34', '34', 'Light Wash', '#89b6f5', 5),
  
  ('22222222-2222-2222-2222-222222222222', 'OBS-W-L-30', '30', 'Faded Black', '#2a2a2a', 10),
  ('22222222-2222-2222-2222-222222222222', 'OBS-W-L-32', '32', 'Faded Black', '#2a2a2a', 25),
  
  ('33333333-3333-3333-3333-333333333333', 'VIN-S-26', '26', 'Dirty Wash', '#a9b49e', 30),
  ('33333333-3333-3333-3333-333333333333', 'VIN-S-28', '28', 'Dirty Wash', '#a9b49e', 12),
  
  ('44444444-4444-4444-4444-444444444444', 'MID-B-26', '26', 'Carbon Black', '#111111', 50),
  ('44444444-4444-4444-4444-444444444444', 'MID-B-28', '28', 'Carbon Black', '#111111', 15);

-- 4. Seed Shipping Configuration
INSERT INTO public.shipping_config (id, free_above, flat_rate, express_rate)
VALUES ('sc111111-1111-1111-1111-111111111111', 99900, 4900, 14900);

-- 5. Refresh Materialized View
-- We must refresh it after seeding so the catalog isn't empty!
REFRESH MATERIALIZED VIEW public.mv_shop_catalog;
