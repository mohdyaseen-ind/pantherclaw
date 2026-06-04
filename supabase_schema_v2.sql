-- Pantherclaw Enterprise E-Commerce Schema (V2)
-- Featuring 100x Architecture Improvements, Constraints, Denormalization, and Indexes

-- ==========================================
-- 1. EXTENSIONS & UTILITIES
-- ==========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Auto-update updated_at column
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- 2. TABLES
-- ==========================================

-- USERS
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone_number TEXT,
  cashfree_customer_id TEXT UNIQUE,
  is_admin BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ADDRESSES (Normalized)
CREATE TABLE IF NOT EXISTS public.addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  label TEXT DEFAULT 'Home', -- 'Home', 'Work', 'Other'
  address_line_1 TEXT NOT NULL,
  address_line_2 TEXT,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'IN',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- CATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- PRODUCTS
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  subtitle TEXT,
  description TEXT,
  price INTEGER NOT NULL, -- Stored in paise/cents
  mrp INTEGER, -- Market retail price in paise (the crossed-out "was" price)
  images TEXT[] NOT NULL DEFAULT '{}', -- Cloudflare R2 URLs
  badge TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT mrp_gte_price CHECK (mrp IS NULL OR mrp >= price)
);

-- PRODUCT VARIANTS (Inventory tracking)
CREATE TABLE IF NOT EXISTS public.product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  sku TEXT UNIQUE NOT NULL,
  size TEXT NOT NULL,
  color TEXT,
  color_hex TEXT, -- e.g. '#6b8cba'
  inventory_count INTEGER NOT NULL DEFAULT 0 CHECK (inventory_count >= 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- REVIEWS & RATINGS
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  verified_purchase BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_product_review UNIQUE (user_id, product_id)
);

-- WISHLISTS
CREATE TABLE IF NOT EXISTS public.wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, product_id)
);

-- CART PERSISTENCE
CREATE TABLE IF NOT EXISTS public.cart_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.cart_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.cart_sessions(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(session_id, variant_id)
);

-- DISCOUNT CODES
CREATE TABLE IF NOT EXISTS public.discount_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  discount_type TEXT DEFAULT 'percent' CHECK (discount_type IN ('percent', 'fixed')),
  discount_value INTEGER NOT NULL,
  min_order_value INTEGER DEFAULT 0, -- minimum cart value in paise
  max_uses INTEGER DEFAULT NULL, -- NULL = unlimited
  used_count INTEGER DEFAULT 0 NOT NULL,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- SHIPPING CONFIGURATION
CREATE TABLE IF NOT EXISTS public.shipping_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  free_above INTEGER NOT NULL DEFAULT 99900,  -- free shipping above ₹999
  flat_rate INTEGER NOT NULL DEFAULT 4900,    -- ₹49 flat rate
  express_rate INTEGER NOT NULL DEFAULT 14900 -- ₹149 express
);

-- NEWSLETTER SUBSCRIBERS
CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  subscribed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- ORDERS
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  cashfree_order_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'refunded', 'return_requested')
  ),
  subtotal INTEGER NOT NULL,
  discount_code_id UUID REFERENCES public.discount_codes(id),
  discount_applied INTEGER DEFAULT 0,
  shipping_fee INTEGER DEFAULT 0,
  total_amount INTEGER NOT NULL,
  shipping_address_id UUID REFERENCES public.addresses(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ORDER ITEMS (Denormalized to prevent historical data rot)
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,     -- snapshot at time of purchase
  product_image TEXT,              -- snapshot at time of purchase  
  size TEXT NOT NULL,              -- snapshot at time of purchase
  color TEXT,
  quantity INTEGER NOT NULL DEFAULT 1,
  price_at_purchase INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- PAYMENTS
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  cashfree_payment_id TEXT UNIQUE,
  cashfree_signature TEXT,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'initiated',
  payment_method TEXT,
  failure_reason TEXT,
  cashfree_refund_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  old_data JSONB,
  new_data JSONB,
  performed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- ==========================================
-- 3. INDEXES FOR PERFORMANCE
-- ==========================================
-- Products
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);

-- Variants
CREATE INDEX IF NOT EXISTS idx_variants_product ON public.product_variants(product_id);

-- Orders
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON public.orders(created_at DESC);

