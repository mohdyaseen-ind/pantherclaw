-- ================================================================
-- PANTHERCLAW - MASTER DATABASE SCHEMA (v3 - Color-First & Unified Inventory)
-- 
-- INSTRUCTIONS:
-- 1. Go to Supabase SQL Editor.
-- 2. If you are wiping an old database, drop existing tables first.
-- 3. Run this entire script to build the world-class backend.
-- ================================================================

-- ================================================================
-- SECTION 1: EXTENSIONS
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ================================================================
-- SECTION 2: UTILITY FUNCTIONS & AUTH HOOKS
-- ================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Sync auth.users to public.users on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: Dropping the trigger requires superuser, so we wrap it in a DO block if needed, 
-- but standard Supabase allows it in the SQL editor.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ================================================================
-- SECTION 3: CORE TABLES
-- (in FK dependency order — do not reorder)
-- ================================================================

-- ── USERS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                    UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                 TEXT        NOT NULL UNIQUE,
  full_name             TEXT,
  phone_number          TEXT,
  cashfree_customer_id  TEXT        UNIQUE,
  is_admin              BOOLEAN     DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── ADDRESSES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.addresses (
  id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID        REFERENCES public.users(id) ON DELETE CASCADE,
  label            TEXT        DEFAULT 'Home',
  address_line_1   TEXT        NOT NULL,
  address_line_2   TEXT,
  city             TEXT        NOT NULL,
  state            TEXT        NOT NULL,
  postal_code      TEXT        NOT NULL,
  country          TEXT        NOT NULL DEFAULT 'IN',
  is_default       BOOLEAN     DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── CATEGORIES (self-referencing for hierarchy) ─────────────────
CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id   UUID        REFERENCES public.categories(id) ON DELETE SET NULL,
  slug        TEXT        NOT NULL UNIQUE,
  name        TEXT        NOT NULL,
  image_url   TEXT,
  sort_order  INTEGER     DEFAULT 0,
  is_active   BOOLEAN     DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── SIZES (predefined master list) ─────────────────────────────
-- This controls what sizes exist across ALL products.
-- Adding a new size here auto-creates variants for every color.
CREATE TABLE IF NOT EXISTS public.sizes (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  label       TEXT        NOT NULL UNIQUE,  -- 'XS', 'S', 'M', 'L', 'XL', 'XXL'
  sort_order  INTEGER     NOT NULL,
  is_active   BOOLEAN     DEFAULT true
);

-- ── PRODUCTS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id         UUID        REFERENCES public.categories(id) ON DELETE SET NULL,
  slug                TEXT        NOT NULL UNIQUE,
  name                TEXT        NOT NULL,
  subtitle            TEXT,
  description         TEXT,
  price               INTEGER     NOT NULL,         -- selling price in paise
  mrp                 INTEGER,                       -- original price in paise (for strikethrough)
  images              TEXT[]      NOT NULL DEFAULT '{}',  -- fallback / og:image thumbnail
  badge               TEXT,                          -- 'New', 'Bestseller', 'Sale'
  fit_type            TEXT,                          -- 'Wide Leg', 'Slim', 'Relaxed'
  fabric_details      TEXT,
  care_instructions   TEXT,
  is_active           BOOLEAN     DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT mrp_gte_price CHECK (mrp IS NULL OR mrp >= price)
);

-- ── PRODUCT COLORS ─────────────────────────────────────────────
-- One row per color per product.
-- Images live HERE — not on products, not on variants.
CREATE TABLE IF NOT EXISTS public.product_colors (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id  UUID        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  color_name  TEXT        NOT NULL,        -- 'Midnight Black'
  color_slug  TEXT        NOT NULL,        -- 'midnight-black'
  color_hex   TEXT        NOT NULL,        -- '#111111'
  images      TEXT[]      NOT NULL DEFAULT '{}',  -- Cloudflare R2 URLs for THIS color
  sort_order  INTEGER     DEFAULT 0,       -- controls swatch order; 0 = default shown
  is_active   BOOLEAN     DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT uq_product_color_name UNIQUE (product_id, color_name),
  CONSTRAINT uq_product_color_slug UNIQUE (product_id, color_slug)
);

