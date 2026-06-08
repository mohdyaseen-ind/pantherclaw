-- Migration: Add images array to product_variants
-- Run this in your Supabase SQL Editor

ALTER TABLE public.product_variants 
ADD COLUMN images text[] NOT NULL DEFAULT '{}';