-- Reviews
CREATE INDEX IF NOT EXISTS idx_reviews_product ON public.reviews(product_id);

-- Audit logs
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_table_record ON public.audit_logs(table_name, record_id);


-- ==========================================
-- 4. TRIGGERS
-- ==========================================
CREATE TRIGGER set_updated_at_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_products BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_variants BEFORE UPDATE ON public.product_variants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_orders BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Audit Log Trigger Function
CREATE OR REPLACE FUNCTION log_audit_event() RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    INSERT INTO public.audit_logs (action, table_name, record_id, old_data, new_data, performed_by)
    VALUES ('UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, auth.uid());
  ELSIF (TG_OP = 'DELETE') THEN
    INSERT INTO public.audit_logs (action, table_name, record_id, old_data, performed_by)
    VALUES ('DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD)::jsonb, auth.uid());
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_products_trigger AFTER UPDATE OR DELETE ON public.products FOR EACH ROW EXECUTE FUNCTION log_audit_event();
CREATE TRIGGER audit_inventory_trigger AFTER UPDATE OR DELETE ON public.product_variants FOR EACH ROW EXECUTE FUNCTION log_audit_event();


-- ==========================================
-- 5. MATERIALIZED VIEWS
-- ==========================================
-- This completely flattens the complex joins so the frontend reads the catalog instantly
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_shop_catalog AS
SELECT 
  p.id,
  p.slug,
  p.name,
  p.subtitle,
  p.description,
  p.price,
  p.mrp,
  p.images,
  p.badge,
  c.name AS category_name,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', v.id, 
        'sku', v.sku, 
        'size', v.size, 
        'color', v.color,
        'color_hex', v.color_hex,
        'inventory_count', v.inventory_count
      )
    ) FILTER (WHERE v.id IS NOT NULL), '[]'::jsonb
  ) as variants,
  COALESCE(AVG(r.rating), 0) as average_rating,
  COUNT(r.id) as review_count
FROM public.products p
LEFT JOIN public.categories c ON p.category_id = c.id
LEFT JOIN public.product_variants v ON v.product_id = p.id
LEFT JOIN public.reviews r ON r.product_id = p.id
WHERE p.is_active = true
GROUP BY p.id, c.name;

CREATE UNIQUE INDEX idx_mv_shop_catalog_id ON public.mv_shop_catalog(id);

-- Function to refresh the view (call this via trigger when products update)
CREATE OR REPLACE FUNCTION refresh_mv_shop_catalog()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_shop_catalog;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refresh_catalog_on_product_change AFTER INSERT OR UPDATE OR DELETE ON public.products FOR EACH STATEMENT EXECUTE FUNCTION refresh_mv_shop_catalog();
CREATE TRIGGER refresh_catalog_on_variant_change AFTER INSERT OR UPDATE OR DELETE ON public.product_variants FOR EACH STATEMENT EXECUTE FUNCTION refresh_mv_shop_catalog();