-- ── PRODUCT VARIANTS ───────────────────────────────────────────
-- One row per color+size combination.
-- AUTO-CREATED by trigger when a color is added.
CREATE TABLE IF NOT EXISTS public.product_variants (
  id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id       UUID        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  color_id         UUID        NOT NULL REFERENCES public.product_colors(id) ON DELETE CASCADE,
  size_id          UUID        NOT NULL REFERENCES public.sizes(id) ON DELETE RESTRICT,

  -- Denormalized copies for fast reads without joins
  sku              TEXT        NOT NULL UNIQUE,
  size             TEXT        NOT NULL,        -- copy of sizes.label
  color            TEXT        NOT NULL,        -- copy of product_colors.color_name
  color_hex        TEXT        NOT NULL,        -- copy of product_colors.color_hex

  inventory_count  INTEGER     NOT NULL DEFAULT 0 CHECK (inventory_count >= 0),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  -- One row per color+size, no duplicates ever
  CONSTRAINT uq_color_size UNIQUE (color_id, size_id)
);

-- ── REVIEWS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID        REFERENCES public.users(id) ON DELETE CASCADE,
  product_id        UUID        REFERENCES public.products(id) ON DELETE CASCADE,
  rating            INTEGER     NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment           TEXT,
  verified_purchase BOOLEAN     DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT uq_user_product_review UNIQUE (user_id, product_id)
);

