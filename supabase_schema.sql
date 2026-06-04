-- Pantherclaw Enterprise E-Commerce Schema

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLES

-- Users / Customer Profiles
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone_number TEXT,
  shipping_address JSONB,
  razorpay_customer_id TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Products (Parent Items)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  subtitle TEXT,
  description TEXT,
  price INTEGER NOT NULL, -- Stored in paise/cents to avoid floating point math
  images TEXT[] NOT NULL DEFAULT '{}', -- Cloudflare R2 URLs
  badge TEXT,
  category TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Product Variants (Child Items - Inventory Tracking)
CREATE TABLE IF NOT EXISTS public.product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  sku TEXT UNIQUE NOT NULL,
  size TEXT NOT NULL,
  color TEXT,
  inventory_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Orders
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  razorpay_order_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, paid, shipped, delivered, cancelled
  total_amount INTEGER NOT NULL,
  shipping_address JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Order Items (Locks in price at time of purchase)
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  price_at_purchase INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Payments
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  razorpay_payment_id TEXT UNIQUE,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'initiated', -- initiated, captured, failed, refunded
  payment_method TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);

-- 4. HIGHLY OPTIMIZED RPC FUNCTION (Stored Procedure)
-- This function aggregates a product with all its variants into a single JSON response, avoiding N+1 queries.
CREATE OR REPLACE FUNCTION get_shop_catalog(category_filter TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'slug', p.slug,
      'name', p.name,
      'subtitle', p.subtitle,
      'price', p.price,
      'images', p.images,
      'badge', p.badge,
      'category', p.category,
      'variants', COALESCE(
        (SELECT jsonb_agg(
          jsonb_build_object(
            'id', v.id,
            'sku', v.sku,
            'size', v.size,
            'inventory_count', v.inventory_count
          )
        ) FROM public.product_variants v WHERE v.product_id = p.id), 
        '[]'::jsonb
      )
    )
  ) INTO result
  FROM public.products p
  WHERE p.is_active = true 
  AND (category_filter IS NULL OR p.category = category_filter);
  
  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- This is what makes using the Anon Key perfectly safe in the frontend!

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Products & Variants: Anyone can read them (Anon Key), but nobody can edit them from the frontend
CREATE POLICY "Allow public read access on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access on variants" ON public.product_variants FOR SELECT USING (true);

-- Orders: Users can only read and create their own orders (if logged in)
CREATE POLICY "Users can view their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Order Items: Users can only view items for their own orders
CREATE POLICY "Users can view their own order items" ON public.order_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid())
);

-- Payments: Users can view their own payments
CREATE POLICY "Users can view their own payments" ON public.payments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.orders WHERE orders.id = payments.order_id AND orders.user_id = auth.uid())
);


-- 6. REALTIME REPLICATION SETUP
-- Enable Realtime for the products table so the frontend cache invalidates automatically
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.product_variants;