-- ==========================================
-- 6. ATOMIC CHECKOUT (Concurrency Control)
-- ==========================================
-- Using SELECT FOR UPDATE to prevent overselling the same jeans
CREATE OR REPLACE FUNCTION process_checkout(p_user_id UUID, p_session_id UUID, p_address_id UUID, p_discount_code TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id UUID;
  v_item RECORD;
  v_total INTEGER := 0;
  v_discount_record RECORD;
  v_discount_amount INTEGER := 0;
  v_shipping_fee INTEGER := 0;
  v_shipping_config RECORD;
BEGIN
  -- 1. Lock the variants we are buying to prevent race conditions
  -- If another user is buying the same variant concurrently, this thread waits until they finish
  FOR v_item IN 
    SELECT ci.variant_id, ci.quantity, pv.inventory_count, p.price 
    FROM public.cart_items ci
    JOIN public.product_variants pv ON ci.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    WHERE ci.session_id = p_session_id
    FOR UPDATE OF pv -- ROW LEVEL LOCK
  LOOP
    IF v_item.inventory_count < v_item.quantity THEN
      RAISE EXCEPTION 'Not enough inventory for variant %', v_item.variant_id;
    END IF;
    
    -- Calculate Subtotal
    v_total := v_total + (v_item.price * v_item.quantity);
    
    -- Deduct inventory
    UPDATE public.product_variants 
    SET inventory_count = inventory_count - v_item.quantity 
    WHERE id = v_item.variant_id;
  END LOOP;

  -- 2. Apply discount if valid
  IF p_discount_code IS NOT NULL THEN
    SELECT * INTO v_discount_record 
    FROM public.discount_codes 
    WHERE code = p_discount_code 
    AND is_active = true 
    AND (expires_at IS NULL OR expires_at > now())
    AND (max_uses IS NULL OR used_count < max_uses)
    AND v_total >= min_order_value;

    IF FOUND THEN
      IF v_discount_record.discount_type = 'percent' THEN
        v_discount_amount := (v_total * v_discount_record.discount_value) / 100;
      ELSE
        v_discount_amount := v_discount_record.discount_value;
      END IF;

      -- Increment usage
      UPDATE public.discount_codes 
      SET used_count = used_count + 1 
      WHERE id = v_discount_record.id;
    END IF;
  END IF;

  -- 3. Calculate Shipping
  SELECT * INTO v_shipping_config FROM public.shipping_config LIMIT 1;
  IF FOUND AND (v_total - v_discount_amount) < v_shipping_config.free_above THEN
    v_shipping_fee := v_shipping_config.flat_rate;
  END IF;

  -- 4. Create the Order
  INSERT INTO public.orders (user_id, status, subtotal, discount_code_id, discount_applied, shipping_fee, total_amount, shipping_address_id)
  VALUES (
    p_user_id, 'pending', v_total, 
    v_discount_record.id, v_discount_amount, v_shipping_fee, 
    (v_total - v_discount_amount + v_shipping_fee), p_address_id
  )
  RETURNING id INTO v_order_id;

  -- 5. Move Cart Items to Order Items (Denormalized)
  INSERT INTO public.order_items (order_id, variant_id, quantity, price_at_purchase, product_name, product_image, size, color)
  SELECT v_order_id, ci.variant_id, ci.quantity, p.price, p.name, p.images[1], pv.size, pv.color
  FROM public.cart_items ci
  JOIN public.product_variants pv ON ci.variant_id = pv.id
  JOIN public.products p ON pv.product_id = p.id
  WHERE ci.session_id = p_session_id;

  -- 6. Clear Cart
  DELETE FROM public.cart_items WHERE session_id = p_session_id;

  RETURN v_order_id;
END;
$$;


-- ==========================================
-- 7. ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;

-- Admins can do anything
CREATE POLICY "Admins have full access" ON public.products FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));
CREATE POLICY "Admins have full access variants" ON public.product_variants FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));
CREATE POLICY "Admins have full access discounts" ON public.discount_codes FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));
CREATE POLICY "Admins have full access orders" ON public.orders FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));
CREATE POLICY "Admins have full access categories" ON public.categories FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));
CREATE POLICY "Admins have full access shipping" ON public.shipping_config FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND is_admin = true));

-- Public Readers
CREATE POLICY "Anyone can read categories" ON public.categories FOR SELECT USING (is_active = true);
CREATE POLICY "Anyone can read active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Anyone can read active variants" ON public.product_variants FOR SELECT USING (true);
CREATE POLICY "Anyone can read reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Anyone can read shipping config" ON public.shipping_config FOR SELECT USING (true);

-- Authenticated User Isolation
CREATE POLICY "Users view own profile" ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "Users edit own profile" ON public.users FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Users view own addresses" ON public.addresses FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own addresses" ON public.addresses FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own addresses" ON public.addresses FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users view own wishlist" ON public.wishlists FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own wishlist" ON public.wishlists FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users delete own wishlist" ON public.wishlists FOR DELETE USING (user_id = auth.uid());

CREATE POLICY "Users view own cart" ON public.cart_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own cart" ON public.cart_sessions FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users manage own cart items" ON public.cart_items FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.cart_sessions 
    WHERE cart_sessions.id = cart_items.session_id 
    AND cart_sessions.user_id = auth.uid()
  )
);

CREATE POLICY "Users view own orders" ON public.orders FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users view own order items" ON public.order_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()));
CREATE POLICY "Users view own payments" ON public.payments FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE orders.id = payments.order_id AND orders.user_id = auth.uid()));

-- Realtime Setup
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.product_variants;