-- ── WISHLISTS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wishlists (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        REFERENCES public.users(id) ON DELETE CASCADE,
  product_id  UUID        REFERENCES public.products(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT uq_wishlist_item UNIQUE (user_id, product_id)
);

-- ── CART SESSIONS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cart_sessions (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── CART ITEMS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cart_items (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id  UUID        REFERENCES public.cart_sessions(id) ON DELETE CASCADE,
  variant_id  UUID        REFERENCES public.product_variants(id) ON DELETE CASCADE,
  quantity    INTEGER     NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT uq_cart_item UNIQUE (session_id, variant_id)
);

-- ── DISCOUNT CODES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.discount_codes (
  id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  code             TEXT        NOT NULL UNIQUE,
  discount_type    TEXT        NOT NULL DEFAULT 'percent'
                               CHECK (discount_type IN ('percent', 'fixed')),
  discount_value   INTEGER     NOT NULL CHECK (discount_value > 0),
  min_order_value  INTEGER     DEFAULT 0,
  max_uses         INTEGER,
  used_count       INTEGER     NOT NULL DEFAULT 0,
  is_active        BOOLEAN     DEFAULT true,
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT discount_percent_max CHECK (
    discount_type != 'percent' OR discount_value <= 100
  )
);

-- ── SHIPPING CONFIG ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shipping_config (
  id            UUID     PRIMARY KEY DEFAULT uuid_generate_v4(),
  free_above    INTEGER  NOT NULL DEFAULT 99900,
  flat_rate     INTEGER  NOT NULL DEFAULT 4900,
  express_rate  INTEGER  NOT NULL DEFAULT 14900
);

-- ── NEWSLETTER SUBSCRIBERS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           TEXT        NOT NULL UNIQUE,
  is_active       BOOLEAN     DEFAULT true,
  subscribed_at   TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- ── ORDERS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id              UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  cashfree_order_id    TEXT        UNIQUE,
  status               TEXT        NOT NULL DEFAULT 'pending'
                                   CHECK (status IN (
                                     'pending', 'paid', 'shipped',
                                     'delivered', 'cancelled',
                                     'refunded', 'return_requested'
                                   )),
  subtotal             INTEGER     NOT NULL,
  discount_code_id     UUID        REFERENCES public.discount_codes(id),
  discount_applied     INTEGER     DEFAULT 0,
  shipping_fee         INTEGER     DEFAULT 0,
  total_amount         INTEGER     NOT NULL,
  shipping_address_id  UUID        REFERENCES public.addresses(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── ORDER ITEMS ────────────────────────────────────────────────
-- Fully denormalized snapshot — survives product edits/deletions.
CREATE TABLE IF NOT EXISTS public.order_items (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id            UUID        REFERENCES public.orders(id) ON DELETE CASCADE,
  variant_id          UUID        REFERENCES public.product_variants(id) ON DELETE SET NULL,
  product_name        TEXT        NOT NULL,   -- snapshot
  product_image       TEXT,                   -- snapshot
  size                TEXT        NOT NULL,   -- snapshot
  color               TEXT,                   -- snapshot
  quantity            INTEGER     NOT NULL DEFAULT 1,
  price_at_purchase   INTEGER     NOT NULL,   -- snapshot
  created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── PAYMENTS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payments (
  id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id              UUID        REFERENCES public.orders(id) ON DELETE CASCADE,
  cashfree_payment_id   TEXT        UNIQUE,
  cashfree_signature    TEXT,
  amount                INTEGER     NOT NULL,
  status                TEXT        NOT NULL DEFAULT 'initiated',
  payment_method        TEXT,
  failure_reason        TEXT,
  cashfree_refund_id    TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── INVENTORY LOGS ─────────────────────────────────────────────
-- Full history of every stock change. Never lose data.
CREATE TABLE IF NOT EXISTS public.inventory_logs (
  id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  variant_id       UUID        NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
  change_type      TEXT        NOT NULL CHECK (change_type IN (
                                 'restock',     -- supplier delivery
                                 'sale',        -- customer purchase
                                 'return',      -- customer return
                                 'adjustment',  -- manual correction
                                 'damage'       -- item damaged/lost
                               )),
  quantity_delta   INTEGER     NOT NULL,   -- positive = added, negative = removed
  quantity_before  INTEGER     NOT NULL,   -- stock level before this change
  quantity_after   INTEGER     NOT NULL,   -- stock level after this change
  note             TEXT,
  performed_by     UUID        REFERENCES auth.users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ── AUDIT LOGS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  action        TEXT        NOT NULL,
  table_name    TEXT        NOT NULL,
  record_id     UUID        NOT NULL,
  old_data      JSONB,
  new_data      JSONB,
  performed_by  UUID        REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);


-- ================================================================
-- SECTION 4: INDEXES
-- ================================================================

-- Products
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(is_active);

-- Product Colors
CREATE INDEX IF NOT EXISTS idx_product_colors_product ON public.product_colors(product_id);
CREATE INDEX IF NOT EXISTS idx_product_colors_active ON public.product_colors(product_id, is_active);

-- Product Variants
CREATE INDEX IF NOT EXISTS idx_variants_product ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_variants_color ON public.product_variants(color_id);
CREATE INDEX IF NOT EXISTS idx_variants_size ON public.product_variants(size_id);

-- Reviews
CREATE INDEX IF NOT EXISTS idx_reviews_product ON public.reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user ON public.reviews(user_id);

-- Cart
CREATE INDEX IF NOT EXISTS idx_cart_items_session ON public.cart_items(session_id);

-- Orders
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

-- Inventory Logs
CREATE INDEX IF NOT EXISTS idx_inv_log_variant ON public.inventory_logs(variant_id);
CREATE INDEX IF NOT EXISTS idx_inv_log_created ON public.inventory_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_log_type ON public.inventory_logs(change_type);

-- Audit Logs
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_table_record ON public.audit_logs(table_name, record_id);


-- ================================================================
-- SECTION 5: UPDATED_AT TRIGGERS
-- ================================================================

CREATE TRIGGER set_updated_at_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_products BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_variants BEFORE UPDATE ON public.product_variants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_updated_at_orders BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ================================================================
-- SECTION 6: AUDIT LOG TRIGGER
-- ================================================================

CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    INSERT INTO public.audit_logs
      (action, table_name, record_id, old_data, new_data, performed_by)
    VALUES
      ('UPDATE', TG_TABLE_NAME, NEW.id,
       row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, auth.uid());
  ELSIF (TG_OP = 'DELETE') THEN
    INSERT INTO public.audit_logs
      (action, table_name, record_id, old_data, performed_by)
    VALUES
      ('DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD)::jsonb, auth.uid());
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_products_trigger AFTER UPDATE OR DELETE ON public.products FOR EACH ROW EXECUTE FUNCTION log_audit_event();
CREATE TRIGGER audit_variants_trigger AFTER UPDATE OR DELETE ON public.product_variants FOR EACH ROW EXECUTE FUNCTION log_audit_event();
CREATE TRIGGER audit_orders_trigger AFTER UPDATE OR DELETE ON public.orders FOR EACH ROW EXECUTE FUNCTION log_audit_event();


-- ================================================================
-- SECTION 7: AUTO-VARIANT CREATION TRIGGERS
-- ================================================================

-- ── Trigger A: New color added → auto-create all size variants ──
CREATE OR REPLACE FUNCTION auto_create_variants_for_new_color()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_product_slug TEXT;
BEGIN
  SELECT slug INTO v_product_slug FROM public.products WHERE id = NEW.product_id;

  INSERT INTO public.product_variants (
    product_id, color_id, size_id, size, color, color_hex, sku, inventory_count
  )
  SELECT
    NEW.product_id, NEW.id, s.id, s.label, NEW.color_name, NEW.color_hex,
    LOWER(v_product_slug || '-' || NEW.color_slug || '-' || s.label), 0
  FROM public.sizes s
  WHERE s.is_active = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_color_insert_create_variants ON public.product_colors;
CREATE TRIGGER on_color_insert_create_variants
  AFTER INSERT ON public.product_colors
  FOR EACH ROW EXECUTE FUNCTION auto_create_variants_for_new_color();

-- ── Trigger B: New size added globally → add to every color ────
CREATE OR REPLACE FUNCTION auto_create_variants_for_new_size()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.product_variants (
    product_id, color_id, size_id, size, color, color_hex, sku, inventory_count
  )
  SELECT
    pc.product_id, pc.id, NEW.id, NEW.label, pc.color_name, pc.color_hex,
    LOWER((SELECT slug FROM public.products WHERE id = pc.product_id) || '-' || pc.color_slug || '-' || NEW.label), 0
  FROM public.product_colors pc
  WHERE pc.is_active = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_size_insert_create_variants ON public.sizes;
CREATE TRIGGER on_size_insert_create_variants
  AFTER INSERT ON public.sizes
  FOR EACH ROW EXECUTE FUNCTION auto_create_variants_for_new_size();

-- ── Trigger C: Color name/hex updated → sync denormalized copies ─
CREATE OR REPLACE FUNCTION sync_color_updates_to_variants()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.color_name != OLD.color_name OR NEW.color_hex != OLD.color_hex THEN
    UPDATE public.product_variants
    SET color = NEW.color_name, color_hex = NEW.color_hex
    WHERE color_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_color_update_sync_variants ON public.product_colors;
CREATE TRIGGER on_color_update_sync_variants
  AFTER UPDATE ON public.product_colors
  FOR EACH ROW EXECUTE FUNCTION sync_color_updates_to_variants();


-- ================================================================
-- SECTION 8: INVENTORY MANAGEMENT FUNCTION
-- ================================================================

CREATE OR REPLACE FUNCTION update_inventory(
  p_variant_id   UUID,
  p_change_type  TEXT,
  p_quantity     INTEGER,
  p_note         TEXT    DEFAULT NULL,
  p_performed_by UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before  INTEGER;
  v_after   INTEGER;
  v_delta   INTEGER;
BEGIN
  SELECT inventory_count INTO v_before FROM public.product_variants WHERE id = p_variant_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Variant % not found', p_variant_id; END IF;

  CASE p_change_type
    WHEN 'sale'       THEN v_delta := -ABS(p_quantity);
    WHEN 'damage'     THEN v_delta := -ABS(p_quantity);
    WHEN 'adjustment' THEN v_delta := p_quantity;
    ELSE                   v_delta := ABS(p_quantity);
  END CASE;

  v_after := v_before + v_delta;
  IF v_after < 0 THEN
    RAISE EXCEPTION 'Stock cannot go below 0. Current: %, Requested change: %. Variant: %', v_before, v_delta, p_variant_id;
  END IF;

  UPDATE public.product_variants SET inventory_count = v_after, updated_at = timezone('utc', now()) WHERE id = p_variant_id;

  INSERT INTO public.inventory_logs (variant_id, change_type, quantity_delta, quantity_before, quantity_after, note, performed_by)
  VALUES (p_variant_id, p_change_type, v_delta, v_before, v_after, p_note, p_performed_by);

  RETURN jsonb_build_object('variant_id', p_variant_id, 'before', v_before, 'after', v_after, 'delta', v_delta, 'change_type', p_change_type);
END;
$$;


-- ================================================================
-- SECTION 9: ATOMIC CHECKOUT FUNCTION
-- ================================================================

CREATE OR REPLACE FUNCTION process_checkout(
  p_user_id       UUID,
  p_session_id    UUID,
  p_address_id    UUID,
  p_discount_code TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_order_id        UUID;
  v_item            RECORD;
  v_subtotal        INTEGER := 0;
  v_discount_type   TEXT;
  v_discount_value  INTEGER := 0;
  v_discount_fixed  INTEGER := 0;
  v_discount_id     UUID;
  v_shipping_fee    INTEGER := 0;
  v_free_above      INTEGER;
  v_flat_rate       INTEGER;
BEGIN
  SELECT COALESCE(free_above, 99900), COALESCE(flat_rate,  4900) INTO v_free_above, v_flat_rate FROM public.shipping_config LIMIT 1;

  FOR v_item IN
    SELECT ci.variant_id, ci.quantity, pv.inventory_count, p.price, p.name AS product_name, COALESCE(pc.images[1], p.images[1]) AS product_image, pv.size, pc.color_name AS color, pv.sku
    FROM public.cart_items ci
    JOIN public.product_variants pv  ON ci.variant_id  = pv.id
    JOIN public.product_colors   pc  ON pv.color_id    = pc.id
    JOIN public.products         p   ON pc.product_id  = p.id
    WHERE ci.session_id = p_session_id
    ORDER BY ci.variant_id
    FOR UPDATE OF pv
  LOOP
    IF v_item.inventory_count < v_item.quantity THEN
      RAISE EXCEPTION 'Only % unit(s) of % in size % left. Please update your bag.', v_item.inventory_count, v_item.product_name, v_item.size;
    END IF;
    
    v_subtotal := v_subtotal + (v_item.price * v_item.quantity);
    PERFORM update_inventory(v_item.variant_id, 'sale', v_item.quantity, 'Reserved for checkout session ' || p_session_id::TEXT, p_user_id);
  END LOOP;

  IF v_subtotal < v_free_above THEN v_shipping_fee := v_flat_rate; END IF;

  IF p_discount_code IS NOT NULL THEN
    SELECT id, discount_type, discount_value INTO v_discount_id, v_discount_type, v_discount_value
    FROM public.discount_codes
    WHERE code = p_discount_code AND is_active = true AND (expires_at IS NULL OR expires_at > now()) AND (max_uses IS NULL OR used_count < max_uses) AND v_subtotal >= min_order_value;
    
    IF NOT FOUND THEN RAISE EXCEPTION 'Discount code "%" is invalid, expired, or minimum order not met.', p_discount_code; END IF;
    
    IF v_discount_type = 'percent' THEN v_discount_fixed := (v_subtotal * v_discount_value / 100);
    ELSE v_discount_fixed := LEAST(v_discount_value, v_subtotal); END IF;
    
    UPDATE public.discount_codes SET used_count = used_count + 1 WHERE id = v_discount_id;
  END IF;

  INSERT INTO public.orders (user_id, status, subtotal, discount_code_id, discount_applied, shipping_fee, total_amount, shipping_address_id)
  VALUES (p_user_id, 'pending', v_subtotal, v_discount_id, v_discount_fixed, v_shipping_fee, v_subtotal - v_discount_fixed + v_shipping_fee, p_address_id)
  RETURNING id INTO v_order_id;

  INSERT INTO public.order_items (order_id, variant_id, product_name, product_image, size, color, quantity, price_at_purchase)
  SELECT v_order_id, ci.variant_id, p.name, COALESCE(pc.images[1], p.images[1]), pv.size, pc.color_name, ci.quantity, p.price
  FROM public.cart_items ci
  JOIN public.product_variants pv  ON ci.variant_id = pv.id
  JOIN public.product_colors   pc  ON pv.color_id   = pc.id
  JOIN public.products         p   ON pc.product_id = p.id
  WHERE ci.session_id = p_session_id;

  DELETE FROM public.cart_items WHERE session_id = p_session_id;
  RETURN v_order_id;
END;
$$;


-- ================================================================
-- SECTION 10: STANDARD VIEW — COLOR CATALOG
-- ================================================================
-- Replaced Materialized View with Standard View to avoid trigger lock crashes.
-- Uses LATERAL/Subqueries to avoid Cartesian product explosion on variants × reviews.

DROP MATERIALIZED VIEW IF EXISTS public.mv_color_catalog CASCADE;
DROP VIEW IF EXISTS public.color_catalog CASCADE;

CREATE OR REPLACE VIEW public.color_catalog AS
SELECT
  pc.id            AS color_id,
  pc.color_slug,
  pc.color_name,
  pc.color_hex,
  pc.images,
  pc.sort_order,
  p.id             AS product_id,
  p.slug           AS product_slug,
  p.name           AS product_name,
  p.subtitle,
  p.price,
  p.mrp,
  p.badge,
  p.fit_type,
  p.description,
  p.fabric_details,
  p.care_instructions,
  c.name           AS category_name,
  c.slug           AS category_slug,

  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'variant_id',      pv.id,
        'sku',             pv.sku,
        'size',            s.label,
        'sort_order',      s.sort_order,
        'inventory_count', pv.inventory_count,
        'in_stock',        (pv.inventory_count > 0)
      )
      ORDER BY s.sort_order
    )
    FROM public.product_variants pv
    JOIN public.sizes s ON s.id = pv.size_id
    WHERE pv.color_id = pc.id
  ) AS sizes,

  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'color_id',   pc2.id,
        'color_name', pc2.color_name,
        'color_hex',  pc2.color_hex,
        'color_slug', pc2.color_slug,
        'thumbnail',  pc2.images[1]
      )
      ORDER BY pc2.sort_order
    )
    FROM public.product_colors pc2
    WHERE pc2.product_id = p.id
      AND pc2.is_active  = true
  ) AS all_colors,

  (
    SELECT COALESCE(ROUND(AVG(rating)::NUMERIC, 1), 0)
    FROM public.reviews
    WHERE product_id = p.id
  ) AS average_rating,

  (
    SELECT COUNT(id)
    FROM public.reviews
    WHERE product_id = p.id
  ) AS review_count,

  EXISTS (
    SELECT 1 FROM public.product_variants pv2
    WHERE pv2.color_id = pc.id
      AND pv2.inventory_count > 0
  ) AS has_stock

FROM public.product_colors pc
JOIN public.products p ON p.id = pc.product_id
LEFT JOIN public.categories c ON c.id = p.category_id
WHERE p.is_active  = true
  AND pc.is_active = true;

-- Note: No refresh triggers are needed for a standard VIEW. It is always 100% real-time.


-- ================================================================
-- SECTION 11: ROW LEVEL SECURITY (RLS)
-- ================================================================

ALTER TABLE public.users                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sizes                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_colors        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_sessions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_codes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_config       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs            ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true);
$$;

-- ── PUBLIC READ policies ──────────────────────────────────────
CREATE POLICY "Public read active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Public read product colors" ON public.product_colors FOR SELECT USING (is_active = true);
CREATE POLICY "Public read product variants" ON public.product_variants FOR SELECT USING (true);
CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (is_active = true);
CREATE POLICY "Public read sizes" ON public.sizes FOR SELECT USING (is_active = true);
CREATE POLICY "Public read reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Public read shipping config" ON public.shipping_config FOR SELECT USING (true);

-- ── ADMIN FULL ACCESS policies ────────────────────────────────
CREATE POLICY "Admin full access users" ON public.users FOR ALL USING (is_admin());
CREATE POLICY "Admin full access addresses" ON public.addresses FOR ALL USING (is_admin());
CREATE POLICY "Admin full access categories" ON public.categories FOR ALL USING (is_admin());
CREATE POLICY "Admin full access sizes" ON public.sizes FOR ALL USING (is_admin());
CREATE POLICY "Admin full access products" ON public.products FOR ALL USING (is_admin());
CREATE POLICY "Admin full access colors" ON public.product_colors FOR ALL USING (is_admin());
CREATE POLICY "Admin full access variants" ON public.product_variants FOR ALL USING (is_admin());
CREATE POLICY "Admin full access reviews" ON public.reviews FOR ALL USING (is_admin());
CREATE POLICY "Admin full access wishlists" ON public.wishlists FOR ALL USING (is_admin());
CREATE POLICY "Admin full access cart_sessions" ON public.cart_sessions FOR ALL USING (is_admin());
CREATE POLICY "Admin full access cart_items" ON public.cart_items FOR ALL USING (is_admin());
CREATE POLICY "Admin full access discount codes" ON public.discount_codes FOR ALL USING (is_admin());
CREATE POLICY "Admin full access orders" ON public.orders FOR ALL USING (is_admin());
CREATE POLICY "Admin full access order_items" ON public.order_items FOR ALL USING (is_admin());
CREATE POLICY "Admin full access payments" ON public.payments FOR ALL USING (is_admin());
CREATE POLICY "Admin full access inventory logs" ON public.inventory_logs FOR ALL USING (is_admin());
CREATE POLICY "Admin full access audit logs" ON public.audit_logs FOR SELECT USING (is_admin());
CREATE POLICY "Admin full access newsletter" ON public.newsletter_subscribers FOR ALL USING (is_admin());

-- ── USER SELF policies ────────────────────────────────────────
CREATE POLICY "Users view own profile" ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "Users update own profile" ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "Users view own addresses" ON public.addresses FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own addresses" ON public.addresses FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own addresses" ON public.addresses FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users delete own addresses" ON public.addresses FOR DELETE USING (user_id = auth.uid());
CREATE POLICY "Users manage own wishlist" ON public.wishlists FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users manage own reviews" ON public.reviews FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own reviews" ON public.reviews FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users delete own reviews" ON public.reviews FOR DELETE USING (user_id = auth.uid());
CREATE POLICY "Users manage own cart session" ON public.cart_sessions FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users manage own cart items" ON public.cart_items FOR ALL USING (EXISTS (SELECT 1 FROM public.cart_sessions cs WHERE cs.id = cart_items.session_id AND cs.user_id = auth.uid()));
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users view own order items" ON public.order_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND o.user_id = auth.uid()));
CREATE POLICY "Users view own payments" ON public.payments FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = payments.order_id AND o.user_id = auth.uid()));
CREATE POLICY "Anyone can subscribe to newsletter" ON public.newsletter_subscribers FOR INSERT WITH CHECK (true);


