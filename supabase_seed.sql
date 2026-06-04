-- Pantherclaw Seed Data
-- Run this AFTER running supabase_schema.sql

-- 1. Insert Products
INSERT INTO public.products (id, slug, name, subtitle, description, price, images, badge, category, is_active)
VALUES 
  (
    '11111111-1111-1111-1111-111111111111', 
    'signature-baggy-light-wash', 
    'Signature Baggy', 
    'Light Wash · Baggy Wide-Leg', 
    'Our classic signature baggy fit. Engineered for excess volume without losing structure at the waist.', 
    4999, 
    ARRAY['https://pub-your-r2-url.dev/img3.jpeg', 'https://pub-your-r2-url.dev/img4.jpeg'], 
    'Bestseller', 
    'Men', 
    true
  ),
  (
    '22222222-2222-2222-2222-222222222222', 
    'obsidian-wide-leg', 
    'Obsidian Wide-Leg', 
    'Faded Black · Baggy Wide-Leg', 
    'Washed and faded to perfection. Heavyweight denim with a perfect drape.', 
    5499, 
    ARRAY['https://pub-your-r2-url.dev/img1.jpeg', 'https://pub-your-r2-url.dev/img2.jpeg'], 
    'New', 
    'Men', 
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333', 
    'vintage-wash-skater', 
    'Vintage Skater', 
    'Dirty Wash · Loose Skater', 
    'Inspired by 90s skate culture. Loose, relaxed, and incredibly durable.', 
    4299, 
    ARRAY['https://pub-your-r2-url.dev/img5.jpeg', 'https://pub-your-r2-url.dev/img6.jpeg'], 
    NULL, 
    'Women', 
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444', 
    'midnight-baggy-mens', 
    'Midnight Baggy', 
    'Carbon Black · Oversized Baggy', 
    'True carbon black dye. Oversized for maximum comfort and silhouette.', 
    5999, 
    ARRAY['https://pub-your-r2-url.dev/img2.jpeg', 'https://pub-your-r2-url.dev/img1.jpeg'], 
    'Bestseller', 
    'Women', 
    true
  );

-- 2. Insert Variants (Inventory for each product)
-- Signature Baggy Variants
INSERT INTO public.product_variants (product_id, sku, size, color, inventory_count)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-28', '28', 'Light Wash', 15),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-30', '30', 'Light Wash', 40),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-32', '32', 'Light Wash', 20),
  ('11111111-1111-1111-1111-111111111111', 'SIG-L-W-34', '34', 'Light Wash', 5);

-- Obsidian Wide-Leg Variants
INSERT INTO public.product_variants (product_id, sku, size, color, inventory_count)
VALUES 
  ('22222222-2222-2222-2222-222222222222', 'OBS-W-L-30', '30', 'Faded Black', 10),
  ('22222222-2222-2222-2222-222222222222', 'OBS-W-L-32', '32', 'Faded Black', 25);

-- Vintage Skater Variants
INSERT INTO public.product_variants (product_id, sku, size, color, inventory_count)
VALUES 
  ('33333333-3333-3333-3333-333333333333', 'VIN-S-26', '26', 'Dirty Wash', 30),
  ('33333333-3333-3333-3333-333333333333', 'VIN-S-28', '28', 'Dirty Wash', 12);

-- Midnight Baggy Variants
INSERT INTO public.product_variants (product_id, sku, size, color, inventory_count)
VALUES 
  ('44444444-4444-4444-4444-444444444444', 'MID-B-26', '26', 'Carbon Black', 50),
  ('44444444-4444-4444-4444-444444444444', 'MID-B-28', '28', 'Carbon Black', 15);