-- ================================================================
-- SECTION 12: SEED DATA
-- ================================================================

INSERT INTO public.sizes (label, sort_order) VALUES
  ('XS',  1),
  ('S',   2),
  ('M',   3),
  ('L',   4),
  ('XL',  5),
  ('XXL', 6)
ON CONFLICT (label) DO NOTHING;

INSERT INTO public.shipping_config (free_above, flat_rate, express_rate)
VALUES (99900, 4900, 14900)
ON CONFLICT DO NOTHING;

INSERT INTO public.categories (slug, name, sort_order) VALUES
  ('women', 'Women',     1),
  ('men',   'Men',       2),
  ('new-in','New In',    3),
  ('sale',  'Sale',      4)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.categories (slug, name, parent_id, sort_order)
VALUES
  ('women-wide-leg',  'Wide Leg',   (SELECT id FROM public.categories WHERE slug='women'), 1),
  ('women-dark-wash', 'Dark Wash',  (SELECT id FROM public.categories WHERE slug='women'), 2),
  ('women-textured',  'Textured',   (SELECT id FROM public.categories WHERE slug='women'), 3),
  ('men-wide-leg',    'Wide Leg',   (SELECT id FROM public.categories WHERE slug='men'), 1),
  ('men-relaxed',     'Relaxed',    (SELECT id FROM public.categories WHERE slug='men'), 2),
  ('men-dark-wash',   'Dark Wash',  (SELECT id FROM public.categories WHERE slug='men'), 3)
ON CONFLICT (slug) DO NOTHING;


-- ================================================================
-- SECTION 13: REALTIME
-- ================================================================

-- Wrap in DO block to ignore if publications already exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  
  ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.product_colors;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.product_variants;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION WHEN OTHERS THEN
  -- Ignored
END;
$$;


-- ================================================================
-- DONE.
-- ================================================================
